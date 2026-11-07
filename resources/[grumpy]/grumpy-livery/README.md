# grumpy-livery

The Territories' livery: buy, stable, care for, train and breed **horses**, and buy, store and use **wagons**, in one
resource with one NUI. Version **1.0.0** is phase 1 of [DESIGN.md](DESIGN.md): a straight merge of the Territories
copies of **rsg-stables 3.4.0** and **rsg-wagons 3.0.0** that behaves exactly as they did. Papers, the Thieves Landing
stable, riding drills, aging, rentals and trainer services follow in later phases.

Replaces `rsg-stables` and `rsg-wagons`: **don't run them alongside it.**

**Credits & licence:** forked from [rsg-stables](https://github.com/Rexshack-RedM/rsg-stables) and
[rsg-wagons](https://github.com/Rexshack-RedM/rsg-wagons) by the RSG Framework authors. Distributed under the
GNU GPLv3 (see `LICENSE`), as the originals are.

---

## Dependencies
- rsg-core, rsg-target, rsg-inventory (saddlebag and wagon stashes), oxmysql
- Optional: grumpy-pob (stable businesses), grumpy-reputation (fence payouts), grumpy-wagonloot (treats `rsgWagonId` wagons as player-owned), rsg-radialmenu (lantern entry)

## Installation
1. Put `grumpy-livery` in `resources/[grumpy]/`.
2. Remove (or stop) `rsg-stables` and `rsg-wagons`.
3. **Database:** tables are created on start (`grumpy_livery_horses`, `grumpy_livery_breeding`, `grumpy_livery_races`,
   `grumpy_livery_wagons`). Manual setup: `install.sql`.
4. **Moving from rsg-stables / rsg-wagons:** nothing to do. On start, if the grumpy-livery tables are empty and the old
   tables (`rsg_stables_horses`, `rsg_stables_breeding`, `rsg_stables_races`, `player_wagons`) exist, their rows are
   copied once, ids kept, so saddlebags (`horse_<id>`) and wagon storage (`wagon_<id>`) keep their contents. The old
   tables are left alone. `migrate.sql` does the same by hand.
5. **Items** in `rsg-core/shared/items.lua` (names configurable): `horse_apple`, `horse_carrot`, `horse_brush`,
   `horse_stimulant`, `horse_medicine`, `horse_reviver`, `horse_lantern` (all **`useable = true`**) and `fullbucket`.
6. **Hooks in other resources** (Territories copies already have them, marked `[grumpy-livery hook]`):
   - `rsg-core/server/player.lua`: the `grumpy_livery_*` tables in `playertables`, so deleted characters lose their horses and wagons.
   - `rsg-radialmenu/config.lua`: the lantern entry calls `grumpy-livery:client:useLantern`.
   - `grumpy-pob` 1.3.1+ and `grumpy-reputation` 1.1.1+ use grumpy-livery's names.
7. `server.cfg`, after its dependencies:
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-target
   ensure rsg-inventory
   ensure grumpy-livery
   ```

---

## Features

### Horses

- **Multiple stables** – Valentine, Blackwater, Rhodes, Saint Denis and Strawberry out of the box, each with a stablehand NPC, map blip and horse preview spot. Add your own in config.
- **Buy menu** – 100+ horse breeds/coats with health, stamina, speed and acceleration ratings, class, handling, descriptions and price-band filters.
- **Ownership limits** – max horses per player, and max horses each player can keep at one stable.
- **Stallions & mares** – choose the gender when buying; foals get a random one.
- **Rename & insure** – rename horses for a fee; insure them so a dead horse can be revived/replaced.
- **Release dead horses** – lay a deceased horse to rest from the stable menu to free up its slot; its saddlebags must be emptied first with **Empty Saddlebags** (the only option for horses that died of old age).
- **Give or sell to a player** – hand a stabled horse to someone standing next to you, free or for an asking price they must accept (and be able to afford). Saddlebags must be emptied first so nothing is handed over by accident.
- **Tack customisation** – blankets, saddles, saddlebags, horns, stirrups, bedrolls, manes, tails, masks, mustaches, holsters, bridles, each item individually priced. Styles swap on the preview horse instantly (no respawn) with a menu sound while cycling. The holster is optional: without one, long guns stay on the player's back instead of going onto the horse (`Config.HolsterStoresLongarms`). Categories can be marked `required`.
- **Horseshoes** – a horse without shoes is noticeably slower and tires faster. Shoes wear down with riding time (faster at a canter or gallop), with warnings as they wear thin. Once fully worn they come off and the horse stays degraded until new shoes are fitted at a stable, which resets the wear (`Config.Horseshoes`). Bought horses and foals come shod; claimed wild horses don't. The horse card shows the current shoe condition.
- **Coat customisation** – custom tint system (main coat, markings, nose, mane, tail) with quick-pick presets and a flat colour-change fee.
- **Horse needs** – hunger and thirst decay over time; starving/dehydrated horses lose health, well-fed horses slowly regenerate.
- **Feeding, watering & brushing** – via rsg-target on your active horse, or by using the feed items / brush straight from the inventory (with the hand-feed and brushing animations). The brush also works from the saddle (`Config.HorseBrushMounted`).
- **Horse actions** – a movable NUI panel (and one command per action) to make your horse **Rest**, **Sleep**, **Graze**, **Roll**, **Rear Up**, **Stay**, **Follow** you or be **Led** by the reins on foot. Resting and sleeping slowly restore stamina and health. Uses Rockstar's own horse animations.
- **Rear up on command** – press **Q** while riding to rear your horse up without being thrown.
- **Saddlebags** – each horse has its own rsg-inventory stash (weight and slots set in config), opened from the horse's target menu or the game's own **Horse Cargo (B)** prompt. Optionally (`requireSaddlebags`) the stash only opens when saddlebags are fitted as tack.
- **Native prompts tidy-up** – the game's own Brush / Feed horse prompts can be hidden so only the rsg-target options are used.
- **Natural drinking** – horses drink on their own at rivers, lakes and water troughs when thirsty.
- **Natural grazing** – a hungry horse wanders to hay near you (configurable hay props) and eats.
- **Hitching posts** – a horse tied at a hitching post doesn't wander off to drink or graze (`Config.HorseHitch`).
- **Horse lantern** – fit or remove a saddle lantern with the `horse_lantern` item; it's saved with the horse's tack.
- **Aging & lifespan** – horses are Young, Adult or Old by real-life days owned. Old horses hold less stamina each day and eventually die of natural causes (no revive).
- **Bonding** – grows when you feed, water and brush your horse.
- **Horse medicine** – usable item that restores health and refills the health core.
- **Field revive** – when your horse goes down you have a short window to use a horse reviver before it dies (logging out counts as letting it die).
- **Tack stat bonuses** – saddles, stirrups, horseshoes and blankets add bonus ranks to health, stamina, speed or acceleration (per category or per item).
- **Sell horses with appraisal** – the stablehand values a stabled horse on breed, condition (health, hunger, thirst), bonding, age and training, plus a bonus if it's shod, and shows the breakdown before you sell (`Config.HorseSell.appraisal`).
- **Horse fence** – sell wild or stolen (unowned) horses to a fence NPC for blood money; add fence locations in `Config.HorseFence`.
- **Courage** – trainable, and raised by bonding, so your horse spooks less.
- **Spooking** – gunfire and explosions near your horse can make it rear up, throw you and bolt. Courage lowers the chance. A spooked horse stays skittish until you **Calm Horse** (rsg-target) or the timer runs out (`Config.HorseSpook`).
- **Field salvage** – when an uninsured horse dies out in the world its body stays for a while so you can search its saddlebags on the spot (`Config.HorseSalvage`).
- **Horse races** – checkpoint races run by the stablehands: pay the entry fee, ride your own horse through every checkpoint and beat the goal time for the prize. Timed and validated on the server, with a best-time leaderboard per race (`Config.HorseRaces`). Build routes in-game with `/raceroute`.
- **Horse training** – ride your horse or pay for training sessions at a stable to level up health, stamina, speed and acceleration.
- **Horse stimulant** – usable item giving a timed stamina fortify and optional speed boost.
- **Whistle recall** – whistle (H) to call your horse; it walks up and stops just in front of you, facing you. Teleports closer first if it's too far away, and respawns it if the game has removed it. Either way it's placed on open ground (preferring behind you) that isn't inside a building, rock or water and has a clear run to you, falling back to the nearest road (`Config.WhistleSpawnDistance`).
- **Persistent active horse** – position is saved to the database while out, so it survives logouts and resource restarts.
- **Flee horse** – send your horse away; optionally return it to the stable automatically.
- **Wild horses** – break a wild horse with the game's taming minigame, ride it to any stable and choose **Claim Wild Horse** at the stablehand to name it and register it. Validated server-side (breed must be in `Config.Breeds`, you must have broken it, claim window, distance and ownership limits).
- **Breeding** – breed a stallion and a mare (adults only) to produce a foal after one real-life day. Foals inherit the parents' averaged stats with a chance to take the better parent's. Parents are locked while breeding and rest afterwards.
- **Horse info card** – native animal info card showing horse stats.
- **Horse stats panel** – live health, stamina, hunger, thirst, bonding, cleanliness, tack and training bonuses from the **Horse Stats** target option or `/horseinfo`.
- **Store anywhere** – store your active horse at whichever stable you're at (or with `/storehorse`); it's kept there from then on (falls back to its previous stable if that stable is full for you).
- **Localisation** – en, de, el, es, fr, ja, nl, pl, pt-br, ro.
- **Auto database setup** – tables are created automatically on resource start.
- **No ox_lib** – notifications, callbacks, locales and dialogs all run on rsg-core and the resource's own NUI.
- **Version checker** – notifies you in the server console when an update is available.


### Wagons
- Yard keeper NPCs at Valentine, Saint Denis, Strawberry, Blackwater and Tumbleweed (rsg-target), full NUI catalogue with category tabs, search and capacity/slots/seats bars.
- Live 3D preview of the selected wagon with its team, orbit camera (A / D or arrows, scroll or + / −).
- Liveries and base colours picked at purchase; cargo props and lanterns picked later (**Customise Wagon**), seen by everyone.
- **My Wagons:** take out, return, rename, repair and sell; trade-in value drops when the wagon is damaged.
- Each wagon has its own storage stash (`wagon_<id>`) sized by the wagon.
- One wagon out per player; call it (**J** or `/callwagon`), send it away (`/fleewagon`), store it at any yard (hold **G**). Wagons that are out stay out across restarts and relogs.
- Field patch (`/repairwagon`, wood) and full yard repair.
- **Hunting cart:** stow carcasses and sell the load at a butcher.
- Every wagon comes with its own team: you don't hitch your own horses.

---

## Configuration
Horses: `shared/config.lua`. Wagons: `shared/wagons.lua`, plus `shared/liveries.lua`, `shared/propsets.lua` and
`shared/huntingcart.lua`. Both share the global `Config` table; the one name both had, `StoreDistance`, is
`Config.StoreDistance` for horses and `Config.WagonStoreDistance` for wagons.
Prices follow the doctrine bands in `doctrine/pricing.md` (commented in config).

### General

| Option | Default | Description |
|---|---|---|
| `Config.MaxOwnedHorses` | `8` | Max horses one player can own |
| `Config.MaxHorsesPerStable` | `20` | Max horses one player can keep at one stable |
| `Config.RenameCost` | `1` | Cost to rename a horse |
| `Config.InsuranceCost` | `3` | Cost to insure a horse |
| `Config.ReviveCost` | `5` | Cost to revive a dead insured horse |
| `Config.StoreDistance` | `8.0` | Max distance of your mount from the stable to store it |
| `Config.PaymentAccount` | `'cash'` | `'cash'` or `'bank'` |
| `Config.WhistleStopDistance` | `1.0` | How far in front of you (to the horse's nose) a whistled horse stops |
| `Config.WhistleAnim` | `'WHISTLEHORSESHORT'` | Whistle sound + animation (`'WHISTLEHORSELONG'`, `'WHISTLEHORSEDOUBLE'`, or `false` to disable) |
| `Config.WhistleTeleportDistance` | `60.0` | Beyond this distance a whistled horse is moved near you |
| `Config.HorseBrushDistance` | `4.0` | How close you must be to use the brush or a feed item from the inventory |
| `Config.HorseBrushMounted` | `true` | Allow brushing while riding |
| `Config.DebugHorseChecks` | `false` | Print why a feed/water/brush server check failed to the server console |
| `Config.HideNativeBrushFeed` | `true` | Hide the game's own Brush / Feed horse prompts |
| `Config.AllowTwoPlayersRide` | `false` | Allow a passenger on the horse |
| `Config.HolsterStoresLongarms` | `true` | Long guns are only stored on the horse when a holster is fitted. `false` = game default (any owned horse stores them) |

### Feature blocks

| Block | What it controls |
|---|---|
| `Config.ActiveHorse` | Position save interval, recall distances and login reminder for horses left out |
| `Config.HorseFeedItems` / `Config.HorseDrinkItems` | Items and how much health/stamina/hunger/thirst they restore |
| `Config.HorseStimulant` | Item, duration, stamina floor, fortify amount, speed multiplier, reuse |
| `Config.HorseNeeds` | Hunger/thirst decay rates, critical threshold, health drain and regen |
| `Config.HorseNaturalDrink` | Thirst threshold, timings, water/trough radius, trough models and max distance from the owner (`maxPlayerDistance`) |
| `Config.HorseNaturalGraze` | Hunger threshold, search radius around the player, eat time, cooldown, animation, hay prop models and max distance from the owner (`maxPlayerDistance`) |
| `Config.HorseHitch` | Stop natural drinking/grazing while hitched, hitch detection radius and hitching post models |
| `Config.HorseBrushItem` | Item required to brush (also usable from the inventory) |
| `Config.HorseLantern` | Horse lantern on/off, item name, lantern shop-item hash and how close you must be to your horse |
| `Config.HorseInventory` | Saddlebag stash on/off, max weight, slots, target distance, `nativeCargoPrompt` (B opens the stash) and `requireSaddlebags` (stash only opens with saddlebags fitted) |
| `Config.HorseBonding` | Bonding gained per feed / water / brush |
| `Config.HorseActions` | Horse actions panel on/off, `/horseaction` command, per-action commands, `/horsestop`, rest/sleep regen, the action list (animations, follow offset/speed) and the rear-up key (`rearKey`) |
| `Config.HorseFlee` | Flee delay, whether fled horses are stored, respawn distance |
| `Config.WildHorse` | Wild horse claiming on/off, registration fee, claim window after breaking, max horse distance |
| `Config.Breeding` | Cost, foal timer, same-stable, stallion + mare requirement, parent lock and cooldown, stat variance, better-parent chance |
| `Config.HorseAging` | Young/Old thresholds, lifespan, "days left" warning, minimum stamina for the oldest horses |
| `Config.HorseGive` | Give/sell to player on/off, distance, giver fee, accept timeout, max asking price |
| `Config.TackSounds` | Frontend sound played while cycling tack styles (`enabled`, `soundset`, `left`, `right`) |
| `Config.Horseshoes` | Unshod slow-down and stamina drain, how long shoes last in riding time, faster wear at speed, wear warnings, whether new horses come shod, mount reminder |
| `Config.Tack` / `Config.TackCategories` / `Config.TackItems` | Enable tack, categories (add `required = true` to force one) and individual tack items with prices |
| `Config.Coat` | Enable coat editor, colour-change fee and presets |
| `Config.HorseCard` | `/horseinfo` command name (`false` to disable) and max distance to your horse |
| `Config.HorseMedicine` | Item, heal %, refill health core, use distance, cooldown |
| `Config.HorseReviver` | Item, revive window, use distance, health after revive, bonding lost when the horse goes down |
| `Config.TackBonuses` | Bonus ranks per tack category (saddle, stirrups, horseshoes, blanket); items can set their own `bonus` |
| `Config.HorseSell` | Sell back to the stablehand on/off, % of breed price, extra per trained level, minimum price, and the `appraisal` weights (condition, bonding, age stage, shod bonus) |
| `Config.HorseSpook` | Spooking on/off, scare radius, base/min chance, throw chance, cooldown, skittish and calmed timers, bolt distance |
| `Config.HorseSalvage` | Field salvage on/off, how long the body stays, search distance |
| `Config.HorseRaces` | Races on/off, route builder command, checkpoint radius, max speed check, dismount timeout, leaderboard size, blip and the `races` list (stable, entry fee, prize, goal time, time limit, cooldown, checkpoints) |
| `Config.HorseFence` | Fence on/off, payout account (`bloodmoney`), % of breed price, cooldown, sell distance, NPC model, blip and `locations` |
| `Config.Training` | Trainable stats and attributes, XP per level, bonus per level, courage from bonding, ride XP settings and paid stable sessions (price, cooldown, rounds) |
| `Config.BuyPriceBands` | Price filters in the buy menu |
| `Config.BreedStatMax` | Max value of breed stat bars |

### Adding a stable

```lua
{
    name          = 'mystable',                -- unique id (stored in DB)
    label         = 'My Stable',
    pedModel      = `u_m_m_bwmstablehand_01`,
    pedCoords     = vector4(x, y, z, heading), -- stablehand NPC
    storeCoords   = vector4(x, y, z, heading), -- where horses are stored
    previewCoords = vector4(x, y, z, heading), -- horse preview spot
    blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
},
```

### Adding a horse breed

```lua
{
    model = `a_c_horse_arabian_white`,
    label = 'Arabian (White)',
    class = 'Race Horse',
    breed = 'arabian',
    price = 150, -- doctrine: elite mount $125-250
    handling = 'Elite',
    health = 4, stamina = 4, speed = 5, acceleration = 5, -- out of Config.BreedStatMax
    description = 'Short description shown in the buy menu.'
},
```

### Translations

Edit or add a JSON file in `locales/`. Locales are loaded by rsg-core (`@rsg-core/shared/locale.lua`). Set the language in your `server.cfg` (falls back to `ox:locale`, then `en`):

```cfg
setr rsg:locale "en"
```

---

## Usage: horses

### At the stable
Walk up to the stablehand and use **rsg-target → Manage Stable** to open the menu, where you can:
- **Buy** a horse (filter by class, breed and price).
- **Take out / store** your horses.
- **Rename**, **insure**, **revive**, **empty the saddlebags of** or **release** (dead) horses.
- **Customise tack** and **coat** (including fitting new **horseshoes** after the old ones wear out).
- **Sell Horse** – sell a stabled horse back to the stablehand.
- **Breed** a stallion and a mare and collect the foal when ready.
- **Give to Player** – give or sell a horse to someone standing next to you (empty its saddlebags first).
- **Horse Races** – shown when the stable has races configured: see the leaderboard and your best time, and start a race (you must be riding your own horse).
- **Claim Wild Horse** – shown when you've just broken a wild horse and it's with you; name it and it's added to that stable.

Each horse in the list shows its gender, stage (Young / Adult / Old, with days left near the end of its life) and health/stamina.

### With your active horse
Target your horse (rsg-target) for:
- **Feed Horse** – uses a feed item.
- **Water Horse** – uses a water item.
- **Brush Horse** – requires the brush item.
- **Horse Stats** – health, stamina, hunger, thirst, bonding and cleanliness.
- **Store Horse** – when near a stable.
- **Train Horse** – paid training session (dismounted, at a stable).
- **Flee Horse** – sends the horse away.
- **Calm Horse** – shown while your horse is skittish after being spooked.

If your uninsured horse dies in the world, target its body to **Search Saddlebags** before it disappears.
- **Horse Actions** – opens the actions panel (drag it by its title to move it; double-click the title to reset).
- **Open Saddlebags** – opens the horse's own stash (you must be standing next to it; with `requireSaddlebags` the horse must have saddlebags fitted).

### At a horse fence
Ride an unowned (wild or stolen) horse to a fence NPC from `Config.HorseFence.locations`, dismount and choose **Sell Horse** to get blood money. Your own stable horses are refused.

### Controls & commands
| Input | Action |
|---|---|
| Whistle key (`INPUT_WHISTLE`, default **H**) | Call your active horse |
| Focus horse + prompt | Show horse info card |
| Horse Cargo (**B**) next to your horse | Open its saddlebags |
| `/storehorse` | Store your active horse at the nearest stable |
| `/horseinfo` | Open the horse stats panel (`Config.HorseCard.command`) |
| **Q** while riding (`Config.HorseActions.rearKey`) | Rear up |
| `/horseaction` | Open the horse actions panel |
| `/horserest`, `/horsesleep`, `/horsegraze`, `/horsewallow`, `/horserear`, `/horsestay`, `/horsefollow` | Run a horse action directly (on foot, near your horse) |
| `/horselead` | Lead your horse by the reins |
| `/horsestop` | Stop the current horse action (or let go of the reins) |
| `/raceroute add \| print \| clear` | Admin: build a race route at your position and print it to the F8 console for `Config.HorseRaces.races` |

### Items
| Item | Use |
|---|---|
| `horse_stimulant` | Use from inventory while mounted or near your horse for a stamina/speed boost |
| `horse_apple`, `horse_carrot` | Use from inventory next to your horse (dismounted), or via **Feed Horse** |
| `horse_brush` | Use from inventory next to or riding your horse, or via **Brush Horse** |
| `fullbucket` | Used through **Water Horse** |
| `horse_medicine` | Use from inventory near your horse to restore health |
| `horse_reviver` | Use next to your downed horse within the revive window |
| `horse_lantern` | Use from inventory next to or riding your horse to fit / remove a saddle lantern (not consumed). It's saved with the horse's tack, so it stays on until removed |

---

### Wagons (`shared/wagons.lua`)


Liveries (`Config.Liveries`) and colour counts (`Config.Tints`) per model live in `shared/liveries.lua`; cargo (`Config.Propsets`) and lantern (`Config.Lanterns`) sets live in `shared/propsets.lua` — remove entries to hide them.

| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Build the table on start. `false` = import `install.sql` yourself |
| `Config.MoneyType` | `'cash'` | Money type taken for purchases and paid for trade-ins |
| `Config.MaxWagons` | `5` | Max wagons a player can own |
| `Config.SellPercent` | `0.50` | Trade-in = price × this |
| `Config.DamagedThreshold` | `90` | Condition % below this counts as damaged |
| `Config.DamagedSellModifier` | `0.5` | Damaged wagons get this fraction of the trade-in |
| `Config.WagonStoreDistance` | `15.0` | How close the player must be to the yard's preview spot to use the keeper menu / sell |
| `Config.CallKey` | `0xF3830D8E` (J) | Key to call your wagon to you (`false` = off) |
| `Config.CallCommand` / `Config.FleeCommand` | `'callwagon'` / `'fleewagon'` | Chat commands to call / send away your wagon (`false` = off) |
| `Config.CallNearDistance` | `25.0` | If the wagon is closer than this, calling just says it's nearby |
| `Config.CallRoadDistance` | `60.0` | A called wagon appears on a road within this distance, otherwise beside you |
| `Config.WagonBlip` | `enabled = true`, `style = 'BLIP_STYLE_PLAYER_COACH'`, `sprite = 'blip_player_coach'` | Map/radar blip on the wagon you have out |
| `Config.FieldRepair` | 35%, 3 x `resource_wood`, 8 s, `/repairwagon` | Temporary patch on the road (item or money) |
| `Config.YardRepair` | `$0.5` per missing % | Full repair to 100% at a yard (My Wagons → Repair) |
| `Config.HuntingCart` (`shared/huntingcart.lua`) | 20 carcasses, tarp, 12 butchers, rsg-hunting prices | Hunting cart (huntercart01): stow carcasses, sell the load at a butcher |
| `Config.StoreRadius` | `35.0` | Wagon and player must both be within this distance of a yard (keeper or preview spot) to store |
| `Config.StorePrompt` | `true` | Show a hold-to-store prompt when near a yard with your wagon out |
| `Config.StoreKey` | `0x760A9C6F` (G) | Key for the store prompt |
| `Config.StoreHoldTime` | `1000` | How long (ms) to hold the store key |
| `Config.UseDistance` | `4.0` | Distance to the wagon to open its storage |
| `Config.InteractDistance` | `3.0` | Target distance to the yard keeper |
| `Config.ActionCooldown` | `1500` | ms between shop actions per player |
| `Config.NameMaxLength` | `24` | Max wagon name length |
| `Config.Preview` | table | Camera radius/min/max, height, rotate speed, idle spin, show draft animals |
| `Config.Blip` | table | Enable, sprite (`blip_shop_coach_fencing`), scale |
| `Config.Stores` | 5 yards | `label`, `npcModel`, `npc` (vec4), `preview` (vec4: preview + spawn point), `showBlip` |
| `Config.Categories` | 5 | Category ids and Font Awesome icons for the tabs |
| `Config.Wagons` | 33 models | `label`, `category`, `price`, `weight` (kg), `slots`, `seats`, `tier` (1–4), `description`, optional `stores` |


## Usage: wagons
1. Go to a wagon yard (wagon blip) and target the yard keeper → **Browse Wagons**.
2. Pick a category or search, click a wagon to preview it. The list swaps to the wagon's details; press **Back** (or **ESC**) to return to the list.
3. Rotate with **A / D**, arrow keys or the on-screen buttons (camera row in the details panel), zoom with the scroll wheel or **+ / −**.
4. Use the **Livery** and **Colour** arrows to pick a paint scheme and base colour (only at purchase; it's permanent and applied every time the wagon is taken out) (the preview updates live), then **Purchase** → name the wagon → it's added to **My Wagons**.
5. In **My Wagons** choose a wagon → **Take Out**. It appears at the yard's preview spot.
6. Target your wagon → **Open Wagon Storage**.
6b. Target your wagon → **Customise Wagon** to pick its **Cargo** and **Lanterns** (live preview, then **Save**). Saved per wagon and seen by everyone.
6e. **Hunting Cart**: carry a carcass (or have one on your horse) to your cart → target → **Stow Carcass** (up to 20; the tarp rises as it fills). Drive to any butcher → target the cart → **Sell Cart Load** for rsg-hunting's prices, items and hunting XP.
6d. Damaged or wrecked on the road? Target the wagon → **Patch Up Wagon**, or `/repairwagon` for a wreck. Costs 3 wood (configurable) and brings it to 35% only; get it fully repaired at a yard (My Wagons → **Repair**).
6c. Target your wagon → **Send Wagon Away** (or `/fleewagon`) to send it off; press **J** (or `/callwagon`) to call it back to the nearest road. It stays out until stored, even across server restarts and relogs: after logging in, just press **J**.
7. Bring it back to any yard and store it: hold **G** on the yard prompt, target the wagon → **Store Wagon**, or use **Return Wagon** at the keeper. **Sell** a stored wagon for its trade-in value.
8. **ESC** closes the shop (from the details panel it goes back to the list first).
9. Drag any window by its title bar to move it; positions are remembered. Double-click a title bar to reset it.


---

## Changelog

### 1.0.0 (2026-11-06)
- rsg-stables 3.4.0 (Territories copy: doctrine prices, grumpy-pob registered stables and training exports) and
  rsg-wagons 3.0.0 (Territories copy: doctrine prices) merged into one resource.
- Events renamed: `rsg-stables:*` → `grumpy-livery:*`, `rsg-wagons:*` → `grumpy-livery:wagons:*` (see DOCS.md).
- Tables renamed to `grumpy_livery_*`, with a one-time copy from the old tables on start (`server/migrate.lua`).
- One NUI page: the horse UI is scoped under `#st-root`, the wagon UI under `#wg-root` (ids prefixed `wg-`).
- Version checkers removed.
