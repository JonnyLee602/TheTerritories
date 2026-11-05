# grumpy-bartender — Documentation

Guide for server owners and developers. For features and installation see [README.md](README.md).
This is a community script and is not supported by the RSG authors.

## Contents
1. Architecture
2. Data formats
3. Server exports
4. Client exports
5. Events & callbacks
6. Integration hooks (rsg-stores / rsg-lottery / rsg-loyalty)
7. Saving & persistence
8. Security model
9. Database
10. Server owner guide
11. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | Models, animations, static bartenders, distances, commands |
| `server/server.lua` | Bartender registry (config + DB), admin create/update/move/delete, sync, integration registration (rsg-stores, rsg-loyalty, grumpy-hotel rental points), `/placebartender` |
| `client/client.lua` | Sync, distance-gated local peds, animations, rsg-target options, blips, NUI bridge |
| `client/placement.lua` | Admin editor + rsg-gizmo placement (ghost ped moved with `Edit`); hotel list comes from grumpy-hotel |
| `client/manager.lua` | `/bartenders` manager panel: list, teleport, duplicate, delete |
| `html/*` | NUI: admin editor view and manager view |
| `integrations/*.md` | The hooks you add to rsg-stores, rsg-lottery and rsg-loyalty |
| `locales/en.json` | All player-facing text |

rsg-gizmo's `Place()` spawns an object ghost, so it can't preview a ped. Placement spawns a local ghost ped in front of the admin and moves it with `exports['rsg-gizmo']:Edit()` instead. Moving an existing bartender uses `Edit()` on its spawned ped.

## 2. Data formats
Bartender record (server → client, `GetBartenders`):
```lua
{
  id = 'db_12' | 'cfg_<key>', dbId = 12 | nil, static = false | true,
  label = 'Smithfield\'s Saloon', model = 'u_m_m_valbartender_01', animation = 'bar_front',
  x = 0.0, y = 0.0, z = 0.0, h = 0.0,                 -- ped coords (GetEntityCoords); spawned at z - 1.0
  services = { store = 3 | false, autoStore = true | nil, hotel = 1 | false (grumpy-hotel id), lottery = true, loyalty = true, blip = false },
}
```
`autoStore` is set only by the server when **Create bar shop** made the store. It is cleared if an admin changes the store id, so a shop you linked by hand is never deleted with the bartender.

Bar shop menu (`Config.BarShop.Items`): `{ name, price, amount? }`. Item names are checked against `RSGCore.Shared.Items` on the server and unknown ones are skipped with a console warning. The defaults all exist in `rsg-core/shared/items.lua`.
Animation preset (`Config.Animations`):
```lua
{ type = 'scenario', name = 'WORLD_HUMAN_BARTENDER' }
{ type = 'anim', dict = 'amb_work@world_human_bartender@pre_service@male_a@idle_a', clip = 'idle_a', flag = 1 }
{ type = 'none' }
```
Values come from `data/rdr3_discoveries`: models from `peds/peds_list.lua`, scenarios from `animations/scenarios/scenario_types_with_conditional_anims.lua`, the anim dict and clip from `animations/ingameanims/ingameanims_list.lua`, and the blip sprite from `useful_info_from_rpfs/textures/blips/README.md`.

Hotels, rooms, rentals, keys and stashes belong to **grumpy-hotel** (see its DOCS.md). A bartender only stores the hotel id.

## 3. Server exports
| Export | Returns | Notes |
|---|---|---|
| `GetBartenders()` | array of records | Config and DB bartenders |
| `GetBartender(id)` | record / nil | |
| `IsNearBartender(src, id)` | bool | Within `Config.ServerDistance` |

Rental lookups moved to grumpy-hotel: `exports['grumpy-hotel']:GetRental(citizenid, hotelId?)`, `HasKey(...)`.

## 4. Client exports
None. Other resources should use the server exports.

## 5. Events & callbacks
Callbacks (rsg-core): `grumpy-bartender:server:getAll` → `{ bartenders, isAdmin }`, `grumpy-bartender:server:adminData` → `{ bartenders }` (admins only, `nil` otherwise).

Server net events (all validated, see §8), all prefixed `grumpy-bartender:server:`:
- Bartenders: `create(form, coords, heading)`, `createHere(form)`, `update(id, form)`, `move(id, coords, heading)`, `moveHere(id)`, `delete(id)`, `teleport(id)`, `createBarShop(id)`. `form.createShop = true` on `create` / `createHere` also creates the bar shop.

Client events: `grumpy-bartender:client:sync(list)`, `:openEditor`, `:editorStore(id, storeId)`, `:openManager`, `:managerRefresh`, `:teleport(pos, heading)`.

