# grumpy-reputation developer and server owner docs

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
| `fxmanifest.lua` | Manifest |
| `shared/config.lua` | All settings: standing range, tiers, actions, money hooks, decay, panel |
| `shared/tiers.lua` | `Rep.Clamp`, `Rep.TierFor`, `Rep.TierRange` (client + server) |
| `shared/pricing.lua` | `Rep.PriceMultiplier`, `Rep.MarketForShop`, `Rep.ShopMultipliers`, `Rep.ArbitrageFactor` (client + server) |
| `server/pricing.lua` | Pricing exports and the sale-hook payout adjustment |
| `integrations/rsg-stores.md` | Local rsg-stores patch for honor/infamy shop prices |
| `server/main.lua` | Standing storage, the single `change()` path, actions with daily caps, decay, exports |
| `server/hooks.lua` | `RSGCore:Server:OnMoneyChange` hook, `/rep` panel callback, `/setstanding` |
| `client/main.lua` | `/rep`, NUI bridge, client exports |
| `html/` | `/rep` panel |
| `locales/en.json` | All text, including tier names/descriptions and rep labels (`rep_<key>`) |

## 2. Data formats
**Player metadata (rsg-core, saved with the character):**
```lua
metadata.rep.standing = -240            -- the standing (rsg-core rep table, next to hunting/fishing/...)
metadata.grumpyrep = {
  last = 1730800000,                    -- os.time() of the last real change (drives decay)
  decayedAt = nil,                      -- how far decay has already been applied
  day = '2026-11-05',                   -- day the caps below belong to
  used = { drug_sale = 12 },            -- standing points used per capped action today
}
```
Don't use rsg-core's `Player.Functions.RemoveRep('standing', …)`: it can't go below 0. Use this resource's exports.

**Action:** `Config.Actions[name] = { amount = number, dailyCap = number|nil, towardZero = bool|nil }`.
- Normal action: `amount` is added (positive = legit, negative = outlaw).
- `towardZero = true`: a penalty. Standing moves toward 0 by `abs(amount)` and stops at 0, so an outlaw becomes less outlaw and a legit player less legit. It can never be used to gain rep.
**Money hook:** `{ reason = 'exact-reason' | pattern = 'lua%-pattern', action = 'name' }`.
**Tier:** `{ name, min }`, highest first. A standing belongs to the first tier whose `min` it reaches.

