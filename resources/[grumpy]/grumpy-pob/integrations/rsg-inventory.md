# rsg-inventory patch (grumpy-pob)

Three small additions. They only add code; existing behaviour is unchanged.
These are local changes to an RSG resource: re-apply after updating rsg-inventory, or offer them upstream.

| Change | Needed for |
|---|---|
| Refresh the core copy when items are added | Custom recipe items (without it the inventory doesn't know `pob<id>_<n>` items and drops them) |
| `stashClosed` event | Stock box: items become shop stock the moment the box closes (without it they move the next time it opens) |
| Full image URLs | Custom item images uploaded to Fivemanage |

## server/main.lua

1. Right after `local RSGCore = exports['rsg-core']:GetCoreObject()` (line 1) add:

```lua
-- Items added at runtime by other resources (rsg-core AddItem) need a fresh core copy
AddEventHandler('RSGCore:Server:UpdateObject', function() RSGCore = exports['rsg-core']:GetCoreObject() end)
```

2. Replace `local function OnClosed(src)` with:

```lua
local function OnClosed(src)
    local id = OpenInv[src]
    OpenInv[src] = nil
    if id then
        SaveStash(id)
        CleanupDropIfEmpty(id)
        if type(id) == 'string' then TriggerEvent('rsg-inventory:server:stashClosed', src, id) end -- server-only
    end
end
```

## server/compat.lua and server/shops.lua

Right after `local RSGCore = exports['rsg-core']:GetCoreObject()` (line 1) of **each** file add the same line:

```lua
AddEventHandler('RSGCore:Server:UpdateObject', function() RSGCore = exports['rsg-core']:GetCoreObject() end)
```

## html/app.js

Replace the `imgSrc` line (near the top, `const imgSrc = ...`) with:

```js
const imgSrc = (it) => {
    const img = it.image || `${it.name}.png`;
    return /^(https?|nui):\/\//.test(img) ? img : state.imagePath + img;
};
```

## Check it worked
- Approve a custom recipe, craft it: the item shows its own name and picture in the inventory.
- Stock the shelves: close the box and the items show under the manager's **Stock** tab straight away.
