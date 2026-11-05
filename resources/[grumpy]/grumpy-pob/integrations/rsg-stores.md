# rsg-stores patch (grumpy-pob)

grumpy-pob needs parts 1 and 2 (the same changes grumpy-bartender uses; skip them if already applied) plus part 3 below.
These are local changes to an RSG resource: re-apply after updating rsg-stores, or offer them upstream. Don't redistribute a modified rsg-stores.

# Part 1: open a shop from another resource

Unpatched rsg-stores only opens a shop from its own NPC, and the server rejects a purchase unless the player
is standing at that NPC (`isNearNpc` in `server/server.lua`). This patch adds two server exports that let another
resource register extra **access points** for a store, plus one client export that opens a store by its NPC id.
The changes only add code. Existing behaviour is unchanged.

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

---

# Part 2: shops created by other resources

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

---

# Part 3: stock, labels and sales reported to another resource

grumpy-pob keeps each business's stock and prices itself and pushes them into its rsg-stores shop. rsg-stores then
runs the purchase as usual (cart, cash check, atomic stock, refunds) and reports every sale back so the money goes
into the business account.

## server/server.lua

1. Right after `local RSGCore = exports['rsg-core']:GetCoreObject()` (line 1) add:

```lua
-- Items added at runtime by other resources (grumpy-pob custom items) need a fresh core copy
AddEventHandler('RSGCore:Server:UpdateObject', function() RSGCore = exports['rsg-core']:GetCoreObject() end)
```

2. In `rsg-stores:server:purchaseCart`, below the line
   `if npc.kind == 'player' and isStaffOf(npc, Player.PlayerData.citizenid) then return fail(locale('sv_staff_no_trade')) end` add:

```lua
    -- Shops run by another resource can bar a job (grumpy-pob: staff can't buy out their own stock)
    if npc.blockJob and exports['rsg-core']:HasPlayerJob(src, npc.blockJob) then return fail(locale('sv_staff_no_trade')) end
```

3. In the same handler, find the block that starts with
   `-- Owned stores: takings go into the store till for the owner to collect.` and **above** it add:

```lua
    -- NPC shops: tell other resources what sold (grumpy-pob routes the money to a business account).
    -- Server-only event: clients cannot trigger it.
    if npc.kind == 'npc' then
        local sold = {}
        for _, l in ipairs(lines) do sold[#sold + 1] = { name = l.name, qty = l.qty, unit = l.unit } end
        TriggerEvent('rsg-stores:server:externalSale', npc.id, src, sold, total)
    end
```

4. At the **end of the file** (after the part 2 exports) add:

```lua
-- true once shops are loaded from the database (other resources wait for this before creating shops)
exports('IsReady', function() return DbReady end)

-- Replace the label and/or items of an NPC shop from another resource.
-- data = { label?, items? = { { name, price, amount } }, blockJob? }. Stock is always limited (amount 0 = sold out).
-- blockJob: players holding this job can't buy here.
exports('SetShopData', function(npcId, data)
    local npc = findNpc(tonumber(npcId))
    if not npc or npc.kind ~= 'npc' or not npc.shop or type(data) ~= 'table' then return false end
    if type(data.label) == 'string' and data.label ~= '' then
        npc.shop.label = data.label:sub(1, 100)
        npc.name = npc.shop.label
        MySQL.update.await('UPDATE rsg_shops_npcs SET name = ?, shop_label = ? WHERE id = ?', { npc.name, npc.shop.label, npc.id })
    end
    if data.blockJob ~= nil then npc.blockJob = type(data.blockJob) == 'string' and data.blockJob or nil end
    if type(data.items) == 'table' then
        local items = sanitizeItems(data.items)
        for _, it in ipairs(items) do it.amount = it.amount or 0 end
        MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { npc.id })
        insertShopItems(npc.id, items)
        npc.shop.items = items
    end
    broadcastShop(npc)
    return true
end)
```

## client/client.lua

Right after `local RSGCore = exports['rsg-core']:GetCoreObject()` (line 1) add:

```lua
-- Items added at runtime (grumpy-pob custom items): refresh labels and images
AddEventHandler('RSGCore:Client:UpdateObject', function() RSGCore = exports['rsg-core']:GetCoreObject() end)
```

## html/script.js

Replace `imgFor` with (custom items can use a full image URL):

```js
    imgFor: function(item) {
        var img = item && item.image;
        if (img && /^(https?|nui):\/\//.test(img)) return img;
        if (img) return this.imagePath + img;
        return this.imagePath + ((item && item.name) || 'unknown') + '.png';
    },
```

## Check it worked
- Restart rsg-stores, then grumpy-pob. The server console must not print `rsg-stores export ... failed`.
- `/createshop` lists one shop per shop-type business (named after it, model `none`).
- Buying from a business NPC adds a `Sale` line to the business ledger.
