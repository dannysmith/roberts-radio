# Frontier Smart / Frontier Silicon & UNDOK Research

Research into Frontier Smart Technologies (formerly Frontier Silicon), their radio platform, the UNDOK app, and the FSAPI protocol.

---

## 1. What is Frontier Smart / Frontier Silicon?

### Company Identity

**Frontier Silicon** was founded in **2001** in the UK. The company later rebranded to **Frontier Smart Technologies**. They are a subsidiary of **Science Group plc** (AIM: SAG), a publicly listed UK technology company.

**Headquarters:** London, UK
**Engineering:** Cambridge (UK), Timisoara (Romania)
**Sales/Operations:** Hong Kong, Shenzhen (China)

### What They Do

Frontier Smart is the **world's leading supplier of semiconductor/module/software solutions for digital radio and connected audio**. They provide:

- **Chipsets** (SoCs) -- silicon chips that power digital radios
- **Modules** -- complete hardware modules (chipset + WiFi + antenna + flash + DAC on a PCB) that radio manufacturers drop into their products
- **Software** -- the SmartSDK firmware platform that runs on the modules
- **Apps** -- UNDOK (legacy) and OKTIV (current) companion apps
- **Services** -- cloud backend infrastructure (formerly Nuvola, now transitioned to Airable)

### Scale

- **80+ million devices shipped** worldwide
- **40+ consumer electronics brands** use their platform
- Used in products from Sony, Philips, Pure, Panasonic, Roberts, Harman Kardon, JBL, Grundig, Bose, Bang & Olufsen, Marshall, Urbanears, and many more

### Chipset History

| Generation | Chip | Era | Notes |
|------------|------|-----|-------|
| 1st gen | Kino | Early 2000s | Early DAB chipsets |
| 2nd gen | Chorus 2i (FS1020) | ~2008-2012 | Used in Venice 6 modules |
| 3rd gen | Chorus 3 | ~2013-2016 | -- |
| 4th gen | Chorus 4 | ~2017+ | Single-chip solution integrating 4 previously separate chips. Significant cost and power savings. Used in Venice X modules. |

### Module Lineup

Modules are the pre-built hardware boards that radio brands integrate into their products:

| Module | Chipset | Description |
|--------|---------|-------------|
| **Venice 6** (FS2026) | Chorus 2i | Single-sided 6-layer PCB, 64-way connector. Includes WiFi, Apollo RF front end, Chorus 2i processor, serial FLASH, audio DAC. |
| **Venice 6.5** (FS2026-5) | Chorus 2i/3 | Complete solution for internet radio, DLNA, UPnP, DAB/DAB+, FM-RDS. |
| **Venice X** (FS2340) | Chorus 4 | Current generation. Complete SmartRadio/connected audio solution. Supports DAB+ and internet streaming. Formats: AAC, AAC+, MP3, FLAC. |
| **Siena** | -- | Entry-level module |
| **Magic X** | -- | -- |
| **AURIA** | -- | Connected audio platform |

### Software Platform: SmartSDK

The firmware running on Venice modules is called **SmartSDK**. It:
- Runs on **MEOS OS** (a real-time operating system by Imagination Technologies)
- Executes on **Imagination Technologies META** processor architecture
- Handles all radio functions: DAB/FM tuning, internet radio streaming, Bluetooth, Spotify Connect, etc.
- Exposes the **FSAPI** (Frontier Smart API) over HTTP on the local network
- Communicates with the cloud backend (airable) for station catalogs and podcast listings
- Firmware files use the `.isu` extension and are encrypted

### Venice X Firmware Naming Convention

```
ir-$MODULE-$INTERFACE-$IFACEVERSION-${MODEL}_V$VERSION.$REVISION-$BRANCH
```

Example: `ir-mmi-FS2026-0500-0052_V2.6.17.EX53300-1RC5`

Firmware updates are checked via: `https://update.wifiradiofrontier.com/FindUpdate.aspx?mac=<mac>&customisation=<model>&version=<version>`

---

## 2. What is UNDOK?

### Overview

**UNDOK** is Frontier Smart's companion app for controlling internet radios on the local network. It is available on iOS and Android. UNDOK stands for... well, it's never been officially explained, but it's the successor to the earlier "DOK" app.

### What UNDOK Can Do

