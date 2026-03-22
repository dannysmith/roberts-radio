# Community Projects for Frontier Silicon / FSAPI Radios

Research into community-built tools, libraries, and projects that interact with Frontier Silicon (now Frontier Smart) based internet radios via the HTTP "FSAPI" (also called NetRemote API).

---

## How the FSAPI Works (Quick Summary)

- The radio exposes an HTTP API on port 80 (some models use port 2244)
- Default PIN: **1234**
- Create a session: `GET http://<IP>/fsapi/CREATE_SESSION?pin=1234` -- returns a session ID
- Read a value: `GET /fsapi/GET/netRemote.sys.audio.volume?pin=1234&sid=<sessionId>`
- Set a value: `GET /fsapi/SET/netRemote.sys.audio.volume?pin=1234&sid=<sessionId>&value=5`
- List items: `GET /fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=10`
- Responses are XML
- No official public documentation exists; everything is community reverse-engineered

---

## 1. Python Libraries

### afsapi (Async Frontier Silicon API) -- THE MAIN ONE
- **Repo:** https://github.com/zhelev/python-afsapi
- **PyPI:** https://pypi.org/project/afsapi/
- **Language:** Python (async/aiohttp)
- **Status:** This is the library used by **Home Assistant's official integration**. Latest release 0.2.8 (Dec 2022). Licensed Apache 2.0.
- **Features:** Power on/off, friendly name, modes, equalisers, presets, sleep timer, volume, mute, play info. All async.
- **Install:** `pip install afsapi`

### python-fsapi (Synchronous version)
- **Repo:** https://github.com/zhelev/python-fsapi
- **Language:** Python (synchronous, uses requests)
- **Status:** Predecessor to afsapi. Less maintained now but simpler to use for scripting.

### tiwilliam/fsapi (Original Python implementation)
- **Repo:** https://github.com/tiwilliam/fsapi
- **Language:** Python
- **Status:** The original Python FSAPI library (20 stars, 13 forks). Tested with Argon iNet 3+. Contains the important **REVERSE.md** file documenting the protocol.
- **Key file:** [REVERSE.md](https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md) -- documents HTTP endpoints with request/response examples

### fsapi-tools (Comprehensive toolkit by MatrixEditor)
- **Repo:** https://github.com/MatrixEditor/fsapi-tools
- **Docs:** https://matrixeditor.github.io/fsapi-tools/
- **PyPI:** `pip install fsapi-tools`
- **Language:** Python 3
- **Status:** The most comprehensive and well-documented project. Actively maintained with full documentation on ReadTheDocs.
- **Features:**
  - **FSAPI-NET Tool:** Interact with Frontier Smart IoT devices via the API
  - **ISUTool:** Inspector for Frontier Smart firmware binaries (.isu files)
  - **XDR-Decompiler:** Decompile binary XDR JavaScript files used by the ScriptMonkey engine
  - **Complete node reference:** Documents ALL available netRemote nodes (not just the common ones)
  - Firmware analysis tools
- **This is arguably the single most valuable resource** for understanding the full API surface

### MatrixEditor/Frontier-Silicon-Radio
- **Repo:** https://github.com/MatrixEditor/Frontier-Silicon-Radio
- **Language:** Python
- **Status:** Archived (July 2022). Predecessor to fsapi-tools. A script for "abusing the features" of Frontier Silicon devices.

---

## 2. Home Automation Integrations

### Home Assistant -- Official Integration
- **Docs:** https://www.home-assistant.io/integrations/frontier_silicon/
- **Status:** Built into Home Assistant core. Uses the `afsapi` Python library.
- **Features:** Power, volume, mute, source selection, presets. Supports auto-discovery.
- **Limitations:** Polls every 30 seconds. Can conflict with UNDOK app on older devices (both create sessions).
- **Setup:** Default PIN 1234. Some devices need port 2244. Check `http://<host>:<port>/device`

