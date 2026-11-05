# rsg-stores hook (for grumpy-bartender "Order food & drink")

Unpatched rsg-stores only opens a shop from its own NPC, and the server rejects a purchase unless the player
is standing at that NPC (`isNearNpc` in `server/server.lua`). This patch adds two server exports that let another
resource register extra **access points** for a store, plus one client export that opens a store by its NPC id.
The changes only add code. Existing behaviour is unchanged.

These are local changes to an RSG resource. Re-apply them after updating rsg-stores, or ask the RSG authors to add
equivalent hooks upstream. Don't redistribute a modified rsg-stores.

## server/server.lua

1. **Above** `local function isNearNpc(src, npc)` add:

```lua
-- Extra places a store can be used from (registered by other resources, e.g. grumpy-bartender)
local accessPoints = {} -- [key] = { npcId = number, coords = vector3, res = string }

exports('SetShopAccessPoint', function(key, npcId, coords)
    npcId = tonumber(npcId)
    if type(key) ~= 'string' or not npcId or type(coords) ~= 'vector3' then return false end
    accessPoints[key] = { npcId = npcId, coords = coords, res = GetInvokingResource() }
    return true
end)

exports('RemoveShopAccessPoint', function(key)
    accessPoints[key] = nil
end)

AddEventHandler('onResourceStop', function(res)
    for key, p in pairs(accessPoints) do
        if p.res == res then accessPoints[key] = nil end
    end
end)
```

2. **Replace** `isNearNpc` with:

```lua
-- Player must be standing at the NPC or at one of its registered access points.
local function isNearNpc(src, npc)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    if #(pos - vector3(npc.x, npc.y, npc.z)) <= MAX_DIST then return true end
    for _, p in pairs(accessPoints) do
        if p.npcId == npc.id and #(pos - p.coords) <= MAX_DIST then return true end
    end
    return false
end
```

## client/client.lua

1. Change the `OpenCustomShop` signature and remember where the shop was opened from:

```lua
local shopOrigin = nil

local function OpenCustomShop(npcData, origin)
    -- ... existing early returns unchanged ...
    currentShop = npcData
    shopOrigin = origin or vector3(npcData.x, npcData.y, npcData.z)
```

2. In the auto-close thread at the end of `OpenCustomShop`, replace

```lua
#(GetEntityCoords(ped) - vector3(currentShop.x, currentShop.y, currentShop.z)) > CLOSE_DIST
```

with

```lua
#(GetEntityCoords(ped) - shopOrigin) > CLOSE_DIST
```

3. At the end of the file add:

```lua
-- Open a store by its NPC id from another resource (the server still checks access points)
exports('OpenShop', function(npcId, origin)
    local n = findNpcById(tonumber(npcId))
    if n then OpenCustomShop(n, type(origin) == 'vector3' and origin or nil) end
end)
```

## Store setup

There are two ways to give a bartender a shop:

- **Automatic (needs part 2 below):** click **Create bar shop** in the bartender editor, or tick it when placing a new
  bartender. grumpy-bartender creates a buy-only rsg-stores shop at the bartender with the menu from
  `Config.BarShop.Items`. It has **no shopkeeper ped** and fills in the store ID for you. Change prices and items
  afterwards in `/createshop` like any other shop.
- **Manual:** create the shop in `/createshop`, note its **NPC id** and put it in the bartender's *rsg-stores store ID*
  field. The rsg-stores NPC spawns where you created it.

---

# Part 2 (optional): automatic bar shops

Adds `CreateShop`, `DeleteShop` and `ShopExists` server exports, and lets a shop have no ped by using the model
`'none'`. Apply part 1 first.

## server/server.lua

At the **end of the file** add:

```lua
-- Create / delete shops from another resource (e.g. grumpy-bartender "Create bar shop").
-- data = { name, shopName, label, x, y, z, h, items = { { name, price, amount? } }, model? }
-- model defaults to 'none' = no shopkeeper ped. Items are checked against RSGCore.Shared.Items (unknown ones are dropped).
exports('CreateShop', function(data)
    if type(data) ~= 'table' then return nil end
    local npc = sanitizeNpc({
        name = data.name, model = data.model or 'none', kind = 'npc',
        x = data.x, y = data.y, z = data.z, h = data.h,
        shop = { name = data.shopName, label = data.label, type = 'buy', items = data.items },
    })
    if not npc or not npc.shop then return nil end
    local s = npc.shop
    npc.id = tonumber(MySQL.insert.await(
        'INSERT INTO rsg_shops_npcs (name, model, x, y, z, h, shop_name, shop_label, shop_type, store_kind) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { npc.name, npc.model, npc.x, npc.y, npc.z, npc.h, s.name, s.label, s.type, 'npc' }))
    if not npc.id then return nil end
    insertShopItems(npc.id, s.items)
    CachedNPCs[#CachedNPCs + 1] = npc
    broadcastNPCs()
    print(('[rsg-stores] shop %d (%s) created by %s'):format(npc.id, s.label, GetInvokingResource() or '?'))
    return npc.id
end)

exports('ShopExists', function(npcId)
    return findNpc(tonumber(npcId)) ~= nil
end)

-- Only NPC shops can be deleted this way (never player-owned stores)
exports('DeleteShop', function(npcId)
    local existing, idx = findNpc(tonumber(npcId))
    if not existing or existing.kind ~= 'npc' then return false end
    MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { existing.id })
    MySQL.query.await('DELETE FROM rsg_shops_ledger WHERE npc_id = ?', { existing.id })
    MySQL.query.await('DELETE FROM rsg_shops_blips WHERE associated_npc_id = ?', { existing.id })
    MySQL.query.await('DELETE FROM rsg_shops_npcs WHERE id = ?', { existing.id })
    table.remove(CachedNPCs, idx)
    for i = #CachedBlips, 1, -1 do
        if CachedBlips[i].associatedNpcId == existing.id then table.remove(CachedBlips, i) end
    end
    broadcastNPCs()
    broadcastBlips()
    print(('[rsg-stores] shop %d deleted by %s'):format(existing.id, GetInvokingResource() or '?'))
    return true
end)
```

## client/client.lua

In the spawn loop (`-- owned stores have no ped`), replace

```lua
local near = npc.kind ~= 'player' and #(coords - vector3(npc.x, npc.y, npc.z)) < Config.DistanceSpawn
```

with

```lua
local near = npc.kind ~= 'player' and npc.model ~= 'none' and #(coords - vector3(npc.x, npc.y, npc.z)) < Config.DistanceSpawn
```

Shops with the model `none` then have no ped and no target of their own, and are opened only through `OpenShop`
(part 1). They still show in `/createshop`, where you can edit their items and prices. Changing the model there to a
real ped gives them a shopkeeper again.