- **Discover radios** on the local network automatically
- **Control playback** -- play, pause, stop, skip
- **Change source/mode** -- switch between Internet Radio, DAB, FM, Spotify, Bluetooth, AUX, etc.
- **Adjust volume** and mute
- **Browse content** -- navigate internet radio stations, podcasts, DAB stations
- **Manage presets** -- save and recall favourite stations
- **Manage favourites** -- for internet radio and podcasts (requires airable.fm account)
- **Configure the radio** -- WiFi setup, equaliser, clock, alarms, sleep timer
- **Multiroom** -- group compatible radios for synchronised playback
- **Initial setup** -- connect a new radio to your WiFi network

### OKTIV: The Replacement

Frontier Smart has developed **OKTIV** as the successor to UNDOK. OKTIV is a redesigned, more modern app:

- Works with Venice X modules running firmware v4.2.4 and above
- Over 700,000 compatible radios in regular use
- Over 300 hours of UX research and testing went into the design
- Features a "My Audio" homescreen for pinned content
- Both UNDOK and OKTIV are still available; which one your radio uses depends on the brand/model

### Which Radios Support Which App

- **UNDOK**: Older radios and many current models (Roberts Revival iStream 3L uses UNDOK)
- **OKTIV**: Newer radios on Venice X with firmware 4.2.4+
- Some brands (like Ruark) have their own branded versions of these apps

---

## 3. How UNDOK Communicates with the Radio (The FSAPI Protocol)

### Discovery: SSDP

UNDOK discovers radios on the local network using **SSDP** (Simple Service Discovery Protocol), the same protocol used by UPnP devices.

**M-SEARCH Request** (sent to multicast):

```
M-SEARCH * HTTP/1.1
HOST:239.255.255.250:1900
MAN:"ssdp:discover"
ST:urn:schemas-frontier-silicon-com:fs_reference:fsapi:1
MX:3
```

- **Multicast address:** 239.255.255.250:1900 (UDP)
- **Service type URN:** `urn:schemas-frontier-silicon-com:fs_reference:fsapi:1`
- Some devices may use variant URNs like `urn:schemas-frontier-silicon-com:argon_001:fsapi:1`

The radio responds with an HTTP 200 containing a `Location` header pointing to a device description URL.

**Device Description XML** (fetched from the Location URL, typically `http://<IP>/device`):

```xml
<netRemote>
  <friendlyName>Roberts iStream 3L 002261c53c78</friendlyName>
  <version>ir-mmi-FS2026-0500-0095_V2.6.17.EX53300-1RC5</version>
  <webfsapi>http://192.168.1.144:80/fsapi</webfsapi>
</netRemote>
```

The `<webfsapi>` element gives the **base URL** for all FSAPI requests. This is typically `http://<IP>:80/fsapi` but some models use port **2244**.

### The FSAPI Protocol

FSAPI is a **simple HTTP-based API**. You send HTTP GET requests and receive XML responses. There is no official public documentation -- everything known has been reverse-engineered by the community.

#### Base URL

```
http://<radio-ip>/fsapi
```

Or on some models:

```
http://<radio-ip>:2244/fsapi
```

#### Authentication

Authentication uses a **numeric PIN** (default: **1234**). The PIN can be changed via the radio's menu: `MENU > System Settings > Network > NetRemote PIN Setup`.

Two authentication modes:

1. **PIN-only** -- pass `pin=<PIN>` with every request
2. **Session-based** -- create a session first, then use the session ID

#### Session Management

**Create a session:**
```
GET /fsapi/CREATE_SESSION?pin=1234
```

Response:
```xml
<fsapiResponse>
  <status>FS_OK</status>
  <sessionId>1932538906</sessionId>
</fsapiResponse>
```

**Delete a session:**
```
GET /fsapi/DELETE_SESSION?pin=1234&sid=1932538906
```

Important: **Only one active session at a time**. Creating a new session invalidates the previous one. This is why UNDOK and Home Assistant can conflict -- when one connects, it kills the other's session.

#### HTTP Status Codes

| HTTP Status | Meaning |
|-------------|---------|
| 200 | Valid request with correct PIN/session |
| 403 | Invalid PIN |
| 404 | Invalid session ID or non-existent endpoint |

#### Operations

| Operation | Purpose | Example |
|-----------|---------|---------|
| `GET` | Read a node value | `/fsapi/GET/netRemote.sys.audio.volume?pin=1234` |
| `SET` | Write a node value | `/fsapi/SET/netRemote.sys.audio.volume?pin=1234&value=10` |
| `LIST_GET_NEXT` | Paginate through a list node | `/fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=10` |
| `CREATE_SESSION` | Get a session ID | `/fsapi/CREATE_SESSION?pin=1234` |
| `DELETE_SESSION` | Destroy a session | `/fsapi/DELETE_SESSION?pin=1234&sid=<sid>` |
| `GET_NOTIFIES` | Long-poll for state changes | `/fsapi/GET_NOTIFIES?pin=1234&sid=<sid>` |
| `GET_MULTIPLE` | Read multiple nodes at once | `/fsapi/GET_MULTIPLE?pin=1234&node=netRemote.sys.audio.volume&node=netRemote.sys.audio.mute` |

