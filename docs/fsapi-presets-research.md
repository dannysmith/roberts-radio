# FSAPI Preset Research

## 1. Are Presets Per-Mode or Global?

**Presets are per-mode.** This is confirmed by multiple sources:

### Evidence

- **flammy/fsapi FSAPI.md** explicitly states that `netRemote.nav.presets` "Lists all favorite Radio Stations **for the current mode**"
- **python-afsapi source code** contains the comment: `"We don't cache this call as it changes when the mode changes"`
- **ioBroker adapter source code** (the most detailed implementation) confirms this definitively in its `getAllPresets()` method, which:
  1. Saves the current mode via `netRemote.sys.mode`
  2. Iterates through every valid mode index
  3. For each mode, calls `netRemote.sys.mode` to **switch to that mode**
  4. Waits 2 seconds for the mode change to register
  5. Calls `LIST_GET_NEXT/netRemote.nav.presets/-1` to get **that mode's presets**
  6. Restores the original mode when done
- **ioBroker adapter data structure** organizes presets as `modes.{modeKey}.presets.{presetNumber}` -- explicitly per-mode
- **Home Assistant community discussion** confirms you must switch to "Internet radio" mode before selecting internet radio presets

### How It Works Internally

When you call `LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=65535`, it returns **only the presets for the currently active mode** (set via `netRemote.sys.mode`). There is no single API call that returns all presets across all modes.

The Roberts Revival iStream 3L's "40 presets for internet radio, 10 for DAB, 10 for FM" means:
- When `netRemote.sys.mode` is set to internet radio mode: up to 40 presets are available
- When set to DAB mode: up to 10 presets
- When set to FM mode: up to 10 presets

These are separate lists stored on the device, indexed 0-39 (internet) or 0-9 (DAB/FM).

---

## 2. Can You Programmatically Create/Modify/Delete Presets?

### What WORKS (well-tested)

#### Selecting a preset
```
GET /fsapi/SET/netRemote.nav.action.selectPreset?pin=1234&value=3
```
Selects preset at index 3 for the **current mode**. You must be in the correct mode first.

#### Saving the currently playing station to a preset slot
```
GET /fsapi/SET/netRemote.play.addPreset?pin=1234&value=5
```
Saves whatever is currently playing to preset slot 5 **in the current mode**. The `netRemote.play.addPresetStatus` node (enum: `0`=PRESET_STORED, `1`=PRESET_NOT_STORED) reports whether it succeeded.

**Important limitation**: This only works for the **currently playing** content. You cannot specify a URL or station -- you must first navigate to and play the station, then save it.

#### Deleting a preset
```
GET /fsapi/SET/netRemote.nav.preset.delete?pin=1234&value=3
```
Deletes the preset at index 3 for the current mode.

#### Swapping preset positions
```
GET /fsapi/SET/netRemote.nav.preset.swap.index1?pin=1234&value=2
GET /fsapi/SET/netRemote.nav.preset.swap.index2?pin=1234&value=5
GET /fsapi/SET/netRemote.nav.preset.swap.swap?pin=1234&value=1
```
Swaps presets at positions 2 and 5.

#### Reading presets
```
GET /fsapi/LIST_GET_NEXT/netRemote.nav.presets/-1?pin=1234&maxItems=100
```
Returns XML with preset items for the current mode.

### What EXISTS But Is Undocumented (preset upload/download)

The FSAPI defines a complete set of upload/download nodes, but **nobody in the open-source community has documented successfully using them to create presets from scratch**:

#### Upload nodes (all NodeC8 / read-write):
- `netRemote.nav.preset.upload.name` -- preset display name
- `netRemote.nav.preset.upload.type` -- preset type identifier (string)
- `netRemote.nav.preset.upload.blob` -- serialized preset data (string, max 2064 bytes)
- `netRemote.nav.preset.upload.artworkUrl` -- artwork URL
- `netRemote.nav.preset.upload.upload` -- (NodeU32) triggers the upload operation

#### Download nodes (all read-only except .download):
- `netRemote.nav.preset.download.name` -- preset display name
- `netRemote.nav.preset.download.type` -- preset type identifier
- `netRemote.nav.preset.download.blob` -- serialized preset data
- `netRemote.nav.preset.download.artworkUrl` -- artwork URL
- `netRemote.nav.preset.download.download` -- (NodeU32, read-write) triggers download/specifies preset index

#### The upload workflow would theoretically be:
1. SET the name, type, blob, and artworkUrl via their respective upload nodes
2. SET `netRemote.nav.preset.upload.upload` with the target preset slot index to execute

