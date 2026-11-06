# grumpy-pob: developer and server owner docs

## Contents
1. Architecture
2. Data formats
3. Exports
4. Events and callbacks
5. Integration examples
6. Persistence
7. Security model
8. Database schema
9. How-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | All settings and the business types |
| `server/sv_config.lua` | Secrets: Fivemanage token, Discord bot (server only) |
| `server/main.lua` | `POB` state, helpers (distance, cooldown, lock, permissions, allowed items), DB load + load hooks, client sync, read exports |
| `server/accounts.lua` | Business and government accounts, ledger, cash in/out, `/govaccount`, money exports |
| `server/jobs.lua` | One rsg-core job per business: create/update/delete definition, give/take, staff list, `myEmployment` |
| `server/shop.lua` | Stock and prices, rsg-stores shop per business, sale hook, stock box, set price, take stock |
| `server/crafting.lua` | Craft menu, two-step crafting (start / finish), business stashes |
| `server/recipes.lua` | Custom recipes: rules, submit, remove, item registration, Fivemanage presign/verify/delete |
| `server/approval.lua` | Approval in game, on Discord (reactions polled over REST) and by timer |
| `server/stable.lua` | rsg-stables registration, horse training requests, sessions and the 40/60 split |
| `server/hotel.lua` | grumpy-hotel hotel per business, rental point, rent income, room rate |
| `server/business.lua` | Sign (buy / apply), duty, manager screen data, deposit/withdraw, hire/fire/grade, rename, appearance, wages |
| `server/launder.lua` | Back room purchase and washing (owner only), law tips, books warrants, audits and seizures |
| `server/upkeep.lua` | Tax bills, repossession, wage payments |
| `server/admin.lua` | `/pob`: create/edit/delete, reset/set owner, teleport, sign placement check |
| `client/main.lua` | Business sync, NPC + sign spawning by distance, blips, target zones, NUI bridge |
| `client/interact.lua` | NPC and sign options, manager/craft/training/government screens |
| `client/admin.lua` | Admin menu, position capture, sign placement with rsg-gizmo |
| `html/*` | NUI: sign, manager (tabs), crafting, training, trainer, government, admin |
| `integrations/*.md` | Local patches for rsg-stores, rsg-core, rsg-inventory, rsg-consume, rsg-stables |

Server files load in manifest order; later modules hook in with `POB.AfterLoad(fn)`, which runs after the businesses are loaded.

## 2. Data formats
**Business type** (`Config.Types[key]`):
```lua
{
    label, price, tax, npcModel, blip = { sprite, color },
    shop = bool, stock = { categories = { 'consumable' }, items = { 'extra_item' } },
    crafting = bool, recipes = { { item, amount, time (ms), ingredients = { [item] = amount } } },
    custom = { bases = { item... }, ingredients = { item... } } | nil,      -- custom recipe rules
    hotel = { maxRooms, defaultRate, maxRate, maxDays } | nil,
    stable = { maxHorses, capExempt, fallback } | nil, training = bool,
}
```
Items on this server have no food/drink categories: food and drink are `category = 'consumable'` in `rsg-core/shared/items.lua`, horse items are `'horse'`.

**Business** (server, `POB.Businesses[id]`):
`{ id, type, label, price, owner = { cid, name } | nil, npcModel, blip = { sprite, color, enabled }, points, settings, shopId, hotelId, rooms, taxDue, taxOwedSince, job = 'pob_<id>' }`
- `points = { npc = {x,y,z,w}, manager = {x,y,z,w}, sign = {x,y,z,rx,ry,rz}, craft = {{x,y,z,w}...}, stash = {...}, door?, interior?, preview? }`
- `settings = { wages = { ['0'] = amount, ... }, training = { [stat] = price }, hotelRate }`

**Accounts**: `biz:<id>` per business and `gov`. **Ledger kinds**: `sale, deposit, withdraw, wage, tax, purchase, rent, training, stock_in, stock_out, price, staff, settings, recipe, owner, repossess, refund, deleted, export`.

