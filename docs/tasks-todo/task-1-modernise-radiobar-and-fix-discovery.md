# Modernise RadioBar and fix discovery

## Problem

RadioBar's Discover button cannot find the Roberts iStream 3L, even on a healthy network. The app also targets macOS 13 and Swift 5.9, pins a dependency version with known macOS 27 problems, and keeps everything in one 1,315-line file.

This task fixes discovery, moves the app to current macOS, Swift and SwiftUI, adopts useful protocol fixes from other FSAPI clients, and brings the CLI and docs up to date.

## Decisions

- **Target macOS 27 only.** This app is mainly for Danny, so there is no need to support older systems. Prefer modern macOS, Swift and SwiftUI APIs wherever they fit.
- **Use Swift 6 language mode.**
- **Keep sessionless polling.** Send the PIN on every request. Sessions can conflict with other clients and aren't needed for polling.
- **Verify before trusting a discovery result.** Only send the PIN to a host that has already identified itself as an FSAPI device.
- **Work on a branch in separate commits**, keeping mechanical changes apart from behaviour changes.

## Findings

### Network incident

During investigation the radio was playing normally but the Mac could not reach it. Restarting the radio restored ARP and Bonjour, but ping and HTTP still failed. A phone on the same Wi-Fi could load the radio's web UI. Restarting the BT Hub fixed the Mac's connection.

RadioBar can't repair this state, but it should describe it clearly rather than implying that no radio exists.

### Discovery

Tested against the live radio after the hub restart, unless noted:

| Method                | Sent by multicast | Sent directly to radio |
| --------------------- | ----------------- | ---------------------- |
| SSDP `undok`          | No reply          | Reply                  |
| SSDP `fs_reference`   | No reply          | No reply               |
| SSDP `invalid`        | Not tested        | No reply               |
| SSDP `ssdp:all`       | No reply          | Reply (as `undok`)     |
| Bonjour `_undok._tcp` | Intermittent      | No reply               |
| HTTP `/device`        | n/a               | Reply                  |

- **Root cause:** `discoverRadio` only searches for `urn:schemas-frontier-silicon-com:fs_reference:fsapi:1`. This radio answers `urn:schemas-frontier-silicon-com:undok:fsapi:1`.
- **Multicast is unreliable here.** Correcting the search target is not enough. Bonjour answered live once after the radio restarted, then did not answer in the post-hub-restart test. The Mac's Bonjour cache can also return the radio's address while the radio is unreachable, so a Bonjour result is only a candidate.
- **SSDP reply:** includes `LOCATION: http://192.168.1.72:80/device`, `SERVER: FOS/1.0 UPnP/1.0 Jupiter/6.5` and `SPEAKER-NAME: iStream3L`.
- **`/device`:** returns the firmware version and `webfsapi` URL, but its `friendlyName` is the placeholder `frname`. Get the real name from `netRemote.sys.info.friendlyName`.
- **Bonjour TXT record:** advertises `DeviceInfoLocation=/dd.xml`, but `/dd.xml` returns 404. Use `/device`.

Other discovery bugs in the current code:

- It sends a single UDP packet and accepts the first reply without checking that it came from a radio.
- A successful discovery doesn't update the settings IP field, so pressing "Set" afterwards restores the old IP.
- `discover()` calls `poll()`, which silently does nothing if another poll is already running.
- The app bundle declares neither `NSLocalNetworkUsageDescription` nor `NSBonjourServices`.

### Code and tooling