#### The download workflow would theoretically be:
1. SET `netRemote.nav.preset.download.download` with the preset index to retrieve
2. GET the name, type, blob, and artworkUrl from their respective download nodes

### The Blob Format Problem

**The blob format is completely undocumented.** Here is what we know:

- From the fsapi-tools node definitions, the `netRemote.nav.presets` list returns items with these fields:
  - `key` (U32) -- preset index
  - `name` (C8, max 65 bytes) -- display name
  - `type` (C8, max 32 bytes) -- type identifier string
  - `uniqid` (C8, max 32 bytes) -- unique identifier
  - `blob` (C8, max 2064 bytes) -- serialized preset data
  - `artworkUrl` (C8, max 512 bytes) -- artwork URL

- The blob is typed as `ARG_TYPE_C8` (character array / string) with a maximum length of 2064 bytes
- It contains the serialized representation of the preset's playback data
- Based on how presets reference airable/vTuner stations, the blob likely contains an opaque reference to the aggregation service rather than a raw stream URL
- **No one in the community has reverse-engineered the blob format**
- The fsapi-tools source code treats it as a raw string with no special encoding/decoding

### What Does NOT Work

- **You cannot create a preset from an arbitrary stream URL** via the documented API. The `addPreset` node only saves the currently-playing content.
- **No open-source project has implemented preset upload** using the upload nodes. All implementations (python-afsapi, flammy/fsapi PHP, z1c0/FsApi .NET, ioBroker adapter, Home Assistant integrations) only support reading and selecting presets.
- The .NET FsApi test fixtures show preset responses with **only empty name fields** (no blob, type, or uniqid data in test fixtures), suggesting even the .NET library author didn't work with these fields.

### Alternative: Radio-API (DNS redirect approach)

