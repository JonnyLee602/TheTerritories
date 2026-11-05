# grumpy-reputation

One **standing** per character, from Outlaw to Legit. Honest work raises it and successful illegal work lowers it. Outlaw standing is only earned by succeeding: failing shrinks your reputation instead. `/rep` shows your standing and every other rep value you've earned (hunting, fishing, cooking, crafting, ...).

Version 1.1.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `oxmysql`
**Used by:** grumpy-rumors (planned) to decide which tips a player can get.

## Features
- **One axis**: −1000 (outlaw) to +1000 (legit), starting at 0. Five tiers: Notorious, Outlaw, Unknown, Respected, Upstanding (names, ranges and descriptions in config/locales).
- Stored with rsg-core's rep data (`metadata.rep.standing`) next to hunting/fishing XP.
- **Offline queue:** changes for a character who isn't online (for example, someone who disconnects mid-robbery to dodge the penalty) are saved in `grumpy_reputation_pending` and applied at their next login. Leaving can't dodge a penalty.
- **Works with RSG jobs without editing them.** Every payout in rsg-core fires a server event with a reason string. Config maps reasons to actions:
  - Legit: deliveries, fishmonger, butcher, hunting vendor, trader, lumber wagon sales, bounty turn-ins, moonshine raids, medic rewards.
  - Outlaw: drug sales and exports, horse fencing, grumpy-robbery store hold-ups and safes, and any blood money payout.
- **You have to succeed to gain outlaw standing.** Unwitnessed crimes do nothing. Being charged or jailed by real lawmen gives a *slight* outlaw gain (`charged`, `jailed`).
- **Getting away with it:** with grumpy-law, a reported crime that **succeeded** followed by 10 minutes free and alive gives the `escaped` outlaw bonus. Jailed, died or logged off means no bonus.
- **Failing costs you.** Penalty actions (`towardZero`) shrink standing toward 0 without crossing it: a failed robber loses outlaw cred, a respectable player caught stealing loses respectability, and nobody gains rep by failing. grumpy-robbery uses `robbery_failed` and `caught_shoplifting`.
- **Illegal jobs always count**: chop shops, fences and other illegal work you add call an action when they pay out.
- **Daily caps per action**, saved on the character, so grinding one job (or relogging) can't max out standing.
- **Decay**: after 7 days with no change, standing drifts 10 points a day back toward 0.
- Players are told when their tier changes ("Folks now see you as Outlaw.").
- `/rep` panel in the house NUI style: tier, description, outlaw ↔ legit bar, and all other rep values.
- **Honor / infamy prices** (The Territories pricing doctrine). Merchants read your standing at the counter:
  - **Legal** merchants: honorable players buy up to 25% cheaper and are paid up to 50% more; outlaws pay up to 50% more and are paid half.
  - **Underground** traders (fences, black market): the reverse.
  - Neutral standing (−199 … 199) pays normal prices; the effect grows smoothly to the ends of the scale.
  - **rsg-stores NPC shops**: buy and sell prices change, the shop shows the adjusted prices, and a notice says why (needs the small [rsg-stores patch](integrations/rsg-stores.md)). Player-owned stores and grumpy-pob businesses keep their own prices.
  - **Other RSG sellers without editing them**: butcher, hunting vendor, fishmonger, lumber wagons, ranch sales (legal), drug sales, drug exports and horse fencing (underground). The difference is paid or taken right after the sale, in the same money type, with a message.
  - **No money loops:** selling a store item back never pays more than the cheapest discounted price it can be bought for. rsg-trader (which buys and sells the same goods) only gets the penalty, never the bonus.

## Installation
1. Put `grumpy-reputation` in your resources folder and add after rsg-core:
   ```
   ensure grumpy-reputation
   ```
