# grumpy-sit

Sit on chairs, stools and benches anywhere in the world through rsg-target. Replaces the base game's "E to sit" prompt.

Version 1.1.0 · Dependencies: `rsg-core`, `rsg-target` · Developer reference: [DOCS.md](DOCS.md)

## Features
- 182 chair, armchair, stool and bench models get a **Sit down** target option (hold Left Alt and aim at the seat).
- Benches have 2–3 seat spots; you take the nearest free one.
- A seat is skipped while any player or NPC is already sitting on it.
- Chairs at grumpy-gambling card tables are left alone (no Sit down there); other resources can claim chairs the same way.
- **[R] Stand up**, shown with rsg-core's text UI.
- Hides the base game's own sit prompt (prompt type 8) so there's only one way to sit.
- Client only: no server script, no database, no network events. No scan loop for props; rsg-target only checks what you aim at.

## Installation
1. Put `grumpy-sit` in `resources/[grumpy]/`.
2. Start it after rsg-core and rsg-target (`ensure [grumpy]` after `ensure [framework]` is enough).
3. No items, images or SQL.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Shows each seat spot's offset on screen for 15 s after you pick Sit, and prints the model hash |
| `Config.DisableNativeSitPrompt` | `true` | Hide the base game's sit prompt every frame |
| `Config.NativeSitPromptType` | `8` | Prompt type to hide ("sit", from rdr3_discoveries prompt types) |
| `Config.TargetDistance` | `2.0` | How close you must be to see Sit down |
| `Config.TargetIcon` | `fa-solid fa-chair` | Target icon |
| `Config.SeatTakenRadius` | `0.45` | Any ped this close to a seat spot makes it taken |
| `Config.StandControl` | `0xE3BF959B` | Stand-up key, INPUT_CONTEXT_X (R / pad X) |
| `Config.ClaimedBy` | grumpy-gambling `IsTableChair` | Resources whose client export (entity -> bool) claims a chair; claimed chairs get no Sit down |
| `Config.ClaimCacheMs` | `3000` | How long one claim answer per chair is reused |
| `Config.SeatTypes` | chair, armchair, stool, barstool, bench, shortbench | Scenario, seat spot offsets and heading per seat type |
| `Config.Models` | 182 models | Model name → seat type, or a table to override one model |

## How to use
- Walk up to a chair, stool or bench, hold **Left Alt**, aim at it, pick **Sit down**.
- Press **R** to stand up.
- You can't sit while mounted, in a vehicle, swimming or dead.

### Tuning a seat that looks wrong
Seat heights and facing are starting values. Set `Config.Debug = true`, restart, sit on the prop and read the
offsets drawn on screen. Then override that model:

```lua
Config.Models.p_chair05x = { type = 'chair', spots = { vector3(0.0, 0.1, 0.45) }, heading = 0.0 }
```

## Developer examples
```lua
if exports['grumpy-sit']:IsSeated() then
    exports['grumpy-sit']:Stand()
end
```

## Locales
en (`locales/en.json`). Copy it to add de, el, es, fr, ja, nl, pl, pt-br or ro.