#### URL Structure

```
/fsapi/<OPERATION>/<NODE_PATH>?pin=<PIN>[&sid=<SESSION_ID>][&value=<VALUE>][&maxItems=<N>]
```

#### Response Format

All responses are XML:

```xml
<fsapiResponse>
  <status>FS_OK</status>
  <value><u8>10</u8></value>
</fsapiResponse>
```

#### Status Codes in Responses

| Status | Meaning |
|--------|---------|
| `FS_OK` | Command executed successfully |
| `FS_FAIL` | Value failed validation |
| `FS_PACKET_BAD` | Attempted SET on read-only node |
| `FS_NODE_BLOCKED` | Node inaccessible in current mode |
| `FS_NODE_DOES_NOT_EXIST` | Invalid node path |
| `FS_TIMEOUT` | Request timed out (normal for GET_NOTIFIES when nothing changed) |
| `FS_LIST_END` | No more list entries available |

#### Data Types

Values are wrapped in type-specific XML tags:

| Tag | Type | Example |
|-----|------|---------|
| `<u8>` | Unsigned 8-bit integer | `<u8>10</u8>` |
| `<u16>` | Unsigned 16-bit integer | `<u16>5000</u16>` |
| `<u32>` | Unsigned 32-bit integer | `<u32>87500</u32>` |
| `<s8>` | Signed 8-bit integer | `<s8>-60</s8>` |
| `<s16>` | Signed 16-bit integer | `<s16>-14</s16>` |
| `<s32>` | Signed 32-bit integer | `<s32>3600</s32>` |
| `<c8_array>` | Character string | `<c8_array>BBC Radio 4</c8_array>` |
| `<e8>` | Enumeration (8-bit) | `<e8>1</e8>` |

#### GET_NOTIFIES (Long Polling)

This special operation keeps the HTTP connection open. The radio sends XML fragments whenever a node value changes. If nothing changes, it eventually returns `FS_TIMEOUT`. This is how apps receive real-time updates without constant polling.

Only available when using a session ID.

#### LIST_GET_NEXT (Pagination)

For list-type nodes, you paginate with a starting index:

```
GET /fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=10
```

- `-1` means start from the beginning
- `maxItems` controls page size
- Response includes items with their indices; use the last index as the starting point for the next page
- Returns `FS_LIST_END` when no more items exist

---

## 4. Complete FSAPI Node Reference

Nodes are organised hierarchically using dot notation. The major categories are:

### System Nodes (`netRemote.sys.*`)

#### Audio

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.audio.volume` | U8 | RW | Volume level (0-32 typical) |
| `netRemote.sys.audio.mute` | E8 | RW | Mute control (0=NOT_MUTE, 1=MUTE) |
| `netRemote.sys.audio.eqPreset` | U8 | RW | EQ preset (0-8: Normal, Flat, Jazz, Rock, Movie, Classic, Pop, News, Custom) |
| `netRemote.sys.audio.eqLoudness` | E8 | RW | Loudness enhancement toggle |
| `netRemote.sys.audio.eqCustom.param0` | S16 | RW | Custom EQ bass (-14 to +14) |
| `netRemote.sys.audio.eqCustom.param1` | S16 | RW | Custom EQ treble (-14 to +14) |
| `netRemote.sys.audio.eqCustom.param2-4` | S16 | RW | Additional custom EQ parameters |
| `netRemote.sys.audio.airableQuality` | E8 | RW | Airable stream quality selection |
| `netRemote.sys.audio.extStaticDelay` | U32 | RW | External audio delay compensation |

#### Power & Mode

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.power` | E8 | RW | Power on/off (0=off, 1=on) |
| `netRemote.sys.mode` | U32 | RW | Current mode (mode numbers vary by device) |
| `netRemote.sys.sleep` | E8 | RW | Sleep timer |
| `netRemote.sys.state` | E8 | RO | Current system state |
| `netRemote.sys.factoryReset` | E8 | RW | Factory reset trigger |
| `netRemote.sys.lang` | U32 | RW | Language setting |

