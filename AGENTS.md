# Roberts Radio Project

Personal project to control a **Roberts Revival iStream 3L** internet radio from macOS. The main output is **RadioBar**, a SwiftUI menubar app.

## The Radio

The Roberts Revival iStream 3L runs on the **Frontier Smart** platform (Venice X module, FS2340, Chorus 4 chip, SmartSDK firmware V4.6.18). It exposes a local HTTP API called **FSAPI** on port 80 for control, and connects to **Airable** cloud servers for station/podcast catalogs and favourites.

- **10 modes:** Internet Radio, Podcasts, Deezer, Amazon Music, Spotify, USB, DAB, FM, Bluetooth, Aux In
- **Default IP:** `192.168.1.72`, **PIN:** `1234`
- **SSDP discoverable** via `urn:schemas-frontier-silicon-com:fs_reference:fsapi:1`
- No official API docs -- everything is community reverse-engineered

See `docs/fsapi-reference.md` for the full protocol and node reference.

## Project Structure

```
RadioBar.swift          # SwiftUI menubar app (single-file, compiles with swiftc)
bin/
  radiobar-gui          # Build & run script for RadioBar
  radio                 # Bash CLI tool for FSAPI (requires curl/xq/jq)
docs/
  fsapi-reference.md    # FSAPI protocol spec, node tables, device-specific info
  community-projects.md # Community tools, libraries, self-hosted backends
  archive/              # Original research docs, probe script and results
```

## RadioBar (SwiftUI Menubar App)

Single-file SwiftUI app for macOS. Build and run without Xcode:

```bash
bin/radiobar-gui [--dock] [--debug]
```

**Features:**
- Now-playing display with artwork, progress bar (clickable to seek on podcasts/Spotify)
- Playback controls (play/pause, stop, next, prev)
- Volume slider with mute
- Mode switching and EQ preset picker
- Preset selection (per-mode)
- Station/podcast browsing via nav tree with search
- Spotify Connect info (account, bitrate)
- Alarm display (collapsible)
- SSDP auto-discovery of the radio on the local network
- Configurable IP and PIN

**Flags:**
- `--dock` -- show dock icon (useful when menubar is full on small screens)
- `--debug` -- print timestamped FSAPI request logs and state changes to stderr

**Technical notes:**
- Polls the radio every 4 seconds via GET_MULTIPLE (chunked to 5 nodes per request)
- XML responses parsed with Foundation's XMLParser (not regex)
- SSDP discovery uses POSIX UDP sockets
- Actions are fire-and-forget: UI updates optimistically, the poll syncs actual state
- Built with Swift Package Manager (`swift build -c release`)

**Build a .app bundle:**
```bash
scripts/build-app.sh    # outputs dist/RadioBar.app
```

**After editing Swift code, run:**
```bash
swiftformat Sources/        # auto-fix formatting
swiftlint lint Sources/     # check for issues (should be 0 violations)
swift build -c release      # verify it compiles
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

- **Presets are per-mode:** 40 slots for Internet Radio/Podcasts, 10 for DAB/FM. Cannot create presets from arbitrary URLs.
- **Navigation is stateful:** must enable (`nav.state=1`) before browsing. Each level fetches from Airable's cloud.
- **No SSL cert verification:** the radio doesn't verify HTTPS certs to Airable, enabling community self-hosted backends via DNS redirection.
- **One session at a time:** if UNDOK is connected, it may conflict with other clients.

## Future Possibilities

- **Self-hosted Airable backend** for managing favourites/stations without the airable.fm portal (see `docs/archive/airable-research.md` and the [fairable](https://github.com/Half-Shot/fairable) project)
- macOS Now Playing / media key integration
- Global hotkeys for common controls

## Key Reference Links

- [fsapi-tools](https://github.com/MatrixEditor/fsapi-tools) -- most comprehensive community FSAPI project
- [flammy/fsapi](https://github.com/flammy/fsapi/blob/master/FSAPI.md) -- protocol documentation
- [afsapi](https://github.com/zhelev/python-afsapi) -- async Python library (powers Home Assistant)
- [fairable](https://github.com/Half-Shot/fairable) -- self-hosted Airable-compatible backend
- [airable.fm](https://airable.fm) -- manage favourites/podcasts via web portal