- `swift build -c release` passes.
- A trial build in Swift 6 language mode passes with one deprecation warning (`String(cString:)` in `discoverRadio`).
- SwiftLint reports one violation (`aspectRatio(contentMode:)` on the artwork).
- SwiftFormat 0.64.7 reports many violations across the file.
- MenuBarExtraAccess is pinned at 1.3.0. Version [1.3.1](https://github.com/orchetect/MenuBarExtraAccess/pull/26) adds macOS 27 support, and its PR says the macOS 27 changes "broke pretty much everything in this package". The app has not yet been run on macOS 27 as part of this work.
- Polling speed depends on the popover's `onAppear` and `onDisappear`, which need checking on macOS 27.
- `RadioViewModel` uses `ObservableObject`, so state changes invalidate more of the popover than necessary.
- Lists use tuples, playback status uses strings, polling uses `Timer`, discovery uses GCD and delays use `Task.sleep(nanoseconds:)`.
- `AGENTS.md` and the file header describe a single file built with `swiftc`, which no longer works because of the package dependency. `AGENTS.md` also says polling is always every 4 seconds, but it's 60 seconds while the popover is closed.

### Ecosystem changes since March 2026

Checked directly:

- [afsapi](https://github.com/wlcrs/python-afsapi) development moved to `wlcrs/python-afsapi` and is at 1.0.3 (2026-10-16).
- Home Assistant discovers these radios with the SSDP `undok` and `invalid` targets.
- Home Assistant [sends `stop` to restart a stopped stream](https://github.com/home-assistant/core/pull/168633) instead of `play`.

From research, not independently rechecked:

- [CVE-2026-94252](https://www.cryptron.ch/en/blog-detail/frontier-silicon-fs2340-xss-security-advisory.html) is an unpatched XSS in the FS2340 web UI, reported on firmware IR4.9. This radio runs V4.6.18, so whether it's affected is unconfirmed. RadioBar has no web view. Don't expose the radio's port 80 beyond the LAN.
- afsapi retries nav lists on `FS_NODE_BLOCKED` and on placeholder items of type `255`.
- [Muga](https://github.com/calvellido/muga) has useful protocol notes and a simulator. [fsapi-radio-controller](https://github.com/pandawidkur/fsapi-radio-controller) is another Swift menubar client.
- [Radio-API 3.0](https://github.com/KIMB-technologies/Radio-API/releases/tag/v3.0.0) supports the newer Airable JSON API and is the strongest self-hosted fallback, but is untested on Venice X.
- No evidence of an Airable shutdown or an FSAPI end-of-life notice.

## Phase 1: Modern foundation

Goal: the existing feature set runs cleanly on a modern base, with no intended behaviour changes.

Before writing SwiftUI or concurrency code, consult the `swiftui-specialist`, `swiftui-whats-new-27` and `swift-concurrency-pro` skills.

- [x] Apply the current SwiftFormat rules in a formatting-only commit.
- [x] Raise the minimum to macOS 27 in `Package.swift`, `scripts/build-app.sh` and `README.md`.
- [x] Move to the current Swift tools version and Swift 6 language mode. Update `.swift-version` and `.swiftformat`.
- [x] Update MenuBarExtraAccess to 1.3.1.
- [x] Confirm the popover works on macOS 27, including multi-monitor positioning.
- [x] Check whether native SwiftUI now covers what MenuBarExtraAccess provides. The macOS 27 SDK still has no native presented state or window access for `MenuBarExtra`, so the dependency stays.
- [x] Split `Sources/RadioBar.swift` into a small set of files by responsibility (app, FSAPI client and parsers, discovery, model, views) in a move-only commit.
- [x] Migrate the view model to `@Observable`.
- [x] Replace tuples with small `Identifiable` models and playback status strings with an enum.
- [x] Replace `Timer` with a single async polling loop and use `Task.sleep(for:)`.
- [x] Replace soft-deprecated SwiftUI APIs such as `foregroundColor` and `cornerRadius`, and fix the SwiftLint violation.
- [x] Confirm fast polling runs only while the popover is open.
- [x] Confirm every existing control still works in the real app.

Done when formatting, linting and the release build are clean, and every existing control still works in the real app.

## Phase 2: Discovery

Goal: RadioBar reliably finds the radio, and explains clearly when it can't.

Discovery order, stopping at the first verified radio:

1. Try the saved IP.
2. Run Bonjour (`NWBrowser`, `_undok._tcp`) and SSDP together. Search for `undok`, `fs_reference` and `invalid`, send more than once, and collect all replies.
3. Scan the Mac's current local subnet for `/device` with bounded concurrency.

Tasks:

- [x] Add a discovery service built on structured concurrency, using Network framework for Bonjour and path monitoring. SSDP stays on BSD sockets because Network framework can't receive unicast replies to a multicast send.
- [x] Verify candidates in two steps: `/device` must return a valid `webfsapi` URL before the PIN is sent, then an FSAPI read must succeed.
- [x] Store the radio's ID after connecting.
- [x] Rediscover automatically when the connection drops and when the network path changes, without repeatedly scanning the subnet.
- [x] Only let automatic rediscovery connect to the saved radio ID, so a laptop on someone else's network never takes control of their radio. Manual Discover may select a new radio.
- [x] Add `NSLocalNetworkUsageDescription` and `NSBonjourServices` to the app bundle.
- [x] Keep the settings IP field in sync with the active radio.
- [x] Make sure a discovery result always triggers a real refresh, even if a poll is in flight.
- [x] Show distinct states for no radio found, saved radio not responding, and wrong PIN. The not-responding state should suggest restarting the router if the radio is still playing.
- [x] Add focused Swift Testing coverage for FSAPI parsing, SSDP reply parsing and `/device` validation, using captured responses.
- [x] Confirm in the real app: Discover from a wrong IP and the wrong PIN message.
- [x] Confirm discovery works in the signed `.app`.
- [ ] Confirm reconnection after a Wi-Fi drop. Danny will test this later.

Done when Discover finds the radio from a wrong saved IP, reconnects after a network interruption, and never sends the PIN to a host that hasn't identified itself as FSAPI.

## Phase 3: Playback and browsing

Goal: controls match what the radio actually supports in each mode.

These tests change playback, so check with Danny before running them.

- [x] Test resuming from stopped on this radio. `play.control=1` resumes a stopped Internet Radio stream, so no workaround is needed. `play.control=2` returns `FS_FAIL` on a live stream.
- [x] Decode `netRemote.play.caps` using afsapi as a reference. Radio 4 in Internet Radio mode reports `2050` (Stop and Add Preset), dropping to `2048` while buffering.
- [ ] Confirm the decoded capabilities against this radio in the other modes, especially Next and Previous on DAB and FM.
- [x] Enable or hide transport controls and seeking based on those capabilities.
- [x] Handle loading placeholders and `FS_NODE_BLOCKED` in browse lists so they don't appear as rows.
- [x] Paginate lists with `LIST_GET_NEXT`, following `<listend/>`. The previous single request cut browse lists off at 200 items.
- [ ] Confirm the updated controls and browsing in the real app.

Done when each control behaves correctly in Internet Radio, Podcasts, Spotify, DAB, FM and Bluetooth, as far as those modes can be tested.

## Phase 4: CLI and docs

Goal: the CLI and documentation match how the project now works.

- [ ] Remove session handling from `bin/radio` and use the PIN on each request.
- [ ] Update `AGENTS.md` and `README.md` for the new structure, requirements, polling and discovery.
- [ ] Update `docs/fsapi-reference.md` with the SSDP target, `/device`, `/dd.xml` and Bonjour findings.
- [ ] Update `docs/community-projects.md` with the afsapi move, new clients and security advisory.
- [ ] Add a short troubleshooting note for the radio being online but unreachable from the Mac.

Done when a fresh reader can build, run and debug the project from the docs alone.

## Verification

Run after Swift changes:

```bash
swiftformat Sources/
swiftlint lint Sources/
swift build -c release
```

In Claude Code's sandbox, `swift build` needs `--disable-sandbox`, and requests to the radio need to run outside the sandbox.

Before changing anything audible on the radio, check with Danny. Read-only FSAPI requests are safe.

## Out of scope

- `GET_NOTIFIES` push updates, unless polling proves inadequate.
- A self-hosted Airable backend.
- Media key integration and global hotkeys.
- Publishing or notarising a new release.