#### Device Info

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.info.friendlyName` | C8 | RW | User-visible device name |
| `netRemote.sys.info.version` | C8 | RO | Firmware version string |
| `netRemote.sys.info.buildVersion` | C8 | RO | Build version |
| `netRemote.sys.info.modelName` | C8 | RO | Device model name |
| `netRemote.sys.info.radioId` | C8 | RO | Radio ID (MAC address) |
| `netRemote.sys.info.serialNumber` | C8 | RO | Serial number |
| `netRemote.sys.info.radioPin` | C8 | RW | The FSAPI PIN |
| `netRemote.sys.info.controllerName` | C8 | RW | Name of connected controller |
| `netRemote.sys.info.dmruuid` | C8 | RO | DMR UUID |
| `netRemote.sys.info.netRemoteVendorId` | C8 | RO | Vendor ID |
| `netRemote.sys.info.activeSession` | E8 | RO | Whether a session is active |

#### Capabilities (Read-Only Lists)

| Node | Type | Description |
|------|------|-------------|
| `netRemote.sys.caps.validModes` | List | Available modes for this device |
| `netRemote.sys.caps.volumeSteps` | U8 | Number of volume steps |
| `netRemote.sys.caps.eqPresets` | List | Available EQ presets |
| `netRemote.sys.caps.eqBands` | List | EQ band configuration |
| `netRemote.sys.caps.dabFreqList` | List | DAB frequency table |
| `netRemote.sys.caps.fmFreqRange.lower` | U32 | FM minimum frequency |
| `netRemote.sys.caps.fmFreqRange.upper` | U32 | FM maximum frequency |
| `netRemote.sys.caps.fmFreqRange.stepSize` | U32 | FM step size |
| `netRemote.sys.caps.clockSourceList` | List | Clock source options |
| `netRemote.sys.caps.validLang` | List | Supported languages |
| `netRemote.sys.caps.utcSettingsList` | List | UTC offset options |

#### Clock

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.clock.localDate` | C8 | RW | Local date |
| `netRemote.sys.clock.localTime` | C8 | RW | Local time |
| `netRemote.sys.clock.timeZone` | C8 | RW | Timezone |
| `netRemote.sys.clock.utcOffset` | S32 | RW | UTC offset in seconds |
| `netRemote.sys.clock.dst` | E8 | RW | DST toggle |
| `netRemote.sys.clock.mode` | E8 | RW | 12/24 hour format |
| `netRemote.sys.clock.dateFormat` | E8 | RW | Date display format |
| `netRemote.sys.clock.source` | E8 | RW | Clock sync source |

#### Alarms

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.alarm.config` | List | RW | Alarm configuration |
| `netRemote.sys.alarm.status` | E8 | RO | Alarm state (IDLE/ALARMING/SNOOZING) |
| `netRemote.sys.alarm.current` | S8 | RO | Current alarm ID |
| `netRemote.sys.alarm.duration` | U32 | RO | Alarm duration |
| `netRemote.sys.alarm.snooze` | U8 | RW | Snooze duration |
| `netRemote.sys.alarm.snoozing` | U16 | RO | Current snooze status |
| `netRemote.sys.alarm.configChanged` | S8 | RO | Alarm config change notification |

#### Network

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.net.wlan.connectedSSID` | C8 | RO | Connected WiFi network |
| `netRemote.sys.net.wlan.rssi` | S8 | RO | WiFi signal strength (dBm) |
| `netRemote.sys.net.wlan.macAddress` | C8 | RO | WiFi MAC |
| `netRemote.sys.net.wlan.interfaceEnable` | E8 | RW | WiFi on/off |
| `netRemote.sys.net.wlan.scan` | E8 | RW | Trigger WiFi scan |
| `netRemote.sys.net.wlan.scanList` | List | RO | Available networks |
| `netRemote.sys.net.wlan.profiles` | List | RO | Saved WiFi profiles |
| `netRemote.sys.net.wlan.setSSID` | C8 | RW | Set WiFi network name |
| `netRemote.sys.net.wlan.setPassphrase` | C8 | RW | Set WiFi password |
| `netRemote.sys.net.wlan.setAuthType` | E8 | RW | Set WiFi auth type |
| `netRemote.sys.net.wlan.setEncType` | E8 | RW | Set WiFi encryption type |
| `netRemote.sys.net.wlan.performWPS` | E8 | RW | Trigger WPS connection |
| `netRemote.sys.net.wlan.region` | E8 | RW | WiFi regulatory region |
| `netRemote.sys.net.wired.interfaceEnable` | E8 | RW | Ethernet on/off |
| `netRemote.sys.net.wired.macAddress` | C8 | RO | Ethernet MAC |
| `netRemote.sys.net.ipConfig.dhcp` | E8 | RW | DHCP on/off |
| `netRemote.sys.net.ipConfig.address` | U32 | RW | IP address |
| `netRemote.sys.net.ipConfig.subnetMask` | U32 | RW | Subnet mask |
| `netRemote.sys.net.ipConfig.gateway` | U32 | RW | Gateway |
| `netRemote.sys.net.ipConfig.dnsPrimary` | U32 | RW | Primary DNS |
| `netRemote.sys.net.ipConfig.dnsSecondary` | U32 | RW | Secondary DNS |
| `netRemote.sys.net.keepConnected` | E8 | RW | Keep connection alive |
| `netRemote.sys.net.commitChanges` | E8 | RW | Commit network config |

