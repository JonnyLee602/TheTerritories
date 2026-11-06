# grumpy-backroom

Back-room card rooms for The Territories. Players slip a doorman a bribe, the room's rsg-doorlock doors open for
the time they paid for, and when time runs out everyone still inside is shown out and the doors lock again.

Version 0.2.0. Dependencies: `rsg-core`, `rsg-doorlock` (with the hook below), `rsg-target`, `rsg-gizmo`,
`rsg-menubase`, `oxmysql`. Optional: `grumpy-reputation` (price by standing), `grumpy-gambling` (players are stood
up from tables and cashed out before they're shown out), `grumpy-sit`. Developer details: [DOCS.md](DOCS.md).

## Features
- Admins set up each room in game with `/backroom`: place the doorman (rsg-gizmo), pick the doors (existing
  rsg-doorlock locks), walk the room's corners to draw the zone, set the kick-out point. Everything is drawn in
  the world while you edit.
- Players talk to the doorman (rsg-target) and choose how long: 30 min $0.50, 1 h $1.00, 2 h $1.75 by default.
  One payment opens the door for everyone; paying again while open adds time (max 3 h).
- Dirty money first (`bloodmoney`, then `cash`). The bribe is destroyed (a money sink). Known outlaws pay less
  (grumpy-reputation underground prices); on-duty lawmen are turned away.
- Warnings at 5 min, 1 min and 15 s to everyone inside, shown as a small panel in the upper-right corner (clear
  of the card-table UI) with the time left and the lengths on offer: **tap J** for another length, **hold J** to pay
  without leaving the table. Same prices and money rules as the doorman; anyone inside can pay. At closing time they're stood up from card tables,
  faded out and moved to the kick-out point, then the doors lock. Anyone still inside a few seconds later is moved
  out by the server.
- Paid time survives a server restart; an rsg-doorlock restart re-opens open rooms.
- Players walking in are told how long the room has left.

## Installation
1. Add the `[grumpy-backroom hook]` to rsg-doorlock (`integrations/rsg-doorlock.md`, already applied on The
   Territories).
2. Put `grumpy-backroom` in `[grumpy]` and start it after rsg-doorlock, rsg-target, rsg-gizmo and rsg-menubase.
3. The table `grumpy_backroom_rooms` is created on start (`install.sql` if you prefer to import it).

## Setting up a room
1. `/doorlock`: make a lock for each door into the back room. Leave it **locked** with **no jobs**.
2. `/backroom` → **+ New back room**.
3. **Name** it, **place the doorman** outside the door, pick the **Doors**.
4. Walk to each corner of the room in order and choose **Add zone corner where I stand**. Set the **Zone height**
   with left/right. The red box is who gets shown out, so cover the whole room, card tables included.
5. Stand outside, facing away from the door, and choose **Kick-out point** (it can't be inside the zone).
6. **Enabled: yes**, then **Save**. **Open for a test** opens it free for 60 seconds so you can watch the kick-out
   (set `Config.Exempt.admins = false`, the default, to be kicked yourself).

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AdminCommand` / `AdminPermission` | `backroom` / `admin` | Setup command and who can use it |
| `TestSeconds` | 60 | "Open for a test" length |
| `Bribes` | 30 min $0.50, 60 min $1.00, 120 min $1.75 | Choices in the doorman's menu (doctrine: fence bribe band) |
| `MaxOpenMinutes` | 180 | Time left can't go above this |
| `PayWith` | `{ 'bloodmoney', 'cash' }` | Money types tried in order |
| `StandingScales` | true | Price × grumpy-reputation underground buy multiplier |
| `BlockLaw` | true | On-duty `leo` jobs can't bribe |
| `WarnAt` | `{ 300, 60, 15 }` | Seconds left when people inside are warned |
| `Reup.Enabled` | true | Re-up panel at the warnings (false = plain notifications) |
| `Reup.Key` / `KeyLabel` | `0xF3830D8E` / `J` | INPUT_OPEN_JOURNAL; the journal is blocked while the panel shows |
| `Reup.HoldMs` | 1200 | Hold time to pay |
| `Reup.ShowSeconds` | 25 | Panel hides after this (or when you leave the room) |
| `Reup.Position` | `{ top = '6vh', right = '1.5vw' }` | CSS position of the panel |
| `LockDelay` | 1500 | ms after showing people out before the doors lock |
| `SweepAfter` | `{ 4000, 10000 }` | ms after closing when the server moves out anyone still inside |
| `StandFromTables` | true | Stand players up from grumpy-gambling tables first |
| `Exempt.admins` / `Exempt.jobs` | false / `{}` | Who may stay after closing |
| `Npc.model` | `u_m_m_gamdoorman_01` | Default doorman (each room can change it) |
| `Npc.scenario` | `WORLD_HUMAN_STAND_WAITING` | Doorman idle scenario (nil = none) |
| `Npc.spawnDistance` | 40.0 | Doorman spawns within this range |
| `InteractDistance` | 2.5 | rsg-target range |
| `Zone.*` | floor offset 1.2, height 4 (2–15), 24 corners | Zone limits |
| `MaxDoors` / `DoorPickRange` | 8 / 30.0 | Doors per room, door picker range |

## Commands
| Command | Permission | What it does |
|---|---|---|
| `/backroom` | admin | Room list and editor |

## Developer example
```lua
-- server: open room 3 for 10 minutes from another script (e.g. a gang perk)
exports['grumpy-backroom']:OpenRoom(3, 600)
local inside, roomId = exports['grumpy-backroom']:IsInside(source)
```

## Locales
en