### Home Assistant -- Advanced Custom Integration (my-frontier-silicon)
- **Repo:** https://github.com/SaintPaddy/my-frontier-silicon
- **Status:** Custom component (install via HACS or manual copy)
- **Features (beyond official):**
  - Full media player control (power, volume, mute, play/pause)
  - Complete source switching (Internet Radio, DAB+, FM, Spotify, Bluetooth, CD, USB, AUX)
  - Direct preset selection
  - Automatic discovery of radio capabilities
  - Rich sensors (current mode, station info)
  - Album art display
  - Utility buttons

### openHAB -- FS Internet Radio Binding
- **Docs:** https://www.openhab.org/addons/bindings/fsinternetradio/
- **Legacy Docs:** https://github.com/openhab/openhab1-addons/wiki/Frontier-Silicon-Radio-Binding
- **Language:** Java
- **Features:** Power, mute, volume, mode, preset, play-info. Supports UPnP discovery.
- **Tested with:** Hama IR110, Medion MD87180, Pinell Supersound II, Silvercrest SIRD 14 C1, Revo Superconnect, Ruark R2, Technisat DigiRadio 450

### ioBroker -- frontier_silicon Adapter
- **Repo:** https://github.com/iobroker-community-adapters/ioBroker.frontier_silicon
- **npm:** https://www.npmjs.com/package/iobroker.frontier_silicon
- **Language:** JavaScript/Node.js
- **Status:** Maintained by iobroker-community-adapters. v0.5.0.
- **Features:** Power, volume, mute, presets, source switching. Syncs with UNDOK app changes.

### Homebridge -- Frontier Silicon Plugin (Apple HomeKit)
- **Repo:** https://github.com/boikedamhuis/homebridge-frontier-silicon
- **npm:** https://www.npmjs.com/package/homebridge-frontier-silicon-plugin
- **Language:** JavaScript/Node.js
- **Features:** Power (as Switch), volume (as Lightbulb brightness). Safe polling -- won't crash if radio is unreachable.

### Node-RED
- **Forum Post:** https://discourse.nodered.org/t/frontier-silicon-based-internet-radio-controlled-by-node-red/33703
- **Status:** Community-shared flow (not a dedicated node). Uses direct HTTP requests to the FSAPI.
- **Tested with:** Silvercrest SIRD 14 B1

---

## 3. JavaScript / Node.js Libraries

### node-frontier-silicon
- **Repo:** https://github.com/dkuku/node-frontier-silicon
- **npm:** https://www.npmjs.com/package/node-frontier-silicon
- **Language:** JavaScript (Node.js)
- **Features:** Get modes, play status, play info (text, artist, album, graphics), volume control, connect/disconnect

### wifiradio
- **npm:** https://www.npmjs.com/package/wifiradio
- **Repo:** https://github.com/ENT8R/wifiradio
- **Language:** JavaScript
- **Features:** High-level API for power, mute, volume, mode, display text. Tagged with fsapi/frontier/silicon/iot keywords.

### internet-radio-poc
- **Repo:** https://github.com/andyt/internet-radio-poc
- **Language:** JavaScript (browser-based)
- **Status:** Proof of concept. Run index.html in a browser to control the radio.

---

## 4. PHP Libraries