#### Firmware Update (ISU)

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.isu.control` | E8 | RW | Firmware update control |
| `netRemote.sys.isu.state` | E8 | RO | Update check state |
| `netRemote.sys.isu.mandatory` | E8 | RO | Mandatory update flag |
| `netRemote.sys.isu.version` | C8 | RO | Available version |
| `netRemote.sys.isu.summary` | C8 | RO | Update summary |
| `netRemote.sys.isu.softwareUpdateProgress` | U8 | RO | Update progress % |

### Playback Nodes (`netRemote.play.*`)

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.play.control` | E8 | RW | Transport control: 0=STOP, 1=PLAY, 2=PAUSE, 3=NEXT, 4=PREVIOUS |
| `netRemote.play.status` | E8 | RO | Playback state: IDLE, PLAYING, PAUSED, ERROR, etc. |
| `netRemote.play.info.name` | C8 | RO | Station/track name |
| `netRemote.play.info.text` | C8 | RO | Now-playing text (e.g. song title on FM RDS) |
| `netRemote.play.info.artist` | C8 | RO | Artist name |
| `netRemote.play.info.album` | C8 | RO | Album name |
| `netRemote.play.info.description` | C8 | RO | Track/stream description |
| `netRemote.play.info.graphicUri` | C8 | RO | Album art / station logo URL |
| `netRemote.play.info.duration` | U32 | RO | Track duration (ms) |
| `netRemote.play.info.providerName` | C8 | RO | Service provider name |
| `netRemote.play.info.providerLogoUri` | C8 | RO | Provider logo URL |
| `netRemote.play.position` | U32 | RW | Playback position |
| `netRemote.play.rate` | S8 | RW | Playback speed (-127 to 127 for rewind/FF) |
| `netRemote.play.repeat` | E8 | RW | Repeat mode: OFF, REPEAT_ALL, REPEAT_ONE |
| `netRemote.play.shuffle` | E8 | RW | Shuffle: ON/OFF |
| `netRemote.play.frequency` | U32 | RW | Current radio frequency (Hz) |
| `netRemote.play.signalStrength` | U8 | RO | Signal strength % |
| `netRemote.play.feedback` | E8 | RW | Track feedback: IDLE, POSITIVE, NEGATIVE |
| `netRemote.play.rating` | E8 | RW | Track rating: NEUTRAL, POSITIVE, NEGATIVE |
| `netRemote.play.scrobble` | E8 | RW | Scrobbling on/off |
| `netRemote.play.addPreset` | U32 | RW | Add current track to preset |
| `netRemote.play.caps` | U32 | RO | Playback capability flags |
| `netRemote.play.alerttone` | E8 | RW | Alert tone: IDLE/PLAY |
| `netRemote.play.errorStr` | C8 | RO | Playback error message |
| `netRemote.play.serviceIds.dabEnsembleId` | U16 | RO | DAB ensemble ID |
| `netRemote.play.serviceIds.dabServiceId` | U32 | RO | DAB service ID |
| `netRemote.play.serviceIds.fmRdsPi` | U16 | RO | FM RDS PI code |
| `netRemote.play.serviceIds.ecc` | U8 | RO | Extended country code |

