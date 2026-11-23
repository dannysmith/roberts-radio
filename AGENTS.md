# Roberts Radio Project

Personal project to control a **Roberts Revival iStream 3L** internet radio from macOS. The main output is **RadioBar**, a SwiftUI menubar app.

## The Radio

The Roberts Revival iStream 3L runs on the **Frontier Smart** platform (Venice X module, FS2340, Chorus 4 chip, SmartSDK firmware V4.6.18). It exposes a local HTTP API called **FSAPI** on port 80 for control, and connects to **Airable** cloud servers for station/podcast catalogs and favourites.

- **10 modes:** Internet Radio, Podcasts, Deezer, Amazon Music, Spotify, USB, DAB, FM, Bluetooth, Aux In
- **Default IP:** `192.168.1.72`, **PIN:** `1234`
- **Discoverable** via Bonjour (`_undok._tcp`), SSDP (`urn:schemas-frontier-silicon-com:undok:fsapi:1`) and `GET /device`
- No official API docs -- everything is community reverse-engineered

See `docs/fsapi-reference.md` for the full protocol and node reference.

## Project Structure

```
Sources/
  RadioBarApp.swift     # App entry point
  RadioViewModel.swift  # Radio state, polling, connection and commands
  RadioModels.swift     # Typed models for playback, presets, browsing and alarms
  Log.swift             # Debug logging
  FSAPI/                # HTTP client and XML parsers
  Discovery/            # Bonjour, SSDP, subnet scan and radio verification
  MacAudio/             # Bluetooth connection and Mac audio output switching
  Views/                # SwiftUI popover views
Tests/RadioBarTests/    # Swift Testing coverage for parsing and playback rules
bin/
  radiobar-gui          # Build & run script for RadioBar
  radio                 # Bash CLI tool for FSAPI (requires curl/xq/jq)
scripts/
  build-app.sh          # Builds and signs the .app bundle
docs/
  fsapi-reference.md    # FSAPI protocol spec, node tables, device-specific info
  community-projects.md # Community tools, libraries, self-hosted backends
  archive/              # Original research docs, probe script and results
```

## RadioBar (SwiftUI Menubar App)

SwiftUI app for macOS 27+, using Swift 6. Build and run without Xcode:

```bash
bin/radiobar-gui [--dock] [--debug]
```

**Features:**
- Now-playing display with artwork, progress bar (clickable where the source supports seeking)
- Playback controls that follow the source's capabilities
- Volume slider with mute
- Mode switching and EQ preset picker
- Preset selection (per-mode), with a count of used slots
- Station/podcast browsing via nav tree with a client-side filter
- Spotify Connect info (account, bitrate)
- Alarm display (collapsible)
- Radio discovery, with automatic reconnection to the saved radio
- Mac Audio button that plays this Mac's audio through the radio over Bluetooth
- Configurable IP and PIN

**Flags:**
- `--dock` -- show dock icon (useful when menubar is full on small screens)
- `--debug` -- print timestamped FSAPI request logs and state changes to stderr

**Technical notes:**
- One async loop runs every poll in sequence: every 4 seconds with the popover open, every 60 seconds with it closed
- Full polls use GET_MULTIPLE (chunked to 5 nodes per request)
- XML responses parsed with Foundation's XMLParser (not regex)
- Discovery tries the saved IP, then Bonjour and SSDP, then a subnet scan of `/device`
- The PIN is only sent to a host that has identified itself as FSAPI
- Automatic reconnection only accepts the saved radio ID. Manual Discover can select a new radio
- SSDP uses BSD sockets because Network framework can't receive unicast replies to a multicast send
- Mac Audio pairs once through System Settings, then uses FSAPI, IOBluetooth and Core Audio. Turning it off restores the previous radio mode and Mac output
- Actions are fire-and-forget: UI updates optimistically, the poll syncs actual state
- Built with Swift Package Manager (`swift build -c release`)

**Build a .app bundle:**
```bash
scripts/build-app.sh    # outputs dist/RadioBar.app
```

**After editing Swift code, run:**
```bash
swiftformat Sources/ Tests/     # auto-fix formatting
swiftlint lint Sources/ Tests/  # check for issues (should be 0 violations)
swift build -c release          # verify it compiles
swift test                      # run the tests
```

## The `radio` CLI Tool

`bin/radio` is a bash CLI that wraps FSAPI, converting XML to JSON via `xq` and `jq`. Useful for debugging and one-off commands.

```bash
bin/radio status          # Power, mode, volume, now playing
bin/radio vol [0-31]      # Get or set volume
bin/radio play/pause/stop # Playback control
bin/radio mode [n]        # Get or set mode
bin/radio presets         # List presets for current mode
bin/radio nav list        # Browse current navigation level
bin/radio get <node>      # Raw GET any FSAPI node
bin/radio set <node> <v>  # Raw SET any FSAPI node
bin/radio help            # Full command reference
```

Requires: `curl`, `jq` (`brew install jq`), `xq` (`brew install python-yq`).
Set `RADIO_IP` and `RADIO_PIN` env vars to override defaults.

## Key Technical Details

- **Presets are per-mode:** slot counts are in `docs/fsapi-reference.md`. `LIST_SET` can write a preset from any audio URL.
- **Navigation is stateful:** must enable (`nav.state=1`) before browsing or reading presets. The radio turns it off on every mode change, and each level fetches from Airable's cloud.
- **Capabilities vary by mode:** live Internet Radio can stop but not pause. See `docs/fsapi-reference.md`.
- **No SSL cert verification:** the radio doesn't verify HTTPS certs to Airable, enabling community self-hosted backends via DNS redirection.
- **One session at a time:** RadioBar and the CLI send the PIN per request and don't create sessions, so they don't take over from UNDOK.

## Future Possibilities

- **Self-hosted Airable backend** for managing favourites/stations without the airable.fm portal (see `docs/archive/airable-research.md` and the [fairable](https://github.com/Half-Shot/fairable) project)
- macOS Now Playing / media key integration
- Global hotkeys for common controls

## Key Reference Links

- [fsapi-tools](https://github.com/MatrixEditor/fsapi-tools) -- most comprehensive community FSAPI project
- [flammy/fsapi](https://github.com/flammy/fsapi/blob/master/FSAPI.md) -- protocol documentation
- [afsapi](https://github.com/wlcrs/python-afsapi) -- async Python library (powers Home Assistant)
- [fairable](https://github.com/Half-Shot/fairable) -- self-hosted Airable-compatible backend
- [airable.fm](https://airable.fm) -- manage favourites/podcasts via web portal
