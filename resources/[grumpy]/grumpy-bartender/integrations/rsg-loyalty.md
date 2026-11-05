# rsg-loyalty hook (for grumpy-bartender "Loyalty rewards")

The loyalty menu already opens from any resource with the client event
`rsg-loyalty:client:openloyaltyUI` (grumpy-bartender passes the bartender's position so the menu closes if the
player walks away). However, the server only allows redeeming within `Config.Loyalty.MaxRedeemDistance` of a
`Config.LoyaltyLocations` NPC (`isNearLoyaltyNpc` in `server/server.lua`). Without this patch players can see
their points at the bartender, but redeeming fails with a "too far" error.

This is a local change to an RSG resource. Re-apply it after updating rsg-loyalty, or ask the RSG authors to add
the hook upstream. Don't redistribute a modified rsg-loyalty.

## server/server.lua

1. **Above** `local function isNearLoyaltyNpc(src)` add:

```lua
-- Extra redeem points registered by other resources (e.g. grumpy-bartender)
local redeemPoints = {} -- [key] = { coords = vector3, res = string }

exports('SetRedeemPoint', function(key, coords)
    if type(key) ~= 'string' or type(coords) ~= 'vector3' then return false end
    redeemPoints[key] = { coords = coords, res = GetInvokingResource() }
    return true
end)

exports('RemoveRedeemPoint', function(key)
    redeemPoints[key] = nil
end)

AddEventHandler('onResourceStop', function(res)
    for key, p in pairs(redeemPoints) do
        if p.res == res then redeemPoints[key] = nil end
    end
end)
```

2. In `isNearLoyaltyNpc`, **before** the final `return false`, add:

```lua
    for _, p in pairs(redeemPoints) do
        if #(pos - p.coords) <= maxDist then return true end
    end
```