### Navigation Nodes (`netRemote.nav.*`)

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.nav.state` | E8 | RW | Navigation state: 0=OFF, 1=ON. **Must be set to 1 before other nav commands work.** |
| `netRemote.nav.status` | E8 | RO | WAITING, READY, FAIL, FATAL_ERR, READY_ROOT |
| `netRemote.nav.list` | List | RO | Items in current directory (with type, name, artist, graphicUri) |
| `netRemote.nav.numItems` | S32 | RO | Count of items in current list |
| `netRemote.nav.depth` | U8 | RO | Current directory depth |
| `netRemote.nav.currentTitle` | C8 | RO | Current item title |
| `netRemote.nav.description` | C8 | RO | Current item description |
| `netRemote.nav.searchTerm` | C8 | RW | Search query |
| `netRemote.nav.browseMode` | U32 | RW | Browse mode |
| `netRemote.nav.caps` | U32 | RO | Navigation capabilities bitmap |
| `netRemote.nav.errorStr` | C8 | RO | Error message |
| `netRemote.nav.refreshFlag` | E8 | RW | Trigger refresh |
| `netRemote.nav.action.navigate` | U32 | SET | Navigate into a directory item (by item key) |
| `netRemote.nav.action.selectItem` | U32 | SET | Select/play an item (by item key) |
| `netRemote.nav.action.selectPreset` | U32 | RW | Select a preset |
| `netRemote.nav.action.dabScan` | E8 | RW | Trigger DAB scan: IDLE/SCAN |
| `netRemote.nav.action.dabPrune` | E8 | RW | Prune invalid DAB stations: IDLE/PRUNE |
| `netRemote.nav.action.context` | U32 | RW | Navigation context ID |

#### Presets

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.nav.presets` | List | RO | All saved presets |
| `netRemote.nav.preset.currentPreset` | U32 | RO | Currently active preset index |
| `netRemote.nav.preset.delete` | U32 | RW | Delete a preset by index |
| `netRemote.nav.preset.listversion` | U32 | RW | Preset list version |
| `netRemote.nav.preset.swap.index1` | U32 | RW | First swap position |
| `netRemote.nav.preset.swap.index2` | U32 | RW | Second swap position |
| `netRemote.nav.preset.swap.swap` | U32 | RW | Execute swap |
| `netRemote.nav.preset.upload.*` | Various | RW | Upload preset (name, blob, type, artworkUrl) |
| `netRemote.nav.preset.download.*` | Various | RO | Download preset data |

