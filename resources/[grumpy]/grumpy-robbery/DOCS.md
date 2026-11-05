# grumpy-robbery developer and server owner docs

## Contents
1. Architecture
2. How the rsg-stores clerk is used
3. Data formats
4. Server exports
5. Events
6. Persistence
7. Security model
8. Database
9. Server owner how-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | All settings |
| `server/main.lua` | `GR` helpers: store cache (rsg-stores rows + our settings + shop item lists), save, sync to clients, law alert, posse lookup |
| `server/robbery.lua` | Register hold-ups (start, server watch, finish, payout, cooldowns) and safes |
| `server/shoplift.lua` | Shelf thefts: item pick, timing, catch roll |
| `server/admin.lua` | `/robberyadmin` server side (toggle, shelves, safe) |
| `client/main.lua` | `GRC` helpers: store list, finding the clerk ped, clerk reactions, NUI bridge |
| `client/robbery.lua` | Aim detection, robbery progress, safe zones/props, safe cracking |
| `client/shoplift.lua` | Shelf target zones and the pocketing progress bar |
| `client/admin.lua` | Admin panel callbacks, "my position", rsg-gizmo safe placement, teleport |
| `html/` | Admin panel |

## 2. How the rsg-stores clerk is used
rsg-stores spawns each NPC shopkeeper as a **local ped** on every client, at the saved coords (snapped to the ground) with the saved model (`rsg_shops_npcs`). grumpy-robbery:
1. Reads the same rows on the server (`store_kind = 'npc'`), so every store has an id, model and coords.
2. On each client, finds the clerk by **model** within `Config.ClerkFindRadius` (2D) of those coords (`GetGamePool('CPed')`).
3. When a robbery starts, the server broadcasts `clerkState(storeId, 'robbed')`. Every client within 80 m plays `TASK_HANDS_UP` on its own copy and re-applies it if rsg-stores respawns the ped. Afterwards it restores `Config.ClerkScenario`.

rsg-stores is not changed. Its **Open Store** target option stays available during a robbery (another resource's options can't be hidden from outside).

## 3. Data formats
Client store list (`grumpy-robbery:client:stores`):
`{ id, label, model, x, y, z, h, enabled, shelves = { {x,y,z} }, safe = { x, y, z, h, prop, rx, ry, rz } | nil }`

Clerk states: `robbed` (hands up, `data.robber`, `data.duration` ms), `cower` (hands up after success, `data.duration` s), `shout` (turns to `data.thief`), `idle`.

## 4. Server exports
| Export | Returns |
|---|---|
| `IsBeingRobbed(storeId)` | boolean |
| `GetCooldown(storeId)` | seconds until the register can be robbed again |

`storeId` is `rsg_shops_npcs.id`.

## 5. Events
| Event (server-local) | Args |
|---|---|
| `grumpy-robbery:server:robbed` | `src, storeId, cash` |
| `grumpy-robbery:server:safeCracked` | `src, storeId, cash` |
| `grumpy-robbery:server:shoplifted` | `src, storeId, item` |
| `grumpy-robbery:server:shopliftCaught` | `src, storeId` |

**grumpy-law (optional):** hold-ups call `OpenIncident(src, { crime = 'store_robbery', victimReports = Config.Robbery.AlertLaw, hot = Duration + 15 })` and `MarkSucceeded` on payout. Caught shoplifters get `{ crime = 'shoplifting', victimReports = Config.Shoplift.AlertLaw, succeeded = false }`, and clean steals get `{ crime = 'shoplifting', succeeded = true }` when `AmbientWitnesses` is on. Without grumpy-law, `GR.AlertLaw` sends the rsg-lawman alert directly (after `AlertDelay` for robberies).

**Clerk lookup:** each store's clerk handle is cached on the client and re-checked (exists, model, within `ClerkFindRadius`). The ped pool is only searched when the handle is gone, and a failed search is not repeated for 1 s.

Payout reasons for grumpy-reputation money hooks: `grumpy-robbery-store`, `grumpy-robbery-safe`. Shoplifted items use the inventory reason `grumpy-robbery-shoplift`.

