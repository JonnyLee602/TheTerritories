# grumpy-law developer and server owner docs

## Contents
1. Architecture
2. Incident lifecycle
3. Data formats
4. Server exports
5. Events (NPC police hooks here)
6. Persistence
7. Security model
8. Performance
9. Server owner how-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | Witness, crime, report and heat settings |
| `shared/animals.lua` | `AnimalModels`: hashes of every `a_c_` / `mp_a_c_` ped model, generated from `data/rdr3_discoveries/peds/peds_list.lua` (the server can't call `IS_PED_HUMAN`) |
| `server/main.lua` | Incidents, server witness scan, client scan validation, reports, heat tracker, exports, `/witnesstest` |
| `client/main.lua` | Line-of-sight scan on the criminal's game, `/witnesstest` client side |

## 2. Incident lifecycle
1. **Open:** a script calls `OpenIncident(src, opts)`. The incident gets a hot window (`opts.hot` or the crime's `hot`).
2. **Witnessing (hot window):**
   - Server, every `ScanInterval`: `GetAllPeds()`, keeping non-player, alive, non-animal peds within `Radius` of the criminal. Those within `CloseRadius` become witnesses.
   - Client, every `ClientInterval`: humans within `Radius` with `HAS_ENTITY_CLEAR_LOS_TO_ENTITY` (nearest `ClientMaxPeds`). It sends network IDs plus a count. The server re-checks each network ID (ped type, not a player, alive, not an animal, within `Radius + 2` of the criminal).
   - Fallback: if the server saw **no** NPCs during the whole window, `min(clientCount, ClientFallbackMax)` witnesses are added from the client's count.
   - `victimReports = true` adds a guaranteed report after `victimDelay`.
3. **Each witness** rolls `ReportChance`. On success, a timer of `ReportDelay` seconds starts. When it fires, if `DeadNoReport` is on and the witness ped is gone or dead, nothing happens.
4. **Report (first one only):** on-duty law gets alerted, the criminal is notified, heat starts, and `grumpy-law:server:crimeReported` fires.
5. **Heat:** see the README table. The escape bonus needs `incident.succeeded == true` when the window ends. Scripts call `MarkSucceeded` when the crime pays out, which can happen after the report.
6. Incidents are forgotten `Heat.Duration + 600` s after opening.

## 3. Data formats
`OpenIncident` options: `{ crime = 'store_robbery'|'shoplifting'|'generic'|<your Config.Crimes key>, coords = vector3?, label = string?, hot = seconds?, victimReports = bool?, succeeded = bool? }`

Public incident (events, `GetIncident`): `{ id, crime, label, coords, criminal (src), citizenid, opened, succeeded, reported, witnesses }`

## 4. Server exports
| Export | Returns | Notes |
|---|---|---|
| `OpenIncident(src, opts)` | incident id or nil | |
| `MarkSucceeded(id)` | boolean | Makes the escape bonus possible |
| `ReportNow(id)` | boolean | Force a report (e.g. a silent alarm) |
| `GetIncident(id)` | public incident or nil | |
| `IsHot(src)` | boolean | Player has heat from any reported incident |
| `LawOnDuty()` | number | On-duty player law |

## 5. Events
| Event (server-local) | Args | Use |
|---|---|---|
| `grumpy-law:server:crimeReported` | `incident, lawOnDutyCount` | **NPC police entry point:** respond when the count is 0 |
| `grumpy-law:server:heatEnded` | `citizenid, incidentId, outcome, incident` | `outcome`: `escaped`, `jailed`, `died`, `offline` |

## 6. Persistence
None. Incidents and heat live in memory. A restart clears them (no bonus, no penalty).

## 7. Security model
- The client can only **add** witnesses that the server can verify by network ID, or supply the fallback count when the server sees no NPCs at all. It can't remove witnesses the server found within `CloseRadius`, and it can't report or end heat.
- Scan results are accepted only from the incident's criminal, during the hot window (+2 s), at most once per `ClientInterval`.
- The escape bonus comes from server state: the crime succeeded (set by the calling script), the heat window ran out, and the player stayed online, alive and out of jail.
- With population **not** networked, the client's count is trusted up to `ClientFallbackMax`. A modded client can send 0 there and avoid witnesses. Keep that cap and the rewards modest, or use victim reports (the clerk always reports in grumpy-robbery).

## 8. Performance
Nothing runs unless an incident is hot or someone has heat.
- Server scan: one `GetAllPeds()` pass with a distance check every 2 s per hot incident (about 45 s for a robbery).
- Client scan: at most 10 raycasts every 3 s, only on the criminal's game, only while hot.
- Heat: one metadata read per hot player every 5 s.

## 9. Server owner how-tos
- **Check population:** `/witnesstest` in Valentine. The server count should be close to your game's count.
- **Harder or easier to be seen:** `Witness.Radius`, `CloseRadius`, `ReportChance`.
- **Longer heat:** `Heat.Duration`.
- **New crime type:** add a `Config.Crimes` entry and an `alert_<crime>` locale string, then open incidents with that name.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| `/witnesstest`: your game's humans show as **read as dead** on the server | The server can't read ambient NPC health; the health check in `npcsNear` and `scanResult` has to go (tell the developer) |
| `/witnesstest` server count is 0 | Ambient population isn't networked: check `onesync` is on and `onesync_population` isn't set to false. Witnessing falls back to the client |
| No escape bonus | The crime didn't succeed (`MarkSucceeded` not called), the player died, was jailed or logged off, or grumpy-reputation's `escaped` daily cap was reached |
| Law gets no alert | No on-duty `leo` players. The `crimeReported` event still fires for future NPC police |
