# Task: Potential new features

Ideas to explore for RadioBar, with what we've learned so far. Nothing here is committed to yet. Findings marked **tested** were run against the real radio (iStream 3L, firmware V4.6.18) on 2026-11-23.

## What the radio can do

### Presets can be written (tested)

- `GET /fsapi/LIST_SET/netRemote.nav.presets?pin=1234&key=<slot>&name=<name>&type=AirableRadio&url=<encoded url>` saves a preset. A blank `name` and `url` clears it. This is how the radio's own web UI edits presets (`/web/common-1.0.3.js`).
- A test preset saved, played from both a local HTTP URL and a public HTTPS podcast URL, then cleared without affecting other slots. Once saved it needs no Mac.
- Internet Radio and Podcasts share the same 40 slots. The `type` field follows the current mode.
- In Internet Radio mode a custom preset behaves like a live station, with Stop but no pause or seek.
- In Podcasts mode the radio reported pause and seek, but that test reused an existing preset's URL, so custom podcast presets are **unproven**.
- `netRemote.nav.caps` shows support per mode: `0x2` has presets, `0x4` presets can be edited.

### There's a hidden UPnP media renderer (tested)

- It runs on port 8080 (`/dd.xml`), with SOAP control at `/AVTransport/control`, `/ConnectionManager/control` and `/RenderingControl/control`. The 3L has no visible mode for it.
- It accepts MP3, AAC, M4A and M4B over HTTP.
- It played an MP3 served from the Mac in both Internet Radio and USB modes, with working pause, seek and automatic next track (`SetNextAVTransportURI`).
- Seeking needs a server that supports HTTP Range. The radio sends `HEAD`, then `GET` with `Range`.
- It rejected the public URLs we tried, both HTTPS and HTTP, with "Resource not found". We don't know why yet. For now, assume the Mac or another LAN device must relay public audio.
- Pass DIDL metadata with `SetNextAVTransportURI`, otherwise the radio shows the URL as the track name.
- After a UPnP session stops, presets won't play until the radio changes mode.
- UPnP holds only one next track, so a longer queue needs something awake to keep supplying tracks.

### Other limits

- The radio stores no podcast played state that a client can read or write.
- Airable favourites live in Airable's cloud. There's no public API, and the airable.fm portal uses an email login with a session cookie.
- After about 15 minutes without Bluetooth playback the radio goes to standby, according to the iStream 3 manual.

## Ideas

### 1. Better favourites and station management

**Goal:** a much nicer Mac interface to find, search and organise the stations and podcasts saved on the radio.

**Approach:** build a preset manager with search, add, rename, reorder and delete, using `LIST_SET`. [Radio Browser](https://www.radio-browser.info/) could provide station search. [Muga](https://github.com/calvellido/muga/blob/main/docs/adr/0005-browsing-and-preset-editing.md) already reorders presets with `LIST_SET` and is a useful reference. Back up all slots before bulk changes.

Read Airable favourites through the radio's nav menus and leave editing them to airable.fm. Automating the portal would be fragile.

### 2. Podcast and episode management

**Goal:** hide episodes already heard elsewhere, find episodes quickly, and ideally build a play queue, while still listening on the radio without a phone or laptop.

**Status:** parked for now. Apple Podcasts isn't used elsewhere, so syncing with its local database isn't relevant.

**Likely approach:** the Mac app owns the catalogue and played state, using the [Apple podcast search API](https://performance-partners.apple.com/search-api) and RSS.

There are two ways to send an episode to the radio:

- **Write it to a reserved preset slot and select it.** This plays public HTTPS URLs directly and keeps playing if the Mac sleeps. It's the most promising route if custom podcast presets support pause and seek.
- **Use UPnP.** This gives seek and next track, but needs a LAN relay and an awake device to run a queue.

A self-hosted Airable backend ([Radio-API](https://github.com/KIMB-technologies/Radio-API)) is possible but high effort. It needs DNS overrides and loses the Airable catalogue unless proxied, so it's a last resort.

### 3. Listening to Audible on the radio

**Goal:** listen to the current Audible book on the radio at the right position, ideally with the phone and Mac off.

**Options, most practical first:**

1. **Echo playing into the radio over Bluetooth.** Alexa can play Audible and handle position, and an Echo can output to a Bluetooth speaker. This is the best route to phone-free and Mac-free listening. Whether the radio accepts an Echo and stays connected is **untested**.
2. **Mac or phone over Bluetooth.** Already works, using the Mac Audio button or the phone.
3. **Always-on home server to UPnP.** [Audiobookshelf](https://www.audiobookshelf.org/) with [Music Assistant](https://www.music-assistant.io/player-support/dlna/) could handle progress and playback, but only with audio that isn't DRM-protected.
4. **USB stick.** Possible for unprotected files. M4B support and resume on this radio are unverified.

**Constraints:**

- AAX and AAXC files are encrypted, so the radio can't play them directly. Check the extension of the downloaded books before considering options 3 or 4.
- Don't build on removing DRM. It breaks Audible's UK terms and risks a civil claim under [CDPA s296ZA](https://www.legislation.gov.uk/ukpga/1988/48/section/296ZA). The UK's private-copying exception was quashed in 2015.

**Position API:** the [unofficial API](https://audible.readthedocs.io/en/latest/misc/external_api.html) can read position with `GET /1.0/annotations/lastpositions?asins=...`. Writing with `PUT /1.0/lastpositions/{asin}` has mixed reports and more account risk, so keep any integration read-only. `audible-cli` is already installed locally.

## Suggested next experiments

1. Pair an Echo with the radio and play Audible. Check that it connects, resumes correctly, and how chapters and standby behave.
2. Save a podcast with a new URL as a `Podcasts` preset. Check pause, seek and whether the radio remembers position.
3. Find out why UPnP rejects public URLs, or try a small relay on the Mac.
4. If unprotected audio is available, test a long M4B over UPnP for seek accuracy.

## Still to verify in the current app

- Reconnecting automatically after a Wi-Fi drop
- Spotify controls during real playback
- The Presets panel with hidden empty slots and the used-slot count
- Browsing a long station list