## 6. Integration hooks
| Service | Without the hook | Hook adds |
|---|---|---|
| rsg-stores (part 1) | Option fails ("not available") | Server `SetShopAccessPoint(key, npcId, coords)` / `RemoveShopAccessPoint(key)`, client `OpenShop(npcId, origin)` |
| rsg-stores (part 2) | **Create bar shop** fails; link shops by id instead | Server `CreateShop(data)` → npcId, `DeleteShop(npcId)`, `ShopExists(npcId)`; model `'none'` = no shopkeeper ped |
| rsg-lottery | Option fails | Client `OpenLottery()` |
| rsg-loyalty | Menu opens, but redeeming fails (too far) | Server `SetRedeemPoint(key, coords)` / `RemoveRedeemPoint(key)` |
| grumpy-hotel | No hook needed | Server `SetRentalPoint(key, hotelId, coords)` / `RemoveRentalPoint(key)`, client `OpenRental(key)`, client `GetHotels()` for the editor list |

grumpy-bartender registers access points with the key `grumpy-bartender:<id>` when it starts and whenever a bartender is created, edited, moved or deleted. It also re-registers them when rsg-stores, rsg-loyalty or grumpy-hotel restarts. The hooks drop a resource's points when that resource stops. All calls are wrapped in `pcall`, so a missing hook never errors; set `Config.Debug = true` to see which hooks fail.

## 7. Saving & persistence
- Placed bartenders: `grumpy_bartenders`. They load on start and are synced to all clients after every change.
- Rentals and room storage are saved by grumpy-hotel. The old `grumpy_bartender_rentals` table and `hotel_<hotel>_<citizenid>` stashes from the built-in hotel are no longer used.

## 8. Security model
- Admin events re-check `HasPermission(src, Config.AdminPermission)`. Static bartenders can't be changed. The manager panel's data callback returns nothing to non-admins.
- **Use my position** / **Move to me** send no coordinates: the server reads the admin's own ped position and heading. Teleport is approved by the server and then carried out by the admin's client.
- Placement uses `rsg-gizmo:IsPlacementValid` and the heading is sanitised. Model and animation must be in config. The label is stripped of `<>"'` and capped at 50 characters, and the store id must be a positive integer.
- The hotel id must be a positive integer. Renting is validated by grumpy-hotel, which only allows it within `RentalDistance` of the position this bartender registered.
- Purchases, lottery tickets, loyalty redemptions and room rentals are validated by those resources' own servers. The hooks only add allowed locations.
- Target `canInteract` checks (admin flag, resource running) are cosmetic only. The server checks every action again.

## 9. Database
```sql
grumpy_bartenders (id PK, label, model, animation, x, y, z, h, services JSON, created_by, created_at)
```
(`grumpy_bartender_rentals` from older versions is unused and can be dropped.)

## 10. Server owner guide
- **Rent rooms at a bartender:** create the hotel in game with `/hotellist` (grumpy-hotel), then pick it under *Hotel* in the bartender editor and save.
- **Bar food & drink (automatic):** with part 2 of the rsg-stores hook applied, tick **Create a bar shop automatically** when making a bartender, or click **Create bar shop** in its editor. You get a buy-only shop named after the bartender (`bar_<id>` internally), placed at the bartender, with no shopkeeper ped and the menu from `Config.BarShop.Items`. Edit items and prices afterwards in `/createshop`. Changing `Config.BarShop.Items` only affects shops created after that.
- **Bar food & drink (manual):** create an rsg-stores shop (`/createshop`) stocked with your food and drinks, then put its NPC id in the bartender's *store ID* field.
- **Change a bartender's look:** add the model to `Config.Models` or an animation preset to `Config.Animations`, restart, and pick it in the editor.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| Food/lottery option says "not available" | Apply the hook in `integrations/` and restart that resource. Check the store id exists |
| Loyalty redeem says too far | Apply `integrations/rsg-loyalty.md` |
| Ped invisible or not spawning | Model not valid. Use one from `peds/peds_list.lua` and add it to `Config.Models` |
| Ped floats or sinks | Move it with **Manage → Move** in fine mode |
| "Placement tool is busy" | rsg-gizmo isn't started, or another gizmo session is active |
| No "Rent a room" option | grumpy-hotel isn't started, or no hotel is picked in the editor |
| Hotel list in the editor is empty | No hotels exist yet (`/hotellist`), or grumpy-hotel isn't started |
| "No rooms are for rent here right now" | The picked hotel was deleted. Pick another one |
| `/bartenders` says "You do not have permission" | Your account needs `Config.AdminPermission` in rsg-core |
| Teleport lands on the bar counter | The point 1.5 m in front of the bartender is on the counter; step off, or use **Move** to turn the bartender |
| "Could not create the shop" | rsg-stores isn't started or part 2 of `integrations/rsg-stores.md` isn't applied |
| "This bartender already has store N" | Clear the store ID (or delete that shop) before creating a new bar shop |
| A bar shop ped appears behind the bar | The rsg-stores client line for `model ~= 'none'` (part 2) is missing |
| Bar shop is missing items | That item name doesn't exist on your server; check the console warning |
