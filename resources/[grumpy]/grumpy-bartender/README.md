# grumpy-bartender

A bartender NPC that admins place in game. Players use it to order food and drink (rsg-stores), rent hotel rooms (grumpy-hotel), play the lottery (rsg-lottery) and collect loyalty rewards (rsg-loyalty).

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`
**Optional:** `rsg-stores`, `rsg-lottery`, `rsg-loyalty` (each needs the small hook in `integrations/`), `grumpy-hotel` (no hook needed)

## Features
- **`/bartenders` manager panel** (like rsg-stores' `/createshop`): lists every bartender with search, and lets admins edit, teleport to, duplicate, move or delete each one. Hotel rentals are managed in grumpy-hotel (`/hotellist`).
- Admins place bartenders with **rsg-gizmo**, or with **Use my position** to put the bartender exactly where they stand. Bartenders can also be edited through their target menu. Placed bartenders are saved in the database.
- You can also set bartenders in `Config.Bartenders`. These are read-only in game.
- You pick the **ped model**, **animation** (a scenario or an anim dict/clip) and **position** for each bartender.
- Each bartender has its own services, set per bartender:
  - **Order food & drink**: opens an rsg-stores shop, with the purchase checked by rsg-stores' own server. **Create bar shop** makes the shop for you: a buy-only rsg-stores shop at the bartender with the menu from `Config.BarShop` and no extra shopkeeper ped. You can also link an existing shop by its NPC id
  - **Rent a room**: opens the grumpy-hotel rental menu for the hotel picked in the editor. The bartender is registered as that hotel's rental point, so grumpy-hotel checks the player is standing at it
  - **Play the lottery**: opens rsg-lottery
  - **Loyalty rewards**: opens rsg-loyalty, with redeeming allowed at the bartender
  - Optional map blip
- Peds are spawned locally and only when a player is nearby. Services whose resource isn't running are hidden.
- The server checks everything: admin permission, placement distance, distance to the bartender, prices from config, and a lock against double clicks.
- NUI in the house theme (Roboto, monochrome, no vignette).

## Installation
1. Put `grumpy-bartender` in your resources folder.
2. Apply the hooks in `integrations/` for each service you want: `rsg-stores.md`, `rsg-lottery.md`, `rsg-loyalty.md`. Each one only adds code to the RSG resource. For **Create bar shop**, apply part 2 of `rsg-stores.md` as well.
3. In `server.cfg`, start it after its dependencies:
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-gizmo
   ensure rsg-stores
   ensure rsg-lottery
   ensure rsg-loyalty
   ensure grumpy-hotel
   ensure grumpy-bartender
   ```
4. Database: the tables are created automatically. To install them by hand instead, set `Config.AutoDatabase = false` and import `install.sql`.
5. No items are needed.
6. Hotels: create them with `/hotellist` (grumpy-hotel), then pick the hotel in the bartender editor. Upgrading from the old built-in hotel: `Config.Hotels` and its rentals are gone; recreate hotels in grumpy-hotel and drop the `grumpy_bartender_rentals` table (see `install.sql`).

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `SpawnDistance` | `40.0` | Distance at which bartender peds spawn |
| `TargetDistance` | `2.5` | rsg-target reach |
| `ServerDistance` | `5.0` | Server-side distance tolerance to a bartender |
| `AdminPermission` | `'admin'` | rsg-core permission for placing and editing |
| `PlaceDistance` | `10.0` | rsg-gizmo max distance |
| `ManageCommand` / `PlaceCommand` | `bartenders` / `placebartender` | Admin commands |
| `DefaultModel`, `Models` | `u_m_m_valbartender_01`, 10 bartender peds | Models admins can pick |
| `DefaultAnimation`, `Animations` | `bar_front` | Animation presets (`scenario`, `anim` or `none`) |
| `BarShop.Enabled` | `true` | Show **Create bar shop** in the editor |
| `BarShop.DeleteWithBartender` | `true` | Deleting a bartender also deletes the shop it created (never a shop you linked by hand) |
| `BarShop.Items` | beer, whisky, gin, rum, red/white wine, coffee, water, stew, bread, cooked meat | Starting menu: `{ name, price, amount? }`; no amount = unlimited stock |
| `Blip` | `blip_saloon`, `0.2` | Blip sprite and scale |
| `Bartenders` | `{}` | Static bartenders (model, animation, `vector4` coords, services) |

## How to use
**Admins**
- `/bartenders` (admin) opens the manager panel on the right of the screen, so you can still see the world.
  - **Bartender list:** search the list and click a row to show its actions: **Edit**, **Teleport** (puts you in front of the bartender), **Duplicate** (opens a new-bartender form with the same settings) and **Delete** (click twice). Bartenders from `Config.Bartenders` are marked *Config*; they can only be teleported to or duplicated.
  - **New bartender:** fill in the form, then click **Place** to position the ghost ped with the gizmo, or **Use my position** to put it where you're standing, facing the way you face. Gizmo controls: LMB or Enter to confirm, RMB or Backspace to cancel, R to switch between free and fine mode.
  - **Edit form:** **Save**, **Move** (gizmo), **Move to me**, **Delete**. The ‹ button goes back to the list.
  - **Bar shop:** tick **Create a bar shop automatically** when making a new bartender, or click **Create bar shop** next to the store ID on one that has no store. The store ID fills in by itself. Change the menu and prices later in `/createshop`.
- `/placebartender` (admin) is a shortcut straight to the new-bartender form.
- You can also target a bartender and choose **Manage bartender**.
- Coordinates of every new bartender are printed to the server console.

**Players**
- Hold Left Alt on the bartender and choose a service.
- **Rent a room**: opens grumpy-hotel's rental menu (rent, extend, renew, check out). Rooms, keys and storage are covered in the grumpy-hotel README.

## Developer examples
```lua
-- server: does this character rent a room at hotel 1? (grumpy-hotel export)
local rental = exports['grumpy-hotel']:GetRental(citizenid, 1)

-- server: all bartenders
for _, b in ipairs(exports['grumpy-bartender']:GetBartenders()) do print(b.id, b.label) end
```

## Locales
Ships with `en`. Other languages fall back to English; copy `locales/en.json` to add more (`setr rsg:locale "xx"`).
