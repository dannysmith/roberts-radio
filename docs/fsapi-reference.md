# FSAPI Protocol Reference

Reference for the Frontier Smart API (FSAPI) as used by the Roberts Revival iStream 3L and other Frontier Smart-based radios. Consolidated from community reverse-engineering efforts and live device probing.

For the original research documents, see `docs/archive/`.

## Protocol Overview

FSAPI is a simple HTTP API. Send GET requests, receive XML responses. No official documentation exists -- everything here is community reverse-engineered.

**Base URL:** `http://<radio-ip>/fsapi`

**Authentication:** Numeric PIN (default `1234`), passed as `pin=` query parameter. Session-based auth is also supported (see below) but pin-per-request is simpler and sufficient for most uses.

## Operations

| Operation | Purpose | Example |
|-----------|---------|---------|
| `GET` | Read a node value | `/fsapi/GET/netRemote.sys.audio.volume?pin=1234` |
| `SET` | Write a node value | `/fsapi/SET/netRemote.sys.audio.volume?pin=1234&value=10` |
| `LIST_GET_NEXT` | Paginate a list node | `/fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=10` |
| `GET_MULTIPLE` | Read several nodes at once | `/fsapi/GET_MULTIPLE?pin=1234&node=X&node=Y` |
| `CREATE_SESSION` | Get a session ID | `/fsapi/CREATE_SESSION?pin=1234` |
| `DELETE_SESSION` | Destroy a session | `/fsapi/DELETE_SESSION?pin=1234&sid=<sid>` |
| `GET_NOTIFIES` | Long-poll for changes | `/fsapi/GET_NOTIFIES?pin=1234&sid=<sid>` |

**URL structure:** `/fsapi/<OPERATION>/<NODE>?pin=<PIN>[&value=<V>][&maxItems=<N>]`

