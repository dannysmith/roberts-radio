# Airable & airable.fm Research

Research into the Airable platform, airable.fm portal, and how they relate to Frontier Smart/Frontier Silicon and radio manufacturers like Roberts.

---

## 1. What is Airable?

**Airable GmbH** is a German B2B company based in Nettetal, operating since 2010 (with roots in digital/online media since 1999). They are a **content aggregation and curation platform** for connected audio devices.

### What they do

- **Aggregate and curate** internet radio stations, podcasts, and music service integrations into a single platform
- Provide the **airable.API** -- a unified API that device manufacturers integrate to give their products access to internet radio, podcasts, and streaming music services
- Maintain a **curated catalog** of 70,000+ internet radio stations and 70,000+ podcasts worldwide
- Handle **metadata management** -- ensuring every station has correct logos, slogans, descriptions, languages, origins, genres, frequencies, etc.
- Provide **favorites/sync infrastructure** so users can manage favorites across devices via a web portal
- Serve approximately **9 million devices** worldwide

### What they explicitly do NOT do

- Store or rebroadcast content (they are an aggregator/directory, not a CDN)
- Influence content through editing or advertising overlays
- Use algorithmic systems to determine quality (they use human curators + editors)

### Music services available through airable.API

Amazon Music, Deezer, TIDAL, Qobuz, Napster, JioSaavn, Calm Radio, IDAGIO, HIGHRESAUDIO, and others. The key value proposition is: integrate one API (airable) instead of individually integrating each music service.

### Notable reference clients (146+ brands)

Bang & Olufsen, Yamaha, Crestron, Technics, Panasonic, Cambridge Audio, KEF, Linn, Dynaudio, Hegel, Roberts Radio, Pure, Sangean, Teufel, Sonoro, TechniSat, Ruark Audio, Philips, Revox, T+A, Burmester, dCS, Mark Levinson, and many more.

---

## 2. What is airable.fm?

**airable.fm** is the **consumer-facing web portal** where users can:

1. **Register an account** (email + password)
2. **Connect their radio device(s)** using a time-limited Connect Code
3. **Browse** the internet radio station and podcast catalog
4. **Save favorites** (stations and podcasts) that sync to their connected radios
5. **Add personal streams** (custom URLs for stations not in the catalog, or paid subscription streams)
6. **Manage favorites** -- sort alphabetically or manually, organize into directories, delete

### Connect Code / Device Pairing Process

The radio generates a temporary code that links the physical device to your airable.fm account:

1. Create an account at airable.fm
2. On the radio: go to Internet Radio > Favourites (for Frontier Smart Venice X devices)
3. The radio displays a **Connect Code** valid for **10 minutes**
4. Enter this code on airable.fm to pair the device
5. Multiple devices can be paired to one account
6. Favorites are **synchronized across all paired devices**

### For Roberts / Frontier Smart Venice X devices specifically

Navigate to: Internet Radio > Favourites, and use the Connect Code displayed.

### Personal Streams

You can add custom stream URLs via the portal. These appear on the radio as "My Added Stations". Important caveat from airable: "What works in our web player does not mean it will work on your radio." Direct MP3/AAC streams work best; HTTPS/HLS support depends on device capabilities. Supported formats vary by device but generally include MP3, AAC, ASF, DASH.

### Favorites on the radio

Favorites saved via airable.fm appear in a **Favourites menu** on the radio, organized under Stations and Podcasts folders. These are separate from the radio's own **preset buttons** (40 for internet radio, 10 for DAB, 10 for FM on the Roberts iStream 3L), which are stored locally on the device.

---

## 3. Relationship: Airable, Frontier Smart, Roberts

### The Stack