## 3. Server exports
| Export | Returns | Notes |
|---|---|---|
| `Action(src, name, mult?)` | applied delta | Configured action with its daily cap. `mult` scales the amount (e.g. 2 for a big job) |
| `ActionByCitizenId(citizenid, name, mult?, queueOnly?)` | boolean | Online character: applied now. Offline, or `queueOnly = true`: saved and applied on their next login. Use `queueOnly` from `playerDropped`, where rsg-core may already have saved the character |
| `Adjust(src, amount, reason?)` | applied delta | Raw change, **no cap**. Positive = legit |
| `GetStanding(src)` | number or nil | |
| `GetTier(src)` | tier name or nil | |
| `InRange(src, min?, max?)` | boolean | `min <= standing <= max`, either bound optional |
| `SetStanding(src, value, reason?)` | boolean | Clamped to the range |
| `GetAllRep(src)` | table | Every rep key → value, standing included |
| `TierFor(value)` | tier name | |
| `TierRange(name)` | min, max | Standing range of a tier |
| `GetPriceMultiplier(src, market, side)` | number | `market` = `'legal'` / `'underground'`, `side` = `'buy'` (what they pay) / `'sell'` (what they're paid). 1.0 if not loaded |
| `GetShopMultipliers(src, shopName)` | buy, sell, market | For an rsg-stores shop name, using `Config.Pricing.Shops` |
| `GetMarketForShop(shopName)` | `'legal'` / `'underground'` / `'none'` | |
| `GetArbitrageFactor()` | number | Lowest buy multiplier x `ArbitrageMargin`; cap a sell-back at `cheapest price x this` |

Exports that take `src` work for online players only. Use `ActionByCitizenId` for characters who might be offline.

## 4. Client exports
| Export | Returns |
|---|---|
| `GetStanding()` | number (from synced player data) |
| `GetTier()` | tier name |
| `GetPriceMultiplier(market, side)` | number (display only) |
| `GetShopMultipliers(shopName)` | buy, sell, market (display only) |
| `GetArbitrageFactor()` | number, same as the server export (rsg-stores shows the capped sell-back price with it) |
| `ShopGreeting(title, buyMult)` | shows "They know your name here: 20% off" / "prices 20% higher" |

Client values are for display. Make decisions on the server.

## 5. Events and callbacks
| Event | Side | Args |
|---|---|---|
| `grumpy-reputation:server:changed` | server-local (`AddEventHandler`) | `src, old, new, reason, oldTier, newTier`. `reason` is the action name, `'decay'`, `'admin'` or your `Adjust` reason |
| `grumpy-reputation:client:changed` | client | `new, newTier` |

Callback: `grumpy-reputation:server:getPanel` (panel data for the caller only).

## 6. Integration examples
**Your own illegal or legal job:** call the action where the server pays out.
```lua
if Player.Functions.AddMoney('cash', price, 'grumpy-chopshop') then
    exports['grumpy-reputation']:Action(src, 'chop_wagon')
end
```
Or give the payout a reason and add a money hook in config, with no code change in the job:
```lua
{ reason = 'grumpy-chopshop', action = 'chop_wagon' },
```

**Law hooks (local edits to RSG resources).** RSG's MDT and prison fire no server events, so add one line where they act:
```lua
-- rsg-mdt/server/charges.lua, after each SetMetaData('criminalrecord', ...) on targetPlayer
exports['grumpy-reputation']:Action(targetPlayer.PlayerData.source, 'charged')

-- rsg-prison: where the player is sent to jail
exports['grumpy-reputation']:Action(src, 'jailed')

-- a witness script: only when the crime itself SUCCEEDED and was reported (never on failure)
exports['grumpy-reputation']:Action(src, 'crime_reported')

-- a job that failed (robbery fell apart, caught by an NPC): penalty toward 0
exports['grumpy-reputation']:Action(src, 'robbery_failed')
```
Keep these as local patches and re-apply them after updating those resources.

**Gate something on standing:**
```lua
local tier = exports['grumpy-reputation']:GetTier(src)
if tier == 'outlaw' or tier == 'notorious' then ... end
-- or by number
if exports['grumpy-reputation']:InRange(src, 200) then ... end -- respected or better
```

**React to changes:**
```lua
AddEventHandler('grumpy-reputation:server:changed', function(src, old, new, reason, oldTier, newTier)
    if newTier == 'notorious' and oldTier ~= 'notorious' then
        -- e.g. put up a wanted poster
    end
end)
```

## 7. Persistence
Everything is in rsg-core player metadata and saves with the character. Actions queued for offline characters are kept in `grumpy_reputation_pending` until that character's next login. Daily caps are saved too, so relogging or a restart doesn't reset them. Caps reset when the server's date changes (`os.date('%Y-%m-%d')`). Decay is worked out when the character loads, then hourly while online.

## 8. Security model
- No net event changes standing. The client can only ask for its own panel data.
- Automatic changes come from `RSGCore:Server:OnMoneyChange`, which rsg-core fires on the server after a real payout. Clients can't fake it.
- Every change is clamped to the range. Configured actions are capped per day per character.
- `Adjust` and `SetStanding` have **no cap**: only call them from validated server code.
- Callers must validate their own jobs (distance, items, cooldowns) before paying out or calling `Action`. An unvalidated payout gives standing as well as money.
- **Prices:** multipliers are worked out on the server from the stored standing at the moment of the sale. The client exports are display only. Sale-hook adjustments use the same money type as the original payout (bloodmoney stays bloodmoney), never take more than the player holds, and use their own reason, which the rep hooks ignore (no standing from price adjustments).
- **No money loops:** the rsg-stores patch caps any sell-back at `cheapest store price x GetArbitrageFactor()` (rsg-stores keeps the cap at `Config.SellCapFactor` when grumpy-reputation is stopped). Resources that buy and sell the same goods (rsg-trader) get `maxMult = 1.0` in `SaleHooks`.

## 9. Database
Standing lives in `players.metadata` through rsg-core. One extra table queues actions for offline characters:
```sql
CREATE TABLE IF NOT EXISTS `grumpy_reputation_pending` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `action` VARCHAR(50) NOT NULL,
  `mult` FLOAT NOT NULL DEFAULT 1,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `citizenid` (`citizenid`)
);
```
Rows are applied (after decay) and deleted when the character loads.

## 10. Server owner how-tos
- **Hook another job:** find its `AddMoney(..., 'reason')`, add `{ reason = 'reason', action = 'some_action' }` to `Config.MoneyHooks` and the action to `Config.Actions`.
- **Change tier thresholds:** edit `Config.Tiers` (highest first). Add `tier_<name>` and `tier_desc_<name>` to locales for new tiers.
- **Turn off decay:** `Config.Decay.enabled = false`.
- **Test:** `Config.NotifyEveryChange = true`, then `/setstanding [id] -500` and `/rep`.
- **Rename a rep in the panel:** add `"rep_<key>": "Label"` to the locale.
- **Make a fence / black-market shop:** create it with `/createshop` in rsg-stores, then add its shop name to `Config.Pricing.Shops` as `'underground'`. Outlaws now get the good prices there.
- **Price a new seller by standing:** if it pays with `AddMoney(type, amount, 'its-reason')`, add `{ reason = 'its-reason', market = 'legal' }` to `Config.Pricing.SaleHooks`. If it also sells the same goods, add `maxMult = 1.0`.
- **Test prices:** `/setstanding [id] 1000`, open a general store (25% off), sell a pelt at the butcher (+50%); then `-1000` and repeat.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| Job pays but standing doesn't move | The payout reason doesn't match a hook. Turn on `Config.Debug`, check the reason in the job's `AddMoney` call, and add it to `Config.MoneyHooks` |
| Standing stops moving from one job | That action hit its `dailyCap` for today |
| A rep shows as a raw key in `/rep` | Add `"rep_<key>"` to the locale |
| Standing drifted toward 0 | Decay: no change for `Config.Decay.afterDays` days |
| Standing stuck at 0 after using `RemoveRep` | rsg-core's `RemoveRep` can't go negative. Use `Action` / `Adjust` |
| Shop prices don't change with standing | Apply `integrations/rsg-stores.md`, restart rsg-stores after grumpy-reputation, and check the shop isn't `'none'` or matched by `ExcludePatterns`. Neutral standing (±199) pays normal prices |
| A seller (butcher, fishmonger…) ignores standing | Its payout reason isn't in `Config.Pricing.SaleHooks`. Turn on `Config.Debug` to see the reason |
| Selling store goods back pays less than 80% | Intended: the sell-back cap (`ArbitrageMargin`) stops buy-low/sell-high loops while honor discounts exist |
