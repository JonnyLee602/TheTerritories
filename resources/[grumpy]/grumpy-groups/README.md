# grumpy-groups

Gangs and posses in one resource. It replaces **rsg-gangmenu** (boss menu, recruiting, gang stash and gang funds) and adds **posses**: temporary groups any players can form by targeting each other. It also gives other scripts one call to find a player's group (posse, then gang, then on-duty coworkers).

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`
**Replaces:** `rsg-gangmenu` (remove it). **Used by:** grumpy-rumors (planned).

## Features
### Gangs (replaces rsg-gangmenu)
- Gang membership itself still lives in rsg-core (`PlayerData.gang`, `rsg-core/shared/gangs.lua`, `/setgang`). This resource is the management side.
- **Boss menu**: at a gang location (prompt, `J`) or anywhere with `/gangmenu`.
  - **Members**: online/offline list sorted by rank. Change a member's rank (up to your own) or remove them.
  - **Recruit**: invite nearby players. They get an Accept/Decline card.
  - **Gang Stash** and **Gang Funds** (deposit / withdraw), only at the gang location.
- Bosses can also target a player and choose **Recruit to gang**.
- Uses the **same stash ids (`gang_<name>`) and `management_funds` rows** as rsg-gangmenu, so existing stashes and money carry over.
- Old `exports['rsg-gangmenu']:AddGangMoney / RemoveGangMoney / GetGangAccount` calls keep working.
- No ox_lib: rsg-core notify, callbacks and locales, and a house-style NUI instead of ox_lib menus.

### Posses
- Target any player and choose **Invite to posse**. They get an Accept/Decline card (30 s).
- Inviting while not in a posse creates one when they accept, with you as leader.
- Gang members and coworkers can form posses too, so a few of them can split off for a job without involving everyone.
- **Hard lifetime cap: 2 hours from creation.** Passing the lead, members joining or leaving, and relogging never extend it. Every member is warned 5 minutes before the end.
- Up to 7 riders. Map blips show each member (leader has the posse-leader icon), even when they're far away.
- `/posse` panel: members, time left, leave. The leader can pass the lead, kick or disband.
- If the leader goes offline, they keep the lead for 2 minutes, then it passes to the next online member. A posse that drops below 2 members, or has nobody online, breaks up.
- Posses live in server memory: a server or resource restart ends them all.

## Installation
1. **Remove `rsg-gangmenu`** from your resources and `server.cfg`.
2. Put `grumpy-groups` in your resources folder and add after rsg-core, rsg-inventory and rsg-target:
   ```
   ensure grumpy-groups
   ```
3. Database: the `management_funds` table is created automatically if it's missing (it usually exists already from rsg-bossmenu/rsg-gangmenu). To do it yourself, set `Config.AutoDatabase = false` and import `install.sql`.
4. Copy your `Config.GangLocations` from rsg-gangmenu's config into `shared/config.lua` (same format).

No items are needed.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create `management_funds` on start |
| `Config.Gang.Command` | `'gangmenu'` | Boss menu anywhere (members + recruit only) |
| `Config.Gang.Keybind` | `'J'` | Prompt key at gang locations |
| `Config.Gang.InteractDistance` | `5.0` | Server-checked distance for stash and funds |
| `Config.Gang.HireDistance` | `10.0` | Max boss–recruit distance |
| `Config.Gang.MaxTransaction` | `1000000` | Max single deposit / withdraw |
| `Config.Gang.StorageMaxWeight` / `StorageMaxSlots` | `4000000` / `50` | Gang stash size |
| `Config.Gang.InviteTimeout` | `30` | Seconds to answer a gang invite |
| `Config.Gang.TargetRecruit` | `true` | "Recruit to gang" target option for bosses |
| `Config.Gang.Blip` | `blip_honor_bad`, `0.2` | Gang location blip sprite and scale |
| `Config.GangLocations` | example | `{ id, name, blipname, coords, showblip, blipforall }`. `id` = gang name |
| `Config.Posse.Command` | `'posse'` | Opens the posse panel |
| `Config.Posse.MaxMembers` | `7` | Including the leader |
| `Config.Posse.MaxLifetime` | `7200` | Seconds from creation. Hard cap |
| `Config.Posse.WarningTime` | `300` | Warning this many seconds before the end |
| `Config.Posse.InviteDistance` | `5.0` | Server-checked inviter–invitee distance |
| `Config.Posse.InviteTimeout` | `30` | Seconds to answer |
| `Config.Posse.InviteCooldown` | `5` | Seconds between invites from one player |
| `Config.Posse.MembersCanInvite` | `false` | `false` = only the leader invites |
| `Config.Posse.LeaderGrace` | `120` | Seconds an offline leader keeps the lead |
| `Config.Posse.TickInterval` | `15` | Seconds between expiry / leader checks |
| `Config.Posse.Blips` | on, every 3 s | Member blips: style, modifier, leader sprite |
| `Config.Members.Radius` | `gang = 100, job = 100` | Default distance for `GetMembers` (posses never check distance) |
| `Config.Members.JobOnDuty` | `true` | Job members must be on duty |
| `Config.Members.IgnoreJobs` | `{ unemployed = true }` | Jobs that never count as a group |

## How to use
| Who | How |
|---|---|
| Gang boss | Press `J` at your gang location, or `/gangmenu` anywhere |
| Gang boss | Target a player → **Recruit to gang** |
| Anyone | Target a player → **Invite to posse** |
| Posse member | `/posse` to see riders and time left, or leave |
| Posse leader | `/posse` → **Lead** (pass leadership), **Kick**, **Disband** |
| Admin | `/removegang [id]` (permission `admin`) |

## Developer examples
```lua
-- server: who should share this job? posse first, then gang within 75 m, then on-duty coworkers within 75 m
local members, kind, groupId = exports['grumpy-groups']:GetMembers(source, 'auto', { radius = 75.0 })

-- server: just the posse (no distance check)
local riders = exports['grumpy-groups']:GetMembers(source, 'posse')

-- server: pay a gang
exports['grumpy-groups']:AddGangMoney('odriscoll', 250)

-- client: am I in a posse?
local inPosse = exports['grumpy-groups']:IsInPosse()
```

## Locales
`locales/en.json` is included. Add other languages (de, el, es, fr, ja, nl, pl, pt-br, ro) as `locales/<code>.json` with the same keys.