#### Amazon Music

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.nav.amazonMpLoginUrl` | C8 | RO | Amazon login URL |
| `netRemote.nav.amazonMpLoginComplete` | E8 | RW | Login complete flag |
| `netRemote.nav.amazonMpGetRating` | U8 | RO | Current rating |
| `netRemote.nav.amazonMpSetRating` | E8 | RW | Set rating |

### Other Node Categories

| Category | Prefix | Description |
|----------|--------|-------------|
| **Bluetooth** | `netRemote.bluetooth.*` | BT discovery, pairing, device management |
| **Spotify** | `netRemote.spotify.*` | Spotify Connect authentication and control |
| **AirPlay** | `netRemote.airplay.*` | AirPlay configuration |
| **Multiroom** | `netRemote.multiroom.*` | Multiroom group management |
| **Multichannel** | `netRemote.multichannel.*` | Multi-channel audio |
| **Google Cast** | `netRemote.cast.*` | Chromecast integration |
| **Amazon Alexa** | `netRemote.avs.*` | Alexa Voice Service integration |
| **Platform** | `netRemote.platform.*` | LED intensity, OEM colour settings |
| **Debug** | `netRemote.debug.*` | Debug tracing, incident reports |
| **FSDCA** | `netRemote.fsdca.*` | Device association authentication |
| **Test** | `netRemote.test.*` | Network testing utilities |
| **Misc** | `netRemote.misc.*` | Miscellaneous settings |

### Mode Numbers

Mode numbers (used with `netRemote.sys.mode`) vary by device. To get the valid modes for a specific radio:

```
GET /fsapi/LIST_GET_NEXT/netRemote.sys.caps.validModes/-1?pin=1234&maxItems=100
```

Typical mappings (vary by model):

| Value | Mode (Model A) | Mode (Model B) |
|-------|----------------|----------------|
| 0 | Internet Radio | Internet Radio |
| 1 | Spotify | Music Player |
| 2 | Player | DAB |
| 3 | AUX IN | FM |
| 4 | -- | AUX |
| 5 | -- | Bluetooth |

You must query the device to get its specific mode list.

---

## 5. Radios That Use This Platform

The Frontier Smart platform powers radios from a huge number of brands. Known brands include:

### Major Brands
- **Roberts** (Revival iStream 3L, Stream 93i, Stream 104, Stream 10, SB1)
- **Pure** (Evoke range, Elan range)
- **Revo** (SuperConnect, Pixis RX)
- **Hama** (DIR3100, IR100, HiFi Tuner DIT2000, IR110)
- **Medion** (Life P85044, Life E85006, Life P85040)
- **Sangean**
- **Ruark Audio** (R2)
- **TechniSat** (DigiRadio 450)
- **Teufel**
- **Sonoro**
- **Como Audio**
- **Pinell** (Supersound II)
- **Denver**
- **Goodmans**
- **Auna**
- **Peaq**
- **Silvercrest** (SIRD 14 C1, SIRD 14 B1)
- **Noxon**
- **Tiny Audio**
- **DUAL** (IR6)
- **TERRIS**

### Premium/Pro Brands (via airable integration)
- Sony, Philips, Panasonic, Bose, Bang & Olufsen, Harman Kardon, JBL, Marshall, Urbanears, Cambridge Audio, KEF, Linn, Dynaudio, Yamaha, Technics, Crestron

(Note: some premium brands may use airable's content API directly without the Frontier Smart Venice hardware)

---

## 6. Official Documentation & SDK

### Official Resources

**There is no publicly available official SDK or API documentation.**

Frontier Smart provides documentation only to their **business customers** (radio manufacturers) through a protected portal:

- **Customer Area:** https://www.frontiersmart.com/customer-area/ (requires login)
- **Support Portal:** https://frontiersmart.atlassian.net/ (Confluence/Jira, for licensed customers)

### What IS Publicly Available

- Frontier Smart's marketing website: https://www.frontiersmart.com/
- Venice X product brief: https://www.frontiersmart.com/wp-content/uploads/2021/10/Venice-X_PB.pdf
- UNDOK help: https://jsm.support.frontiersmart.com/servicedesk/customer/portal/9/topic/fec077e0-eacd-4a38-b69a-1d0df216e39f

### Community Documentation (the real source of truth)

All practical FSAPI documentation comes from community reverse-engineering:

| Resource | URL | Description |
|----------|-----|-------------|
| **fsapi-tools** (most comprehensive) | https://matrixeditor.github.io/fsapi-tools/ | ALL nodes, firmware analysis, Python tools |
| **fsapi-tools GitHub** | https://github.com/MatrixEditor/fsapi-tools | Source code and node definitions |
| **flammy FSAPI.md** | https://github.com/flammy/fsapi/blob/master/FSAPI.md | Protocol documentation with all operations |
| **tiwilliam REVERSE.md** | https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md | Protocol reverse engineering details |
| **ex_frontier** | https://hexdocs.pm/ex_frontier/fsapi.html | Clean FSAPI protocol explanation |
| **Half-Shot blog** | https://half-shot.uk/blog/new-frontiers/ | Airable backend reverse engineering |
| **Home Assistant docs** | https://www.home-assistant.io/integrations/frontier_silicon/ | Practical setup and usage |
| **openHAB binding** | https://www.openhab.org/addons/bindings/fsinternetradio/ | Device list and setup |

---

## 7. Quick Reference: Controlling a Radio

### Step 1: Find the Radio

Send an SSDP M-SEARCH to `239.255.255.250:1900` with ST `urn:schemas-frontier-silicon-com:fs_reference:fsapi:1`, or just try `http://<known-ip>/device` or `http://<known-ip>:2244/device`.

### Step 2: Create a Session

```bash
curl "http://192.168.1.100/fsapi/CREATE_SESSION?pin=1234"
```

### Step 3: Get Device Info

```bash
curl "http://192.168.1.100/fsapi/GET/netRemote.sys.info.friendlyName?pin=1234&sid=<sid>"
curl "http://192.168.1.100/fsapi/GET/netRemote.sys.info.version?pin=1234&sid=<sid>"
```

### Step 4: Control It

```bash
# Power on
curl "http://192.168.1.100/fsapi/SET/netRemote.sys.power?pin=1234&sid=<sid>&value=1"

# Set volume to 5
curl "http://192.168.1.100/fsapi/SET/netRemote.sys.audio.volume?pin=1234&sid=<sid>&value=5"

# Get current station name
curl "http://192.168.1.100/fsapi/GET/netRemote.play.info.name?pin=1234&sid=<sid>"

# List available modes
curl "http://192.168.1.100/fsapi/LIST_GET_NEXT/netRemote.sys.caps.validModes/-1?pin=1234&maxItems=100"

# Switch mode (e.g. to Internet Radio, mode 0)
curl "http://192.168.1.100/fsapi/SET/netRemote.sys.mode?pin=1234&sid=<sid>&value=0"

# List presets
curl "http://192.168.1.100/fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=20"

# Select preset 3
curl "http://192.168.1.100/fsapi/SET/netRemote.nav.action.selectPreset?pin=1234&sid=<sid>&value=3"

# Play/Pause
curl "http://192.168.1.100/fsapi/SET/netRemote.play.control?pin=1234&sid=<sid>&value=1"  # PLAY
curl "http://192.168.1.100/fsapi/SET/netRemote.play.control?pin=1234&sid=<sid>&value=2"  # PAUSE
```