```
┌─────────────────────────────────────────────┐
│  Consumer Brand (Roberts, Pure, Teufel...)   │  <-- sells the radio
├─────────────────────────────────────────────┤
│  UNDOK App (companion app by Frontier Smart) │  <-- local network control
├─────────────────────────────────────────────┤
│  Frontier Smart SmartSDK + Venice Chipset     │  <-- hardware + firmware platform
│  (FSAPI for local control, HTTP on LAN)      │
├─────────────────────────────────────────────┤
│  airable.API (cloud backend)                 │  <-- content catalog + sync
│  - Internet radio station directory          │
│  - Podcast catalog                           │
│  - Music service integrations                │
│  - Favorites sync (airable.fm portal)        │
└─────────────────────────────────────────────┘
```

### Frontier Smart (formerly Frontier Silicon)

- **Role:** Hardware/firmware platform provider. They make the Venice chipset family and the SmartSDK software that runs on it. They also make the UNDOK companion app.
- **Products:** Venice 6, Venice X, MagicX chipset modules used by 50+ radio brands
- **Previously:** Frontier Smart ran their own cloud backend called **Nuvola** for internet radio, podcasts, and favorites
- **Now:** Frontier Smart **terminated Nuvola** at the end of October 2024 to focus on chip/hardware business. Airable now provides all cloud content services.

### Airable

