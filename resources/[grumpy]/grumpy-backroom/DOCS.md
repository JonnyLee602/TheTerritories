# grumpy-backroom — developer docs

1. Architecture
2. Data formats
3. Exports
4. Events and callbacks
5. Persistence
6. Security model
7. Database
8. How-tos
9. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | All settings (prices carry their doctrine band) |
| `shared/zone.lua` | `BackroomZone.Valid/Contains/Centre`: polygon extruded from `minZ` to `maxZ`, used by the server to decide who is inside |
| `server/main.lua` | Rooms in memory + DB, `GlobalState.grumpyBackrooms`, the bribe, the 1 s ticker (warnings, closing), showing out, rsg-doorlock door control, admin callbacks, exports |
| `client/main.lua` | Doorman peds (spawn within range, rsg-target option), bribe menu (rsg-menubase), rsg-core poly zones for the "time left" notice, the show-out (fade, stand up from grumpy-sit, teleport) |
| `client/reup.lua` + `html/` | Closing-time re-up panel: NUI without focus, upper right; arrow up/down (or a tap of the key) = pick a length, hold the key = `server:reup`; all keys are ignored while another UI has NUI focus (`IsNuiFocused`); hides on timeout, leaving the zone, death, payment (`client:reupDone`) or show-out |
| `client/admin.lua` | `/backroom` list + editor, rsg-gizmo doorman placement (local ghost ped + `Edit()`), door picker, corner capture, preview lines |
| `integrations/rsg-doorlock.md` | The `SetDoorState` hook for rsg-doorlock |

Flow: bribe → `openRoom` (adds time, unlocks the doors if it was closed, saves `open_until`) → ticker warns players
inside at `WarnAt` (each gets `client:reup` with their own prices; paying there runs the same `pay()` as the doorman, but checks the player is inside the zone instead of near the doorman) → at 0 `closeRoom`: everyone inside (server-side `GetEntityCoords` + polygon test) is stood up
from grumpy-gambling (`StandPlayer`, chips cashed out; bets already in a hand stay in it) and sent
`client:showOut` → doors lock after `LockDelay` → `SweepAfter` checks move anyone still inside with server
`SetEntityCoords`.

## 2. Data formats
Room (server): `{ id, name, model, npc = {x,y,z,w}, doors = { rsgDoorlockId, ... }, zone = { points = { {x,y}, ... }, minZ, maxZ }, exit = {x,y,z,w}, enabled, openUntil, warned }`.
`npc` and `exit` are standing ped coords (the doorman spawns at `z - 1.0`). `doors` are `rsg_doorlocks.id` values.
`GlobalState.grumpyBackrooms` = usable rooms only, `{ id, name, model, npc, zone }` (no door ids, no timers).

## 3. Exports (server)
| Export | Returns | Notes |
|---|---|---|
| `GetTimeLeft(roomId)` | seconds | 0 = closed |
| `OpenRoom(roomId, seconds)` | bool | Adds time like a bribe, free. Caller checks who may do it |
| `CloseRoom(roomId)` | bool | Shows everyone out and locks |
| `IsInside(src, roomId?)` | bool, roomId | Any room if `roomId` is nil |

## 4. Events and callbacks
| Name | Side | Notes |
|---|---|---|
| `grumpy-backroom:server:bribe (roomId, choice)` | server event | `choice` = index into `Config.Bribes` |
| `grumpy-backroom:server:reup (roomId, choice)` | server event | Re-up from inside; payer must be inside the zone and the room still open |
| `grumpy-backroom:server:quote (roomId)` | callback | `{ id, name, left, max, options = { {minutes, price, fits} } }`, price already × standing |
| `grumpy-backroom:server:timeLeft (roomId)` | callback | seconds |
| `grumpy-backroom:server:adminRooms / adminSave / adminDelete / adminSetOpen` | callbacks | admin only |
| `grumpy-backroom:client:showOut (exit)` | client event | fade + teleport |
| `grumpy-backroom:client:reup (quote)` / `client:reupDone (roomId)` | client events | Show / hide the re-up panel |
| `grumpy-backroom:client:openAdmin` | client event | from `/backroom` |

Uses: `rsg-doorlock:server:getDoors` (door picker), `exports['rsg-doorlock']:SetDoorState` (hook),
`rsg-doorlock:client:setState` (fallback), `exports['grumpy-gambling']:StandPlayer`,
`exports['grumpy-reputation']:GetPriceMultiplier(src, 'underground', 'buy')`, `exports['grumpy-sit']:IsSeated/Stand`.

## 5. Persistence
Rooms live in `grumpy_backroom_rooms`. `open_until` (unix time) is saved on every open/close, so paid time survives
a restart; rooms whose time ran out while the server was down are closed and locked on start. Door states set by
the hook are not saved by rsg-doorlock (its DB keeps the door locked), and grumpy-backroom re-applies open rooms
when rsg-doorlock restarts.

## 6. Security model
- The client only sends a room id and a choice index. Price, standing, money type, distance to the doorman
  (`InteractDistance + DistanceTolerance`), dead/cuffed, on-duty law and the max-time cap are all checked on the
  server. 2 s cooldown per player.
- Who gets shown out is decided on the server from ped coords; the client teleport is a courtesy and the server
  sweeps afterwards.
- Admin callbacks check `Config.AdminPermission`; room data is sanitised (finite coords, 3–24 corners, height cap,
  door ids are integers, kick-out point outside the zone, enabled rooms must be complete).
- Other resources calling `OpenRoom` must do their own checks.

## 7. Database
```sql
grumpy_backroom_rooms (id PK, name VARCHAR(48), npc_model VARCHAR(64), npc JSON, doors JSON, zone JSON,
                       exit_point JSON, enabled TINYINT, open_until INT)
```

## 8. How-tos
- **Change prices/durations:** edit `Config.Bribes` (keep it in the fence-bribe band, `doctrine/pricing.md`).
- **Test the warnings / re-up panel / kick-out:** stand in the room and type `/backroomtest` (6 min left: the 5-minute
  warning comes after ~1 min) or `/backroomtest 0.5` (30 s: straight to the 15-second warning and the kick-out).
- **Let a job stay after closing:** `Config.Exempt.jobs = { 'jobname' }`.
- **Rooms on two floors:** draw the zone per floor as separate rooms, or raise the height; the zone is one
  polygon from the floor up.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| Console: "no SetDoorState export" | Add the hook (`integrations/rsg-doorlock.md`) and restart rsg-doorlock |
| Door picker is empty | Make the doors in `/doorlock` first, stand within 30 m |
| Door doesn't open for someone who just joined | Hook missing (fallback mode) |
| "Kick-out point is inside the zone" | Move the point outside the red lines |
| People on the stairs/balcony aren't shown out | Zone too low or a corner missing: raise the height or add corners |
| Re-up keys / arrows do nothing | The card table has the mouse (your turn): press Esc, or wait for the next warning |
| Doorman never appears | Room not enabled or incomplete (list says "Not set up") |
