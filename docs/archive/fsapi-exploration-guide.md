# FSAPI Hands-On Exploration Guide

Practical guide for exploring the Frontier Silicon API (FSAPI) on a Roberts Revival iStream 3L from macOS.

## The Protocol in 60 Seconds

FSAPI is a simple HTTP API. The radio runs a web server (port 80). You send HTTP GET requests, you get XML responses. Every setting and piece of state is a "node" with a dot-notation path like `netRemote.sys.audio.volume`. You can GET, SET, or LIST nodes. Authentication is a 4-digit PIN (default: `1234`).

**Base URL format:** `http://<RADIO_IP>/fsapi/<OPERATION>/<NODE>?pin=<PIN>`

**Operations:**
| Operation | URL Pattern | Purpose |
|-----------|------------|---------|
| `GET` | `/fsapi/GET/netRemote.sys.power?pin=1234` | Read a value |
| `SET` | `/fsapi/SET/netRemote.sys.audio.volume?pin=1234&value=10` | Write a value |
| `LIST_GET_NEXT` | `/fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=100` | List items (paginated) |
| `CREATE_SESSION` | `/fsapi/CREATE_SESSION?pin=1234` | Get a session ID |
| `DELETE_SESSION` | `/fsapi/DELETE_SESSION?sid=12345` | End session |
| `GET_NOTIFIES` | `/fsapi/GET_NOTIFIES?sid=12345` | Long-poll for changes |
| `GET_MULTIPLE` | `/fsapi/GET_MULTIPLE?pin=1234&node=netRemote.sys.power&node=netRemote.sys.mode` | Batch read |

**Response format (XML):**
```xml
<fsapiResponse>
  <status>FS_OK</status>
  <value><u8>1</u8></value>
</fsapiResponse>
```

**Status codes:** `FS_OK`, `FS_FAIL`, `FS_PACKET_BAD` (read-only node), `FS_NODE_BLOCKED` (wrong mode), `FS_NODE_DOES_NOT_EXIST`, `FS_TIMEOUT`, `FS_LIST_END`

**Important:** The device supports only **one concurrent session**. Creating a new session invalidates the previous one. The UNDOK app creates sessions, so if UNDOK is connected, your session may get killed and vice versa.

---

## 1. Finding the Radio on the Network

### Option A: Check Your Router's DHCP Table
The simplest approach. Log into your router's admin page and look for the radio's hostname in the connected devices list. Roberts radios typically show up with their friendly name.

### Option B: SSDP/UPnP Discovery (Recommended)
The radio advertises itself via SSDP using the service URN `urn:schemas-frontier-silicon-com:fs_reference:fsapi:1`.

**Using `async-upnp-client` (Python):**
```bash
pip install async-upnp-client
upnp-client search
```
This will print JSON with discovered devices, including the radio's location URL.

**Using `upnp-client` with pretty printing:**
```bash
upnp-client --pprint search
```
Look for entries mentioning "Frontier" or "Roberts" or your radio's friendly name.

### Option C: nmap
```bash
# Scan your subnet for devices with port 80 open
nmap -p 80 --open 192.168.1.0/24

# Or specifically look for UPnP
nmap -p 80,1900 --open 192.168.1.0/24
```

### Option D: DNS-SD / Bonjour
```bash
# macOS built-in - look for UPnP devices
dns-sd -B _upnp._tcp
```

### Verify You Found It
Once you have a candidate IP, confirm it's the radio:
```bash
curl "http://<IP>/fsapi/GET/netRemote.sys.info.friendlyName?pin=1234"
```
If you get back XML with `<status>FS_OK</status>` and a `<c8_array>` containing your radio's name, you've found it. If you get `403 Forbidden`, the PIN is wrong (try `0000`).

---

## 2. Curl-Based Exploration (Fastest Start)

This requires zero installation. Just a terminal.

### First Commands to Run

