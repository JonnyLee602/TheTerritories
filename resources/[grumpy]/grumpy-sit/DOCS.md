# grumpy-sit — developer docs

## Contents
1. Architecture
2. Data formats
3. Exports
4. Events
5. Integration
6. Persistence
7. Security model
8. Database
9. How-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Client-only resource, rsg-core locale loader |
| `shared/config.lua` | Seat types, seatable models, stand key, native prompt toggle |
| `client/client.lua` | Registers the rsg-target model option, seats/stands the player, hides the native sit prompt |
| `locales/en.json` | Target label, stand hint, seat taken message |

**Flow:** at start every `Config.Models` entry is resolved to `{ scenario hash, spots, heading }` and the model names are
registered once with `exports['rsg-target']:addModel`. Choosing **Sit down** gives `data.entity`; the client works out
each seat spot with `GetOffsetFromEntityInWorldCoords`, drops spots with a ped within `Config.SeatTakenRadius`
(`GetGamePool('CPed')`, only on select), and runs `TaskStartScenarioAtPosition` on the nearest free spot (same call
shape as rsg-theatre's audience seats). While seated, a per-frame thread watches the stand key and ends the
seated state if the ped leaves the scenario (ragdoll, death, another script).

**Performance:** no server code and no network traffic; the game syncs the seated ped like any other animation.
Two per-frame client threads: the native prompt blocker (one native call per frame) and the stand-key watcher (only
while seated). No prop scanning; rsg-target's raycast only runs while the player is targeting.

## 2. Data formats
```lua
Config.SeatTypes.<name> = {
    scenario = 'PROP_HUMAN_SEAT_CHAIR', -- scenario name (PROP_HUMAN_SEAT_*)
    spots    = { vector3(x, y, z), ... }, -- offsets in the prop's own space: x right, y forward, z up
    heading  = 180.0,                    -- added to the prop's heading
}
Config.Models.<model> = '<seat type>'                                    -- or
Config.Models.<model> = { type = 'chair', spots = {...}, heading = 0.0, scenario = '...' } -- per-model override
```

Value sources: models from `data/rdr3_discoveries/objects/object_list.lua`; scenarios from
`data/rdr3_discoveries/animations/scenarios`; prompt type 8 from
`data/rdr3_discoveries/graphics/HUD/prompts/prompt_types/README.md`; `_UI_PROMPT_DISABLE_PROMPT_TYPE_THIS_FRAME`
`0xFC094EF26DD153FA` from `natives/db/HUD.md`; INPUT_CONTEXT_X `0xE3BF959B` from `data/rdr3_discoveries/Controls`.

## 3. Exports (client)
| Export | Returns | Description |
|---|---|---|
| `IsSeated()` | boolean | True while the player is sitting through grumpy-sit |
| `Stand()` | — | Stands the player up (no-op when not seated) |

## 4. Events
None registered by this resource. It listens to `RSGCore:Client:OnPlayerUnload` (stands the player up).

## 5. Integration
Another resource that needs the player upright (cutscenes, arrests, minigames):
```lua
if GetResourceState('grumpy-sit') == 'started' and exports['grumpy-sit']:IsSeated() then
    exports['grumpy-sit']:Stand()
end
```
Props a resource seats players on itself (barber, theatre, gambling tables) are left out of `Config.Models` so the two
don't fight. Remove a model from the list if another script starts using it.

## 6. Persistence
None. Seated state is client memory only and is cleared on unload and resource stop.

## 7. Security model
Nothing to trust: the resource changes no money, items or server state. Sitting is a local animation.

## 8. Database
None.

## 9. How-tos
- **Add a model:** add `p_model = 'chair'` (or another type) to `Config.Models`. Use only names from `object_list.lua`.
- **Fix a seat:** `Config.Debug = true`, sit, read the drawn offsets, then add a per-model override table.
- **Keep the base game prompt:** `Config.DisableNativeSitPrompt = false`.

## 10. Troubleshooting
| Problem | Cause / fix |
|---|---|
| Player floats or sinks into the seat | Tune that model's `z` offset (debug mode) |
| Player faces the wrong way | Set that model's `heading` (try `0.0` instead of `180.0`) |
| No Sit down option on a chair | Model isn't in `Config.Models`; check its name with rsg-target debug |
| "Somebody is already sitting there" on an empty bench | Lower `Config.SeatTakenRadius` or fix the spot offsets |
| Other base-game prompts disappeared | Prompt type 8 covers them too; set `Config.DisableNativeSitPrompt = false` |
| R does nothing while seated | Change `Config.StandControl` to another control hash from `data/rdr3_discoveries/Controls` |
