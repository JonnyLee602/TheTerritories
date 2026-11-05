# rsg-consume patch (grumpy-pob)

Lets a custom item (for example "Grumpy's Rye", `pob3_7`) use its base item's eat/drink animation, prop and effects
(`glass_whisky`). Using it removes the custom item; a refund gives the custom item back; the base item's return item
(`emptybottle` etc.) is given as usual.
These are local changes to an RSG resource: re-apply after updating rsg-consume, or offer them upstream.

## server/server.lua

1. Right after `local RSGCore = exports['rsg-core']:GetCoreObject()` add:

```lua
-- Items added at runtime by other resources need a fresh core copy (refunds check RSGCore.Shared.Items)
AddEventHandler('RSGCore:Server:UpdateObject', function() RSGCore = exports['rsg-core']:GetCoreObject() end)
```

2. Below the `for category, items in pairs(config.Consumables) do ... end` loop add:

```lua
---Registers alias (an item another resource added) to consume exactly like base.
local function categoryOf(base)
    for category, items in pairs(config.Consumables) do
        if items[base] then return category end
    end
    return nil
end

exports('RegisterAlias', function(alias, base)
    local category = categoryOf(base)
    if type(alias) ~= 'string' or not category then return false end
    RSGCore.Functions.CreateUseableItem(alias, function(source, item)
        local src = source
        if not RSGCore.Functions.GetPlayer(src) then return end
        local active = pending[src]
        if active and active.expires > GetGameTimer() then return notifyBusy(src) end
        if not exports['rsg-inventory']:RemoveItem(src, alias, 1, item and item.slot, 'rsg-consume') then return end
        pending[src] = { item = base, refund = alias, category = category, expires = GetGameTimer() + CONSUME_TIMEOUT }
        TriggerClientEvent('rsg-consume:client:consume', src, base, category)
    end)
    return true
end)
```

3. In `rsg-consume:server:finish`, change the refund line

```lua
        addItem(src, active.item, 'rsg-consume-refund')
```

to

```lua
        addItem(src, active.refund or active.item, 'rsg-consume-refund')
```

## Check it worked
Craft a custom drink and use it: the base drink's animation plays and the custom item is used up.