The [KIMB-technologies/Radio-API](https://github.com/KIMB-technologies/Radio-API) project takes a completely different approach:
- Instead of using preset upload nodes, it redirects the radio's DNS so HTTP requests to the manufacturer's servers go to a custom server
- The custom server serves user-defined stations with stream URLs (MP3, M3U, etc.)
- This replaces the entire station catalog, not just presets
- It's a server-side solution, not a device-side preset manipulation

---

## 3. Relationship Between Presets and Current Mode

### Mode Switching and Nav State

Every change to `netRemote.sys.mode` **disables the navigation state** (`netRemote.nav.state`), resetting the current menu position. To use presets after a mode switch:

1. Switch mode: `SET/netRemote.sys.mode?value={mode_id}`
2. Enable nav state: `SET/netRemote.nav.state?value=1`
3. Now you can query/select presets for that mode

The ioBroker adapter also waits 2 seconds after a mode switch before querying presets, suggesting the device needs settling time.

### How the ioBroker Adapter Discovers All Presets

The most complete implementation (`getAllPresets` in the ioBroker adapter):

```javascript
async getAllPresets(force) {
    await this.enableNavIfNeccessary();
    let response = await this.callAPI('netRemote.sys.mode');
    const originalMode = response.result.value[0].u32[0]; // save original mode

    // Mute to prevent audio glitches during mode switching
    let unmute = (response for mute check) == 0;

    for (let i = 0; i <= this.config.ModeMaxIndex; ++i) {
        // Skip modes that don't exist
        let mode = await this.getStateAsync(`modes.${i}.key`);
        if (mode === null) continue;

        // Switch to mode i
        await this.callAPI('netRemote.sys.mode', i.toString());
        await this.sleep(2000); // wait for mode change
        await this.enableNavIfNeccessary();

        // Get presets for this mode
        response = await this.callAPI('netRemote.nav.presets', '', -1, 65535);
        // ... store preset names for mode i ...
    }

    await this.callAPI('netRemote.sys.mode', originalMode); // restore
    if (unmute) await this.callAPI('netRemote.sys.audio.mute', '0');
}
```

Key behaviors:
- **Mutes the radio** during mode switching to avoid audio artifacts
- **Switches through every mode** to collect presets
- **Restores the original mode** when done
- **Calls `enableNavIfNeccessary()`** after each mode switch (sets `netRemote.nav.state` to 1)

### Preset Selection Also Requires Correct Mode

To select a preset, you must be in the correct mode:
```
SET/netRemote.sys.mode?value=0          (switch to internet radio)
SET/netRemote.nav.state?value=1         (enable navigation)
SET/netRemote.nav.action.selectPreset?value=3  (select preset 3)
```

The ioBroker adapter verifies the current mode matches before allowing preset set operations.

---

## 4. Cloud vs Local Presets

There are **two separate preset systems** on these radios:

### Local/Button Presets (FSAPI presets)
- Stored on the device itself
- Managed via FSAPI nodes (`netRemote.nav.presets`, `netRemote.play.addPreset`, etc.)
- Per-mode (40 internet, 10 DAB, 10 FM on Roberts iStream 3L)
- Physical preset buttons on the radio map to these
- The UNDOK app can also manage these

### Cloud Favourites (airable/Nuvola portal)
- Stored on airable's servers (previously Nuvola, before that vTuner)
- Managed via the airable.fm portal or UNDOK app with airable account
- Appear as a "My Favourites" folder in the radio's internet radio/podcast navigation tree
- Can include custom/personal stream URLs via the portal
- Synced across multiple devices linked to the same airable account
- These are NOT the same as FSAPI presets -- they're entries in the navigation tree

---

## 5. Legacy Preset Nodes

The nodes.txt file in fsapi-tools lists these legacy preset paths:
- `misc.preset.dab`
- `misc.preset.fm`
- `misc.preset.lastlisten`
- `misc.preset.vtuner`

These appear to be older/alternative preset storage paths. No documentation exists for their format or whether modern devices still support them.

---

## Summary

| Question | Answer |
|----------|--------|
| Are presets per-mode? | **Yes.** Each mode has its own preset list. |
| Can you list presets? | **Yes.** `LIST_GET_NEXT/netRemote.nav.presets` (for current mode only) |
| Can you select a preset? | **Yes.** `SET/netRemote.nav.action.selectPreset?value=N` |
| Can you save current station to preset? | **Yes.** `SET/netRemote.play.addPreset?value=N` |
| Can you delete a preset? | **Yes.** `SET/netRemote.nav.preset.delete?value=N` |
| Can you reorder presets? | **Yes.** Via swap nodes. |
| Can you create a preset from a URL? | **No.** Upload nodes exist but blob format is undocumented and no one has successfully used them. |
| Can you upload/download preset data? | **Theoretically yes** (nodes exist), but **practically no** (blob format unknown). |
| Do you need to switch modes to manage presets? | **Yes.** Presets are per-mode; you must be in the right mode. |

## Sources

- [flammy/fsapi FSAPI.md](https://github.com/flammy/fsapi/blob/master/FSAPI.md) - Core FSAPI documentation
- [fsapi-tools netRemote.nav documentation](https://frontier-smart-api.readthedocs.io/en/latest/api/net/netRemote/netRemote-nav.html) - Node reference
- [fsapi-tools documentation](https://matrixeditor.github.io/fsapi-tools/) - Comprehensive node definitions
- [fsapi-tools netRemote.play documentation](https://frontier-smart-api.readthedocs.io/en/latest/api/net/netRemote/netRemote-play.html) - addPreset/addPresetStatus
- [python-afsapi](https://github.com/zhelev/python-afsapi) - Python async FSAPI implementation
- [ioBroker.frontier_silicon](https://github.com/iobroker-community-adapters/ioBroker.frontier_silicon) - Most complete preset implementation
- [Home Assistant Frontier Silicon preset discussion](https://community.home-assistant.io/t/frontier-silicon-device-change-radio-station-in-internet-radio-mode-by-use-of-presets/262456)
- [my-frontier-silicon](https://github.com/SaintPaddy/my-frontier-silicon) - Advanced HA integration with preset dropdown
- [z1c0/FsApi .NET](https://github.com/z1c0/FsApi) - .NET FSAPI implementation
- [KIMB-technologies/Radio-API](https://github.com/KIMB-technologies/Radio-API) - DNS-redirect alternative approach
- [airable FAQ](https://www.airablenow.com/faq-en/) - Cloud favourites portal
- [airable portal announcement](https://www.airablenow.com/its-available-the-all-new-frontier-smart-radio-podcast-portal/)
- [ex_frontier FSAPI docs](https://hexdocs.pm/ex_frontier/fsapi.html) - Elixir FSAPI documentation
- [tiwilliam/fsapi REVERSE.md](https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md) - Reverse engineering notes
- [ioBroker forum discussion](https://forum.iobroker.net/topic/66890/test-adapter-frontier_silicon-v0-5-x-latest/1?lang=en-US)
- [openHAB Frontier Silicon binding](https://www.openhab.org/addons/bindings/fsinternetradio/)