```bash
# Set your radio's IP
RADIO=192.168.1.XXX
PIN=1234

# 1. Check it's alive and get the friendly name
curl "http://$RADIO/fsapi/GET/netRemote.sys.info.friendlyName?pin=$PIN"

# 2. Get firmware version
curl "http://$RADIO/fsapi/GET/netRemote.sys.info.version?pin=$PIN"

# 3. Get the radio's unique ID
curl "http://$RADIO/fsapi/GET/netRemote.sys.info.radioId?pin=$PIN"

# 4. Check power state (1=on, 0=standby)
curl "http://$RADIO/fsapi/GET/netRemote.sys.power?pin=$PIN"

# 5. Get current volume
curl "http://$RADIO/fsapi/GET/netRemote.sys.audio.volume?pin=$PIN"

# 6. Get max volume steps
curl "http://$RADIO/fsapi/GET/netRemote.sys.caps.volumeSteps?pin=$PIN"

# 7. Get current mode (Internet Radio, DAB, FM, etc.)
curl "http://$RADIO/fsapi/GET/netRemote.sys.mode?pin=$PIN"

# 8. List all available modes
curl "http://$RADIO/fsapi/LIST_GET_NEXT/netRemote.sys.caps.validModes/-1?pin=$PIN&maxItems=20"

# 9. What's currently playing?
curl "http://$RADIO/fsapi/GET/netRemote.play.info.name?pin=$PIN"
curl "http://$RADIO/fsapi/GET/netRemote.play.info.text?pin=$PIN"
curl "http://$RADIO/fsapi/GET/netRemote.play.info.artist?pin=$PIN"
curl "http://$RADIO/fsapi/GET/netRemote.play.info.album?pin=$PIN"

# 10. List favourite/preset stations
curl "http://$RADIO/fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=$PIN&maxItems=50"

# 11. Get network info
curl "http://$RADIO/fsapi/GET/netRemote.sys.net.wlan.connectedSSID?pin=$PIN"
curl "http://$RADIO/fsapi/GET/netRemote.sys.net.wlan.rssi?pin=$PIN"
curl "http://$RADIO/fsapi/GET/netRemote.sys.net.wlan.macAddress?pin=$PIN"

# 12. Batch read multiple nodes at once
curl "http://$RADIO/fsapi/GET_MULTIPLE?pin=$PIN&node=netRemote.sys.power&node=netRemote.sys.mode&node=netRemote.sys.audio.volume&node=netRemote.play.info.name&node=netRemote.play.info.text"
```

### Controlling the Radio

```bash
# Turn on
curl "http://$RADIO/fsapi/SET/netRemote.sys.power?pin=$PIN&value=1"

# Turn off (standby)
curl "http://$RADIO/fsapi/SET/netRemote.sys.power?pin=$PIN&value=0"

# Set volume (0-20 typically, check volumeSteps for your device)
curl "http://$RADIO/fsapi/SET/netRemote.sys.audio.volume?pin=$PIN&value=8"

# Mute / unmute
curl "http://$RADIO/fsapi/SET/netRemote.sys.audio.mute?pin=$PIN&value=1"
curl "http://$RADIO/fsapi/SET/netRemote.sys.audio.mute?pin=$PIN&value=0"

# Switch mode (use the key values from validModes list)
curl "http://$RADIO/fsapi/SET/netRemote.sys.mode?pin=$PIN&value=0"

# Play/pause/next/prev (1=play, 2=pause, 3=next, 4=previous)
curl "http://$RADIO/fsapi/SET/netRemote.play.control?pin=$PIN&value=1"

# Select a preset station
curl "http://$RADIO/fsapi/SET/netRemote.nav.action.selectPreset?pin=$PIN&value=0"

# Set sleep timer (seconds, 0=off)
curl "http://$RADIO/fsapi/SET/netRemote.sys.sleep?pin=$PIN&value=1800"
```

### Shell Helper for Easier Exploration

