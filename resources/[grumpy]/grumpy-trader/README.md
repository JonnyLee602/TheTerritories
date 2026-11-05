# grumpy-trader

Dynamic-price NPC traders where the admin picks, per trader, whether it is a **legal trader** or an **illegal
fence**. Fences pay in dirty money, trade with outlaws on better terms, keep away from on-duty lawmen, and can
**launder** dirty money into clean cash for a cut. One resource replaces both rsg-trader and a separate fence script.

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

Based on **rsg-trader by RexShack** (Rexshack-RedM): NPC spawning, stock-based pricing, the trade UI and the admin
panel are his work. This is a community modification. It is **not** made or supported by the RSG authors, so please
don't ask them for help with it.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`
**Optional:** `grumpy-reputation` (honor/infamy prices, laundering cut by standing, standing from sales)

## Features
- Everything rsg-trader does: NPC traders by distance with fade-in, an rsg-target option, a Buy / Sell window with stock bars, prices that move with stock, `/traderadmin` to place and edit traders and stock, map blips, draggable panels, Discord webhooks.
- **Legal or illegal, per trader.** Choose in the trader form in `/traderadmin`.

  | | Legal trader | Illegal trader (fence) |
  |---|---|---|
  | Pays sellers | clean cash | **dirty money** (bloodmoney) |
  | Takes payment in | cash | dirty money first, else cash |
  | Prices by standing (grumpy-reputation) | legal market: honorable players get the best deals | underground market: outlaws get the best deals |
  | On-duty lawmen | welcome | turned away |
  | Map blip by default | on | off |
  | Target label | "Speak with the Trader" | "Talk business" |
  | Standing from selling | legit (`trader_sale`) | outlaw (`fence_sale`) |

- **Item trade mode per item:** players buy and sell, buy only, or sell only. List goods players gather or steal (pelts, jewellery) as **sell only** so they get the full honor or infamy bonus.
- **Money laundering** at fences that have it switched on. Players get a **Launder** tab:
  - Hand over dirty money and get clean cash back, minus the fence's cut (default 30%, adjustable per fence).
  - With grumpy-reputation, outlaws get a smaller cut and honorable players a bigger one (×0.75 to ×1.5).
  - Daily limits per character and per fence (default $100 and $500) keep big piles of dirty money hard to wash.
- **No money loops.** With honor discounts, selling something back could pay more than buying it. A sale never pays more per unit than the cheapest discounted price that item can be bought for at any trader.
- **First start imports rsg-trader**: traders and stock come over automatically as legal traders.

## Installation
1. Put `grumpy-trader` in your resources folder.
2. In `server.cfg`, **remove `ensure rsg-trader`** and add, after rsg-core, rsg-inventory, rsg-target and oxmysql (and grumpy-reputation if you use it):
   ```
   ensure grumpy-trader
   ```
3. Database: tables are created on start (`Config.AutoDatabase = true`). On the very first start your rsg-trader traders and stock are copied over (`Config.ImportRsgTrader`). With `Config.AutoDatabase = false`, import `install.sql` (the copy queries are at the bottom).
4. In game, `/traderadmin`: set existing traders' kind, add fences, and switch items players only sell to **Players sell only**.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` / `ImportRsgTrader` | `true` / `true` | Create tables on start / copy rsg-trader's data on the first start |
| `Config.MaxBuyAmount` / `MaxSellAmount` | `10` / `10` | Items per transaction |
| `Config.InteractDistance` / `Cooldown` | `5.0` / `2000` | Server-checked distance (m) / ms between transactions |
| `Config.Pricing` | low ×1.2, high ×0.9, 0.7–1.5, sell ×0.8 | Stock-based prices (from rsg-trader) |
| `Config.Kinds.legal` / `.illegal` | see table above | `market`, `payWith`, `payOut`, `blockLaw`, `defaultBlip` per kind |
| `Config.Reasons` | `grumpy-trader-*` | Money reasons (grumpy-reputation reads these for standing) |
| `Config.Standing.Enabled` | `true` | Honor/infamy prices when grumpy-reputation runs |
| `Config.Laundering.DefaultCut` / `MinCut` / `MaxCut` | `30` / `5` / `90` | Fence's cut in percent |
| `Config.Laundering.StandingScales` | `true` | Cut × the player's underground buy multiplier |
| `Config.Laundering.MinAmount` | `1` | Smallest dirty amount per wash |
| `Config.Laundering.PlayerDailyLimit` / `TraderDailyLimit` | `100` / `500` | Dirty dollars per character per fence per day / per fence per day (0 = no limit) |
| `Config.AdminCommand` | `'traderadmin'` | Admin panel command |
| `Config.DefaultModel` / `DefaultBlip` | `mp_u_m_m_trader_01` / market stall | New trader defaults |
| `server/webhook_config.lua` | off | Discord channels: `trade` (buy, sell, launder), `admin`, `security` |

## How to use
| Who | How |
|---|---|
| Players | Target a trader → **Speak with the Trader** / **Talk business** → Buy, Sell or Launder |
| Admins | `/traderadmin` → Add Trader (pick **Kind**; for fences tick **Launders dirty money** and set the cut) → Items → Add Item (pick the **Trade** mode) |
| Admins | `/traderwebhooktest` sends a test message to every webhook channel |

## Commands
| Command | Permission | Description |
|---|---|---|
| `/traderadmin` | admin | Trader and stock admin panel |
| `/traderwebhooktest` | admin | Test the Discord webhooks |

## Locales
`locales/en.json` is included. rsg-trader's other languages can be copied from rsg-trader and the new keys (kinds, laundering, modes) added.