**GET_MULTIPLE** is limited to ~5 nodes per request (the radio's HTTP server rejects long URLs).

**LIST_GET_NEXT** uses `-1` as starting index to mean "from the beginning". Returns `FS_LIST_END` when no more items exist.

**GET_NOTIFIES** requires a session ID. Keeps the connection open and sends XML fragments when node values change. Returns `FS_TIMEOUT` if nothing changes. Only one session at a time -- creating a new one kills the previous.

## Response Format

```xml
<fsapiResponse>
  <status>FS_OK</status>
  <value><u8>10</u8></value>
</fsapiResponse>
```

### Status Codes

| Status | Meaning |
|--------|---------|
| `FS_OK` | Success |
| `FS_FAIL` | Value failed validation |
| `FS_PACKET_BAD` | SET on a read-only node |
| `FS_NODE_BLOCKED` | Node inaccessible in current mode |
| `FS_NODE_DOES_NOT_EXIST` | Invalid node path |
| `FS_TIMEOUT` | Long-poll timeout (normal for GET_NOTIFIES) |
| `FS_LIST_END` | No more list entries |

HTTP 403 = invalid PIN. HTTP 404 = invalid session or endpoint.

### Data Types

| Tag | Type |
|-----|------|
| `<u8>`, `<u16>`, `<u32>` | Unsigned integers |
| `<s8>`, `<s16>`, `<s32>` | Signed integers |
| `<c8_array>` | String |
| `<e8>` | Enumeration (8-bit) |

## Node Reference

Nodes use dot-notation paths (e.g. `netRemote.sys.audio.volume`). Type is RW (read-write) or RO (read-only).

### System: Audio

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.audio.volume` | U8 | RW | Volume (0 to volumeSteps) |
| `netRemote.sys.audio.mute` | E8 | RW | 0=unmuted, 1=muted |
| `netRemote.sys.audio.eqPreset` | U8 | RW | EQ preset index |
| `netRemote.sys.audio.eqCustom.param0-4` | S16 | RW | Custom EQ bands (-14 to +14) |
| `netRemote.sys.audio.airableQuality` | E8 | RW | Stream quality selection |

### System: Power & Mode

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.power` | E8 | RW | 0=standby, 1=on |
| `netRemote.sys.mode` | U32 | RW | Current mode (device-specific IDs) |
| `netRemote.sys.sleep` | E8 | RW | Sleep timer (seconds, 0=off) |

### System: Device Info

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.info.friendlyName` | C8 | RW | Device name |
| `netRemote.sys.info.version` | C8 | RO | Firmware version |
| `netRemote.sys.info.radioId` | C8 | RO | Radio ID (MAC-based) |
| `netRemote.sys.info.dmruuid` | C8 | RO | DMR UUID |
| `netRemote.sys.info.activeSession` | E8 | RO | Session active flag |

### System: Capabilities

| Node | Type | Description |
|------|------|-------------|
| `netRemote.sys.caps.validModes` | List | Available modes |
| `netRemote.sys.caps.volumeSteps` | U8 | Max volume level |
| `netRemote.sys.caps.eqPresets` | List | Available EQ presets |
| `netRemote.sys.caps.eqBands` | List | EQ band config |
| `netRemote.sys.caps.dabFreqList` | List | DAB frequencies |
| `netRemote.sys.caps.fmFreqRange.*` | U32 | FM range (lower, upper, stepSize) |

### System: Clock

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.clock.localDate` | C8 | RW | `YYYYMMDD` |
| `netRemote.sys.clock.localTime` | C8 | RW | `HHMMSS` |
| `netRemote.sys.clock.utcOffset` | S32 | RW | UTC offset in seconds |
| `netRemote.sys.clock.dst` | E8 | RW | DST toggle |
| `netRemote.sys.clock.source` | E8 | RW | Clock sync source |

### System: Alarms

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.alarm.config` | List | RW | Alarm configurations |
| `netRemote.sys.alarm.status` | E8 | RO | IDLE / ALARMING / SNOOZING |
| `netRemote.sys.alarm.snooze` | U8 | RW | Snooze duration |

### System: Network

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.sys.net.ipConfig.address` | U32 | RW | IP (as 32-bit int) |
| `netRemote.sys.net.ipConfig.dhcp` | E8 | RW | DHCP on/off |
| `netRemote.sys.net.wlan.connectedSSID` | C8 | RO | Connected WiFi |
| `netRemote.sys.net.wlan.rssi` | S8 | RO | WiFi signal (dBm) |
| `netRemote.sys.net.wlan.macAddress` | C8 | RO | WiFi MAC |
| `netRemote.sys.net.keepConnected` | E8 | RW | Keep-alive |

### Playback

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.play.control` | E8 | RW | 0=STOP, 1=PLAY, 2=PAUSE, 3=NEXT, 4=PREVIOUS |
| `netRemote.play.status` | E8 | RO | 1=buffering, 2=playing, 3=paused |
| `netRemote.play.info.name` | C8 | RO | Station/track name |
| `netRemote.play.info.text` | C8 | RO | Now-playing text |
| `netRemote.play.info.artist` | C8 | RO | Artist |
| `netRemote.play.info.album` | C8 | RO | Album |
| `netRemote.play.info.graphicUri` | C8 | RO | Artwork URL |
| `netRemote.play.info.duration` | U32 | RO | Duration in ms (0 for live streams) |
| `netRemote.play.position` | U32 | RW | Position in ms |
| `netRemote.play.rate` | S8 | RW | Playback speed |
| `netRemote.play.repeat` | E8 | RW | Repeat mode |
| `netRemote.play.shuffle` | E8 | RW | Shuffle on/off |
| `netRemote.play.frequency` | U32 | RW | Radio frequency (Hz) |
| `netRemote.play.signalStrength` | U8 | RO | Signal strength % |
| `netRemote.play.addPreset` | U32 | RW | Save current to preset slot |
| `netRemote.play.caps` | U32 | RO | Capability flags (undocumented bitmask) |

### Navigation

Navigation is **stateful** -- you must enable it (`nav.state=1`) before other nav commands work. Each browse operation triggers an HTTPS request to Airable's cloud servers.

| Node | Type | RW | Description |
|------|------|-----|-------------|
| `netRemote.nav.state` | E8 | RW | 0=off, 1=on (must enable first) |
| `netRemote.nav.status` | E8 | RO | WAITING, READY, FAIL, etc. |
| `netRemote.nav.list` | List | RO | Items at current level |
| `netRemote.nav.numItems` | S32 | RO | Item count |
| `netRemote.nav.depth` | U8 | RO | Directory depth |
| `netRemote.nav.currentTitle` | C8 | RO | Current level title |
| `netRemote.nav.searchTerm` | C8 | RW | Search query (form backing store; setting alone does not trigger search) |
| `netRemote.nav.caps` | U32 | RO | Nav capability flags |
| `netRemote.nav.action.navigate` | U32 | SET | Enter a directory (by item key, or 4294967295 to go back) |
| `netRemote.nav.action.selectItem` | U32 | SET | Play an item (by item key) |
| `netRemote.nav.action.selectPreset` | U32 | RW | Select a preset |
| `netRemote.nav.action.dabScan` | E8 | RW | Trigger DAB scan |

### Presets

Presets are **per-mode**: Internet Radio and Podcasts get 40 slots each, DAB and FM get 10 each. You must be in the correct mode to access that mode's presets.

| Operation | Command |
|-----------|---------|
| List presets | `LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=100` |
| Select preset | `SET/netRemote.nav.action.selectPreset?pin=1234&value=<index>` |
| Save current to slot | `SET/netRemote.play.addPreset?pin=1234&value=<index>` |
| Delete preset | `SET/netRemote.nav.preset.delete?pin=1234&value=<index>` |
| Swap positions | SET `swap.index1`, `swap.index2`, then `swap.swap=1` |

You **cannot create a preset from an arbitrary URL** -- the upload blob format is undocumented. You must navigate to and play the station first, then save it.

### Spotify

| Node | Type | Description |
|------|------|-------------|
| `netRemote.spotify.username` | C8 | Connected Spotify account |
| `netRemote.spotify.status` | E8 | Connection status |
| `netRemote.spotify.bitRate` | E8 | Quality (0=Low, 1=Normal, 2=High, 3=Very High) |
| `netRemote.spotify.lastError` | E8 | Last error code |

## Device-Specific: Roberts Revival iStream 3L

Based on live probing of a Venice X (FS2340) module running firmware V4.6.18:

- **96 GET nodes** respond successfully, **1 blocked** (`play.rating`), **48 missing**, **9 LIST nodes**
- **Volume steps:** 31 (0-31)
- **Modes:** 10 (Internet Radio, Podcasts, Deezer, Amazon Music, Spotify, USB, DAB, FM, Bluetooth, Aux In)
- **EQ presets:** 7
- **FM range:** 87500-108000 Hz, step 50
- **Default PIN:** 1234
- **SSDP search target:** `urn:schemas-frontier-silicon-com:fs_reference:fsapi:1`
- **No SSL certificate verification** on HTTPS connections to Airable (enables community self-hosted backends via DNS redirection)

Full probe results are in `docs/archive/probe-results.json`.