```bash
# Add these to your shell for a quick exploration session:
RADIO=192.168.1.XXX
PIN=1234

fsapi_get() { curl -s "http://$RADIO/fsapi/GET/$1?pin=$PIN" | xmllint --format - 2>/dev/null || curl -s "http://$RADIO/fsapi/GET/$1?pin=$PIN"; }
fsapi_set() { curl -s "http://$RADIO/fsapi/SET/$1?pin=$PIN&value=$2" | xmllint --format - 2>/dev/null || curl -s "http://$RADIO/fsapi/SET/$1?pin=$PIN&value=$2"; }
fsapi_list() { curl -s "http://$RADIO/fsapi/LIST_GET_NEXT/$1/-1?pin=$PIN&maxItems=${2:-100}" | xmllint --format - 2>/dev/null || curl -s "http://$RADIO/fsapi/LIST_GET_NEXT/$1/-1?pin=$PIN&maxItems=${2:-100}"; }

# Then just:
fsapi_get netRemote.sys.power
fsapi_set netRemote.sys.audio.volume 10
fsapi_list netRemote.sys.caps.validModes
```

---

## 3. Node Discovery - Enumerating Everything

**There is no "list all nodes" endpoint.** You have to try nodes and see which ones exist (return `FS_OK` vs `FS_NODE_DOES_NOT_EXIST`). But there is a well-documented set of known nodes.

### Brute-Force Node Probing Script