**Reputation rules:** outlaw standing is only gained on success (the two payout hooks). A clean shoplift changes nothing (unwitnessed). A failed robbery calls `robbery_failed` and being caught shoplifting calls `caught_shoplifting`. Both are grumpy-reputation `towardZero` penalties that shrink standing toward 0 and never past it, so failing can't be farmed for rep. Disconnecting, logging out or switching character mid-robbery still fails it, and the penalty is queued against that character (`ActionByCitizenId(..., queueOnly = true)`) and applied at their next login. A server restart during a robbery clears it with no penalty (active robberies are in memory).

## 6. Persistence
- `grumpy_robbery_stores` holds per-store settings (robbable, shelves, safe).
- Stores and shop item lists are re-read from rsg-stores every `Config.StoreRefresh` seconds and on **Reload** in the admin menu.
- Cooldowns, active robberies and safe windows are in memory. A restart clears them.

## 7. Security model
**Hold-up.** The client only says "I'm aiming at store X's clerk" and "I lowered my gun". The server checks:
- the store exists and can be robbed, nobody is already robbing it, and the player isn't already robbing another;
- the player is alive and within `AimDistance + 2` of the clerk, holding a weapon (`GetSelectedPedWeapon` isn't unarmed);
- the player isn't on-duty law, plus the cooldowns and minimum lawmen.

The server then times the robbery itself: once a second it checks the robber is still connected, on the same character, alive and within `LeaveDistance`. The client can end a robbery early but can't finish or speed one up. The payout comes from config.

**Safe.** Only open after a successful hold-up, for the robber and the posse members **at that moment**, for `Window` seconds. Checks: distance to the safe, `MaxAttempts`, one cracker at a time, the required item, and a minimum attempt time. Without rsg-lockpick the server rolls the result itself. With the minigame the client reports the result (limited by attempts, timing and the window).

**Shoplifting.** The server picks the item from that store's own list (config price cap, blacklist, unique items and weapons refused), times the attempt (`Time - 0.5 s`), re-checks distance and rolls the catch. The client sends only whether the clerk has line of sight. A cheater can report "not seen", but the base chance and witness chance (counted on the server) still apply. Cooldowns are per character per store.

**Admin.** Every admin event re-checks `Config.AdminPermission`. Points must be within `MaxPointDistance` of the clerk and 15 m of the admin. Safe props go through `rsg-gizmo:IsPlacementValid` / `SanitiseRotation`.

## 8. Database
```sql
CREATE TABLE IF NOT EXISTS `grumpy_robbery_stores` (
  `npc_id` INT NOT NULL,            -- rsg_shops_npcs.id
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `shelves` LONGTEXT NULL,          -- JSON [{x,y,z}] (max 4)
  `safe` LONGTEXT NULL,             -- JSON {x,y,z,h,prop,rx,ry,rz}
  PRIMARY KEY (`npc_id`)
);
```
Read-only use of rsg-stores tables: `rsg_shops_npcs` (id, name, shop_label, model, x, y, z, h, store_kind) and `rsg_shops_items` (npc_id, item_name, price, stock).

## 9. Server owner how-tos
- **Set up a store:** `/robberyadmin` → pick the store → stand at a shelf → **Add shelf at my position** (up to 4) → stand at the back-room safe → **Safe at my position**, or **Place safe prop**.
- **Make a store safe from robbery but keep shoplifting:** toggle **Register can be robbed** off. Shelves still work.
- **Require law in town:** `Config.Robbery.MinLawmen = 2`.
- **Require a tool for safes:** `Config.Safe.RequiredItem = 'your_item'` (it must exist in your items).
- **New shop created in `/createshop`:** press **Reload** in `/robberyadmin`, or wait for `StoreRefresh`.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| Aiming at the clerk does nothing | The store is toggled off, on cooldown, or you're too far (`AimDistance`). With `Config.Debug`, check that the clerk ped's model matches the rsg-stores model, and widen `ClerkFindRadius` if rsg-stores' ground snap moved it |
| Clerk doesn't raise hands for other players | They must be within 80 m and have the store's ped spawned (rsg-stores `DistanceSpawn` is 20 m) |
| "No NPC shops found" | rsg-stores has no `store_kind = 'npc'` shops, or its tables are missing |
| "Nothing worth taking here" | No item in that shop is within `MaxPrice` with unlimited stock. Raise `MaxPrice` or set `AllowLimitedStock = true` |
| Safe never opens | The safe opens only after a successful register robbery, for the robber's posse at that moment, for `Window` seconds |
| Law gets no alert | rsg-lawman isn't running (on-duty law get a plain notification instead), or `AlertLaw = false` |
