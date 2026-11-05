# grumpy-trader developer and server owner docs

Based on rsg-trader by RexShack. Sections marked *(new)* are grumpy-trader additions.

## Contents
1. Architecture
2. Data formats
3. Prices *(new rules)*
4. Laundering *(new)*
5. Callbacks, events and exports
6. Integration with grumpy-reputation
7. Persistence and database
8. Security model
9. Server owner how-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest |
| `shared/config.lua` | Settings, trader kinds, laundering, and the shared price helpers (`GetBuyPrice`, `GetSellPrice`, `GetLowestBuyPrice`) |
| `server/database.lua` | Creates/upgrades the tables, imports rsg-trader on the first start, fires `grumpy-trader:server:databaseReady` |
| `server/server.lua` | Trader cache, shop data, buy / sell / launder, standing prices, admin callbacks |
| `server/webhooks.lua`, `server/webhook_config.lua` | Discord logging (server only) |
| `client/client.lua` | Blips, NUI bridge, shop and admin panel |
| `client/npcs.lua` | Ped spawning by distance, rsg-target option |
| `html/` | Shop (Buy / Sell / Launder) and admin panel |

Traders are kept in memory on the server and sent to clients through `GlobalState.grumpyTraders` (id, name, model,
position, heading, blip, kind). Laundering settings stay on the server.

## 2. Data formats
Trader (server): `{ traderid, tradername, npcmodel, x, y, z, heading, showblip, kind = 'legal'|'illegal', launder = bool, launder_cut = number|nil }`

Item row: `{ traderid, item, stock, lowstock, highstock, baseprice, mode = 'both'|'buy'|'sell' }`
- `buy` = players can only buy it, `sell` = players can only sell it.

## 3. Prices
1. Stock price (rsg-trader): `base × (1.2 if stock ≤ low, 0.9 if stock ≥ high, else 1.0)`, clamped to 0.7–1.5 × base.
   Sellers get 0.8 × that.
2. *(new)* Standing (grumpy-reputation running and `Config.Standing.Enabled`): buy price × the player's `buy` multiplier,
   sell price × their `sell` multiplier, for the trader's market (`legal` or `underground`).
3. *(new)* Loop cap: if any trader sells the item (`mode ~= 'sell'`), a sale pays at most
   `lowest possible buy price of that item anywhere × GetArbitrageFactor()` per unit. With the defaults that's
   `base × 0.9 × 0.7125` ≈ 64% of the cheapest base price. Sell-only items are never capped.
4. Prices are worked out on the server for each player when the window opens and again on every trade.
   The client only shows them.

## 4. Laundering *(new)*
- Available at traders with `kind = 'illegal'` and `launder = true`.
- `clean = dirty × (1 − cut / 100)`. `cut = trader.launder_cut or Config.Laundering.DefaultCut`, times the player's
  underground buy multiplier when `StandingScales` is on, clamped to `MinCut`–`MaxCut`.
- Limits per real day (server date): `PlayerDailyLimit` per character per fence and `TraderDailyLimit` per fence
  across everyone. Usage is stored in `grumpy_trader_laundering`; rows older than 7 days are removed on start.
- Order of operations: limits checked → bloodmoney removed → cash added (if that fails the bloodmoney is returned)
  → usage row written. One wash per fence at a time (in-memory lock), so two players can't both use the last of
  the daily limit.
- Money reason: `grumpy-trader-launder` for both the removal and the cash.

## 5. Callbacks, events and exports
| Name | Type | Args → returns |
|---|---|---|
| `grumpy-trader:server:traderdata` | callback | `traderid` → `{ ok, msg?, items, kind, payWith, payOut, money, buyMult, launder? }` |
| `grumpy-trader:server:buy` / `:sell` | callback | `traderid, item, amount` → `{ ok, msg }` |
| `grumpy-trader:server:launder` *(new)* | callback | `traderid, amount` → `{ ok, msg }` |
| `grumpy-trader:server:admin:*` | callbacks | admin only: `isAdmin`, `traders`, `saveTrader`, `deleteTrader`, `items`, `saveItem`, `deleteItem` |
| `grumpy-trader:client:openAdmin` | client event | opened by `/traderadmin` |
| `grumpy-trader:server:databaseReady` | server event | tables ready, traders load |
| `SendWebhook(event, src, title, fields, description)` | server export | Discord log through this resource's webhooks |