**Stock**: one row per business and item: `qty` and `price` (`NULL` = hidden). A price stays when stock runs out.

**Custom recipe**: item name `pob<businessId>_<recipeId>`. `status`: `pending → approved | rejected`, `approved → retired` (no longer craftable, item kept so existing copies keep working). `image_status`: `none | gallery | pending | approved | rejected`.

**Stash ids**: `grumpy_pob_stash_<id>_<n>` (business stashes), `grumpy_pob_stock_<id>_<citizenid>` (personal stock box).

**rsg-stores shop**: `shop_name = 'pob_<id>'`, model `none`, access point key `grumpy-pob:<id>`. **grumpy-hotel** rental point key `grumpy-pob:<id>`. **rsg-stables** stable name `pob_<id>`.

## 3. Exports
**Server**
| Export | Returns | Notes |
|---|---|---|
| `GetBusinesses()` | public business list | Same data clients get |
| `GetBusiness(id)` | public business or `nil` | |
| `GetBusinessByJob(job)` | public business or `nil` | |
| `GetBusinessBalance(id)` | number or `nil` | |
| `AddBusinessMoney(id, amount, note)` | bool | Ledger kind `export` |
| `GetGovBalance()` | number | |
| `AddGovMoney(amount, note)` | bool | |
| `RemoveGovMoney(amount, note)` | bool | Fails when the balance is too low |
| `GetOwnedBusinesses(cid)` | `{ id, label, type, npc, backroom }[]` | Businesses a character owns now (1.2.0, for grumpy-gambling) |
| `IsOwner(id, cid)` | bool | Is this character the current owner (1.2.0) |
| `HasBackroom(id)` | bool | The current owner bought the back room (1.2.0) |
| `IsReady()` | bool | Businesses are loaded (1.2.0) |

Public business: `{ id, type, label, owned, price, job, npcModel, blip, points, shop, crafting, hotel, stable, training, shopId, hotelId }`.

No client exports.

## 4. Events and callbacks
Callbacks (rsg-core, all re-validated): `signInfo`, `canShop`, `manager`, `ledger`, `audit`, `nearbyPlayers`, `craftMenu`, `craftStart`, `presign`, `submitRecipe`, `trainingInfo`, `trainingRequests`, `acceptTraining`, `govData`, `myEmployment`, `adminData`, `adminRecipes`, `adminCheckSign` (all `grumpy-pob:server:*`).

Server net events (`grumpy-pob:server:*`, all validated): `requestSync`, `buy`, `apply`, `duty`, `money`, `hire`, `application`, `fire`, `setGrade`, `rename`, `appearance`, `wages`, `setPrice`, `takeStock`, `openStock`, `openStash`, `craftFinish`, `deleteRecipe`, `requestTraining`, `cancelTraining`, `finishTraining`, `setTrainingPrice`, `setHotelRate`, `govMoney`, `buyBackroom`, `launder`, `issueBooksWarrant`, `seize`, `adminSave`, `adminDelete`, `adminReset`, `adminSetOwner`, `adminTeleport`, `adminRecipeDecide`.

Client events (sent by the server): `sync(list)`, `refresh(which)`, `auditRefresh(id)`, `employmentChanged`, `openAdmin`, `openGov`.