```bash
#!/bin/bash
RADIO=192.168.1.XXX
PIN=1234

# All known FSAPI nodes (comprehensive list from community documentation)
NODES=(
  # System Info
  netRemote.sys.info.friendlyName
  netRemote.sys.info.version
  netRemote.sys.info.radioId
  netRemote.sys.info.radioPin
  netRemote.sys.info.controllerName
  netRemote.sys.info.dmruuid
  netRemote.sys.info.activeSession

  # Power & Sleep
  netRemote.sys.power
  netRemote.sys.sleep
  netRemote.sys.state
  netRemote.sys.mode

  # Audio
  netRemote.sys.audio.volume
  netRemote.sys.audio.mute
  netRemote.sys.audio.eqPreset
  netRemote.sys.audio.eqLoudness
  netRemote.sys.audio.eqCustom.param0
  netRemote.sys.audio.eqCustom.param1
  netRemote.sys.audio.eqCustom.param2
  netRemote.sys.audio.eqCustom.param3
  netRemote.sys.audio.eqCustom.param4

  # Playback Info
  netRemote.play.info.name
  netRemote.play.info.text
  netRemote.play.info.artist
  netRemote.play.info.album
  netRemote.play.info.graphicUri
  netRemote.play.info.duration
  netRemote.play.position
  netRemote.play.status
  netRemote.play.control
  netRemote.play.rate
  netRemote.play.repeat
  netRemote.play.shuffle
  netRemote.play.shuffleStatus
  netRemote.play.scrobble
  netRemote.play.caps
  netRemote.play.errorStr
  netRemote.play.frequency
  netRemote.play.signalStrength
  netRemote.play.addPreset
  netRemote.play.addPresetStatus

  # DAB/FM Service IDs
  netRemote.play.serviceIds.dabEnsembleId
  netRemote.play.serviceIds.dabScids
  netRemote.play.serviceIds.dabServiceId
  netRemote.play.serviceIds.ecc
  netRemote.play.serviceIds.fmRdsPi

  # Navigation
  netRemote.nav.state
  netRemote.nav.status
  netRemote.nav.caps
  netRemote.nav.numItems
  netRemote.nav.depth
  netRemote.nav.browseMode
  netRemote.nav.errorStr
  netRemote.nav.searchTerm
  netRemote.nav.action.dabScan
  netRemote.nav.action.dabPrune
  netRemote.nav.action.navigate
  netRemote.nav.action.selectItem
  netRemote.nav.action.selectPreset

  # Capabilities (most are LIST operations)
  netRemote.sys.caps.volumeSteps
  netRemote.sys.caps.fmFreqRange.lower
  netRemote.sys.caps.fmFreqRange.upper
  netRemote.sys.caps.fmFreqRange.stepSize

  # Clock
  netRemote.sys.clock.localDate
  netRemote.sys.clock.localTime
  netRemote.sys.clock.mode
  netRemote.sys.clock.source
  netRemote.sys.clock.dst
  netRemote.sys.clock.utcOffset
  netRemote.sys.clock.dateFormat

  # Network
  netRemote.sys.net.ipConfig.address
  netRemote.sys.net.ipConfig.subnetMask
  netRemote.sys.net.ipConfig.gateway
  netRemote.sys.net.ipConfig.dhcp
  netRemote.sys.net.ipConfig.dnsPrimary
  netRemote.sys.net.ipConfig.dnsSecondary
  netRemote.sys.net.keepConnected
  netRemote.sys.net.wlan.connectedSSID
  netRemote.sys.net.wlan.macAddress
  netRemote.sys.net.wlan.rssi
  netRemote.sys.net.wlan.interfaceEnable
  netRemote.sys.net.wlan.setAuthType
  netRemote.sys.net.wlan.setEncType
  netRemote.sys.net.wired.macAddress
  netRemote.sys.net.wired.interfaceEnable

  # Language & Config
  netRemote.sys.lang
  netRemote.sys.cfg.irAutoPlayFlag

  # Software Update
  netRemote.sys.isu.control
  netRemote.sys.isu.state
  netRemote.sys.isu.mandatory
  netRemote.sys.isu.version
  netRemote.sys.isu.summary
  netRemote.sys.isu.softwareUpdateProgress

  # Factory Reset (BE CAREFUL)
  # netRemote.sys.factoryReset

  # RSA/Security
  netRemote.sys.rsa.publicKey
  netRemote.sys.rsa.status

  # Alarms
  netRemote.sys.alarm.current
  netRemote.sys.alarm.duration
  netRemote.sys.alarm.status
  netRemote.sys.alarm.snooze
  netRemote.sys.alarm.snoozing
  netRemote.sys.alarm.configChanged

  # Spotify
  netRemote.spotify.username
  netRemote.spotify.lastError
  netRemote.spotify.status
  netRemote.spotify.bitRate

  # AirPlay
  netRemote.airplay.clearPassword
  netRemote.airplay.setPassword

  # Multiroom
  netRemote.multiroom.caps.maxClients
  netRemote.multiroom.caps.protocolVersion
  netRemote.multiroom.device.listAllVersion
  netRemote.multiroom.device.serverStatus
  netRemote.multiroom.device.clientStatus
  netRemote.multiroom.device.clientIndex
  netRemote.multiroom.device.transportOptimisation
  netRemote.multiroom.group.name
  netRemote.multiroom.group.id
  netRemote.multiroom.group.state
  netRemote.multiroom.group.masterVolume
  netRemote.multiroom.group.streamable

  # Debug / Test
  netRemote.misc.fsDebug.component
  netRemote.misc.fsDebug.traceLevel
  netRemote.test.iperf.console
  netRemote.test.iperf.commandLine
  netRemote.test.iperf.execute
)

echo "=== Probing $(echo ${#NODES[@]}) nodes on $RADIO ==="
echo ""

for node in "${NODES[@]}"; do
  response=$(curl -s -m 2 "http://$RADIO/fsapi/GET/$node?pin=$PIN")
  status=$(echo "$response" | grep -oP '(?<=<status>).*(?=</status>)' 2>/dev/null)
  if [ "$status" = "FS_OK" ]; then
    value=$(echo "$response" | grep -oP '(?<=<value>).*(?=</value>)' 2>/dev/null)
    echo "[OK] $node = $value"
  elif [ "$status" = "FS_NODE_DOES_NOT_EXIST" ]; then
    : # skip silently
  elif [ "$status" = "FS_NODE_BLOCKED" ]; then
    echo "[BLOCKED] $node (exists but blocked in current mode)"
  else
    echo "[${status:-TIMEOUT}] $node"
  fi
done

echo ""
echo "=== LIST nodes ==="
LIST_NODES=(
  netRemote.sys.caps.validModes
  netRemote.sys.caps.eqPresets
  netRemote.sys.caps.eqBands
  netRemote.sys.caps.dabFreqList
  netRemote.sys.caps.validLang
  netRemote.sys.caps.clockSourceList
  netRemote.sys.caps.utcSettingsList
  netRemote.nav.presets
  netRemote.nav.list
  netRemote.sys.alarm.config
  netRemote.multiroom.device.listAll
)

for node in "${LIST_NODES[@]}"; do
  response=$(curl -s -m 3 "http://$RADIO/fsapi/LIST_GET_NEXT/$node/-1?pin=$PIN&maxItems=100")
  status=$(echo "$response" | grep -oP '(?<=<status>).*(?=</status>)' 2>/dev/null)
  if [ "$status" = "FS_OK" ]; then
    echo "[OK-LIST] $node (has items)"
  elif [ "$status" = "FS_LIST_END" ]; then
    echo "[EMPTY-LIST] $node (exists but empty)"
  elif [ "$status" != "FS_NODE_DOES_NOT_EXIST" ]; then
    echo "[${status:-TIMEOUT}] $node"
  fi
done
```