### flammy/fsapi -- THE REFERENCE DOCUMENTATION
- **Repo:** https://github.com/flammy/fsapi
- **Language:** PHP
- **Status:** Contains the most widely-referenced API documentation files.
- **Key docs:**
  - [FSAPI.md](https://github.com/flammy/fsapi/blob/master/FSAPI.md) -- Complete list of netRemote nodes/endpoints
  - [Documentation.md](https://github.com/flammy/fsapi/blob/master/Documentation.md) -- Additional API documentation
- **Developed for:** Frontier Silicon Venice 6.2 chipset. Tested with TERRIS Stereo Internetradio.
- **Also has:** [fsapi-remote](https://github.com/flammy/fsapi-remote) -- example web remote control UI

### psott/fsapi
- **Repo:** https://github.com/psott/fsapi
- **Language:** PHP
- **Status:** Fork/variant of the PHP implementation

### tichachm/fsapi-1
- **Repo:** https://github.com/tichachm/fsapi-1
- **Language:** PHP

---

## 5. .NET / C#

### z1c0/FsApi
- **Repo:** https://github.com/z1c0/FsApi
- **Language:** C# / .NET
- **Features:** Remote control of Internet/WLAN radios

### FSRadio-Remote (Desktop Application)
- **Download:** https://sourceforge.net/projects/fs-remote/
- **Language:** .NET (Windows desktop app)
- **Status:** Developed 2016-2020 by Eric Marchesin. Based on the z1c0 .NET library.
- **Features:** Full GUI remote: power, mute, volume, equalizer, presets, menu navigation, now-playing info, internet search for artist/title.
- **Compatibility:** Any UNDOK-compatible device (Roberts, Hama, Medion, Technisat, Dual, Sangean, Revo, Ruark, Silvercrest, Auna, Como Audio)

---

## 6. Other Languages

### Elixir -- ex_frontier
- **Docs:** https://hexdocs.pm/ex_frontier/fsapi.html
- **Language:** Elixir
- **Status:** v0.1.0. Contains good FSAPI documentation explaining the request/response format.

### Shell Script -- fsradio
- **Repo:** https://github.com/LiberationFrequency/fsradio
- **Language:** POSIX shell
- **Status:** Early alpha. Proof of concept for controlling Frontier Silicon Jupiter/Venice 6.5 radios from the command line.

---

## 7. Backend Replacements (Self-Hosted Station Lists)

These projects replace the cloud backend that serves station lists to the radio, allowing you to host your own stations and podcasts.

### KIMB-technologies/Radio-API
- **Repo:** https://github.com/KIMB-technologies/Radio-API
- **Docker:** https://hub.docker.com/r/kimbtechnologies/radio_api
- **Language:** PHP
- **Status:** Actively maintained. Docker support.
- **Features:**
  - Hosts custom internet radio stations and podcasts
  - Uses RadioBrowser for station discovery
  - Browse by country, language, tags, clicks, votes
  - Per-user station lists
  - Nextcloud audio share support
  - Works by DNS redirect: point the radio's backend domain to your server

### compujuckel/librefrontier
- **Repo:** https://github.com/compujuckel/librefrontier
- **Language:** C# / .NET
- **Status:** Created after Frontier Silicon's May 2019 backend provider switch broke many radios.
- **How it works:** DNS redirect `wifiradiofrontier.com` to your LibreFrontier instance. Sources radio data from radio-browser.info.

### Half-Shot/fairable
- **Repo:** https://github.com/Half-Shot/fairable
- **Language:** JavaScript/Node.js (Node 18+)
- **Status:** Alpha. Requires SSL certificate.
- **Blog post:** https://half-shot.uk/blog/new-frontiers/ -- excellent technical writeup of reverse engineering the Airable protocol
- **Purpose:** Self-hosted Airable-compatible server for newer radios that use `airable.wifiradiofrontier.com` over HTTPS

### rhaamo/pyrable
- **Repo:** https://github.com/rhaamo/pyrable
- **Language:** Python
- **Status:** For newer radios using the Airable JSON API (not the older XML API)
- **Requires:** Dedicated VM/IP with DNS (port 53) and HTTPS (port 443). Override DNS on radio to point to your server.

### seife/frontier-airable
- **Repo:** https://github.com/seife/frontier-airable
- **Language:** Python
- **Status:** Reimplementation of fairable in Python (fewer dependencies). Includes airable-proxy for caching/intercepting Frontier server calls.

---

## 8. Firmware Analysis

### cweiske/frontier-silicon-firmwares
- **Repo:** https://github.com/cweiske/frontier-silicon-firmwares
- **Purpose:** Collection of Frontier Silicon internet radio firmware binaries (.isu files)
- **Notes:** Venice modules run MEOS OS on Imagination Technologies META processor. Firmware is encrypted.

### MatrixEditor/frontier-silicon-firmwares (Updated fork)
- **Repo:** https://github.com/MatrixEditor/frontier-silicon-firmwares
- **Status:** Contains 35+ more firmware binaries than the original cweiske repo

---

## 9. Key API Documentation Resources (Summary)

| Resource | URL | What it documents |
|----------|-----|-------------------|
| flammy FSAPI.md | https://github.com/flammy/fsapi/blob/master/FSAPI.md | Complete netRemote node list |
| tiwilliam REVERSE.md | https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md | HTTP protocol reverse engineering |
| fsapi-tools Docs | https://matrixeditor.github.io/fsapi-tools/ | ALL nodes, firmware analysis, tools |
| fsapi-tools Node Reference | https://matrixeditor.github.io/fsapi-tools/fsapi-tools.html | Comprehensive node reference |
| ex_frontier Docs | https://hexdocs.pm/ex_frontier/fsapi.html | Clear explanation of request/response format |
| Half-Shot Blog | https://half-shot.uk/blog/new-frontiers/ | Airable backend reverse engineering |

---

## 10. Key netRemote Nodes (Common Endpoints)

### System
- `netRemote.sys.power` -- Power on/off (0/1)
- `netRemote.sys.mode` -- Current mode (Internet Radio, DAB, FM, Spotify, etc.)
- `netRemote.sys.audio.volume` -- Volume level
- `netRemote.sys.audio.mute` -- Mute on/off
- `netRemote.sys.audio.eqPreset` -- Equalizer preset
- `netRemote.sys.audio.eqLoudness` -- Loudness on/off
- `netRemote.sys.sleep` -- Sleep timer
- `netRemote.sys.info.friendlyName` -- Device name
- `netRemote.sys.info.version` -- Firmware version
- `netRemote.sys.info.radioId` -- Unique radio ID
- `netRemote.sys.lang` -- Language setting
- `netRemote.sys.caps.validModes` -- List of available modes
- `netRemote.sys.caps.volumeSteps` -- Number of volume steps
- `netRemote.sys.caps.fmFreqRange` -- FM frequency range
- `netRemote.sys.caps.dabFreqList` -- DAB frequency list

### Playback
- `netRemote.play.info.name` -- Current station/track name
- `netRemote.play.info.text` -- Now playing text
- `netRemote.play.info.artist` -- Artist name
- `netRemote.play.info.album` -- Album name
- `netRemote.play.info.graphicUri` -- Album art URL
- `netRemote.play.status` -- Play status
- `netRemote.play.control` -- Play/pause/stop control
- `netRemote.play.frequency` -- Current frequency (FM/DAB)
- `netRemote.play.caps` -- Playback capabilities

### Navigation
- `netRemote.nav.state` -- Navigation state (must be set to 1 to enable nav commands)
- `netRemote.nav.list` -- Browse items in current navigation context
- `netRemote.nav.numItems` -- Number of items in current list
- `netRemote.nav.presets` -- List of saved presets

### Network
- `netRemote.sys.net.wlan.connectedSSID` -- Connected WiFi network
- `netRemote.sys.net.wlan.rssi` -- WiFi signal strength
- `netRemote.sys.net.wlan.macAddress` -- WiFi MAC address

### Multiroom
- `netRemote.multiroom.device.listAll` -- List all multiroom devices
- `netRemote.multiroom.group.*` -- Multiroom group management

---

## Recommended Starting Points

1. **To control your radio programmatically (Python):** Start with `afsapi` (`pip install afsapi`)
2. **To understand the full API:** Read the [fsapi-tools documentation](https://matrixeditor.github.io/fsapi-tools/) and [flammy's FSAPI.md](https://github.com/flammy/fsapi/blob/master/FSAPI.md)
3. **To integrate with Home Assistant:** Use the [built-in integration](https://www.home-assistant.io/integrations/frontier_silicon/) or [my-frontier-silicon](https://github.com/SaintPaddy/my-frontier-silicon) for more features
4. **To self-host your own station/podcast lists:** Look at [Radio-API](https://github.com/KIMB-technologies/Radio-API) or [fairable](https://github.com/Half-Shot/fairable)
5. **To build a JavaScript/Node.js tool:** Use `node-frontier-silicon` or `wifiradio` from npm
6. **To reverse engineer the protocol further:** Study [tiwilliam's REVERSE.md](https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md) and the [fsapi-tools source](https://github.com/MatrixEditor/fsapi-tools)
