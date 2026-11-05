-- Shop stock and prices. grumpy-pob owns the numbers; rsg-stores (patched, see integrations/rsg-stores.md)
-- shows the shop and runs the purchase, then reports each sale back here.
local RSGCore = POB.Core()

local Shop = {}
POB.Shop = Shop

local STORES = 'rsg-stores'
local openStock = {} -- [src] = { biz = id, stash = id, who = { cid, name } }

local function storesCall(fn, ...)
    local args = { ... }
    local ok, a, b = pcall(function() return exports[STORES][fn](exports[STORES], table.unpack(args)) end)
    if not ok then
        print(('^1[grumpy-pob] rsg-stores export %s failed (is integrations/rsg-stores.md applied?): %s^7'):format(fn, tostring(a)))
        return nil
    end
    return a, b
end

function Shop.Rows(biz)
    local rows = MySQL.query.await('SELECT item, qty, price FROM grumpy_pob_stock WHERE business_id = ?', { biz.id }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { item = r.item, label = POB.ItemLabel(r.item), qty = tonumber(r.qty) or 0, price = r.price and tonumber(r.price) or nil }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Items the shop sells right now: priced and in stock
function Shop.ForSale(biz)
    local list = {}
    for _, r in ipairs(Shop.Rows(biz)) do
        if r.price and r.qty > 0 and RSGCore.Shared.Items[r.item] then
            list[#list + 1] = { name = r.item, label = r.label, price = r.price, amount = r.qty }
        end
    end
    return list
end

function Shop.Push(biz)
    if not biz.shopId then return end
    storesCall('SetShopData', biz.shopId, { label = biz.label, items = biz.owner and Shop.ForSale(biz) or {}, blockJob = biz.job })
end

function Shop.EnsureStore(biz)
    local t = POB.Type(biz)
    if not t or not t.shop or not biz.points.npc then return end
    local npc = biz.points.npc
    if biz.shopId and not storesCall('ShopExists', biz.shopId) then biz.shopId = nil end
    if not biz.shopId then
        local id = storesCall('CreateShop', {
            name = biz.label, shopName = 'pob_' .. biz.id, label = biz.label,
            x = npc.x, y = npc.y, z = npc.z, h = npc.w or 0.0, items = {}, model = 'none',
        })
        if not id then return end
        biz.shopId = id
        POB.SaveBiz(biz)
    end
    storesCall('SetShopAccessPoint', 'grumpy-pob:' .. biz.id, biz.shopId, POB.Vec(npc))
    Shop.Push(biz)
end

function Shop.RemoveStore(biz)
    if not biz.shopId then return end
    storesCall('RemoveShopAccessPoint', 'grumpy-pob:' .. biz.id)
    storesCall('DeleteShop', biz.shopId)
    biz.shopId = nil
end

function Shop.AddStock(biz, item, qty)
    MySQL.query.await('INSERT INTO grumpy_pob_stock (business_id, item, qty) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE qty = qty + VALUES(qty)', { biz.id, item, qty })
end

function Shop.TakeStock(biz, item, qty)
    local n = MySQL.update.await('UPDATE grumpy_pob_stock SET qty = qty - ? WHERE business_id = ? AND item = ? AND qty >= ?', { qty, biz.id, item, qty })
    return n and n > 0
end

function Shop.Wipe(biz)
    MySQL.update.await('UPDATE grumpy_pob_stock SET qty = 0 WHERE business_id = ?', { biz.id })
    Shop.Push(biz)
end

---------------------------------------------------------------------
-- Sales reported by rsg-stores (server-only event from the patch)
---------------------------------------------------------------------
AddEventHandler('rsg-stores:server:externalSale', function(shopId, src, lines, total)
    local biz
    for _, b in pairs(POB.Businesses) do if b.shopId == shopId then biz = b break end end
    if not biz or type(lines) ~= 'table' then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local buyer = Player and POB.PlayerName(Player) or '?'
    for _, l in ipairs(lines) do
        local qty = POB.Int(l.qty, 1)
        if qty and type(l.name) == 'string' then
            MySQL.update.await('UPDATE grumpy_pob_stock SET qty = GREATEST(qty - ?, 0) WHERE business_id = ? AND item = ?', { qty, biz.id, l.name })
        end
    end
    total = POB.Money(total) or 0
    if total > 0 then
        local account = biz.owner and POB.AccountId(biz) or POB.Acc.GOV
        local parts = {}
        for _, l in ipairs(lines) do parts[#parts + 1] = ('%dx %s'):format(tonumber(l.qty) or 0, POB.ItemLabel(l.name)) end
        POB.Acc.Add(account, total, 'sale', { cid = Player and Player.PlayerData.citizenid, name = buyer }, table.concat(parts, ', '))
    end
end)

---------------------------------------------------------------------
-- Customer opens the shop
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-pob:server:canShop', function(source, cb, id)
    local biz = POB.Biz(id)
    local t = POB.Type(biz)
    if not biz or not t or not t.shop or not biz.shopId then return cb(false, 'unavailable') end
    if not biz.owner then return cb(false, 'biz_closed') end
    if not POB.Near(source, biz.points.npc) then return cb(false, 'too_far') end
    -- staff could set a low price and buy the stock out; they use "take out" (with its permission) instead
    if exports['rsg-core']:HasPlayerJob(source, biz.job) then return cb(false, 'staff_no_buy') end
    if #Shop.ForSale(biz) == 0 then return cb(false, 'shop_empty') end
    cb(true, biz.shopId)
end)

---------------------------------------------------------------------
-- Stocking: an on-duty employee drops items into a personal stock box (rsg-inventory stash).
-- Whatever is in it becomes shop stock when the box closes (patched rsg-inventory event) or the
-- next time it is opened.
---------------------------------------------------------------------
local function stashId(biz, cid) return ('grumpy_pob_stock_%d_%s'):format(biz.id, cid) end

local function flush(biz, sid, src, who)
    local inv = exports['rsg-inventory']:GetInventory(sid)
    if not inv or type(inv.items) ~= 'table' then return 0 end
    local added, returned = {}, 0
    for slot, it in pairs(inv.items) do
        slot = tonumber(slot)
        local qty = math.tointeger(tonumber(it.amount)) or 0
        local quality = type(it.info) == 'table' and tonumber(it.info.quality) or nil
        local ok = qty > 0 and POB.ItemAllowed(biz, it.name) and (not quality or quality >= Config.Shop.MinQuality)
        if ok then
            if exports['rsg-inventory']:RemoveItem(sid, it.name, qty, slot, 'grumpy-pob-stock') then
                Shop.AddStock(biz, it.name, qty)
                added[#added + 1] = ('%dx %s'):format(qty, POB.ItemLabel(it.name))
            end
        elseif src and GetPlayerPing(src) > 0 and exports['rsg-inventory']:CanAddItem(src, it.name, qty) then
            if exports['rsg-inventory']:RemoveItem(sid, it.name, qty, slot, 'grumpy-pob-stock-return') then
                exports['rsg-inventory']:AddItem(src, it.name, qty, it.info, nil, 'grumpy-pob-stock-return')
                returned = returned + 1
            end
        end
    end
    if #added > 0 then
        POB.Acc.Log(POB.AccountId(biz), 'stock_in', 0, who, table.concat(added, ', '))
        Shop.Push(biz)
        if src then POB.Notify(src, locale('stocked', #added), 'success') end
    end
    if returned > 0 and src then POB.Notify(src, locale('stock_returned'), 'inform') end
    return #added
end

RegisterNetEvent('grumpy-pob:server:openStock', function(id)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'stock', 1500) then return end
    local t = POB.Type(biz)
    if not t or not t.shop then return end
    local Player = POB.Require(src, biz, 'stock', true)
    if not Player then return end
    if not POB.Near(src, biz.points.npc) then return POB.Notify(src, locale('too_far'), 'error') end
    local cid = Player.PlayerData.citizenid
    local who = POB.Acc.Who(Player)
    local sid = stashId(biz, cid)
    exports['rsg-inventory']:RegisterStash(sid, { label = locale('stock_box', biz.label), slots = Config.Shop.StockSlots, maxWeight = Config.Shop.StockWeight })
    flush(biz, sid, src, who) -- leftovers from last time
    openStock[src] = { biz = biz.id, stash = sid, who = who }
    exports['rsg-inventory']:OpenStash(src, sid, { label = locale('stock_box', biz.label), slots = Config.Shop.StockSlots, maxWeight = Config.Shop.StockWeight })
end)

-- Fired by the rsg-inventory patch when any container closes
AddEventHandler('rsg-inventory:server:stashClosed', function(src, sid)
    local o = openStock[src]
    if not o or o.stash ~= sid then return end
    openStock[src] = nil
    local biz = POB.Biz(o.biz)
    if biz then flush(biz, sid, src, o.who) end
end)

AddEventHandler('playerDropped', function() openStock[source] = nil end)

---------------------------------------------------------------------
-- Manager actions: prices + taking stock out
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:setPrice', function(id, item, price)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'price', 300) then return end
    local Player = POB.Require(src, biz, 'prices')
    if not Player or not POB.Near(src, biz.points.manager) then return end
    if type(item) ~= 'string' or not POB.ItemAllowed(biz, item) then return end
    local p
    if price ~= nil and price ~= '' then
        p = POB.Money(tonumber(price))
        if not p or p < Config.Shop.MinPrice or p > Config.Shop.MaxPrice then
            return POB.Notify(src, locale('price_range', Config.Shop.MinPrice, Config.Shop.MaxPrice), 'error')
        end
    end
    MySQL.query.await('INSERT INTO grumpy_pob_stock (business_id, item, qty, price) VALUES (?, ?, 0, ?) ON DUPLICATE KEY UPDATE price = VALUES(price)', { biz.id, item, p })
    POB.Acc.Log(POB.AccountId(biz), 'price', 0, POB.Acc.Who(Player), ('%s = %s'):format(POB.ItemLabel(item), p and ('$' .. p) or locale('hidden')))
    Shop.Push(biz)
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager')
end)

RegisterNetEvent('grumpy-pob:server:takeStock', function(id, item, qty)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'takestock', 800) then return end
    local Player = POB.Require(src, biz, 'takeStock')
    if not Player or not POB.Near(src, biz.points.manager) then return end
    qty = POB.Int(qty, 1, 1000)
    if type(item) ~= 'string' or not qty or not RSGCore.Shared.Items[item] then return end
    if not exports['rsg-inventory']:CanAddItem(src, item, qty) then return POB.Notify(src, locale('inventory_full'), 'error') end
    if not Shop.TakeStock(biz, item, qty) then return POB.Notify(src, locale('not_enough_stock'), 'error') end
    if not exports['rsg-inventory']:AddItem(src, item, qty, nil, nil, 'grumpy-pob-takestock') then
        Shop.AddStock(biz, item, qty)
        return POB.Notify(src, locale('inventory_full'), 'error')
    end
    POB.Acc.Log(POB.AccountId(biz), 'stock_out', 0, POB.Acc.Who(Player), ('%dx %s'):format(qty, POB.ItemLabel(item)))
    Shop.Push(biz)
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager')
end)

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
local function syncAll()
    CreateThread(function()
        if not POB.WaitReady(STORES) then return end -- rsg-stores must have its shops loaded, or we'd create duplicates
        for _, biz in pairs(POB.Businesses) do Shop.EnsureStore(biz) end
    end)
end

POB.AfterLoad(syncAll)

AddEventHandler('onResourceStart', function(res)
    if res == STORES and POB.Ready then syncAll() end
end)