### Step 5: Browse Content (Navigation)

```bash
# Enable navigation
curl "http://192.168.1.100/fsapi/SET/netRemote.nav.state?pin=1234&sid=<sid>&value=1"

# List items
curl "http://192.168.1.100/fsapi/LIST_GET_NEXT/netRemote.nav.list/-1?pin=1234&sid=<sid>&maxItems=20"

# Navigate into a folder (e.g. item 0)
curl "http://192.168.1.100/fsapi/SET/netRemote.nav.action.navigate?pin=1234&sid=<sid>&value=0"

# Select/play an item
curl "http://192.168.1.100/fsapi/SET/netRemote.nav.action.selectItem?pin=1234&sid=<sid>&value=3"
```

---

## Sources

### Frontier Smart Official
- [Frontier Smart Technologies (website)](https://www.frontiersmart.com/)
- [Venice X Product Brief (PDF)](https://www.frontiersmart.com/wp-content/uploads/2021/10/Venice-X_PB.pdf)
- [Frontier Smart Customer Area](https://www.frontiersmart.com/customer-area/)
- [OKTIV product page](https://www.frontiersmart.com/product/oktiv/)
- [OKTIV on Google Play](https://play.google.com/store/apps/details?id=com.frontiersmart.oktiv)
- [UNDOK on App Store](https://apps.apple.com/us/app/undok/id940349372)

### Airable (Nuvola Transition)
- [Frontier Smart transition to airable](https://www.airablenow.com/fs-transition/)
- [airable.fm portal](https://airable.fm/auth)
- [FAQ for Venice module devices](https://www.airablenow.com/faq-en/)

### Community FSAPI Documentation
- [fsapi-tools docs (comprehensive)](https://matrixeditor.github.io/fsapi-tools/)
- [fsapi-tools GitHub](https://github.com/MatrixEditor/fsapi-tools)
- [flammy/fsapi FSAPI.md (protocol reference)](https://github.com/flammy/fsapi/blob/master/FSAPI.md)
- [flammy/fsapi Documentation.md](https://github.com/flammy/fsapi/blob/master/Documentation.md)
- [tiwilliam/fsapi REVERSE.md](https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md)
- [ex_frontier FSAPI docs](https://hexdocs.pm/ex_frontier/fsapi.html)

### Home Automation Integrations
- [Home Assistant Frontier Silicon integration](https://www.home-assistant.io/integrations/frontier_silicon/)
- [openHAB FS Internet Radio binding](https://www.openhab.org/addons/bindings/fsinternetradio/)
- [ioBroker frontier_silicon adapter](https://github.com/iobroker-community-adapters/ioBroker.frontier_silicon)

### SSDP/Discovery
- [Wolfgang Ziegler: SSDP and Internet Radios](https://wolfgang-ziegler.com/blog/udp-multicasts-ssdp-and-windows-phone)
- [openHAB Community: Frontier Silicon via HTTP](https://community.openhab.org/t/frontier-silicon-radios-via-http/90186)

### Firmware
- [cweiske/frontier-silicon-firmwares](https://github.com/cweiske/frontier-silicon-firmwares)
- [MatrixEditor/frontier-silicon-firmwares](https://github.com/MatrixEditor/frontier-silicon-firmwares)
- [Frontier Silicon firmware downloads (blog)](https://cweiske.de/tagebuch/frontier-firmware-dl.htm)

### Other Community Projects
- [GitHub topic: frontier-silicon](https://github.com/topics/frontier-silicon)
- [KIMB-technologies/Radio-API](https://github.com/KIMB-technologies/Radio-API)
- [SaintPaddy/my-frontier-silicon (HA custom integration)](https://github.com/SaintPaddy/my-frontier-silicon)
- [OKTIV discussion on HA Community](https://community.home-assistant.io/t/frontier-silicon-integration-oktiv-not-undok-app-supported-devices-working-or-not/634118)

### General
- [LearnHole: Frontier Smart Technologies overview](https://learnhole.com/frontier-smart-technologies/)
- [IT History Society: Frontier Silicon](https://do.ithistory.org/db/companies/frontier-silicon)
- [OKTIV case study (Green Custard)](https://www.green-custard.com/customers/frontier-smart-technologies/)
- [Sangean: Nuvola to Airable transition](https://us.sangean.com/en/blog/142)
