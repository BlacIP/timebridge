# TimeBridge — Time Zone Converter

A tiny, offline-capable PWA that converts between **any two time zones in the world**. Defaults to **Provo, Utah (Mountain Time, MST/MDT) → Nigerian time (WAT)** — built for scheduling meetings with US colleagues on Mountain Time.

- **Any zone, searchable** — tap either clock to pick from all ~400 IANA zones; search by city (*Lagos*, *London*), country (*Nigeria*, *India*), or abbreviation (*MST*, *PST*, *WAT*, *IST*)
- **Live clocks** for both selected zones, with current abbreviation (MST/MDT status) and UTC offset
- **Two-way converter** — two time fields, one per zone; edit either side and the other recalculates (a small button copies the conversion for pasting into chat). Zone choices are remembered on the device
- **Quick reference** table mapping business hours between the two zones
- **DST-safe**: the 7-hour gap (summer, MDT) vs 8-hour gap (winter, MST) is handled automatically via the browser's timezone database — no updates ever needed
- **No build step, no dependencies** — plain HTML/CSS/JS, works fully offline once installed

## Run locally

```sh
python3 -m http.server 8080
# open http://localhost:8080
```

(Any static file server works.)

## Deploy

It's a static site — anything that serves files over **HTTPS** works (HTTPS is required for the PWA service worker).

**Vercel** (simplest):

```sh
npx vercel          # first run: log in + link project
npx vercel --prod   # production deploy
```

**Netlify**: drag the folder onto [app.netlify.com/drop](https://app.netlify.com/drop)

**GitHub Pages**: push this folder to a repo → Settings → Pages → deploy from branch.

## Install on your phone (PWA)

Open your deployed URL, then:

- **iPhone (Safari)**: Share button → **Add to Home Screen**
- **Android (Chrome)**: menu (⋮) → **Add to Home screen** / **Install app**

It launches full-screen like a native app and works with no connection.

## Mac menu bar

Both options show live times in the menu bar with a meeting quick-reference dropdown:

```text
🏔 9:00am · 🇳🇬 4:00pm
```

### Option A — native app, nothing third-party

[`menubar/native/`](menubar/native/) contains a small Swift menu bar app compiled on your own machine with Apple's toolchain (needs Xcode or the free Command Line Tools):

```sh
cd menubar/native
./build.sh
open "TimeBridge Bar.app"
```

To start it automatically: System Settings → General → **Login Items** → **+** → select the app.
To change zones, convert a different default city, or set the converter URL, edit the constants at the top of `TimeBridgeBar.swift` and re-run `./build.sh`.

### Option B — SwiftBar/xbar plugin

If you'd rather not compile anything, [`menubar/denver-lagos.1m.sh`](menubar/denver-lagos.1m.sh) does the same via **SwiftBar** (free, open source — [xbar](https://xbarapp.com) works identically):

```sh
brew install swiftbar
```

1. Launch SwiftBar; it asks you to choose a plugin folder (e.g. `~/Documents/SwiftBar`)
2. Copy the plugin in:

   ```sh
   cp menubar/denver-lagos.1m.sh ~/Documents/SwiftBar/
   chmod +x ~/Documents/SwiftBar/denver-lagos.1m.sh
   ```

3. (Optional) edit the variables at the top of the script:
   - `FROM_TZ` / `TO_TZ` — any IANA zones (defaults: `America/Denver`, `Africa/Lagos`)
   - `APP_URL` — your deployed URL, to get an "Open converter" item in the dropdown.

Alternative: [MenubarX](https://menubarx.app) can pin the deployed web app itself into the menu bar as a mini browser window.

## Project layout

```text
index.html            app shell
styles.css            dark, mobile-first styling
tz.js                 pure Intl-based timezone helpers (DST-safe)
zones.js              zone catalog + search (cities, countries, abbreviations)
app.js                UI logic: clocks, zone picker, converter, quick reference
sw.js                 service worker (offline cache)
manifest.webmanifest  PWA manifest
icons/                app icons (regenerate with tools/make-icons.py)
menubar/              menu bar: native Swift app (native/) + SwiftBar/xbar plugin
```
