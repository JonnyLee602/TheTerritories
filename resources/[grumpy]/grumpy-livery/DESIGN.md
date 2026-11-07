# grumpy-livery — design

Status: **phase 1 built and tested in game** 2026-11-06 as v1.0.0 (merge only, behaves like rsg-stables + rsg-wagons;
owner tested horses, wagons, POB stable, radial lantern). **Phase 2 built** 2026-11-07 as v1.1.0 (pricing, papers,
Thieves Landing; not yet tested in game). Design revised the same day with owner notes (no papers item; no self-serve training). This file is the contract for the build: update it whenever a
decision changes. Decisions marked **(owner)** were made by the server owner; **(proposed)** values need sign-off.

grumpy-livery replaces **rsg-stables** and **rsg-wagons** with one resource: an 1890s *livery*, a place that boards,
sells, trains and breeds horses and sells and rents rigs. It is a fork of the **Territories copies** in
`territories-server/resources/[framework]/` (`main` branch: doctrine repricing plus the grumpy-pob hooks), not of
stock RSG.

---

## Contents
1. [Goals](#1-goals)
2. [Doctrine placement](#2-doctrine-placement)
3. [Decisions at a glance](#3-decisions-at-a-glance)
4. [Base and architecture](#4-base-and-architecture)
5. [Horses: what carries over](#5-horses-what-carries-over)
6. [Papers](#6-papers)
7. [Selling horses](#7-selling-horses)
8. [Thieves Landing stable](#8-thieves-landing-stable)
9. [Training](#9-training)
10. [Trainer services (POB staff)](#10-trainer-services-pob-staff)
11. [Aging and lifespan](#11-aging-and-lifespan)
12. [Wagons](#12-wagons)
13. [Horse theft and the law](#13-horse-theft-and-the-law)
14. [Integrations](#14-integrations)
15. [Prices](#15-prices)
16. [Security](#16-security)
17. [Database and migration](#17-database-and-migration)
18. [Config outline](#18-config-outline)
19. [Build phases](#19-build-phases)
20. [Open items](#20-open-items)
21. [Sources](#21-sources)

---

## 1. Goals
- **One livery, not two scripts.** Horses and wagons share a keeper NPC, one NUI, one call/flee/store system and
  one set of saved-position code, instead of two copies of each.
- **Training you ride, not a minigame.** Everyone's horse improves slowly just from being ridden. Real training is a
  drill run by a trainer: pay, get a time window, meet riding goals, and the horse levels up.
- **Work for the trainer job.** Drills (trainers only), stud service, farrier work, breaking and vet care give stable staff (grumpy-pob)
  real role-play with customers, and pay them for it.
- **Honest and dishonest horse trade.** Papers separate legal stock from stolen stock. Legal stables pay cash,
  fences and Thieves Landing deal in bloodmoney, and no route turns into a free laundry or a cash farm.
- **Bloodlines that matter.** Horses age and die on a predictable average, so breeding is how a good line survives.

## 2. Doctrine placement
| Feature | Path | Stage | Notes |
|---|---|---|---|
| Buying horses and wagons, tack, services | Civilian | Survival → Enterprise by price | Doctrine: the Specialist "buys draft horses, heavy wagons". Cash only at legal stables |
| Wagon rental | Civilian | Survival | Day-labor freight without owning a rig |
| Breaking and selling wild horses | Civilian | Survival | Below legal horse-trading tier 1 per sale (§7.2) |
| Trainer / stable staff services | Civilian (POB staff) | Stability | Wages through the existing grumpy-pob 40/60 split |
| Horse fence (stolen local horses) | Outlaw | Survival | Scrapper "rustling, low-tier fences". Kept far below tier 1 until consequences exist (§13) |
| Thieves Landing stable | Outlaw / Hybrid | Survival → Stability | Cash or bloodmoney; underground price multipliers; forged papers are a laundering service (§8) |
| Wagon chop shop | Outlaw | Survival → Stability | **Not in rsg-wagons 3.0.0** (only stale files of an older version in the brain mirror). Port later as its own phase, priced against the outlaw bands |

Horses and wagons count as **personal gear**, not property, so bloodmoney may buy them, but **only at Thieves Landing**
(owner). Legal stables and wagon yards take cash.

## 3. Decisions at a glance
| # | Decision | By |
|---|---|---|
| 1 | Merge rsg-stables + rsg-wagons into `grumpy-livery` (fork; leaves the RSG update pipeline for both) | owner |
| 2 | Keep: horse items used from the inventory (brush, feed, medicine…), breeding, coat and tack customization, wild horse claim, races, horseshoes, spooking, saddlebags, salvage | owner |
| 3 | Remove the NUI timing minigame. Non-trainers get **passive XP only**: every few minutes of active riding, a random stat gains XP and bonding rises. **No self-serve training** | owner |
| 3a | Passive XP stops at **level 2** per stat; levels 3–5 only through trainer drills | owner |
| 4 | **Drills only with a trainer** (grumpy-pob stable staff or owner); courses are laid out by trainers and stable owners | owner |
| 5 | **Papers** for every registered horse; claiming a wild horse papers it. **No papers item**: a **Check papers** target option shows them to nearby players | owner |
| 6 | Legal **"sell wild horse"** at stables for cash | owner |
| 7 | Stolen local horses sell to the fence only, **cheap and capped** until law consequences exist | owner |
| 8 | Theft opens a **grumpy-law incident** so NPC police and bounty hunters can plug in later | owner |
| 9 | **Thieves Landing stable**: cash or bloodmoney, bloodmoney costs **+30%**, infamy is a **discount** there | owner |
| 10 | Thieves Landing buyers choose whether to buy **forged papers** | owner |
| 11 | Legal stables apply honor/infamy pricing (`legal` market) | owner |
| 12 | Wagons, bought **or rented**, always come with their own team; no hitching your own horses | owner |
| 13 | **Wagon rental** is new | owner |
| 14 | Keep chop shop, hunting cart, wagon storage, condition and repair (chop shop: see §20, not in 3.0.0) | owner |
| 15 | Aging: hidden lifespan roll 160–200 real days (average 180); stages in §11 | owner |
| 16 | Shop horses start at a random adult age; the appraisal prices age | owner |
| 17 | Migration SQL from the old tables | owner |
| 18 | All §15 prices approved; wagon rental minimum raised to **$2** | owner |
| 19 | **`horseshoes` usable item** for re-shoeing; crafting later, locked to trainers/stable owners | owner |

## 4. Base and architecture

### 4.1 Base
- **Horses:** `territories-server/resources/[framework]/rsg-stables` on `main` (3.4.0 + `[Territories]` repricing +
  `[grumpy-pob hook]` registered stables and training exports).
- **Wagons:** `territories-server/resources/[framework]/rsg-wagons` on `main` (3.0.0 + repricing).
- After the switch, both RSG resources leave `upstream.lock`, the recipe and live `[framework]` (moved to `_removed\`),
  the same way rsg-trader and rsg-loading were retired. Credits to the RSG authors stay in the README (MIT/GPL as per
  their licences); per house rules the resource carries no RexShack author or footer otherwise.

### 4.2 Layout (target)
```
grumpy-livery/
  fxmanifest.lua
  shared/config.lua            -- general, keepers/locations, payments, papers, pricing hooks
  shared/breeds.lua            -- Config.Breeds (from rsg-stables)
  shared/tack.lua              -- Config.TackItems
  shared/wagons.lua            -- Config.Wagons + liveries, propsets, hunting cart
  shared/training.lua          -- drills, passive XP, levels
  shared/aging.lua
  server/main.lua              -- keepers, registered stables, callbacks
  server/db.lua                -- all SQL, auto-migrate
  server/money.lua             -- prices: market (legal/underground), multipliers, account choice
  server/horses.lua            -- buy, store, call, give/sell, insure, revive, aging
  server/papers.lua
  server/sell.lua              -- appraisal, wild sale, fence
  server/breeding.lua
  server/training.lua          -- drills, passive XP, trainer sessions
  server/wagons.lua            -- buy, rent, store, repair, storage, chop, hunting cart
  server/theft.lua             -- grumpy-law incidents
  server/exports.lua           -- compat exports (§14)
  client/*.lua                 -- split by feature, same as above
  html/                        -- one NUI: Horses, Wagons, Rentals tabs; drill goals; papers card
  locales/en.json
  install.sql, migrate.sql
  README.md, DOCS.md
```
One keeper NPC per livery opens one menu. A location config says which tabs it offers (`horses`, `wagons`,
`rentals`, `fence`), so a town can have a livery with both, or a horse-only or wagon-only yard.

## 5. Horses: what carries over
Unchanged in behaviour (code cleaned up and shared where it overlaps with wagons): buy menu and preview, ownership
limits, stallions and mares, rename, insurance, release dead horses, give/sell to a player (now hands over the
papers, §6), tack and coat customization, horseshoes, needs, feeding/watering/brushing by target **or inventory item**,
horse actions panel, rear on command, saddlebags, native prompt tidy-up, natural drinking and grazing, hitching posts,
lantern, bonding, medicine, field revive, tack stat bonuses, appraisal, courage and spooking, field salvage, races,
stimulant, whistle recall, saved position, flee, wild horse claim, breeding, info card, stats panel, store anywhere.

Changed: training (§9), aging (§11), selling (§7), fence (§7.3, §13), pricing by market (§8, §15).

## 6. Papers
Every registered horse has a **papers** record: the horse's registered owner, how it was registered and whether
the papers are genuine or forged.

| How the horse arrived | Papers |
|---|---|
| Bought at a legal stable | Genuine, free |
| Foaled from papered parents | Genuine, free |
| Wild horse claimed at a stable | Genuine, registration fee (§15) |
| Bought at Thieves Landing, papers bought | **Forged**, fee (§8) |
| Bought at Thieves Landing, no papers | **None** |
| Foaled with an unpapered parent | None |

Rules:
- **Legal stables** only buy, appraise or accept a transfer of a horse with papers (genuine or forged; a forged set
  passes unless a lawman inspects it, see §20).
- **Player-to-player sale** moves the papers with the horse. Selling an unpapered horse to a player is allowed; the
  buyer is warned that it has none.
- **No papers item (owner):** items get lost and take inventory space. Papers live only on the horse's DB row.
- **Check papers:** an rsg-target option on your own horse (and in the stable menu for stabled horses). The server
  sends a papers card (horse name, breed, sex, age stage, registered owner, how it was registered, livery of
  registration) to the owner **and every player within a few metres** (proposed 5 m), so it works for role-play
  sales and for a lawman standing there. The card reads the same for genuine and forged papers (§20 covers
  inspection). An unpapered horse shows "No papers".

## 7. Selling horses

### 7.1 To a legal stable (owned, papered horse)
The existing appraisal stays (breed, condition, bonding, age, training, shod bonus) and is multiplied by the
`legal` sell multiplier from grumpy-reputation. Paid in **cash**. Unpapered horses are refused.

### 7.2 Wild horse sale (new)
A horse you broke yourself can be sold at a legal stable without claiming it first. The stablehand papers it and
buys it in one step.
- Same server-side check as the claim: it must be the horse the server recorded as broken by you, within the claim
  window and distance, and the breed must be in `Config.Breeds`.
- Price = breed price × `wildPercent` (**proposed 0.30**: unshod, untrained, no bond) × legal sell multiplier, paid in
  **cash**. Wild breeds at $15–35 sell for about **$4.50–10.50**.
- **Daily cap (proposed 2 per character per real day)** and a cooldown. Two sales a day stay near one legal tier-1
  job ($15–18), and breaking plus riding a wild horse in takes real time.

### 7.3 Horse fence (stolen local horses)
The fence buys **unowned, unpapered** horses: local (ambient NPC) horses and wild horses someone didn't bother to
claim. Paid in **bloodmoney**.
- **Cheap until consequences exist (owner):** flat **$0.50–$2.00** by breed class (proposed: working/draft $0.50,
  riding $1.00, mid-grade $1.50, elite $2.00), × the `underground` sell multiplier (up to ×1.5 for infamous players).
  Same scale as grumpy-wagonloot's no-risk theft ($0.05–$1.00).
- **Cap 3 per character per real day**, cooldown 20 minutes (proposed).
- Once grumpy-law's NPC police or bounty hunters can act on a horse-theft report (§13), the payout can rise toward
  the outlaw tier-1 rustling jobs (Barn Snipping, $25).
- Player-owned horses are never fenced here. Stealing a player's horse is out of scope (§20).

## 8. Thieves Landing stable
A livery location with `market = 'underground'`, no blip by default.

**Buying (horses, tack, services):**
- Pays in **cash or bloodmoney**, the player's choice per purchase.
- Price = list price × the `underground` **buy** multiplier from grumpy-reputation: infamous players pay down to
  **×0.75**, honorable players up to **×1.5** (doctrine `pricing.md` §2). That is the reverse of legal stables (owner).
- **Bloodmoney costs ×1.30** on top (owner). This is the wash fee: spending dirty money here is never as cheap as
  spending clean money.
- Optional **forged papers** at checkout (owner). **Proposed fee:** 25% of the horse's list price, in the same
  currency as the purchase (so ×1.30 when paid in bloodmoney).

**Why it can't be a laundry:** a horse bought with bloodmoney and forged papers costs about 1.3 × (1.0 + 0.25) ≈ 1.6×
list in bloodmoney before standing, and a legal stable buys it back at the appraisal (50% of list at best, before
the legal sell multiplier, which cuts infamous players further). That loses more than half the money, which is worse
than any laundering cut. Without papers it can't be sold legally at all.

**Selling here:** Thieves Landing buys any horse (papered or not) at fence prices for bloodmoney, under the fence
cap in §7.3. Papered horses get the normal appraisal × `underground` sell multiplier, paid in bloodmoney.
*(v1.1.0: until the phase 3 fence rework, every owned horse sold there gets the appraisal × `underground` sell
multiplier in bloodmoney, papered or not.)*

**Wagons at Thieves Landing (owner, 2026-11-06):** the same keeper sells wagons (owner gave a wagon preview and
spawn point), same market, accounts and ×1.30. Wagons have no papers, so a wagon bought there with bloodmoney can be
traded in at a legal yard for cash: neutral standing pays 1.30 W and gets 0.50 W back (−62%), worse than laundering.

**Built in v1.1.0 (phase 2), choices made while building (Claude; the sale cap is owner-approved, the rest not yet):**
- **Sale cap (owner-approved 2026-11-07):** every livery sale (horse, wagon trade-in) pays at most `Config.Money.sellCap` (0.70) × what the same
  player would pay to buy it there (rsg-stores uses the same 0.70). Without it an honorable player buys at ×0.75 and
  sells at ×1.5, a profit loop.
- **Thieves Landing registers nothing:** claiming a wild horse there gives no papers and charges no fee; a foal born
  there has no papers even if both parents do.
- **Not repriced by standing:** player-to-player sales and gift fees (a deal between players), race entry fees and
  prizes, field repairs, hunting-cart sales, paid training sessions (removed in phase 4).
- Selling at Thieves Landing for bloodmoney counts as earning blood money for grumpy-reputation (`blood_money`).

## 9. Training

### 9.1 Stats
Trainable stats are applied as attribute **bonus ranks**, the same layer rsg-stables uses now (tack bonuses never
overwrite a breed's base). Attribute IDs from `data/rdr3-native-enums/PedAttribute__AttributeType.md`:

| Stat | Attribute | Drill |
|---|---|---|
| Health | `PA_Health = 0` | **Conditioning**: ride a set distance with set elevation climbed (hill work) |
| Stamina | `PA_Stamina = 1` | **Endurance**: cover a distance in the window without the stamina core emptying |
| Courage | `PA_Courage = 3` | **Spook course**: ride past gunfire/spook points without being thrown or bolting (uses the existing spook system) |
| Agility (new) | `PA_Agility = 4` | **Jumps and turns**: clear jump markers and slalom gates |
| Speed | `PA_Speed = 5` | **Sprints**: hold a full gallop for set times, or beat a timed straight |
| Acceleration | `PA_Acceleration = 6` | **Starts**: reach gallop from a standstill within a time, several times |

Levels stay as now: XP thresholds `{100, 250, 450, 700, 1000}`, one bonus rank per level, max 5.

### 9.2 Passive XP (everyone)
There is **no self-serve training** (owner). Players without a trainer improve their horse only by riding it:
- Every **5 minutes of active riding** (proposed), a **random trainable stat** gains XP (proposed 10) and **bonding**
  rises (proposed +1 on the 0–100 scale).
- **Active riding** = mounted on your own active horse and covering ground above a walk, judged from server-side
  position samples (the `trainingRideTick` method). Standing still, AFK circles in place and teleports (above
  `maxSpeed`) don't count.
- Small on purpose (owner). **Cap (owner):** passive XP raises a stat to **level 2** at most; levels 3–5 need a
  trainer, so riding alone never makes trainers pointless. The random pick skips stats already at the cap; once every
  stat is at level 2, riding still raises bonding but gives no stat XP.
- Replaces the current distance-based `riding` XP and the paid stable session (`Config.Training.session`, the NUI
  minigame), which are both removed.

### 9.3 Drills (trainers only)
Drills are run by a **trainer**: on-duty staff or the owner of a grumpy-pob stable business (§10).
1. The customer requests a drill at the business and picks a stat. The trainer accepts it and picks a course. The
   horse must be the customer's active, living horse, mounted, near the business.
2. A **drill window** starts (proposed 10 minutes). The customer's NUI shows the goals and progress, with no
   minigame. The trainer sees the same progress.
3. Goals are tracked: distance, climb and speed from **server-side position samples** of the horse. Events the server
   can't see (jumps, a spook survived) are reported by the client, checked for plausibility (the horse was moving,
   near a marker, within the window) and capped per drill.
4. At the end of the window: XP = `baseXp × goals met ÷ goals total`. The trainer must stay within range (riding
   alongside counts), or the drill pauses.
5. Cooldown per horse per stat (proposed 30 minutes real time), so a level takes several days of play.

**Courses:** laid out by **trainers and stable owners** at their business with **rsg-gizmo** (flags, jump poles,
gates, spook points), saved per business. There are no fixed livery courses.

## 10. Trainer services (POB staff)
grumpy-pob's stable business already gives its staff training requests (customer asks, staff accepts, 40% business /
60% trainer). That stays, but the trainer's 20-second progress bar becomes a real session:

- **Drills (§9.3):** the only way past the passive cap. The trainer accepts the request, picks one of the business's
  courses and stays with the rider. Price inside the doctrine band, set by the business as now.
- **Course editor:** trainers and the owner lay out and edit the business's courses with rsg-gizmo (markers per stat
  type: distance/climb waypoints, sprint straights, start lines, jump poles, slalom gates, spook points).
- **Stud service:** an owner (or the business) lists an adult stallion at the business with a stud fee. Other players
  breed their mare to it there. The fee pays the stallion's owner, less the business's cut. Stallion cooldowns apply
  as in normal breeding.
- **Farrier:** shoes become an item (new; today they're only a $0.65 tack purchase at the stable, and rsg-core has no
  horseshoe item). `horseshoes` = one set of four, a **usable item** consumed on use, which fits shoes and resets
  wear to 0:
  - **Trainers and stable owners** can use it on **any** horse within reach (a customer's), as a paid service.
  - **Owners** can use it on **their own** horse, like the brush, so buying a set from a trainer and fitting it
    yourself works too.
  - **Crafting** it will be locked to trainers and stable owners when crafting recipes are settled (owner), so every
    set traces back to the trainer job. Until then, admins or the business stock it.
  - The NPC stablehand's re-shoe (tack, $0.65) stays as the fallback for players with no trainer around.
- **Breaking for a client:** staff break a wild horse, then **transfer the claim** to a customer at the business. The
  customer pays the registration fee plus the trainer's fee.
- **Vet:** staff can use horse medicine and revivers on a customer's horse (the item use already exists; staff get a
  better effect, proposed +25%).

Every service is paid in **cash** (POB accounts never take bloodmoney).

## 11. Aging and lifespan
Ages count in **real days since birth** (foals) or since the horse's starting age (bought horses). The server runs
`Config.Timescale = 4` in rsg-weather, so 1 game day = 6 real hours and 180 real days ≈ 2 game years.

| Stage | Real days | Rules |
|---|---|---|
| Young | 0 – 14 | Can't breed; normal riding |
| Adult | 14 – (lifespan − 40) | Prime; breeding window |
| Old | last ~40 days | Can't breed; stamina core cap falls each day to `oldMinStamina` (40%) |
| Death | lifespan | Dies of old age; can't be revived or insured back |

- **Lifespan** is rolled per horse, hidden, **160–200 days** (average 180). Warnings start **14 days** before the end.
- **Foals** start at day 0. Bought horses start at a **random adult age** (proposed 14–60 days), and the appraisal
  already prices age (young ×0.8, adult ×1.0, old ×0.6), so an older shop horse is cheaper but has fewer years left
  (shown on the buy card as an age, not a lifespan).
- Existing horses keep their current age at migration but get a fresh lifespan roll.

## 12. Wagons
Everything in rsg-wagons 3.0.0 carries over: catalogue and 3D preview, My Wagons, condition and trade-in, storage
stash per wagon, one wagon out, call and flee, wagon blip, field and yard repair, hunting cart. (The chop shop is not
in rsg-wagons 3.0.0; see §20.)

**Teams:** every wagon spawns with its own draft animals, as now. No hitching your own horses (owner).

**Rental (new):**
- At a livery with the `rentals` tab, pick a wagon from a short rental list (carts, freight wagons, buggies;
  no coaches, proposed).
- Pay a **fee** for a time window plus a **deposit**. The rental behaves like an owned wagon (storage, call, repair)
  but can't be renamed, customized or sold.
- Return it to **any** livery before the window ends: the deposit comes back, less a damage charge at the yard repair
  rate.
- Late, abandoned, chopped or destroyed: the deposit is kept. Anything left in its storage when the rental ends is
  lost (the storage is cleared), and the player is warned first.
- One rental at a time, and only if the player has no owned wagon out.

## 13. Horse theft and the law
- **Detecting theft (server-confirmed):** when a player mounts or leads away a **local horse** (an ambient NPC-owned
  horse, not wild and not player-owned), the client reports it and the server opens a grumpy-law incident with crime
  `horse_theft` (new `Config.Crimes` entry, proposed `hot = 45`, `victimDelay = {20, 40}`, `escapeMult = 0.5`).
  Witnesses and reports work as for grumpy-wagonloot. **The natives that tell a local horse from a wild one still
  need to be looked up** (§20).
- When the horse is fenced, the incident is marked succeeded (`MarkSucceeded`), which feeds grumpy-law's escape bonus.
- When nobody is on duty, grumpy-law's `crimeReported` event is where NPC police or bounty hunters will plug in. Once
  they do, the fence payout in §7.3 can be raised.

## 14. Integrations
| Resource | What grumpy-livery provides or uses |
|---|---|
| grumpy-pob | Keep the server exports it calls: `RegisterStable`, `RemoveStable`, `MoveHorses`, `GetActiveHorse`, `CanTrainHorse`, `TrainHorse`, client `OpenStable`, and the `restrictJob` / `maxHorses` / `capExempt` behaviour. grumpy-pob's `server/stable.lua` and `client/interact.lua` move from `rsg-stables` to `grumpy-livery` and gain drill sessions and the §10 services |
| grumpy-reputation | `GetPriceMultiplier(src, 'legal'\|'underground', 'buy'\|'sell')` on every purchase and sale. Its payout hook reason `rsg-stables-horse-fence` becomes `grumpy-livery-horse-fence` (update its config) |
| grumpy-law | `OpenIncident`, `MarkSucceeded` for horse theft (§13) |
| grumpy-wagonloot | It treats wagons with state bag `rsgWagonId` as player-owned. Keep setting `rsgWagonId` (and set it on rentals too), or change both together |
| rsg-inventory | Saddlebag and wagon stashes (keep the `wagon_<id>` and horse stash names so contents survive migration) |
| rsg-core | Usable items: existing horse items, plus **`horseshoes`** (new: one set, consumed on use; add to `shared/items.lua` as a `[Territories]` customization). No papers item |
| rsg-target | Horse options, including **Check papers** |
| rsg-gizmo | Trainers and owners placing drill course markers |
| Compatibility | Provide `exports['rsg-stables']` / `exports['rsg-wagons']` names? No: no other resource on the server calls them except grumpy-pob, which is updated in the same release |

## 15. Prices
All from `doctrine/pricing.md`; bands commented in config. Existing repriced values carry over unchanged.

| Item | Value | Band / note |
|---|---|---|
| Horses | as now: working/draft/riding $15–35, mid-grade $50–110, elite $125–250 | pricing.md horses |
| Tack | as now | pricing.md tack |
| Rename / insurance / revive / breeding / coat | $1 / $3 / $5 / $5 / $2 | stable services |
| Trainer drill | business sets $1–25 (default $3) | grumpy-pob `Training` (no self-serve training) |
| Wild horse registration | **$0.50** (approved) | stable services, scaled down (paperwork) |
| Forged papers | **25% of list** (approved), ×1.30 in bloodmoney | Laundering service; §8 shows it never beats a wash |
| Wild horse sale | breed price × 0.30 × legal sell mult, **cap 2/day** (approved) | Below legal tier 1 ($15–18) per day |
| Fence (stolen local) | **$0.50–2.00 flat by class** (approved) × underground sell mult, cap 3/day | Below outlaw tier 1 until consequences exist |
| Wagons | as now: carts $10–20, wagons $15–35, buggies $25–45, coaches $65–130 | pricing.md wagons |
| Wagon rental fee | **5% of the wagon's price per real hour, minimum $2** (owner) | $2 ≈ two deer at the trapper, a few minutes' work. New pricing.md row |
| Rental deposit | **25% of the wagon's price** (owner) | Refundable, so not a sink |
| Stud fee | owner sets, **cap $10** | Twice the stable breeding fee |
| Horseshoes (item) | business sets; NPC re-shoe stays $0.65 (tack) | stable services; crafting recipe later |

Thieves Landing: every price × underground buy multiplier, × 1.30 when paid in bloodmoney.

## 16. Security
Per `conventions/security.md`:
- Every buy, sell, rent, return, claim, train, breed and transfer runs on the server: prices are read from server
  config, never from the client. Market, multiplier and account are decided on the server.
- Distance checks to the livery keeper (server-side ped coords from config) and to the horse/wagon (server-side
  entity coords).
- Drill progress: positions sampled on the server; client-reported events checked for plausibility and capped;
  speeds above `maxSpeed` treated as teleports and ignored (as now).
- Wild horse claim and sale use the server's own record of who broke which horse.
- Fence and wild-sale caps counted per citizenid in the DB, so they survive restarts and relogs.
- Rate limits on every callback (`ActionCooldown`, as rsg-wagons does now).
- Papers: forged/genuine flag only ever set by the server.

## 17. Database and migration
New tables (prefix `grumpy_livery_`), created automatically on start:
- `grumpy_livery_horses`: `rsg_stables_horses` columns + `papers` (`genuine`/`forged`/`none`), `born_at`,
  `lifespan_days`, `origin` (`shop`/`foal`/`wild`/`underground`).
- `grumpy_livery_breeding`, `grumpy_livery_races`: same as the rsg-stables tables (+ `stud_fee`, `stud_owner` on
  breeding).
- `grumpy_livery_wagons`: `player_wagons` columns + `rental_until`, `deposit` (NULL for owned wagons).
- `grumpy_livery_stud`: listed stallions per business.
- `grumpy_livery_courses`: trainer course markers per business.
- `grumpy_livery_limits`: daily counters (wild sales, fence sales) per citizenid.

`migrate.sql` (run once by hand, safe on an empty DB): copies rows from `rsg_stables_horses`, `rsg_stables_breeding`,
`rsg_stables_races` and `player_wagons` if they exist, sets `papers = 'genuine'`, `origin = 'shop'`, keeps
`created_at` as `born_at` minus a random adult start age, rolls `lifespan_days`, and leaves the old tables untouched.
Stash names are kept so saddlebag and wagon contents carry over. The recipe gets the install SQL; prod starts empty.

## 18. Config outline
```lua
Config.Locale, Config.Debug
Config.Liveries = { { name, label, coords, preview, blip, market = 'legal'|'underground',
                      tabs = { horses, wagons, rentals, fence }, accounts = { 'cash' } | { 'cash','bloodmoney' } } }
Config.Money = { legalAccount = 'cash', bloodmoneyMarkup = 1.30, reputation = true }
Config.Papers = { registerFee = 0.50, forgedPercent = 0.25, showRadius = 5.0 }
Config.WildSale = { enabled, wildPercent = 0.30, dailyCap = 2, cooldown }
Config.Fence = { enabled, classPrice = { draft = 0.5, riding = 1.0, mid = 1.5, elite = 2.0 }, dailyCap = 3, cooldown = 1200 }
Config.Theft = { enabled, crime = 'horse_theft' }
Config.Training = { stats, levelXp, bonusPerLevel,
                    passive = { everySec = 300, xp = 10, bonding = 1, maxLevel = 2, minSpeed, maxSpeed },
                    drills  = { windowSec = 600, cooldownSec = 1800, baseXp, trainerRange } }  -- courses live in the DB
Config.Aging = { youngUntil = 14, oldFor = 40, lifespan = { 160, 200 }, warnDays = 14, oldMinStamina = 40, shopStartAge = { 14, 60 } }
Config.Rental = { feePerHourPercent = 0.05, minFee = 2.00, depositPercent = 0.25, models = {...} }
Config.Farrier = { item = 'horseshoes', reach = 2.5, ownHorse = true, anyHorseJobs = 'POB stable staff/owner' }
Config.Stud = { maxFee = 10 }
-- plus everything carried over from rsg-stables / rsg-wagons (breeds, tack, wagons, races, spook, salvage…)
```

## 19. Build phases
1. **Fork and merge** ✅ v1.0.0, tested in game 2026-11-06. Both Territories copies in one resource, events/exports/tables renamed, one NUI page
   (two scoped UIs), one-time table copy on start + `migrate.sql`, grumpy-pob 1.3.1 / grumpy-reputation 1.1.1 /
   rsg-core / rsg-radialmenu hooks. Separate keepers and duplicated call/store code stay for now (behaviour
   unchanged).
2. **Pricing and papers** ✅ v1.1.0 (2026-11-07). `server/money.lua` (markets, reputation multipliers, account choice,
   ×1.30, sale cap), papers records, Check papers card, Thieves Landing livery (horses + wagons, one keeper), forged
   papers at checkout, $0.50 registration.
3. **Selling.** Wild horse sale, fence rework with caps, horse-theft incidents (after the native lookup).
4. **Training.** Passive XP (random stat + bonding per active-riding interval, cap), agility stat, removal of the
   minigame and paid sessions. Drill tracking and NUI land here too, used by phase 7.
5. **Aging.** Lifespan rolls, stages, shop start age, migration of existing horses.
6. **Wagons.** Rentals (fee, deposit, return anywhere, expiry), `rsgWagonId` on rentals; one keeper per town with
   Horses / Wagons / Rentals tabs.
7. **Trainer services.** grumpy-pob update: drill sessions, courses with rsg-gizmo, stud, farrier, breaking transfer,
   vet. Then retire rsg-stables/rsg-wagons from the repo, recipe and live server.
8. **Audit and docs.** `audit/audit-checklist.md` (doctrine section), README.md, DOCS.md, `doctrine/compliance.md`,
   pricing.md rental band.

## 20. Open items
- **Native lookup:** how to tell a local (NPC-owned) horse from a wild one, and a jump event or check for agility
  drills. Look up in `natives/db/` and `data/rdr3_discoveries/` before coding; don't guess.
- **Inspecting papers:** should on-duty law be able to inspect a horse's papers and spot forgeries (a chance, raised by
  the forger's quality)? That would give forged papers a real risk.
- **Stealing player-owned horses:** out of scope for now.
- **Rental band:** approved (5%/h, minimum $2; deposit 25%). Add the row to `pricing.md` in phase 8.
- **Farrier animation:** no farrier/hoof animation found in `data/rdr3_discoveries/` yet (only hoof bone names).
  Search `animations/ingameanims/ingameanims_list.lua` and the decompiled scripts before phase 7.
- **Horseshoes crafting recipe:** waiting on the crafting pass; lock it to trainers and stable owners.
- **Thieves Landing location:** coords for the keeper and preview spot (the C'sky TL MLO install is still pending).
- **Chop shop:** rsg-wagons 3.0.0 has none. The brain's `source/rsg-wagons` still holds `client/chop.lua` and
  `server/chop.lua` from an older version (not loaded by its fxmanifest). Port them as a later phase if wanted, priced
  against the outlaw bands.
- **One keeper per town:** phase 1 keeps the separate stablehands and wagon-yard keepers at their old spots. Merging
  them needs in-game placement (wagon previews need room), so it moves to phase 6 with rentals.
- **Races:** keep as is, or let trainers run them as events?

## 21. Sources
- `territories-server/resources/[framework]/rsg-stables` and `rsg-wagons` (`main`): current behaviour, prices,
  grumpy-pob hooks.
- `builds/grumpy-pob/` (`server/stable.lua`, `shared/config.lua` `Config.Training`, `integrations/rsg-stables.md`).
- `builds/grumpy-law/` (`OpenIncident`, `MarkSucceeded`, `Config.Crimes`), `builds/grumpy-wagonloot/` (theft
  precedent, `rsgWagonId`), `builds/grumpy-reputation/` (`GetPriceMultiplier`, fence payout hook).
- `doctrine/README.md`, `doctrine/pricing.md` (bands, honor/infamy multipliers, job tiers).
- `data/rdr3-native-enums/PedAttribute__AttributeType.md` (attribute IDs).
- `source/rsg-weather/shared/config.lua` (`Config.Timescale = 4`).