2. No items. The small `grumpy_reputation_pending` table is created automatically (or set `Config.AutoDatabase = false` and import `install.sql`).
3. Optional, for honor/infamy prices in rsg-stores shops: apply [integrations/rsg-stores.md](integrations/rsg-stores.md). Mark fence or black-market shops as `'underground'` in `Config.Pricing.Shops`.
4. Optional: add the law hooks in [DOCS.md → Integration](DOCS.md#6-integration-examples) so being charged or jailed gives a slight outlaw gain.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create the offline queue table on start |
| `Config.Standing` | key `standing`, −1000..1000, start 0 | Where and how standing is stored |
| `Config.Tiers` | 5 tiers | `{ name, min }`, highest first. Labels: `tier_<name>` / `tier_desc_<name>` in locales |
| `Config.Actions` | see file | `name = { amount, dailyCap }`. Positive = legit, negative = outlaw |
| `Config.MoneyHooks` | RSG job payouts | `{ reason = 'exact' }` or `{ pattern = 'lua pattern' }` → `action` |
| `Config.BloodMoneyAction` | `'blood_money'` | Action for any bloodmoney payout not matched by a hook. `nil` = off |
| `Config.MinHookAmount` | `1` | Ignore payouts below this |
| `Config.Decay` | on, after 7 days, 10/day | Drift toward 0 when idle |
| `Config.Pricing.Enabled` / `Deadzone` | `true` / `199` | Honor/infamy prices on/off; standing within ± this pays normal prices |
| `Config.Pricing.Markets` | legal buy 0.75/1.5, sell 1.5/0.5; underground the reverse | `{ buy = { honor, infamy }, sell = { honor, infamy } }` multipliers at the ends of the scale |
| `Config.Pricing.DefaultMarket` / `Shops` / `ExcludePatterns` | `'legal'` / `{}` / `{ '^pob_' }` | Market for each rsg-stores shop name (`'legal'`, `'underground'`, `'none'`) |
| `Config.Pricing.ArbitrageMargin` | `0.95` | Store sell-back cap: cheapest price x lowest buy multiplier x this |
| `Config.Pricing.SaleHooks` | RSG sellers | `{ reason \| pattern, market, maxMult?, minMult? }`: adjust that payout by the seller's standing |
| `Config.Pricing.MinSale` / `NotifySale` | `0.05` / `true` | Smallest payout adjusted; tell the player |
| `Config.NotifyTierChange` | `true` | Tell players when their tier changes |
| `Config.NotifyEveryChange` | `false` | Small notify on every change (handy for testing) |
| `Config.Command` | `'rep'` | Opens the panel |
| `Config.ShowStandingNumber` | `true` | Show the number under the bar |
| `Config.RepOrder` / `Config.HideRep` | hunting, fishing, cooking, crafting, drugs | Panel order / keys to hide. Labels: `rep_<key>` in locales |
| `Config.AdminCommand` / `AdminPermission` | `'setstanding'` / `'admin'` | `/setstanding [id] [value]` |

## How to use
| Who | How |
|---|---|
| Players | `/rep` to see standing and trades |
| Admins | `/setstanding [id] [value]` |

## Developer examples
```lua
-- server: your chop shop paid out
exports['grumpy-reputation']:Action(source, 'chop_wagon')

-- server: a job failed -> shrink standing toward 0 (never past it)
exports['grumpy-reputation']:Action(source, 'robbery_failed')

-- server: is this player outlaw enough for a tip? (standing <= -200)
if exports['grumpy-reputation']:InRange(source, nil, -200) then ... end

-- server: price an item in your own fence script (doctrine: underground market)
local mult = exports['grumpy-reputation']:GetPriceMultiplier(source, 'underground', 'sell')
Player.Functions.AddMoney('bloodmoney', basePrice * mult, 'my-fence-sale')

-- client: my tier
local tier = exports['grumpy-reputation']:GetTier() -- 'outlaw'
```

## Locales
`locales/en.json` is included. Add other languages (de, el, es, fr, ja, nl, pl, pt-br, ro) as `locales/<code>.json` with the same keys.
