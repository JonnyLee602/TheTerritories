# grumpy-pob

Player owned businesses for RedM. Admins build saloons, restaurants, hotels and stables in game with `/pob`. Players buy them at the open sign, hire staff, stock the shop, craft, pay wages and tax, and keep the takings in a business account.

Version 1.1.0 · for RSG Framework (rsg-core 3.0.3) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `rsg-stores`, `oxmysql`
**Optional:** `grumpy-hotel` 1.1+ (hotel businesses), `rsg-stables` (stable businesses), `rsg-consume` (custom food/drink items)
**Local patches required:** see [Installation](#installation) step 2.

## Features
- **`/pob` admin menu.** Create a business from a config-driven type, set its name and price, then place its points:
  - **NPC**: customers buy goods here (rsg-stores shop) or rent rooms (hotel). On-duty staff stock the shop here.
  - **Manager desk**: clock in/out and the manager screen.
  - **Open sign** (`p_sign_open_close06x`, placed with rsg-gizmo): unowned it reads **Closed** and offers **Buy**. Once bought it turns 180° to **Open** and offers **Apply for a job**.
  - **1 to 3 crafting stations** (types with crafting) and **0 to 3 stashes**, staff only.
  - **Hotel**: door and room interior points, plus the number of rooms. **Stable**: horse preview spot.
  - Edit, teleport, set owner, reset owner, delete; government account; recipe approvals.
- **Business types in config.** Saloon, Restaurant, Hotel and Stable are included. Add more by copying a type: shop on/off, which item categories may be stocked, crafting recipes, custom recipe rules, hotel or stable features, price, tax.
- **One rsg-core job per business** (`pob_<id>`) with grades Trainee → Owner. Clock in at the manager desk (makes it your active job). Every permission is a minimum grade in `Config.Permissions`.
- **Stocking the shop.** An on-duty employee uses the NPC: a stock box (rsg-inventory) opens. Whatever they put in becomes shop stock when the box closes. Items the business can't sell are handed back.
  - Items stay **hidden** until a manager sets a price. Prices are remembered, so a re-stocked item is for sale straight away.
  - Managers can **take stock back out** (grade 3+ by default).
  - Customers buy through the normal rsg-stores shop menu. An empty shop says it's sold out. Staff can't buy from their own business.
- **Business account** (not rsg-banking): sales, rent and training income go in; deposits and withdrawals happen at the manager desk with a per-grade daily limit. Every change is atomic and written to the **ledger** (readable by grade).
- **Government account**: purchase prices and tax go here. Admins and the jobs in `Config.Government.Jobs` (for example a future `governor`) open it with `/govaccount`.
- **Wages** per grade, set by the owner, paid from the account every 30 minutes to on-duty staff. Owners aren't paid.
- **Tax** every 14 real days from the account. Unpaid tax for 3 days repossesses the business: staff are let go, the balance goes to the government, stock and stashes are cleared, the sign flips back to Closed.
- **Applications**: players apply at the sign. Managers accept (hire) or reject them on the manager screen. Managers can also hire anyone standing nearby, fire and promote staff below their own grade.
- **Manager screen**: overview (duty, balance, tax), stock and prices, staff, applications, ledger, settings (rename, NPC model, blip icon/colour/visibility, hotel room rate, training prices, wages), recipes.
- **Crafting**: type recipes from config, plus **custom recipes** owners design: name, description, base item, ingredients, output, craft time and a picture.
  - A custom recipe becomes a real item with its own name and picture that works like its base item (eat/drink effects).
  - Pictures: pick an existing item picture, or **upload** one to Fivemanage from the menu (file picker or Ctrl+V).
  - **Approval**: in game (`/pob` → Approvals), on **Discord** (bot posts the recipe, approvers react ✅ / ❌), or automatically after 15 minutes when no admin is online. Auto-approved items use the base picture until a person approves the custom one.
- **Back room (laundering), owner only.** The owner can buy a back room once ($750 from the business account, shown as "Renovations"). Then only the owner can wash **dirty money** (bloodmoney) at the manager desk: 15% disappears, the rest goes into the business account as **"Private sale"** lines, so staff never see what's going on. Standing doesn't affect it. A front can only wash as much per week as its books can explain: its honest income (sales, rent, training) over the last 7 days, at least $350. Lost on repossession or sale.
- **The law can audit fronts.** Each wash may tip off on-duty lawmen ("dirty money is changing hands at …"). A lawman of grade 2+ issues a **books warrant** at the manager desk; any on-duty lawman holding it can **Inspect the books** there, see the real laundering records from the last 14 days, and **seize** the laundered money from the account into the government account. The owner is told.
- **Hotel businesses** use grumpy-hotel: the NPC rents rooms, owners set the rate, rent goes into the account.
- **Stable businesses** use rsg-stables: only staff can keep horses there (40 per employee instead of the normal limit, not counted toward the owned-horse cap). Customers request **horse training** at the NPC; an on-duty trainer accepts, trains the horse, and the price is split **40% business / 60% trainer**. Staff horses train free.
- Everything is checked on the server: permission, grade, duty, distance, ownership, amounts, item rules, cooldowns and locks.
- NUI in the house theme (Roboto, monochrome, no vignette).

## Installation
1. Put `grumpy-pob` in your resources folder. If you use hotels, update `grumpy-hotel` to 1.1.0 (adds the exports this needs).
2. Apply the patches in `integrations/` to your RSG resources (they only add code):

   | Patch | Needed for |
   |---|---|
   | [rsg-stores.md](integrations/rsg-stores.md) | **Required.** Shops opened from the business NPC, stock/prices pushed from grumpy-pob, sales paid into the account |
   | [rsg-core.md](integrations/rsg-core.md) | Hiring into a brand-new business without a restart |
   | [rsg-inventory.md](integrations/rsg-inventory.md) | Custom items, instant stocking, uploaded pictures |
   | [rsg-consume.md](integrations/rsg-consume.md) | Custom food/drink items having their base item's effects |
   | [rsg-stables.md](integrations/rsg-stables.md) | Stable businesses and horse training |
3. `server.cfg` (after the resources it uses):
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-gizmo
   ensure rsg-stores
   ensure rsg-stables
   ensure rsg-consume
   ensure grumpy-hotel
   ensure grumpy-pob
   ```
4. Database: tables are created automatically. To install them by hand, set `Config.AutoDatabase = false` and import `install.sql`.
   For law audits, add the warrant item to `rsg-core/shared/items.lua` (and a `books_warrant.png` image to rsg-inventory's images, e.g. a copy of `hotel_warrant.png`):
   ```lua
   books_warrant = { name = 'books_warrant', label = 'Books Warrant', weight = 10, type = 'item', image = 'books_warrant.png', unique = true, useable = true, shouldClose = true, description = 'A warrant to inspect a business\'s books', category = 'law' },
   ```
   No warrants wanted? Set `Config.Audit.Enabled = false`.
5. Optional services, in `server/sv_config.lua` (server only, never shared with clients):
   - **Fivemanage** image uploads: put your API token in `SvConfig.Fivemanage.ApiKey` and set `Config.Images.Enabled = true`.
   - **Discord approval**: create a bot, invite it with *View Channel, Send Messages, Embed Links, Add Reactions, Read Message History* on the approval channel, fill `SvConfig.Discord` (token, guild id, channel id, approver role ids) and set `Config.Approval.Discord.Enabled = true`.
6. Optional: create a `governor` job in `/jobadmin` so it can use `/govaccount`.
7. In game: `/pob` → **New business**.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AdminCommand` / `AdminPermission` | `pob` / `'admin'` | Admin menu command and permission |
| `SpawnDistance` / `InteractDistance` / `ServerDistance` | `60` / `2.5` / `6.0` | NPC/sign spawn range, target range, server distance tolerance |
| `SignModel` / `SignOpenRotation` | `p_sign_open_close06x` / `180` | Sign prop and the turn that shows "Open" |
| `PlaceDistance` | `30.0` | rsg-gizmo range when placing points (a ghost of the business NPC) |
| `Grades` / `OwnerGrade` | Trainee…Owner / `4` | Grades of every business job (last = owner) |
| `Permissions` | see file | Minimum grade per action (stock, craft, prices, takeStock, withdraw, hire, fire, rename, wages, …) |
| `WithdrawDailyLimit` | `{ [3] = 50 }` | Daily withdrawal limit per grade (owner unlimited) |
| `RequireDutyForStash` / `RequireDutyForCraft` | `true` / `true` | Stashes / crafting need the player on duty |
| `MaxPrice` / `MaxTransfer` / `LedgerPageSize` | `1000000` / `100000` / `50` | Purchase price cap, largest single deposit/withdrawal, ledger page |
| `Government.Command` / `Jobs` / `RequireDuty` | `govaccount` / `{ governor = 0 }` / `false` | Government account access |
| `Wages.Enabled` / `IntervalMinutes` / `Max` | `true` / `30` / `5` | Wage payments |
| `Tax.Enabled` / `IntervalDays` / `GraceDays` / `CheckMinutes` / `Default` | `true` / `14` / `3` / `30` / `25` | Tax bills and repossession |
| `Repossess.BalanceToGovernment` / `WipeStock` / `WipeStashes` | `true` | What repossession clears |
| `Shop.MinPrice` / `MaxPrice` / `MinQuality` / `StockSlots` / `StockWeight` | `0.01` / `1000` / `0` / `30` / `200000` | Shop prices and the stock box |
| `MaxCraftStations` / `MaxStashes` / `Stash.Slots` / `Stash.Weight` | `3` / `3` / `50` / `400000` | Station/stash limits and stash size |
| `Applications.MaxLength` / `CooldownMinutes` / `MaxPending` | `500` / `60` / `30` | Job applications |
| `NpcModels` / `BlipSprites` / `BlipColors` | see file | Choices offered to managers |
| `CustomRecipes.*` | enabled, 10 per business, 4 ingredients, 3–20 s | Custom recipe limits and `BlockedWords` |
| `Approval.Mode` | `'timed'` | `'manual'`, `'auto'` or `'timed'` |
| `Approval.AutoApproveMinutes` / `AutoApproveOnlyIfNoAdminOnline` / `ImagesNeedHuman` | `15` / `true` / `true` | Timed auto-approval rules |
| `Approval.Discord.Enabled` / `PollSeconds` / `ImagePollHours` | `false` / `30` / `72` | Discord reaction approval |
| `Images.Enabled` / `MaxKB` / `Types` / `AllowedPrefix` / `PresignCooldown` | `false` / `512` / png,jpg,webp / `https://r2.fivemanage.com/` / `30` | Fivemanage uploads |
| `Training.*` | 40/60 split, $1–25 (default $3), 60 XP, 20 s | Horse training |
| `Types` | saloon, restaurant, hotel, stable | Business types (see DOCS.md → Data formats). `launder = true` lets the type buy a back room |
| `Laundering.Enabled` / `Price` / `ServerCut` / `MinAmount` | `true` / `750` / `15` / `1` | Back room price (clean, from the account) and the % of dirty money that disappears |
| `Laundering.WindowDays` / `Floor` / `SalesShare` | `7` / `350` / `1.0` | Weekly allowance = max(Floor, SalesShare × honest income over WindowDays) |
| `Laundering.Tip.*` | on, 5% per $100, max 50%, 60–300 s | Chance a wash tips off on-duty law |
| `Laundering.KeepDays` | `60` | Laundering records are deleted after this |
| `Audit.Enabled` / `Item` | `true` / `books_warrant` | Law audits |
| `Audit.JobTypes` / `MinGrade` / `RequireOnDuty` | `{ leo = true }` / `2` / `true` | Who counts as law; grade needed to issue a warrant |
| `Audit.Minutes` / `Cooldown` | `60` / `30` | Warrant lifetime / seconds between warrants per officer |
| `Audit.LookbackDays` / `AllowSeize` / `NotifyOwner` | `14` / `true` / `true` | How far back records count; seizing; tell the owner |

## How to use
**Admins** (`/pob`, permission `admin`):
1. **New business** → pick a type, name and price.
2. Press **Place** on each point: rsg-gizmo shows a ghost of the business NPC that you can walk around with. Turn it to face the right way and click to set it. Do this for the NPC, manager desk, crafting stations, stashes and the hotel/stable points. You can close the menu at any time and walk off: `/pob` reopens your unsaved changes (only Save, Cancel or the back arrow drop them).
3. **Place sign**: rsg-gizmo opens; place it so it reads **Closed**. Save.
4. Approve custom recipes under **Approvals**. Open the government account with the button at the top.

**Players**:
- **Buy**: target the sign → **Buy this business**. Cash is taken; you become the owner (grade Owner).
- **Apply**: target the sign of an owned business → write an application.
- **Staff**: target the manager desk → **Clock in / out** and **Manage business**. On duty, target the NPC → **Stock the shelves**; use crafting stations and stashes.
- **Customers**: target the NPC → **Browse goods**, **Rent a room** or **Horse training**.
- **Owners**: Manage business → **Back room** tab → build it, then wash dirty money you carry. Outlaws hand you their dirty money in person; what you pay them back is up to you.
- **Lawmen** (on duty): at the manager desk → **Issue a books warrant** (grade 2+), then **Inspect the books** while holding it → **Seize**.
- **Trainers** (stables, on duty): target the NPC → **Training requests** → accept, then stand by the horse until the bar finishes.

Commands: `/pob` (admin), `/govaccount` (admins and government jobs).

## Developer examples
```lua
-- server: pay a business from another script (for example a delivery job)
exports['grumpy-pob']:AddBusinessMoney(businessId, 150, 'Delivery contract')

-- server: let a governor script spend public money
if exports['grumpy-pob']:RemoveGovMoney(500, 'Road repairs') then ... end

-- server: which business is this job?
local biz = exports['grumpy-pob']:GetBusinessByJob(Player.PlayerData.job.name)
```

## Locales
English (`locales/en.json`). Every player-facing string, including the NUI (`ui_*` keys), is in the locale file. Add a language by copying `en.json` and setting `setr rsg:locale "<lang>"`.