---

## 4. fsapi-tools CLI (`fsapi-ctl`)

### Installation

```bash
pip install fsapi-tools
```

### Usage

```bash
# GET a node value
fsapi-ctl get netremote.sys.info.friendlyName 192.168.1.XXX

# SET a node value
fsapi-ctl set netremote.sys.info.friendlyName "My Radio" 192.168.1.XXX

# View node metadata (type, permissions, etc.)
fsapi-ctl view netremote.sys.power

# Use a custom PIN
fsapi-ctl get netremote.sys.power 192.168.1.XXX --pin 0000

# Force a new session
fsapi-ctl get netremote.sys.power 192.168.1.XXX --force-session
```

**Note:** `fsapi-ctl` uses lowercase node names (e.g., `netremote.sys.power` not `netRemote.sys.power`) - it handles the conversion internally.

### Limitations
- No built-in device discovery (you need to know the IP)
- No "explore all nodes" command
- No interactive/REPL mode
- Primarily designed for scripting, not interactive exploration
- The `view` command shows metadata about a node from the library's built-in registry, not from the device itself

### When to Use It
`fsapi-ctl` is best for scripting and automation. For initial exploration, raw `curl` is actually faster because you see the raw XML and can understand the protocol directly. Use `fsapi-ctl` once you know what you want to automate.

---

## 5. Python REPL Exploration

### Using fsapi-tools

```bash
pip install fsapi-tools
python3
```

```python
from fsapi.net import FSDevice, wrap, nodes

# Connect
device = FSDevice("192.168.1.XXX")
device.pin = 1234  # if not default
device.new_session()

# Wrap for high-level API
api = wrap(device)

# Explore
print(api.friendly_name)
print(api.volume)
print(api.power)

# List all valid modes
modes = api.ls_valid_modes()
print(modes)

# Raw node access
response = device.get(nodes / "netRemote.sys.info.version")
print(response)

# Get notifications (what's changing right now)
notifies = device.get_notifies()
print(notifies)
```

### Using afsapi (async)

```bash
pip install afsapi
python3
```

```python
import asyncio
from afsapi import AFSAPI

async def explore():
    radio = await AFSAPI.create("http://192.168.1.XXX:80/device", 1234, 2)

    print("Name:", await radio.get_friendly_name())
    print("Power:", await radio.get_power())
    print("Modes:", await radio.get_modes())
    print("Current mode:", await radio.get_mode())
    print("EQ presets:", await radio.get_equalisers())
    print("Presets:", await radio.get_presets())
    print("Sleep:", await radio.get_sleep())

asyncio.run(explore())
```

**Note:** `afsapi` has a smaller API surface than `fsapi-tools` - it wraps only common operations. For deep exploration, `fsapi-tools` or raw `curl` gives you access to all nodes.

### Interactive Exploration Pattern (fsapi-tools)

The most productive REPL approach - write a small explorer:

