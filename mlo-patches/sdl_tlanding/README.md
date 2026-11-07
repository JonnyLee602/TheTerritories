# sdl_tlanding patch: grumpy-maphide

Our own add-on for the paid **C'sky / Peashooterrr Thieves Landing MLO** (`resources/[mlos]/sdl_tlanding`).
The MLO itself is paid and is never committed (`[mlos]` is git-ignored). Only our two script files live here.

It hides chosen props inside the MLO at runtime with the game's model-hide native.
The MLO's own files are not edited, apart from two lines appended to its `fxmanifest.lua`.

## What it hides
The saloon poker table top: 2 beer bottles, 3 chip stacks, cards, an ashtray. The full list with coordinates is in `grumpy_hide_config.lua`.

## Install (dev and prod; redo after any C'sky update replaces the folder)
1. Copy `grumpy_hide_config.lua` and `grumpy_hide.lua` into `resources/[mlos]/sdl_tlanding/`.
2. Append this to the end of `resources/[mlos]/sdl_tlanding/fxmanifest.lua`:
   ```lua
   -- [grumpy-maphide patch] hide props (see TheTerritories mlo-patches/sdl_tlanding)
   client_scripts { 'grumpy_hide_config.lua', 'grumpy_hide.lua' }
   ```
3. `restart sdl_tlanding` (or restart the server).

## Hiding more props
Add `{ model = '<prop>', coords = vector3(x, y, z) }` to `GrumpyHide.Props`. An optional `radius` overrides the default 0.3 m.
Set `GrumpyHide.Debug = true` to print each hide in F8.

## Undo
Remove the two manifest lines (or restore `fxmanifest.lua.orig`) and delete the two files.