Money reasons (for `RSGCore:Server:OnMoneyChange` listeners):

| Reason | When |
|---|---|
| `grumpy-trader-buy` / `grumpy-trader-sell` | legal trader purchase / sale |
| `grumpy-trader-fence-buy` / `grumpy-trader-fence` | illegal trader purchase / sale |
| `grumpy-trader-launder` | laundering (bloodmoney out, cash in) |
| `grumpy-trader-refund` | refunds after a failed trade |

## 6. Integration with grumpy-reputation
- Prices: `exports['grumpy-reputation']:GetPriceMultiplier(src, market, side)` and `GetArbitrageFactor()`.
- Standing: grumpy-reputation's `Config.MoneyHooks` maps `grumpy-trader-sell` → `trader_sale` (legit) and
  `grumpy-trader-fence` → `fence_sale` (outlaw). Payouts under $1 (`MinHookAmount`) give no standing.
- **Don't** add grumpy-trader reasons to grumpy-reputation's `Config.Pricing.SaleHooks`: prices would be adjusted twice.
- Without grumpy-reputation everything works at stock prices, and the laundering cut is the flat configured value.

## 7. Persistence and database
| Table | Purpose |
|---|---|
| `grumpy_trader` | Item listings per trader (unique `traderid + item`, indexed by `item` for the loop cap) |
| `grumpy_trader_npcs` | Traders, with `kind`, `launder`, `launder_cut` |
| `grumpy_trader_laundering` | Dirty dollars washed per trader, character and day |

rsg-trader's tables (`rsg_trader`, `rsg_trader_npcs`) are only read, once, for the import. They are never changed.

## 8. Security model
- Everything is decided on the server: prices, money type, distance (`InteractDistance`), cooldown, stock (atomic
  `UPDATE ... WHERE stock >= ?`), item mode, the lawman check, and laundering limits.
- The client sends only trader id, item and amount (and a dirty amount for laundering). All are type and range checked.
  Malformed requests and trades away from the trader are logged to the `security` webhook.
- Payment comes from one money type, checked with `GetMoney` and removed with `RemoveMoney` (result checked). Failed
  item adds refund the same money type and restore the stock.
- Admin callbacks check the `admin` permission on the server; positions are always taken from the admin's ped on the server.
- Players never see base prices or other traders' laundering settings.

## 9. Server owner how-tos
- **Turn an imported trader into a fence:** `/traderadmin` → Edit → Kind: Illegal. Untick the blip if it shouldn't be on the map.
- **Set up laundering:** on an illegal trader tick **Launders dirty money**; leave the cut blank for the default or enter 5–90.
- **Stolen goods only the fence buys:** add the item to the fence with **Players sell only** and a base price.
- **Make dirty money harder to wash:** lower `PlayerDailyLimit` / `TraderDailyLimit`, or raise `DefaultCut`.
- **Let lawmen use fences (undercover RP):** `Config.Kinds.illegal.blockLaw = false`.
- **Pay fences in clean cash instead:** `Config.Kinds.illegal.payOut = 'cash'` (not recommended by the doctrine).

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| Traders spawn twice | rsg-trader is still running. Remove `ensure rsg-trader` |
| No traders after switching | The import only runs when `grumpy_trader_npcs` is created. Run the copy queries at the bottom of `install.sql` |
| Prices ignore standing | grumpy-reputation isn't started, `Config.Standing.Enabled = false`, or the player's standing is within ±199 (neutral) |
| An item sells for much less than before | It's also sold by some trader, so the loop cap applies. Set it to **Players sell only** if traders shouldn't sell it |
| Laundering tab missing | The trader isn't illegal or **Launders dirty money** isn't ticked |
| "I've washed all I can today" | The fence's `TraderDailyLimit` is used up for today |
| Lawman can't open a fence | Intended: on-duty `leo` jobs are blocked (`blockLaw`) |
