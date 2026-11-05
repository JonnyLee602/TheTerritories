# grumpy-groups developer and server owner docs

## Contents
1. Architecture
2. Data formats
3. Server exports
4. Client exports
5. Events and callbacks
6. Integration examples
7. Persistence
8. Security model
9. Database
10. Server owner how-tos
11. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest. `provide 'rsg-gangmenu'` so scripts depending on it still start |
| `shared/config.lua` | All settings |
| `server/main.lua` | Core object, `Groups` helper table (notify, rate limit, distance, invite prompt), auto table creation |
| `server/gangs.lua` | Port of rsg-gangmenu: funds, stash, members, ranks, recruit, `/removegang` |
| `server/posse.lua` | Posse state, invites, leave/kick/lead/disband, lifetime tick, member blip feed, login/logout handling |
| `server/api.lua` | Public exports (`GetMembers`, `GetGroup`, posse + gang funds) and the `rsg-gangmenu` export aliases |
| `client/main.lua` | NUI bridge (`UI`), invite card client callback, target ped → server id |
| `client/gang.lua` | Gang location prompts and blips, `/gangmenu`, "Recruit to gang" target option, gang NUI callbacks |
| `client/posse.lua` | `/posse`, "Invite to posse" target option, posse member blips, client exports |
| `html/` | NUI: gang ledger, posse panel, confirm/amount dialog, invite card |
| `locales/en.json` | Every player-facing string, including all NUI text |

## 2. Data formats
**Posse (server memory)**
```lua
{
  id = 3,                         -- number, unique until restart
  leader = 'ABC12345',            -- citizenid
  members = { 'ABC12345', ... },  -- citizenids, join order (used for leader hand-off)
  names = { ABC12345 = 'Arthur Morgan' },
  createdAt = 1730800000, expiresAt = 1730807200, -- os.time(); expiresAt never changes
  warned = false, leaderOfflineSince = nil,
}
```
**Posse snapshot sent to clients** (`grumpy-groups:client:posseUpdate`, `getPosse` callback):
`{ id, isLeader, canInvite, remaining (seconds), max, members = { { citizenid, name, online, isLeader, isSelf } } }`. `nil` means not in a posse.

**State bag:** `Player(src).state.posse` = posse id or `nil` (replicated, so clients can read `LocalPlayer.state.posse`).

## 3. Server exports
| Export | Returns | Notes |
|---|---|---|
| `GetMembers(src, kind?, opts?)` | `members[], kind, groupId` | `kind`: `'auto'` (default), `'posse'`, `'gang'`, `'job'`. `opts.radius` (number or `false` = no check; default `Config.Members.Radius[kind]`), `opts.onDuty` (default `Config.Members.JobOnDuty`). Always includes `src`. Posses ignore both options. `'auto'` uses the first group the player **belongs to** (posse → gang → job), even if nobody else from it is nearby. With no group: `{ src }, nil, nil` |
| `GetGroup(src)` | table or `nil` | What `'auto'` would pick: `{ kind='posse', id, leader, expiresAt, size }`, `{ kind='gang', id, label, isBoss }` or `{ kind='job', id, label, onDuty }` |
| `GetPosse(src)` | table or `nil` | `{ id, leader, createdAt, expiresAt, members = { { citizenid, name } } }` |
| `IsInPosse(src)` | boolean | |
| `ArePosseMates(a, b)` | boolean | Both in the same posse |
| `DisbandPosse(id)` | boolean | Ends a posse (members told it was staff) |
| `GetGangAccount(gang)` | number | Gang funds |
| `AddGangMoney(gang, amount)` | boolean | Amount > 0 |
| `RemoveGangMoney(gang, amount)` | boolean | `false` if not enough funds |

`exports['rsg-gangmenu']:GetGangAccount / AddGangMoney / RemoveGangMoney` are aliased to the same functions.

Job membership uses the player's **active** job (`PlayerData.job`). An off-duty caller has no job group when `onDuty` is on.

## 4. Client exports
| Export | Returns |
|---|---|
| `IsInPosse()` | boolean (from the state bag) |
| `GetPosse()` | latest posse snapshot or `nil` |

## 5. Events and callbacks
**Server-local events (listen with `AddEventHandler`, server side):**
| Event | Args | When |
|---|---|---|
| `grumpy-groups:server:posseChanged` | `posseId` | Any member, leader or online change |
| `grumpy-groups:server:posseDisbanded` | `posseId, citizenids[], reasonKey` | Posse ended. `reasonKey`: `posse_expired`, `posse_disbanded_leader`, `posse_disbanded_small`, `posse_disbanded_empty`, `posse_disbanded_admin` |

Job scripts should **not** end a job when a posse disbands: snapshot the member list when the job starts.

