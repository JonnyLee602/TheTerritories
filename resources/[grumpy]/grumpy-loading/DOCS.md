# grumpy-loading — developer & server owner docs

## Contents
1. Architecture
2. Data formats
3. Exports
4. Events & messages
5. Integration
6. Persistence
7. Security model
8. Database
9. How-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | `loadscreen 'html/index.html'` with `loadscreen_manual_shutdown 'yes'`; serves html, music, images and locales. |
| `shared/config.lua` | Lua options: `CloseOnPlayerLoaded`, `CloseDelay`, `ServerInfo`. |
| `server/main.lua` | On `playerConnecting`, calls `deferrals.handover({ grumpyLoading = { players, maxPlayers, serverName } })`. The server name comes from `sv_projectName`, or `sv_hostname` if that is empty, with `^n` colour codes stripped. |
| `client/main.lua` | On `RSGCore:Client:OnPlayerLoaded`: sends `{ type = 'grumpy-loading:finish' }`, waits `Config.CloseDelay` ms, then calls `ShutdownLoadingScreenNui()`. |
| `html/index.html` | Page markup. Fonts come from Google Fonts. |
| `html/style.css` | Newspaper styling on a fixed 1600×900 `#stage`, scaled with the `--scale` variable. |
| `html/config.js` | Page options (`window.GAZETTE_CONFIG`). |
| `html/script.js` | Locale loading, masthead, story and notice rotation, backgrounds, music, telegraph progress, finish and auto-close. |
| `locales/en.json` | All on-screen text. |
| `html/music/`, `html/images/` | Music and background photos. |

## 2. Data formats
**Locale keys** (`locales/<lang>.json`). Numbered groups stop at the first missing number.

| Key | Use |
|---|---|
| `masthead_title`, `ear_left`, `ear_right`, `price`, `motto` | Masthead text |
| `issue` | `%s` = issue number |
| `population` | `%s` = players, `%s` = max players |
| `population_unknown` | Shown when there is no handover data |
| `story_N_kicker`, `story_N_headline`, `story_N_deck`, `story_N_body` | Front-page stories (a story counts when `headline` is present) |
| `paths_title`, `path_N_name`, `path_N_motto`, `path_N_text` | The Three Roads column |
| `wanted_title`, `wanted_subject`, `wanted_text`, `wanted_reward` | WANTED poster |
| `wanted_discord` | `%s` = `discord` from the config |
| `notices_title`, `notice_N` | Rotating notices |
| `wire_label`, `wire_stage_N`, `wire_ready` | Telegraph bar. Stages split 0–100% evenly. |
| `music_hint`, `page_title` | Other text |

The **dateline** is `new Date(year, month, day)` formatted with `toLocaleDateString(locale, { weekday, month, day, year })`, so the weekday is correct for that year.

## 3. Exports
None.

## 4. Events & messages
| Name | Direction | Payload | Notes |
|---|---|---|---|
| `grumpy-loading:finish` | Lua → page (`SendLoadingScreenMessage`) | `{ type = 'grumpy-loading:finish' }` | Sets progress to 100%, shows `wire_ready`, stops the rotations and fades the music. It does **not** close the screen; call `ShutdownLoadingScreenNui()` for that. |
| `loadFraction` | Game → page | `{ loadFraction = 0..1 }` | Native load progress. Until the first one arrives, the bar drifts forward on its own to a maximum of 95%. The bar never moves backwards. |
| `window.nuiHandoverData.grumpyLoading` | Server → page | `{ players, maxPlayers, serverName }` | Set by `server/main.lua` (`serverName` is sent but not shown yet). |

## 5. Integration
- **rsg-character** calls `ShutdownLoadingScreen()` and `ShutdownLoadingScreenNui()` when character selection opens (`client/charselect.lua`). That is normally what closes this screen. **rsg-core** (`client/events.lua`) also calls `ShutdownLoadingScreenNui()`.
- To get the music fade before rsg-character closes the screen, send `grumpy-loading:finish` about 1 s before that call. This is optional, since a hard cut also works.

## 6. Persistence
None. Nothing is saved.

## 7. Security model
The page is display-only. It reads its own files and the handover data, and sends nothing to the server. The handover holds only the public player count and server name.

## 8. Database
None.

## 9. How-tos
- **Change the song:**
  1. Drop an `.mp3` or `.ogg` into `html/music/`.
  2. Set `music: 'music/<file>'` in `html/config.js`.
  3. Keep the file under about 8 MB, because every new player downloads it before joining.
- **Add background photos:** put them in `html/images/` and list them in `backgrounds`. Screenshots from Rockstar Editor in RedM work well. Keep each under about 1 MB.
- **Add a story:** add `story_6_kicker`, `story_6_headline`, `story_6_deck` and `story_6_body` to the locale.
- **Preview outside the game:** serve the resource folder over HTTP, because `file://` blocks the locale fetch. For example, run `py -m http.server 8731 --directory builds/grumpy-loading`, then open `/html/index.html`. The progress bar runs on its own when previewed this way.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| The old RSG screen still shows | `rsg-loading` is still started. Remove its `ensure` or delete it. |
| Blank text | The locale file failed to load. Check that `locale` in `config.js` matches a file in `locales/` and that the JSON is valid. |
| Plain serif fonts | Google Fonts couldn't load (player offline or blocked). The page falls back to Georgia or Times New Roman. |
| No music | `music` is blank or the path is wrong, or the player pressed SPACE. |
| Shows "Souls arriving daily" instead of a count | `Config.ServerInfo = false`, or another resource's deferrals overwrote the handover. |
| Screen never closes | Nothing called `ShutdownLoadingScreenNui`. Keep `autoCloseSeconds` above 0, and check rsg-character. |
