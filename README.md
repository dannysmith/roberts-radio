# RadioBar

A macOS menubar app for controlling a Roberts Revival iStream 3L internet radio over the local network.

Built on the community-reverse-engineered [FSAPI protocol](docs/fsapi-reference.md) used by Frontier Smart-based radios, so *should* also work with other Radios.

![Stylized image of a Roberts Radio](docs/image.png)

## Features

- Now playing: track name, artist, artwork, progress
- Playback controls: play/pause, stop, next, previous
- Volume slider with mute
- Mode switching (Internet Radio, Podcasts, DAB, FM, Spotify, etc.)
- EQ presets
- Preset selection per mode
- Browse stations and podcasts with search
- Seek on podcasts and Spotify (click the progress bar)
- Spotify Connect account info
- Alarm display
- Auto-discover the radio on your network (SSDP)
- Configurable IP and PIN

## Build & Run

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
bin/radiobar-gui
```

This compiles the app on first run (or when the source changes) and launches it. The radio icon appears in your menubar.

**Flags:**
- `--dock` -- also show a dock icon (useful on small screens where the menubar is full)
- `--debug` -- print request logs and state changes to stderr

No Xcode project needed. The app is a single Swift file compiled with `swiftc`.

## CLI Tool

There's also a bash CLI for quick commands and debugging:

```bash
bin/radio status          # What's playing, volume, mode
bin/radio vol 15          # Set volume
bin/radio play            # Resume playback
bin/radio presets         # List presets
bin/radio help            # Full command reference
```

Requires `curl`, `jq`, and `xq` (`brew install jq python-yq`).

## Configuration

By default, the app connects to `192.168.1.72` with PIN `1234`. You can change both in the app's settings (gear icon), or use the "Discover" button to find the radio automatically.

The CLI uses environment variables: `RADIO_IP` and `RADIO_PIN`.

## How It Works

The radio runs a Frontier Smart (formerly Frontier Silicon) platform with an HTTP API called FSAPI. The app polls the radio every few seconds for status, and sends commands when you interact with the UI. See [docs/fsapi-reference.md](docs/fsapi-reference.md) for protocol details.