Server-only events grumpy-pob fires (1.2.0, local `AddEventHandler`; used by grumpy-gambling's business tables):
- `grumpy-pob:server:ownerChanged(id, oldCid, newCid, reason)`: someone bought the business (`bought`), it was
  repossessed (`tax`), an admin reset it or gave it away (`admin`), or it was deleted (`deleted`). A repossession fires
  with `newCid = nil`; a new owner fires again with `oldCid = nil`.
- `grumpy-pob:server:businessChanged(id)`: an admin saved the business (its points, e.g. the NPC, may have moved).
- `grumpy-pob:server:seized(id, lawSrc)`: an officer seized laundered money from the books.

Server-only events grumpy-pob listens to (from the patches, clients can't trigger them):
- `rsg-stores:server:externalSale(shopId, src, lines, total)`
- `rsg-inventory:server:stashClosed(src, stashId)`
- `grumpy-hotel:server:rentPaid(hotelId, src, amount, kind)`

## 5. Integration examples
```lua
-- A delivery script pays the business that ordered the goods
RegisterNetEvent('my-deliveries:server:done', function(businessId)
    -- ...validate the delivery first...
    exports['grumpy-pob']:AddBusinessMoney(businessId, 150, 'Delivery')
end)

-- A governor script spends public money
RSGCore.Commands.Add('fundroad', 'Fund road repairs', {}, false, function(source)
    if not exports['grumpy-pob']:RemoveGovMoney(1000, 'Road repairs') then return end
    -- ...
end)

-- Is the player on duty at a business?
local biz = exports['grumpy-pob']:GetBusinessByJob(Player.PlayerData.job.name)
if biz and Player.PlayerData.job.onduty then ... end
```

## 5b. Laundering and audits
**Back room.** Stored in the business's `settings.backroom = { cid, at }`. It only counts while `cid` is the current
owner, so a new owner (sale, `/pob` set owner) doesn't inherit it; repossession also clears it.

**Washing** (`grumpy-pob:server:launder`), owner only (the actual owner's citizenid, at the manager desk):
1. Checks the back room, the amount (`MinAmount`–`MaxTransfer`), the bloodmoney carried, and the weekly allowance:
   `max(Floor, SalesShare × SUM(ledger amount where kind in sale/rent/training over WindowDays))` minus the dirty
   amount already washed in that window. Washed money is logged as kind `private`, so it never raises the allowance.
2. Works out `sink = dirty × SinkCut/100` and `cut = dirty × BusinessCut/100` (rounded to cents), and `cash = dirty − sink − cut`,
   so the three always add up. Removes the bloodmoney (`grumpy-pob:launder`) and gives the owner `cash` as clean cash to
   hand back to the player (if that fails, the bloodmoney is returned and nothing happens). Adds `cut` to the account as
   kind `private` with no name or note: the only ledger line a wash makes. `sink` isn't paid to anyone.
   The real record goes to `grumpy_pob_launder` with `clean = cash + cut` and `business_cut = cut`.
   A seizure takes the unseized `clean` total (cash paid out + private sales) from the account, capped at its balance,
   so the account answers for the cash the owner already walked away with.
3. Rolls a tip: `min(MaxChance, ChancePer100 × dirty / 100)` %. After `Delay` seconds every on-duty law player gets an
   rsg-lawman alert at the business (or a notify if rsg-lawman isn't running). No names are given.

Standing (grumpy-reputation) is not involved: no multiplier, and RemoveMoney / account deposits don't fire its hooks.

**Books warrant** (`books_warrant` item): issued at the manager desk by on-duty law with grade ≥ `MinGrade`.
Metadata `{ business, owner (citizenid), expires, label, suspect, issuer, description }`. It is only valid for that
business **and that owner**, until it expires. Using the item shows what it's for.

**Audit** (`grumpy-pob:server:audit`): on-duty law holding a valid warrant, at the manager desk. Returns the records
from the last `LookbackDays` (dirty, clean, who, when, seized), whether a back room exists, the balance and the
unseized total. The owner is notified. **Seize** moves `min(unseized clean total, balance)` from the business account
to the government account (ledger kind `seized`, visible to staff, with the officer's name) and marks those records
seized so they can't be taken twice.

## 6. Persistence
- Businesses, accounts, ledger, stock, applications, daily withdrawals and recipes are in MySQL and written immediately.
- On start grumpy-pob waits for rsg-stores and grumpy-hotel to load (`IsReady`) before creating their shops and hotels, so restarts never duplicate them. When rsg-stores, rsg-stables, grumpy-hotel or rsg-consume restart, their side is rebuilt automatically.
- Custom items are registered with rsg-core on every start (they aren't stored by rsg-core).
- Tax and wage timers run in memory; a missed tax check simply happens on the next run.
- Crafting and training sessions live in memory. If the server restarts mid-craft, the ingredients are lost (same as cancelling a job). A trainer disconnecting refunds the customer.

## 7. Security model
- **The client never decides.** Every action re-checks on the server: the player, ownership, job held (`HasPlayerJob`), grade against `Config.Permissions`, on-duty where needed, and distance to the right point.
- **Money**: amounts are rounded, range-checked and capped (`MaxTransfer`). Account changes are single conditional `UPDATE`s (`balance >= amount`), so two clicks can't overdraw. `RemoveMoney` is checked before anything is given; failures refund. Per-business lock on deposits/withdrawals and purchases.
- **Shop**: prices and items come from the server's stock table; rsg-stores runs the purchase with its own checks. Staff can't buy from their own business (would let a price-setter buy stock out). Only items allowed by the type (or the business's own custom items) can be stocked or priced.
- **Crafting**: the server removes ingredients at start, hands out a one-time token and gives the result only after the full time, near the station.
- **Training**: the price comes from the server; the customer's horse is checked by model and distance; the customer pays when the trainer accepts and is refunded on cancel, disconnect or failure.
- **Staff**: you can only fire, promote or demote people below your own grade, never to owner.
- **Admin**: every admin event re-checks `Config.AdminPermission`; form values are sanitised and coordinates range-checked. The sign position is checked with `rsg-gizmo:IsPlacementValid`.
- **Recipes**: names/descriptions are sanitised and filtered (`BlockedWords`); bases and ingredients must be in the type's lists. Uploaded images are verified with Fivemanage by id (the URL from the client is never used) and must start with `AllowedPrefix`. The Fivemanage token stays on the server; the client only gets a short-lived presigned upload URL.
- **Discord**: only reactions from members with an `ApproverRoles` role count; the bot's own reactions are ignored.
- **Gambling tables**: owner only (citizenid), at the manager desk, under the per-business money lock; the limit
  (placed + carried < grumpy-gambling's per-business max) and inventory space are checked before the account is
  charged; if the item can't be given the money goes back. Net event `grumpy-pob:server:buyGamblingTable(id, kind)`.
- **Laundering**: owner only, checked by citizenid (not just the owner grade), at the manager desk, under the per-business money lock. The allowance can't be raised by laundering itself. Staff only ever see anonymous "Private sale" lines; manager data includes the back room only for the owner.
- **Audits**: law status, distance and a matching unexpired warrant (business + current owner) are checked on every audit and seizure. Seizing marks records so the same money can't be seized twice.
- **Other scripts** calling `AddBusinessMoney` / `RemoveGovMoney` must validate their own players first.

## 8. Database schema
```
grumpy_pob_businesses   (id PK, type, label, price, owner_cid, owner_name, npc_model, blip JSON, points JSON, settings JSON,
                         shop_id, hotel_id, rooms, tax_due, tax_owed_since, created_by, created_at)
grumpy_pob_accounts     (account PK 'biz:<id>' | 'gov', balance)
grumpy_pob_ledger       (id PK, account, ts, kind, amount, balance, who_cid, who_name, note)
grumpy_pob_withdrawals  (business_id, citizenid, day PK, amount)
grumpy_pob_stock        (business_id, item PK, qty, price NULL = hidden)
grumpy_pob_applications (id PK, business_id, citizenid UNIQUE per business, name, message, created_at)
grumpy_pob_launder      (id PK, business_id, ts, dirty, clean, business_cut, citizenid, name, seized)  -- real laundering records, pruned after KeepDays
grumpy_pob_recipes      (id PK, business_id, item_name, label, description, base_item, ingredients JSON, amount, craft_time,
                         image_url, image_id, image_status, status, discord_msg, created_by, created_at, decided_by)
multijob_jobs / player_jobs   (rsg-core) job pob_<id>
rsg_shops_npcs / rsg_shops_items (rsg-stores) shop per shop business
grumpy_hotels (grumpy-hotel) hotel per hotel business
inventories (rsg-inventory) grumpy_pob_stash_* / grumpy_pob_stock_*
```

## 9. How-tos
- **Add a business type**: copy a type in `Config.Types`, give it a new key, set `stock.categories`/`items`, recipes and blip. Restart. It appears in `/pob`.
- **Change grades or permissions**: edit `Config.Grades` / `Config.Permissions`. Grades are pushed to every business job on the next start. Keep the owner as the last grade.
- **Turn off tax or wages**: `Config.Tax.Enabled = false` / `Config.Wages.Enabled = false`.
- **Instant custom items with no approval**: `Config.Approval.Mode = 'auto'` (images still wait for a person when `ImagesNeedHuman = true`).
- **Move a point**: `/pob` → Edit → **Place** on that point (the ghost or marker starts where the point is now) → move it → Save. A crafting prop is moved with **Place prop**. Moving the NPC moves the shop access point too.
- **Take a business from an inactive owner**: `/pob` → Reset owner. Staff are let go and the balance goes to the government.
- **Give a business to a player**: `/pob` → Set owner → their server id.
- **Laundering off for a type**: remove `launder = true` from it. Off everywhere: `Config.Laundering.Enabled = false`.
- **Fronts too easy / too hard**: lower or raise `Floor` and `SalesShare`; raise `SinkCut` (more destroyed) or lower `BusinessCut` (less profit for the owner); raise `Tip.ChancePer100`.
- **Audits off**: `Config.Audit.Enabled = false` (no warrants, no inspections). Tips still go out unless `Tip.Enabled = false`.
- **Hotel rooms**: set in `/pob`. Lowering the count below a rented room is refused by grumpy-hotel until that room is evicted (`/hotellist`).

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| Console: `rsg-stores export ... failed` | Apply `integrations/rsg-stores.md` (all three parts) and restart rsg-stores, then grumpy-pob |
| "Browse goods" says sold out | Nothing is both in stock and priced. Stock it on duty, then set prices under Stock |
| Hiring fails in a new business | Apply `integrations/rsg-core.md`, or restart the server once after creating the business |
| No "Manage business" option | You don't hold the business job. Check `/myjobs`; managers hire you or accept your application |
| Can't stock / craft | Clock in at the manager desk first (on duty) |
| Stock appears only when reopening the box | Apply the `stashClosed` part of `integrations/rsg-inventory.md` |
| Custom item vanishes or shows as unknown | Apply `integrations/rsg-inventory.md` (core refresh). Without it rsg-inventory doesn't know items added while running |
| Custom item can't be used | Apply `integrations/rsg-consume.md`; the base item must be in rsg-consume's config |
| Upload fails | `Config.Images.Enabled`, `SvConfig.Fivemanage.ApiKey` and token permissions (upload + delete). The in-game browser may not open file pickers: paste the image with Ctrl+V |
| No **Back room** tab | Only the actual owner sees it, and only for types with `launder = true` |
| "The books can't explain any more money this week" | Weekly allowance used up. Honest sales, rent and training raise it |
| Lawman has no books options | Must be on duty with a `leo` job type; issuing needs grade ≥ `Audit.MinGrade`. The business must be owned |
| "You need a valid books warrant" | Warrant expired, is for another business, or the business changed owner since it was issued |
| Discord nothing happens | Bot token, guild/channel ids, `ApproverRoles` and the bot's channel permissions. Set `Config.Debug = true` to see HTTP errors |
| "Open stable" does nothing / not allowed | Apply `integrations/rsg-stables.md`, and hold the business job |
| Hotel NPC has no "Rent a room" | grumpy-hotel 1.1+ must be running and the business owned |
| Sign shows "Open" while for sale | It was placed rotated. Edit the business and place it again so it reads "Closed" |