**Net events (internal, all validated on the server):** `grumpy-groups:server:openGangStash`, `gangWithdraw`, `gangDeposit`, `gangSetGrade`, `gangFire`, `gangRecruit`, `posseInvite`, `posseLeave`, `posseKick`, `posseSetLeader`, `posseDisband`.
**Callbacks:** `grumpy-groups:server:getGangMenu`, `getGangMembers`, `getNearbyRecruits`, `getPosse`. Client callback: `grumpy-groups:client:confirmInvite`.
**Client events:** `grumpy-groups:client:posseUpdate`, `posseBlips`, `closeInvite`, `openGangLocation`.

## 6. Integration examples
```lua
-- grumpy-rumors style: start a job for whoever should share it
local members, kind = exports['grumpy-groups']:GetMembers(src, 'auto', { radius = 75.0 })
for _, id in ipairs(members) do
    TriggerClientEvent('my-job:client:start', id, jobData)
end

-- tidy up when a posse ends (only if your script tracks posse-wide state)
AddEventHandler('grumpy-groups:server:posseDisbanded', function(posseId, citizenids, reason)
    print(('posse %s ended (%s)'):format(posseId, reason))
end)

-- gang payout from a job
if kind == 'gang' then exports['grumpy-groups']:AddGangMoney(groupId, 100) end
```

## 7. Persistence
- **Gang funds** are kept in memory and written to `management_funds` on every change. Loaded at start.
- **Gang stashes** are rsg-inventory stashes `gang_<gangname>` (rsg-inventory saves them).
- **Gang membership and ranks** are rsg-core player data.
- **Posses are not saved.** They end on a server or resource restart. Members keep their place through a relog because membership is keyed by citizenid.

## 8. Security model
What this resource checks:
- Every net event nil-checks the player and rate-limits per action.
- Gang actions require a real gang boss (`gang.isboss` and the gang exists in rsg-core). Rank changes can't go above your own rank or touch someone who outranks you. You can't remove yourself.
- Stash and funds require being within `InteractDistance` of your gang's location (server-side coords). Amounts are sanitised (integer, 1..`MaxTransaction`, no NaN). Deposits check cash before `RemoveMoney`; withdrawals only pay after `RemoveGangMoney` succeeds.
- Recruit and posse invites check distance on the server, pending invites and membership, then **re-check everything after the invite is answered**.
- Posse kick/lead/disband require the current leader. Targets must be members.
- The client never sends a posse id, gang name, amount owner or member list. They come from server state.
- NUI callbacks only forward to these validated events.

What calling scripts must check themselves:
- `AddGangMoney` / `RemoveGangMoney` trust their caller: only call them from your own validated server code.
- `GetMembers` returns who belongs to the group, not who is eligible for your job. Check anything else your job needs (items, cooldowns, reputation).

## 9. Database
Uses the existing `management_funds` table (`type = 'gang'` rows). Created automatically when `Config.AutoDatabase = true`:
```sql
CREATE TABLE IF NOT EXISTS `management_funds` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
  PRIMARY KEY (`id`), UNIQUE KEY `job_name` (`job_name`), KEY `type` (`type`)
);
```
No other tables. Posses are memory-only.

## 10. Server owner how-tos
- **Move from rsg-gangmenu:** remove it, copy `Config.GangLocations` across, ensure grumpy-groups. Funds and stashes carry over.
- **Add a gang:** add it to `rsg-core/shared/gangs.lua` (with an `isboss` grade), add a `Config.GangLocations` entry with the same `id`, give a player the gang with `/setgang`.
- **Shorter or longer posses:** change `Config.Posse.MaxLifetime` (seconds) and `WarningTime`.
- **Let any member invite:** `Config.Posse.MembersCanInvite = true`.
- **Turn off posse blips:** `Config.Posse.Blips.enabled = false`.
- **Discord logs:** gang money, recruit and removal go through `rsg-log:server:CreateLog` on channel `grumpygroups`.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| "Only a gang boss can use this" | The player's gang grade needs `isboss = true` in `rsg-core/shared/gangs.lua` |
| Stash / funds missing from the menu | You opened it with `/gangmenu`. Use the prompt at the gang location |
| "You need to be at your gang's location" | `Config.GangLocations[].id` must match the gang name, and coords must be within `InteractDistance` |
| Both menus show / duplicate prompts | rsg-gangmenu is still running. Remove it |
| No "Invite to posse" option | rsg-target isn't started before grumpy-groups, or you're a member (not leader) with `MembersCanInvite = false` |
| Posse ended early | Fewer than 2 members left, or nobody online for `LeaderGrace` after the leader left |
| Warning arrives a few seconds late | Checks run every `TickInterval` seconds (15 by default). Lower it if needed |