- **Role:** Cloud content/service layer. Provides the internet radio directory, podcast catalog, music service integrations, and favorites portal that the radios connect to.
- **Previously:** Was already the content provider behind Nuvola (Frontier Smart was essentially white-labeling airable's content)
- **Now:** Directly services the radios. Brands had to sign agreements with airable to continue receiving service after the Nuvola shutdown.

### Roberts

- **Role:** Consumer electronics brand. Designs and sells radios (like the Revival iStream 3L) built on Frontier Smart Venice chipsets.
- **Roberts is confirmed** as one of the brands that transitioned to airable after the Nuvola shutdown.

### The Nuvola-to-Airable Transition (Oct 2024)

- Frontier Smart terminated Nuvola Service end of October 2024
- Brands that signed agreements with airable continue to work seamlessly -- no firmware update required on devices
- Users had to create new airable.fm accounts (couldn't migrate Nuvola logins due to privacy regulations)
- There was an export/import feature to migrate favorites from the old Nuvola portal to airable
- The infrastructure switch occurred October 29-31, 2024

---

## 4. Airable API

### Official API (B2B, NDA-protected)

The official airable.API is **not publicly documented**. To get access:

1. Contact info@airablenow.com
2. Exchange and sign an **NDA agreement**
3. Receive API documentation and test/development URLs
4. Develop using the airable.API
5. Go through certification and validation

The API provides access to:
- airable Internet Radio catalog
- airable Podcast catalog
- Music service integrations (Spotify, Amazon Music, Deezer, TIDAL, etc.)
- Favorites/sync infrastructure

### Platform Partners with pre-certified airable.API

Frontier Silicon, Stream Unlimited, Nicent, Appsolute, Audivo, Libre Wireless Technologies, CA Chip China, Interface Co. (Japan). These platforms come with airable.API already embedded.

### Reverse-Engineered Protocol Details

Community projects have reverse-engineered how radios communicate with the airable backend. There are two generations:

#### Old Protocol (XML-based, pre-airable, used by Nuvola/vTuner)

Used by older Frontier Silicon radios. The radio makes HTTP requests (port 80, no SSL) to a vendor-specific subdomain:

```
http://<vendor>.wifiradiofrontier.com/setupapp/<vendor>/asp/BrowseXML/<endpoint>.asp?<params>
```

**Query parameters on every request:**
- `mac` -- authentication token (not actually a MAC address)
- `dlang` -- language code (e.g., `eng`, `ger`)
- `fver` -- firmware version
- `ven` -- vendor identifier (e.g., `hama7`, `medion2`)

**Key endpoints:**
- `/loginXML.asp?token=0` -- connection test, returns encrypted token
- `/loginXML.asp?gofile=` -- main menu directory
- `/navXML.asp?gofile=Radio` -- browse radio stations
- `/navXML.asp?gofile=ShowPod` -- browse podcasts
- `/FavXML.asp?empty=&sFavName=<group>&startItems=1&endItems=100` -- list favorites
- `/AddFav.asp?empty=&showid=<id>` -- add favorite
- `/RemoveFavs.asp?empty=&ID=<id>&sFavName=<group>` -- remove favorite
- `/Search.asp?sSearchtype=3&Search=<stationId>` -- search by station ID
- `/GetShowXML.asp?showid=<id>&ShowStatic=&gofile=favorite` -- get podcast details

**Response format:** XML with UTF-8 encoding. `Content-Length` header is mandatory.

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ListOfItems>
  <ItemCount>-1</ItemCount>
  <Item>
    <ItemType>Station</ItemType>
    <StationId>12345</StationId>
    <StationName>BBC Radio 4</StationName>
    <StationUrl>http://...</StationUrl>
    <StationDesc>...</StationDesc>
    <Logo>http://...</Logo>
    <StationFormat>Talk</StationFormat>
    <StationLocation>London</StationLocation>
    <StationBandWidth>128</StationBandWidth>
    <StationMime>audio/mpeg</StationMime>
  </Item>
</ListOfItems>
```

**Item types:** Dir (directory/folder), Previous (back button), Station, ShowOnDemand (podcast), ShowEpisode (episode), Search (search input).

#### New Protocol (JSON-based, airable, used by Venice 6/Venice X)

Used by newer radios including the Roberts Revival iStream 3L. The radio makes **HTTPS** requests (port 443) to:

```
https://airable.wifiradiofrontier.com/...
```

Also uses `assets.wifiradiofrontier.com` for logos/artwork.

Key differences from the old protocol:
- **HTTPS** (port 443) instead of HTTP (port 80)
- **JSON** responses instead of XML (described by reverse engineers as "awful json but still json")
- Certificate validation is **not enforced** by the radio (self-signed certs work)
- Stations are organized hierarchically with folder/station structure
- Logos are served as PNG, approximately 150x150px

The exact JSON schema is not publicly documented, but the community projects (fairable, pyrable, frontier-airable) implement compatible servers.

### Community Self-Hosted Backend Projects

These replace the airable cloud backend, letting you serve your own station lists:

| Project | Language | Targets | Repo |
|---------|----------|---------|------|
| **fairable** | Node.js | New airable JSON API (HTTPS) | [Half-Shot/fairable](https://github.com/Half-Shot/fairable) |
| **pyrable** | Python | New airable JSON API (HTTPS) | [rhaamo/pyrable](https://github.com/rhaamo/pyrable) |
| **frontier-airable** | Python | New airable JSON API (HTTPS) | [seife/frontier-airable](https://github.com/seife/frontier-airable) |
| **Radio-API** | PHP | Old XML API (HTTP) | [KIMB-technologies/Radio-API](https://github.com/KIMB-technologies/Radio-API) |
| **librefrontier** | C# | Old XML API (HTTP) | [compujuckel/librefrontier](https://github.com/compujuckel/librefrontier) |

All of these work by **DNS redirection**: you configure DNS so that `airable.wifiradiofrontier.com` (or the vendor-specific subdomain) resolves to your local server's IP address instead of the real airable server. The radio then sends its requests to your server.

---

## 5. How Sync Works

### Architecture

```
┌──────────────┐     HTTPS      ┌─────────────────────────────────┐
│  airable.fm  │ ◄────────────► │  airable cloud infrastructure   │
│  (web portal)│                │  (API servers, catalog DB,       │
└──────────────┘                │   favorites storage)             │
                                └───────────┬─────────────────────┘
                                            │
                                            │ HTTPS (port 443)
                                            │ airable.wifiradiofrontier.com
                                            │
                                ┌───────────▼─────────────────────┐
                                │  Radio (Frontier Smart Venice)   │
                                │  - Fetches station catalog       │
                                │  - Fetches favorites list        │
                                │  - Displays in "Favourites" menu │
                                └─────────────────────────────────┘
```

### The Flow

1. **User registers** at airable.fm and pairs their radio using the Connect Code
2. **User browses** the station/podcast catalog on airable.fm and clicks the star icon to save favorites
3. **airable stores** the favorites list server-side, associated with the user's account and linked devices
4. **Radio fetches** its content from `airable.wifiradiofrontier.com` -- this includes the station directory AND the user's favorites
5. **Favorites appear** on the radio in a "Favourites" or "My Saved Stations" menu
6. **Personal streams** added via the portal appear as "My Added Stations" on the radio
7. **Multi-device sync**: All radios paired to the same account see the same favorites (there are no per-device groups in the new airable portal)

### Key Technical Points

- The radio **pulls** favorites from the airable cloud -- it is not a push mechanism
- The radio identifies itself to the airable backend (likely using the `mac` token or a device ID)
- The airable backend knows which user account is linked to which device (via the Connect Code pairing)
- Favorites are stored **server-side** in airable's cloud, not on the radio itself
- Radio presets (saved via the preset buttons on the physical radio) are stored **locally on the radio** and do NOT sync
- The UNDOK app connects to the radio via the **local network** using FSAPI (HTTP), not through the airable cloud

### Two Separate Systems

It's important to understand there are two distinct communication paths:

1. **FSAPI (local, LAN)**: The radio exposes an HTTP API on the local network (port 80 or 2244). The UNDOK app and Home Assistant use this to control playback, volume, presets, etc. This is direct radio-to-app communication.

2. **Airable API (cloud, WAN)**: The radio connects to `airable.wifiradiofrontier.com` over the internet to fetch the station catalog, podcast listings, and favorites. The airable.fm web portal also connects to the same cloud backend to manage favorites. This is how favorites sync between the portal and the radio.

---

## 6. Caching, Offline Behavior, and Navigation Architecture

### Q1: Does the radio make HTTPS requests directly to the cloud, or through a proxy?

**The radio makes direct HTTPS requests to the airable cloud.** There is no intermediary proxy in the standard architecture.

- Newer radios (Venice 6/Venice X, including the Roberts Revival iStream 3L) connect directly to `airable.wifiradiofrontier.com` over HTTPS (port 443) and to `assets.wifiradiofrontier.com` for logos/artwork.
- Older radios (pre-airable) connected directly to `<vendor>.wifiradiofrontier.com` over plain HTTP (port 80).
- The radio does **not verify SSL certificates** -- Half-Shot confirmed this via mitmproxy interception: "Critically the radio does not verify the certificates for the host at all." This is how community projects like frontier-airable and fairable work: they generate self-signed certs and the radio accepts them without complaint.
- The UNDOK app does **not** proxy cloud requests. UNDOK connects to the radio over the LAN via FSAPI (HTTP) for local control. Cloud content browsing is handled by the radio's own firmware connecting to airable directly.

Source: [Half-Shot blog: New Frontiers](https://half-shot.uk/blog/new-frontiers/), [seife/frontier-airable](https://github.com/seife/frontier-airable)

### Q2: Are catalogs, podcast listings, and favourites cached locally or fetched every time?

**Almost nothing is cached locally. The radio fetches content from the cloud on every browse operation.**

Evidence from multiple sources:

1. **SWLing Post / community reports (May 2019 vTuner outage):** When the vTuner aggregator was shut off, users discovered that "very little is actually stored locally in these WiFi radios. It seems everything down to the front panel presets rely on the aggregator functioning properly." Even stations saved to the radio's physical preset buttons stopped working.

2. **seife/frontier-airable proxy analysis:** The `airable-proxy.py` caching proxy was specifically created because the radio makes repeated requests for the same content without local caching. The proxy caches HTTP 200 responses in-memory (`if req.status_code == 200: cache[url] = req`). The fact that this proxy provides a "significant performance improvement" confirms the radio does not cache cloud responses locally.

3. **Presets vs Favourites -- storage location differs:**
   - **Favourites** (managed via airable.fm portal): Stored entirely server-side in airable's cloud. Not on the radio.
   - **Presets** (physical preset buttons on the radio): These store a **reference** (station ID/URL) locally on the radio, but the radio still needs the cloud backend to **resolve** that reference to a playable stream URL. This is why presets failed during the 2019 outage -- the preset is essentially a pointer that requires the cloud to dereference.
   - **Exception (some older models):** Some Frontier Silicon radios had an internal web server where users could store up to 99 custom stream URLs directly. These would survive a backend outage because the full stream URL was stored locally. This is model-dependent and not available on all devices.

4. **KIMB-technologies Radio-API:** The server-side implementation caches podcast episode lists for a configurable duration (`CONF_CACHE_EXPIRE` seconds), confirming the radio itself does not cache these. The radio also tracks "My Last" (recently played stations) which implies some minimal local storage of recent history.

5. **Contrast with Reciva radios:** Reciva (a competing platform) stored presets locally on the device, so presets continued to work during server outages. Frontier Silicon made the opposite architectural choice -- presets resolve via the cloud.

Source: [SWLing Post: vTuner aggregation aggravation](https://swling.com/blog/2019/05/frontier-silicon-and-vtuner-aggregation-aggravation-continues/), [seife/frontier-airable](https://github.com/seife/frontier-airable), [KIMB-technologies/Radio-API](https://github.com/KIMB-technologies/Radio-API)

### Q3: What happens when the radio loses internet connectivity?

**Internet radio, podcasts, and favourites become completely inaccessible.** The radio cannot show previously browsed stations or favourites from a local cache.

Documented behavior during outages:

- **May 2019 (vTuner dropped):** "Most of our WiFi radios became expensive internet appliances that were unable to function as advertised." Users reported that searching for stations, playing from presets, and accessing favourites all failed. The official Frontier Silicon statement acknowledged: "It is no longer possible to recall Favourites."
- **October 2024 (Nuvola shutdown):** Brands that did not sign agreements with airable lost all internet radio and podcast functionality for their devices. "The 75,000 Internet radio stations, 100,000+ podcasts, My Favorites, and the smart radio portal" all became inaccessible.
- **What still works offline:** FM radio, DAB radio, Bluetooth, USB input, and Aux input. These modes do not depend on cloud connectivity. DAB and FM presets (stored locally) continue to work.
- **"Last Listened" may partially work:** Some users reported that the radio could replay the last-tuned internet radio station if it had the stream URL cached in memory from the current session. But navigating to find new stations or accessing the station directory is impossible without internet.

Source: [SWLing Post: vTuner aggregation aggravation](https://swling.com/blog/2019/05/frontier-silicon-and-vtuner-aggregation-aggravation-continues/), [SWLing Post: aggregation aggravation update](https://swling.com/blog/2019/05/aggregation-aggravation-update-frontier-silicon-working-on-favorites-and-personal-streams/), [Recommended Stations: Internet Radio Update (Nov 2024)](https://recommendedstations.com/2024/11/01/an-internet-radio-update/)

### Q4: How does the FSAPI navigation system relate to cloud content browsing?

**The local FSAPI (`netRemote.nav.*`) acts as a thin presentation layer that proxies cloud content. Each menu level in the "Internet Radio" mode is a separate request to the cloud.**

#### The Two-API Architecture

The radio has two completely separate communication interfaces:

```
┌─────────────────────────────────────────────────────────────────┐
│                        RADIO FIRMWARE                           │
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────────────┐  │
│  │  FSAPI Server         │    │  Airable Client              │  │
│  │  (HTTP, LAN-facing)   │    │  (HTTPS, WAN-facing)         │  │
│  │                       │    │                              │  │
│  │  Listens on port      │    │  Connects to:                │  │
│  │  80 or 2244           │    │  airable.wifiradiofrontier   │  │
│  │                       │    │  .com (port 443)             │  │
│  │  Serves: playback     │    │                              │  │
│  │  control, volume,     │    │  Fetches: station catalog,   │  │
│  │  nav state, presets,  │    │  podcast listings, favourites│  │
│  │  system info          │    │  logos, stream URLs           │  │
│  └──────────┬───────────┘    └──────────┬───────────────────┘  │
│             │                           │                       │
│             │    ┌──────────────┐        │                       │
│             └───►│ Navigation   │◄───────┘                       │
│                  │ State Machine│                                │
│                  │ (nav.state,  │                                │
│                  │  nav.list,   │                                │
│                  │  nav.depth)  │                                │
│                  └──────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
        ▲                                       ▲
        │ HTTP (LAN)                             │ HTTPS (WAN)
        │                                        │
   UNDOK App /                              airable cloud
   Home Assistant /                         (station catalog,
   openHAB                                  favorites, podcasts)
```

#### How Navigation Works Step by Step

When a user browses "Internet Radio" on the radio (or via UNDOK/Home Assistant using FSAPI):

1. **Set mode:** The radio's system mode is set to Internet Radio (`netRemote.sys.mode`). Every mode change resets the navigation state.

2. **Enable nav state:** `SET netRemote.nav.state = 1` -- this activates the navigation subsystem and tells the radio firmware to prepare the top-level menu for the current mode.

3. **Radio firmware contacts the cloud:** The firmware's airable client makes an HTTPS request to `airable.wifiradiofrontier.com` to fetch the top-level Internet Radio menu (e.g., "Local Stations", "Stations by Genre", "Stations by Country", "Podcasts", "Favourites", etc.).

4. **Firmware populates nav.list:** The cloud response populates the internal navigation list. The FSAPI then exposes this via `LIST_GET_NEXT/netRemote.nav.list/-1?maxItems=N`, which returns items with:
   - `name` -- display text
   - `type` -- 0 for directory/folder, 1+ for playable items
   - `subtype` -- additional classification

5. **User selects a folder:** `SET netRemote.nav.action.navigate = <index>` -- this tells the firmware to "enter" the folder at that index. The firmware then makes **another HTTPS request** to the cloud to fetch the contents of that folder. `netRemote.nav.depth` increments.

6. **Repeat for each level:** Each folder navigation triggers a new cloud request. The radio's navigation status (`netRemote.nav.status`) goes through states:
   - `WAITING` -- cloud request in progress
   - `READY` -- response received, list populated
   - `FAIL` / `FATAL_ERR` -- request failed
   - `READY_ROOT` -- at the top level

7. **User selects a station:** `SET netRemote.nav.action.selectItem = <index>` -- this selects a playable item. The radio resolves the stream URL (from the cloud response) and begins playback.

8. **Going back:** `SET netRemote.nav.action.navigate = -1` -- returns to the parent folder. The radio may re-request the parent folder contents from the cloud.

#### Navigation Is Stateless and Cloud-Dependent

Key observations from the community:

- **Each menu level = separate cloud request.** There is no evidence of the radio pre-fetching or caching folder contents. When you navigate into "Stations by Country > United Kingdom > London", that is three separate HTTPS requests to the cloud.

- **The FSAPI nav nodes are a local abstraction over cloud content.** The `netRemote.nav.list` data is populated by the cloud response, not stored persistently. When you change modes or reset nav.state, the list is cleared.

- **Pagination is handled locally but data comes from cloud.** The `LIST_GET_NEXT` operation with `startItem` and `maxItems` parameters handles local pagination of the list the cloud returned. The cloud likely returns the full list for a given folder level.

- **The `netRemote.nav.browseMode` node is documented as "cacheable"** in the fsapi-tools documentation, but this refers to the FSAPI node property (whether the home automation client can cache the value), not whether the radio caches cloud content.

- **The airable-proxy.py project confirms the radio makes repeated identical requests** -- the proxy exists specifically to intercept and cache these, because the radio does not do so itself.

#### Navigation for the Old XML Protocol

For the old XML-based protocol, the navigation is self-describing. Each API response includes `<UrlDir>` elements that tell the radio what URL to request next. The radio only needs two initial URLs:
1. The login endpoint (`loginXML.asp?token=0`)
2. The root directory endpoint

From there, every subsequent menu level is navigated by following the `<UrlDir>` URLs embedded in each response. This is explicitly a cloud-fetch-per-level design -- the radio follows URL breadcrumbs through the cloud API.

#### Navigation for the New JSON Protocol

The new airable JSON protocol uses a similar hierarchical approach:
- Root: `GET /` or `GET /frontiersmart/x_streams`
- Station detail: `GET /frontiersmart/radio/<id>`
- Playback: `GET /frontiersmart/radio/<id>/play`

Each response contains `"url"` fields pointing to child resources, and `"content"` objects with `"entries"` arrays. Navigation is still a per-level cloud fetch.

Source: [fsapi-tools netRemote.nav docs](https://frontier-smart-api.readthedocs.io/en/latest/api/net/netRemote/netRemote-nav.html), [fsapi-tools device API](https://matrixeditor.github.io/fsapi-tools/api/net/device.html), [flammy/fsapi FSAPI.md](https://github.com/flammy/fsapi/blob/master/FSAPI.md), [ex_frontier FSAPI docs](https://hexdocs.pm/ex_frontier/fsapi.html), [openHAB forum](https://community.openhab.org/t/frontier-silicon-radios-via-http/90186), [WiFi-RadioAPI protocol docs](https://github.com/kimbtech/WiFi-RadioAPI)

### Summary Table

| Aspect | Stored Locally? | Fetched from Cloud? | Works Offline? |
|--------|----------------|--------------------|--------------  |
| Station catalog (browsing) | No | Yes, every browse | No |
| Podcast listings | No | Yes, every browse | No |
| Favourites (airable.fm) | No | Yes, every access | No |
| Internet radio presets (physical buttons) | Reference only | Resolved via cloud | No (usually) |
| DAB/FM presets | Yes | No | Yes |
| Currently playing stream | Buffered in RAM | Initial URL from cloud | Continues until buffer empties |
| Station logos/artwork | No | Yes, from assets.wifiradiofrontier.com | No |
| "Last Listened" history | Possibly minimal | Stream URL resolution needs cloud | Partially (current session only) |
| WiFi credentials | Yes | No | N/A |
| System settings (volume, EQ) | Yes | No | Yes |

---

## Sources

### Official Airable Pages
- [airable home](https://www.airablenow.com/)
- [Who We Are](https://www.airablenow.com/company/about/)
- [airable.API](https://www.airablenow.com/airable/airable-api/)
- [airable.radio](https://www.airablenow.com/airable/radio/)
- [airable.portal](https://www.airablenow.com/airable/airable-portal/)
- [B2B Services](https://www.airablenow.com/b2b/services/)
- [Platform Partners](https://www.airablenow.com/company/platform-partners/)
- [Reference Clients](https://www.airablenow.com/company/reference-clients/)
- [Frontier Smart Transition](https://www.airablenow.com/fs-transition/)
- [Nuvola Shutdown](https://www.airablenow.com/fs-nuvola-shutdown/)
- [FAQ (Frontier Smart Venice)](https://www.airablenow.com/faq-en/)
- [Frontier Silicon adds airable.API](https://www.airablenow.com/frontier-silicon-adds-airable-api/)

### airable.fm Portal
- [airable.fm login](https://airable.fm/auth)
- [Favorites support](https://airable.fm/support/favorites)
- [Device support](https://airable.fm/support/device)
- [Welcome/setup](https://airable.fm/support/welcome)

### Community / Reverse Engineering
- [fairable (Node.js airable replacement)](https://github.com/Half-Shot/fairable)
- [pyrable (Python airable replacement)](https://github.com/rhaamo/pyrable)
- [frontier-airable (Python airable tools)](https://github.com/seife/frontier-airable)
- [Radio-API (PHP, old XML protocol)](https://github.com/KIMB-technologies/Radio-API)
- [WiFi-RadioAPI protocol docs](https://github.com/kimbtech/WiFi-RadioAPI)
- [Half-Shot blog: New Frontiers](https://half-shot.uk/blog/new-frontiers/)
- [Home Assistant Frontier Silicon integration](https://www.home-assistant.io/integrations/frontier_silicon/)

### FSAPI Documentation & Tools
- [fsapi-tools: netRemote.nav documentation](https://frontier-smart-api.readthedocs.io/en/latest/api/net/netRemote/netRemote-nav.html)
- [fsapi-tools: Device API](https://matrixeditor.github.io/fsapi-tools/api/net/device.html)
- [fsapi-tools: Node Reference](https://frontier-smart-api.readthedocs.io/en/latest/api/net/nodes.html)
- [fsapi-tools GitHub](https://github.com/MatrixEditor/fsapi-tools)
- [flammy/fsapi FSAPI.md](https://github.com/flammy/fsapi/blob/master/FSAPI.md)
- [flammy/fsapi Documentation.md](https://github.com/flammy/fsapi/blob/master/Documentation.md)
- [tiwilliam/fsapi REVERSE.md](https://github.com/tiwilliam/fsapi/blob/master/REVERSE.md)
- [ex_frontier FSAPI documentation](https://hexdocs.pm/ex_frontier/fsapi.html)
- [librefrontier (Go, old XML protocol)](https://github.com/compujuckel/librefrontier)

### Community Discussions & Reports
- [SWLing Post: vTuner aggregation aggravation (May 2019)](https://swling.com/blog/2019/05/frontier-silicon-and-vtuner-aggregation-aggravation-continues/)
- [SWLing Post: aggregation aggravation update](https://swling.com/blog/2019/05/aggregation-aggravation-update-frontier-silicon-working-on-favorites-and-personal-streams/)
- [SWLing Post: Frontier Silicon tag](https://swling.com/blog/tag/frontier-silicon/)
- [Recommended Stations: Internet Radio Update (Nov 2024)](https://recommendedstations.com/2024/11/01/an-internet-radio-update/)
- [Sound & Vision: Como Audio radios](https://www.soundandvision.com/content/owners-como-audio-table-radios-could-be-rude-awakening)
- [openHAB Forum: Frontier Silicon radios via HTTP](https://community.openhab.org/t/frontier-silicon-radios-via-http/90186)
- [Home Assistant Forum: FS presets in internet radio mode](https://community.home-assistant.io/t/frontier-silicon-device-change-radio-station-in-internet-radio-mode-by-use-of-presets/262456)
- [Node-RED Forum: Frontier Silicon radio control](https://discourse.nodered.org/t/frontier-silicon-based-internet-radio-controlled-by-node-red/33703)

### Other
- [LearnHole: Frontier Smart Technologies overview](https://learnhole.com/frontier-smart-technologies/)
- [Teufel: Using Internet Radio via airable](https://support.teufel.de/hc/en-us/articles/28135953800594)
- [Pure: Frontier to Airable transition](https://support.pure-audio.com/en-US/kb/articles/internet-radio-change-from-frontier-to-airable-service-evoke-range-classic-stereo-elan-connect)
- [Volumio: airable plugin request](https://community.volumio.com/t/sync-for-radio-stations-airable-radio-station-plugin/70764)
- [WiFi-RadioAPI protocol logs](https://github.com/kimbtech/WiFi-RadioAPI/blob/master/HamaData.md)