```python
from fsapi.net import FSDevice, nodes
import xml.etree.ElementTree as ET

device = FSDevice("192.168.1.XXX")
device.new_session()

def get(node_path):
    """GET a node and print the raw response."""
    resp = device.get(nodes / node_path)
    print(f"Status: {resp.status}")
    if resp.status == "FS_OK":
        print(f"Value: {resp.value}")
    return resp

def set_val(node_path, value):
    """SET a node value."""
    resp = device.put(nodes / node_path, value=value)
    print(f"Status: {resp.status}")
    return resp

def ls(node_path, max_items=100):
    """LIST a node."""
    resp = device.list_get_next(nodes / node_path, pos=-1, max_items=max_items)
    print(f"Status: {resp.status}")
    if hasattr(resp, 'items'):
        for item in resp.items:
            print(f"  {item}")
    return resp

# Now just call these in the REPL:
# get("netRemote.sys.info.friendlyName")
# ls("netRemote.sys.caps.validModes")
# set_val("netRemote.sys.audio.volume", 8)
```

---

## 6. Network Sniffing (Watching UNDOK)

Sniffing UNDOK's traffic is valuable for discovering undocumented nodes and understanding the app's workflow.

### Using mitmproxy

Since UNDOK communicates over plain HTTP (not HTTPS) to the radio on the local network, you can intercept it easily:

```bash
brew install mitmproxy

# Start mitmproxy on your Mac
mitmproxy --mode regular --listen-port 8080
```

Then configure your iPhone/iPad to use your Mac as an HTTP proxy:
1. Settings > Wi-Fi > tap your network > Configure Proxy > Manual
2. Server: your Mac's IP, Port: 8080

Open UNDOK and browse around. Every request UNDOK makes to the radio will show up in mitmproxy. This reveals:
- Which nodes UNDOK reads on startup
- The sequence of operations for browsing internet radio stations
- How podcast/favourite management works with airable.fm
- Any undocumented nodes your specific radio supports

**Alternative - Wireshark:**
```bash
brew install --cask wireshark
```
Filter by your radio's IP: `ip.addr == 192.168.1.XXX`
Filter specifically for FSAPI: `http.request.uri contains "fsapi"`

### What to Watch For
- The navigation flow: UNDOK sets `netRemote.nav.state`, then `netRemote.nav.action.navigate`, then reads `netRemote.nav.list` in a loop
- Session management: watch the `CREATE_SESSION` and `GET_NOTIFIES` patterns
- Spotify Connect / streaming service setup sequences
- Any proprietary nodes not in the community documentation

---

## 7. Web-Based Tools

### flammy/fsapi-remote
A PHP web UI for controlling FSAPI radios. Requires a PHP web server.

**Setup:**
```bash
git clone https://github.com/flammy/fsapi-remote.git
cd fsapi-remote
composer install
# Needs a PHP-capable web server (Apache/nginx with PHP, or php -S localhost:8000)
```

Then open in browser and use the setup button to add your radio's IP. It provides a GUI for basic operations (volume, mode switching, presets).

**Verdict:** Dated (2015-era Bootstrap/jQuery/PHP). Useful as a reference implementation but not the best exploration tool. The curl/Python approaches give you more control.

### Alternative: Build Your Own
Since the API is just HTTP+XML, you could build a quick exploration UI with any framework. But for initial exploration, the terminal is fastest.

---

## 8. Recommended Exploration Sequence

**Step 1: Find the radio**
```bash
# Try SSDP first
pip install async-upnp-client
upnp-client search | grep -i -A5 "frontier\|roberts"

# Or just check your router's DHCP table
```

**Step 2: Verify connectivity and PIN**
```bash
curl "http://<IP>/fsapi/GET/netRemote.sys.info.friendlyName?pin=1234"
# If 403, try pin=0000
```

**Step 3: Get the lay of the land**
```bash
RADIO=<IP> PIN=1234

# Device identity
curl -s "http://$RADIO/fsapi/GET/netRemote.sys.info.friendlyName?pin=$PIN"
curl -s "http://$RADIO/fsapi/GET/netRemote.sys.info.version?pin=$PIN"

# What modes does it support?
curl -s "http://$RADIO/fsapi/LIST_GET_NEXT/netRemote.sys.caps.validModes/-1?pin=$PIN&maxItems=20"

# What's it doing right now?
curl -s "http://$RADIO/fsapi/GET_MULTIPLE?pin=$PIN&node=netRemote.sys.power&node=netRemote.sys.mode&node=netRemote.play.info.name&node=netRemote.play.status"
```

