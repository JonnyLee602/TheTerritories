# grumpy-robbery

Store hold-ups, back-room safes and shoplifting for **rsg-stores NPC shops**. Point a gun at the clerk and they raise their hands. Keep them covered while the register is emptied, then crack the safe with your posse. Or quietly pocket something from the shelves and hope nobody saw. Admins set everything up in game.

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-stores`, `rsg-gizmo` (admin placement), `oxmysql`
**Optional:** `grumpy-law` (witnesses, reports, heat), `rsg-lawman` (alerts), `rsg-lockpick` (safe minigame), `grumpy-groups` (posse shares the safe), `grumpy-reputation` (standing)

## Features
- **Uses rsg-stores as it is.** Stores are read from rsg-stores' `rsg_shops_npcs` table (NPC shops only, never player-owned stores). The clerk is the ped rsg-stores already spawns: grumpy-robbery finds it by model and position. **rsg-stores is not modified.**
- **Register hold-up**
  - Aim a gun at the clerk to start. The clerk raises their hands (`TASK_HANDS_UP`), and every nearby player sees it.
  - Keep them covered for 30 s. Lowering your gun for more than 3 s, walking away or dying fails the robbery.
  - Payout is `math.random(CashMin, CashMax)` in blood money.
  - Per-store cooldown, optional global cooldown, and an rsg-lawman alert to on-duty law.
  - **Minimum lawmen** setting, **off by default**. On-duty lawmen can't rob.
- **Safe (optional per store)**
  - After a successful hold-up, the robber **and their posse** have 5 minutes to crack the safe.
  - Uses the rsg-lockpick minigame if it's running, otherwise a progress bar with a server-rolled chance.
  - Limited attempts, an optional required tool (with break chance), cash plus optional item rewards.
  - The safe can be an existing safe in the interior (just a point) or a `p_gen_safe01` prop placed with rsg-gizmo.
- **Shoplifting (always available, no lawmen needed)**
  - Up to 4 shelf points per store. Target one and choose **Pocket something**.
  - The server picks a cheap item **from that store's own item list** (price cap, blacklist, unlimited-stock items only by default). rsg-stores stock is never changed.
  - Catch chance is rolled on the server: a base chance, plus more if the clerk can see you, plus more for each other player nearby who isn't in your posse.
  - Getting caught: the clerk turns on you, the law can be alerted, your reputation shrinks toward 0 (`caught_shoplifting`), and a longer cooldown applies.
- **Admin menu `/robberyadmin`:** lists every rsg-stores NPC shop by distance. Per store you can:
  - Toggle whether it can be robbed.
  - Add up to 4 shelf points with rsg-gizmo: aim a small marker at the shelf itself (you can walk while placing). Remove them or teleport to them.
  - Mark an existing safe (aim the marker at it) or place a safe prop, both with rsg-gizmo. Remove it or teleport to it.
  - Reload the store list (picks up shops just made in `/createshop`).
- **With grumpy-law:** a hold-up opens a `store_robbery` incident. The clerk reports it, and NPCs nearby can witness it. Getting caught shoplifting opens a `shoplifting` incident the clerk reports. A clean steal can still be seen by NPCs nearby (`AmbientWitnesses`). After a report, the robber is "hot" for 10 minutes; escaping after a **successful** crime adds outlaw standing. Without grumpy-law, the clerk alerts rsg-lawman directly.
- **Reputation:** hold-ups and safes are hooked by payout reason (`grumpy-robbery-store`, `grumpy-robbery-safe`). Outlaw standing is only gained by succeeding. A failed robbery (`robbery_failed`) or being caught shoplifting (`caught_shoplifting`) shrinks the player's reputation toward 0 instead, so failing never makes anyone a "better" criminal.

## Installation
1. Put `grumpy-robbery` in your resources and add after rsg-stores (and the optional resources):
   ```
   ensure grumpy-robbery
   ```
2. The `grumpy_robbery_stores` table is created automatically (or set `Config.AutoDatabase = false` and import `install.sql`).
3. In game, run `/robberyadmin`, pick a store, add shelf points and (optionally) a safe.
4. If you use grumpy-reputation, update it too: its config now includes the `store_robbery` and `safe_crack` hooks.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.StoreRefresh` | `300` | Seconds between re-reading rsg-stores' NPC shops |
| `Config.ClerkScenario` | `WORLD_HUMAN_STAND_IMPATIENT` | Restored on the clerk afterwards (rsg-stores' default) |
| `Config.Robbery.AimDistance` / `LeaveDistance` | `8.0` / `12.0` | Start range / fail range (server-checked) |
| `Config.Robbery.Duration` / `Grace` | `30` / `3` | Seconds to hold / seconds you may lower the gun |
| `Config.Robbery.MoneyType`, `CashMin`, `CashMax` | `bloodmoney`, `15`, `45` | Payout |
| `Config.Robbery.StoreCooldown` / `FailCooldown` / `GlobalCooldown` | `3600` / `600` / `0` | Seconds |
| `Config.Robbery.MinLawmen` | `0` (off) | On-duty law (`job.type == 'leo'`) needed to start |
| `Config.Robbery.BlockLawmen`, `AlertLaw`, `AlertDelay` | `true`, `true`, `5` | |
| `Config.Safe.Window` / `MaxAttempts` | `300` / `3` | |
| `Config.Safe.RequiredItem` / `BreakChance` | `nil` / `30` | Tool needed to crack, chance it breaks on a fail |
| `Config.Safe.FallbackChance` / `CrackTime` | `50` / `15000` | Used when rsg-lockpick isn't running |
| `Config.Safe.CashMin` / `CashMax` / `Items` | `50` / `150` / `{}` | Payout |
| `Config.Safe.PropModel` | `p_gen_safe01` | Safe prop |
| `Config.Shoplift.MaxShelves` | `4` | Shelf points per store |
| `Config.Shoplift.Time` / `Cooldown` / `CaughtCooldown` | `4000` / `180` / `900` | |
| `Config.Shoplift.MaxPrice` / `AllowLimitedStock` / `Blacklist` | `1.0` / `false` / money items | What can be taken |
| `Config.Shoplift.BaseChance` / `ClerkSees` / `PerWitness` / `MaxChance` | `15` / `45` / `10` / `90` | Catch chance (%) |
| `Config.AdminCommand` / `AdminPermission` | `robberyadmin` / `admin` | |
| `Config.MaxPointDistance` | `40.0` | Shelves and safes must be this close to the clerk |
| `Config.PointMarker` / `PlaceDistance` | `p_bottlebeer01x` / `12.0` | Marker prop and range for placing shelf and safe points with rsg-gizmo |

## How to use
| Who | How |
|---|---|
| Robber | Aim a gun at a store clerk and keep it on them until the register is empty |
| Robber + posse | After the hold-up, target the safe → **Crack the safe** |
| Anyone | Target a shelf point → **Pocket something** |
| Admin | `/robberyadmin` |

## Developer examples
```lua
-- server: react to robberies (e.g. a wanted poster)
AddEventHandler('grumpy-robbery:server:robbed', function(src, storeId, cash) end)
AddEventHandler('grumpy-robbery:server:shopliftCaught', function(src, storeId) end)

-- server: is a store being robbed right now?
local busy = exports['grumpy-robbery']:IsBeingRobbed(storeId)
```

## Locales
`locales/en.json` is included. Add other languages (de, el, es, fr, ja, nl, pl, pt-br, ro) as `locales/<code>.json` with the same keys.
