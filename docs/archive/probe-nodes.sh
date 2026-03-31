#!/bin/bash
# Probe all known FSAPI nodes on a Frontier Silicon radio and output JSON
# Usage: ./probe-nodes.sh [IP] [PIN]

RADIO="${1:-192.168.1.72}"
PIN="${2:-1234}"

# Extract status from XML response
get_status() { echo "$1" | sed -n 's/.*<status>\(.*\)<\/status>.*/\1/p'; }

# Extract the inner value (e.g. <u8>10</u8> -> 10, <c8_array>foo</c8_array> -> foo)
get_value() { echo "$1" | sed -n 's/.*<value><[^>]*>\(.*\)<\/[^>]*><\/value>.*/\1/p'; }

# Extract the value type tag (e.g. <u8>10</u8> -> u8)
get_type() { echo "$1" | sed -n 's/.*<value><\([^>]*\)>.*/\1/p'; }

# All known GET nodes
GET_NODES=(
  # System Info
  netRemote.sys.info.friendlyName
  netRemote.sys.info.version
  netRemote.sys.info.buildVersion
  netRemote.sys.info.modelName
  netRemote.sys.info.radioId
  netRemote.sys.info.serialNumber
  netRemote.sys.info.radioPin
  netRemote.sys.info.controllerName
  netRemote.sys.info.dmruuid
  netRemote.sys.info.netRemoteVendorId
  netRemote.sys.info.activeSession

  # Power & Mode
  netRemote.sys.power
  netRemote.sys.sleep
  netRemote.sys.state
  netRemote.sys.mode
  netRemote.sys.lang

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
  netRemote.sys.audio.airableQuality
  netRemote.sys.audio.extStaticDelay

  # Playback
  netRemote.play.info.name
  netRemote.play.info.text
  netRemote.play.info.artist
  netRemote.play.info.album
  netRemote.play.info.description
  netRemote.play.info.graphicUri
  netRemote.play.info.duration
  netRemote.play.info.providerName
  netRemote.play.info.providerLogoUri
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
  netRemote.play.feedback
  netRemote.play.rating
  netRemote.play.alerttone

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
  netRemote.nav.currentTitle
  netRemote.nav.description
  netRemote.nav.refreshFlag
  netRemote.nav.action.dabScan
  netRemote.nav.action.dabPrune
  netRemote.nav.action.context

  # Presets
  netRemote.nav.preset.currentPreset
  netRemote.nav.preset.listversion

  # Capabilities (scalar)
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
  netRemote.sys.clock.timeZone

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
  netRemote.sys.net.wlan.region
  netRemote.sys.net.wired.macAddress
  netRemote.sys.net.wired.interfaceEnable

  # Config
  netRemote.sys.cfg.irAutoPlayFlag

  # Software Update
  netRemote.sys.isu.control
  netRemote.sys.isu.state
  netRemote.sys.isu.mandatory
  netRemote.sys.isu.version
  netRemote.sys.isu.summary
  netRemote.sys.isu.softwareUpdateProgress

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

  # Bluetooth
  netRemote.bluetooth.connectedDevice

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

  # Amazon Music
  netRemote.nav.amazonMpLoginUrl
  netRemote.nav.amazonMpLoginComplete
  netRemote.nav.amazonMpGetRating
  netRemote.nav.amazonMpSetRating

  # Debug / Test
  netRemote.misc.fsDebug.component
  netRemote.misc.fsDebug.traceLevel
  netRemote.test.iperf.console
  netRemote.test.iperf.commandLine
  netRemote.test.iperf.execute

  # Platform
  netRemote.platform.ledIntensity
  netRemote.platform.softApState
)

# LIST nodes (need LIST_GET_NEXT)
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
  netRemote.sys.net.wlan.scanList
  netRemote.sys.net.wlan.profiles
)

echo "Probing ${#GET_NODES[@]} GET nodes + ${#LIST_NODES[@]} LIST nodes on $RADIO ..." >&2
echo "" >&2

# JSON output
echo "{"

# GET nodes
echo '  "get_nodes": {'
first=true
ok_count=0
blocked_count=0
missing_count=0

for node in "${GET_NODES[@]}"; do
  response=$(curl -s -m 3 "http://$RADIO/fsapi/GET/$node?pin=$PIN")
  status=$(get_status "$response")

  if [ "$status" = "FS_OK" ]; then
    value=$(get_value "$response")
    type=$(get_type "$response")
    # Escape double quotes and backslashes in value for JSON
    value=$(echo "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if [ "$first" = true ]; then first=false; else echo ","; fi
    printf '    "%s": {"value": "%s", "type": "%s"}' "$node" "$value" "$type"
    ok_count=$((ok_count + 1))
  elif [ "$status" = "FS_NODE_BLOCKED" ]; then
    if [ "$first" = true ]; then first=false; else echo ","; fi
    printf '    "%s": {"blocked": true}' "$node"
    blocked_count=$((blocked_count + 1))
  else
    missing_count=$((missing_count + 1))
  fi
done

echo ""
echo "  },"

# LIST nodes
echo '  "list_nodes": {'
first=true
list_ok=0

for node in "${LIST_NODES[@]}"; do
  response=$(curl -s -m 5 "http://$RADIO/fsapi/LIST_GET_NEXT/$node/-1?pin=$PIN&maxItems=100")
  status=$(get_status "$response")

  if [ "$status" = "FS_OK" ] || [ "$status" = "FS_LIST_END" ]; then
    has_items="false"
    [ "$status" = "FS_OK" ] && has_items="true"
    if [ "$first" = true ]; then first=false; else echo ","; fi
    printf '    "%s": {"exists": true, "has_items": %s}' "$node" "$has_items"
    list_ok=$((list_ok + 1))
  fi
done

echo ""
echo "  },"

# Summary
echo "  \"summary\": {"
echo "    \"ip\": \"$RADIO\","
echo "    \"pin\": \"$PIN\","
echo "    \"get_ok\": $ok_count,"
echo "    \"get_blocked\": $blocked_count,"
echo "    \"get_missing\": $missing_count,"
echo "    \"list_ok\": $list_ok"
echo "  }"
echo "}"

echo "" >&2
echo "Done: $ok_count OK, $blocked_count blocked, $missing_count missing, $list_ok lists" >&2