**Step 4: Run the node probe script** (Section 3 above) to discover which nodes your specific radio supports.

**Step 5: Explore navigation** (this is how Internet Radio / Podcast browsing works):
```bash
# Enable navigation
curl -s "http://$RADIO/fsapi/SET/netRemote.nav.state?pin=$PIN&value=1"

# Check how many items in current nav level
curl -s "http://$RADIO/fsapi/GET/netRemote.nav.numItems?pin=$PIN"

# List current nav items
curl -s "http://$RADIO/fsapi/LIST_GET_NEXT/netRemote.nav.list/-1?pin=$PIN&maxItems=50"

# Navigate into an item (by its index from the list)
curl -s "http://$RADIO/fsapi/SET/netRemote.nav.action.navigate?pin=$PIN&value=0"

# Check depth
curl -s "http://$RADIO/fsapi/GET/netRemote.nav.depth?pin=$PIN"

# Go back up: set navigate to -1
curl -s "http://$RADIO/fsapi/SET/netRemote.nav.action.navigate?pin=$PIN&value=-1"
```

**Step 6: Set up mitmproxy** and watch UNDOK to discover anything the community docs missed.

---

## Key Resources

| Resource | URL | What It's For |
|----------|-----|--------------|
| FSAPI Protocol Docs | https://github.com/flammy/fsapi/blob/master/FSAPI.md | Complete HTTP API reference |
| fsapi-tools | https://github.com/MatrixEditor/fsapi-tools | Python library + CLI |
| python-afsapi | https://github.com/zhelev/python-afsapi | Async Python library (Home Assistant) |
| flammy/fsapi (PHP) | https://github.com/flammy/fsapi | PHP library with SSDP discovery |
| flammy/fsapi-remote | https://github.com/flammy/fsapi-remote | PHP web UI |
| Frontier Silicon firmwares | https://github.com/cweiske/frontier-silicon-firmwares | Firmware files, device database |

---

## Complete Node Reference

See the node probe script in Section 3 for the full list. Key categories:

- **`netRemote.sys.info.*`** - Device identity (name, version, radio ID, MAC)
- **`netRemote.sys.power`** - Power on/off
- **`netRemote.sys.mode`** - Current operating mode (Internet Radio, DAB, FM, Spotify, etc.)
- **`netRemote.sys.audio.*`** - Volume, mute, EQ
- **`netRemote.sys.clock.*`** - Time, date, timezone, DST
- **`netRemote.sys.net.*`** - Network config (IP, SSID, signal strength)
- **`netRemote.sys.caps.*`** - Device capabilities (modes, EQ presets, freq ranges)
- **`netRemote.sys.alarm.*`** - Alarm clock settings
- **`netRemote.sys.sleep`** - Sleep timer
- **`netRemote.play.*`** - Now playing info, playback control, signal strength
- **`netRemote.nav.*`** - Menu navigation (browse stations, podcasts, etc.)
- **`netRemote.spotify.*`** - Spotify Connect status
- **`netRemote.airplay.*`** - AirPlay config
- **`netRemote.multiroom.*`** - Multi-room audio (if supported)
- **`netRemote.sys.isu.*`** - Software update control

## Notes

- The default PIN on most Frontier Silicon radios is `1234`. Some use `0000`.
- `xmllint` (from `libxml2`) is pre-installed on macOS and useful for formatting XML responses: `curl ... | xmllint --format -`
- Navigation (`netRemote.nav.*`) is stateful - you need to enable it first (`nav.state=1`), then it works like a menu tree you navigate into and out of.
- Some nodes only work in specific modes (e.g., `play.frequency` only works in FM mode; Spotify nodes only when in Spotify mode). You'll get `FS_NODE_BLOCKED` otherwise.
- The `GET_NOTIFIES` endpoint is a long-poll - it blocks until something changes on the radio, then returns what changed. Useful for building a live dashboard.
