# Roberts Radio Project

Personal project to understand, control, and eventually build custom interfaces for a **Roberts Revival iStream 3L** internet radio.

## The Radio

The Roberts Revival iStream 3L is built on the **Frontier Smart** (formerly Frontier Silicon) platform — specifically a **Venice X module** (FS2340) with a **Chorus 4** chip, running **SmartSDK** firmware `V4.6.18`.

It has 10 modes: Internet Radio, Podcasts, Deezer, Amazon Music, Spotify, USB, DAB, FM, Bluetooth, Aux In.

The radio's IP on the local network is `192.168.1.72`, and the default FSAPI PIN is `1234`.

## How It Works

There are three layers to understand:

1. **Frontier Smart** — the hardware/firmware platform provider. Their Venice X module and SmartSDK firmware run on the radio. They also make the UNDOK companion app. No public SDK or API docs exist — everything is community reverse-engineered.

2. **FSAPI** (local, LAN) — the radio exposes a simple HTTP API on port 80. You send GET requests with dot-notation "node" paths (e.g. `netRemote.sys.audio.volume`) and get XML responses. This is how UNDOK controls the radio. Supports GET, SET, LIST, GET_MULTIPLE, CREATE_SESSION, GET_NOTIFIES operations. Session-based auth with a numeric PIN (default 1234). Only one session at a time — the radio **hangs** (doesn't respond) on requests without a valid session.

3. **Airable** (cloud, WAN) — the radio connects directly to `airable.wifiradiofrontier.com` over HTTPS for station catalogs, podcast listings, and favourites. Almost nothing is cached locally — every browse operation fetches from the cloud. Favourites are managed via the [airable.fm](https://airable.fm) web portal. Frontier Smart shut down their own cloud backend (Nuvola) in Oct 2024; Airable now handles everything.

## Project Structure

```
bin/
  radio               # CLI tool for controlling the radio via FSAPI (bash, requires curl/xq/jq)

scripts/
  probe-nodes.sh      # Brute-force probe of all known FSAPI nodes, outputs JSON
  probe-results.json  # Results from probing this specific radio (96 GET nodes, 9 LIST nodes)

docs/
  frontier-smart-and-undok-research.md   # Frontier Smart, UNDOK, FSAPI protocol, full node reference
  airable-research.md                    # Airable platform, airable.fm, cloud sync, reverse-engineered protocols
  community-projects.md                  # Community tools, libraries, Home Assistant integrations, self-hosted backends
  fsapi-presets-research.md              # How presets work (per-mode, programmatic management, limitations)
  fsapi-exploration-guide.md             # Hands-on guide to exploring the FSAPI
```

## The `radio` CLI Tool

`bin/radio` is a bash CLI that wraps the FSAPI, converting XML responses to JSON via `xq` and `jq`.

### Prerequisites

- `curl` (pre-installed on macOS)
- `jq` (`brew install jq`)
- `xq` from python-yq (`brew install python-yq`)

### Usage

```bash
bin/radio status          # Power, mode, volume, now playing with position/duration
bin/radio info            # Device name, firmware, IP, MAC, wifi signal
bin/radio modes           # List all available modes
bin/radio presets         # List presets for current mode (presets are per-mode)
bin/radio vol [0-31]      # Get or set volume
bin/radio play/pause/stop # Playback control
bin/radio mode [n]        # Get or set mode
bin/radio nav list        # Browse current navigation level
bin/radio nav into <key>  # Navigate into a folder
bin/radio nav back        # Go up one level
bin/radio get <node>      # Raw GET any FSAPI node
bin/radio set <node> <v>  # Raw SET any FSAPI node
bin/radio help            # Full command reference
```

### Environment Variables

- `RADIO_IP` — radio's IP address (default: `192.168.1.72`)
- `RADIO_PIN` — FSAPI PIN (default: `1234`)

### Key Limitations

- GET_MULTIPLE is limited to ~5 nodes per request (the radio's HTTP server rejects long URLs). The CLI handles this automatically by chunking.
- Only one FSAPI session at a time. If UNDOK is connected, the CLI's session may get killed and vice versa. The CLI auto-retries with a new session.
- Some nodes are mode-dependent — e.g. `play.frequency` only works in FM mode, Spotify nodes only in Spotify mode.

## Key Technical Details

- The radio has **96 working GET nodes** and **9 LIST nodes** (see `scripts/probe-results.json` for the full map).
- Presets are **per-mode**: 40 slots for Internet Radio/Podcasts, 10 for DAB, 10 for FM. You can save the current station to a slot (`play.addPreset`) and delete/reorder presets, but you **cannot create a preset from an arbitrary URL** — the upload blob format is undocumented.
- Navigation (`netRemote.nav.*`) is stateful and proxies cloud content. Each menu level triggers a separate HTTPS request to Airable's servers. You must enable nav (`nav.state=1`) before using nav commands.
- The radio does **not verify SSL certificates** on its HTTPS connections to Airable, which is how community self-hosted backend projects work (DNS redirection + self-signed certs).

## Key Reference Links

- [fsapi-tools](https://github.com/MatrixEditor/fsapi-tools) — most comprehensive community project, documents all FSAPI nodes
- [flammy/fsapi FSAPI.md](https://github.com/flammy/fsapi/blob/master/FSAPI.md) — protocol documentation
- [afsapi](https://github.com/zhelev/python-afsapi) — async Python library (powers Home Assistant integration)
- [Home Assistant integration](https://www.home-assistant.io/integrations/frontier_silicon/)
- [fairable](https://github.com/Half-Shot/fairable) — self-hosted Airable-compatible backend
- [Half-Shot blog: New Frontiers](https://half-shot.uk/blog/new-frontiers/) — reverse engineering the Airable protocol
- [airable.fm](https://airable.fm) — manage favourites/podcasts
