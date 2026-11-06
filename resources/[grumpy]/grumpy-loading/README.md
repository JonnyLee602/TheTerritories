# grumpy-loading

**The Territories Gazette**: a loading screen laid out as an 1890s frontier newspaper. It shows a live population count, rotating front-page stories that teach the server's doctrine, the three paths, a WANTED poster, notices, a telegraph-line progress bar and background music.

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** none (it listens for `RSGCore:Client:OnPlayerLoaded`, but runs without rsg-core).
**Replaces:** `rsg-loading`. Run only one loading screen.

## Features
- **Newspaper front page.** It has the server logo framed in the corner, a blackletter masthead and the issue number, which counts days since `firstIssue`. The dateline shows today's month and day in 1899, with the right weekday.
- **Live population** in the masthead: "12 of 48 souls in the Territory today". It comes from the server while the player connects.
- **Rotating lead stories.** Each one has a kicker, headline, deck and body. The default five cover:
  - settlement and no fixed path;
  - why blood money can't buy deeds or businesses;
  - reputation and shop prices;
  - 1890s prices;
  - buying saloons and shops with clean money.
- **The Three Roads** column covers Civilian, Outlaw and Hybrid.
- **WANTED poster** for new settlers, with an optional Discord line.
- **Rotating notices** (tips and rules).
- **Telegraph progress line.** Dots and dashes fill the wire from pole to pole, using the game's real `loadFraction`. Status text moves through in-character stages, from "Opening the line…" to "Fresh off the press…".
- **Music** loops quietly. Players press **SPACE** to mute or unmute, and it fades out when the screen closes.
- **Optional photo slideshow** behind the paper, dimmed, with a slow drift.
- **Scales to any resolution.** The page is drawn on a fixed 1600×900 canvas and scaled to fit.
- **Respects "reduce motion".**

## Installation
1. Copy `grumpy-loading` into your resources (e.g. `resources/[grumpy]/`).
2. **Stop `rsg-loading`**: move its folder out of `resources/` and remove its `ensure` line. If your `server.cfg` has `ensure [framework]`, removing the line alone is not enough, because the folder still starts. Two loading screens fight each other.
3. `ensure grumpy-loading` (already covered by `ensure [grumpy]`).
4. Restart the server. The loading screen is downloaded when players connect, so `restart grumpy-loading` alone won't show changes to players already in game.

There are no items and no database.

## Configuration

### `html/config.js` (the page)
| Option | Default | Description |
|---|---|---|
| `locale` | `'en'` | Language file in `locales/` |
| `logo` | `'images/logo.png'` | Server logo, framed in the masthead's left corner (it replaces the left corner text). Blank = text only. |
| `year` | `1899` | Year printed in the dateline |
| `firstIssue` | `'2026-11-05'` | Date of Issue No. 1. The issue number counts days since then. |
| `storySeconds` | `14` | Seconds per front-page story |
| `noticeSeconds` | `8` | Seconds per notice |
| `music` | `'music/song2.mp3'` | Music file in `html/music/`. Blank = no music. |
| `musicVolume` | `0.3` | 0.0 – 1.0 |
| `musicFadeSeconds` | `1.0` | Fade-out when the screen closes |
| `backgrounds` | `[]` | Photos behind the paper (`'images/x.jpg'` or URLs). Several = slideshow. Empty = plain desk. |
| `backgroundSeconds` | `15` | Seconds per photo |
| `backgroundDim` | `0.55` | 0 = full brightness, 1 = black |
| `discord` | `''` | Shown on the WANTED poster. Blank hides the line. |
| `autoCloseSeconds` | `300` | Safety net: close after this many seconds. 0 = never. |

### `shared/config.lua` (Lua)
| Option | Default | Description |
|---|---|---|
| `Config.CloseOnPlayerLoaded` | `true` | Close the screen on `RSGCore:Client:OnPlayerLoaded` |
| `Config.CloseDelay` | `1200` | Milliseconds between telling the page to finish (music fade) and shutting it |
| `Config.ServerInfo` | `true` | Send player count and server name to the masthead |

## How to use
Players see it while they connect, and it closes at character selection, when rsg-character calls `ShutdownLoadingScreenNui`. **SPACE** toggles the music. There are no commands.

To change the text, edit `locales/en.json`:
- Stories are numbered `story_1_*`, `story_2_*` and so on. Each needs `kicker`, `headline`, `deck` and `body`, and numbering stops at the first gap.
- Notices are `notice_1`, `notice_2` and so on.
- The three roads are `path_1_*` to `path_3_*`.
- Keep a story body under about 70 words, or it won't fit the column.

## Developer example
Close the screen early from your own client script:
```lua
SendLoadingScreenMessage(json.encode({ type = 'grumpy-loading:finish' })) -- fades music, shows "Extra! Extra!"
Wait(1200)
ShutdownLoadingScreenNui()
```

## Locales
en (copy `locales/en.json` to add a language, then set `locale` in `html/config.js`).

## Credits
- **Fonts:** UnifrakturMaguntia, IM Fell English and Playfair Display, from Google Fonts (SIL Open Font License). They fall back to Georgia or Times New Roman when offline.
- **Music:** `song2.mp3` was taken from the `bln_loading` resource. Check its licence before you redistribute this resource.
