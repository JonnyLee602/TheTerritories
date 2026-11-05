-- Crafting stations and business stashes (employees only).
local RSGCore = POB.Core()

local Craft = {}
POB.Craft = Craft

local pending = {} -- [src] = { token, biz, item, amount, ingredients, finishAt }

local function station(biz, index)
    index = POB.Int(index, 1, Config.MaxCraftStations)
    return index and biz.points.craft[index] or nil
end

-- All recipes this business can craft: type recipes + approved custom recipes
function Craft.Recipes(biz)
    local t = POB.Type(biz)
    local out = {}
    for i, r in ipairs(t.recipes or {}) do
        if RSGCore.Shared.Items[r.item] then
            out[#out + 1] = { key = 'type:' .. i, item = r.item, label = POB.ItemLabel(r.item), amount = r.amount or 1,
                time = r.time or 5000, ingredients = r.ingredients, custom = false }
        end
    end
    for _, r in ipairs(POB.Recipes and POB.Recipes.Approved(biz) or {}) do
        if RSGCore.Shared.Items[r.item] then out[#out + 1] = r end
    end
    return out
end

local function findRecipe(biz, key)
    for _, r in ipairs(Craft.Recipes(biz)) do if r.key == key then return r end end
    return nil
end

local function imageOf(name)
    local it = RSGCore.Shared.Items[name]
    return it and it.image or (name .. '.png')
end

RSGCore.Functions.CreateCallback('grumpy-pob:server:craftMenu', function(source, cb, id, index)
    local biz = POB.Biz(id)
    if not biz or not POB.Type(biz).crafting then return cb(nil) end
    local Player = POB.Require(source, biz, 'craft', Config.RequireDutyForCraft)
    local st = biz and station(biz, index)
    if not Player or not st or not POB.Near(source, st) then return cb(nil) end
    local list = {}
    for _, r in ipairs(Craft.Recipes(biz)) do
        local ings, can = {}, true
        for name, amt in pairs(r.ingredients) do
            local have = exports['rsg-inventory']:GetItemCount(source, name) or 0
            if have < amt then can = false end
            ings[#ings + 1] = { name = name, label = POB.ItemLabel(name), amount = amt, have = have }
        end
        table.sort(ings, function(a, b) return a.label < b.label end)
        list[#list + 1] = { key = r.key, item = r.item, label = r.label, amount = r.amount, time = r.time,
            image = imageOf(r.item), ingredients = ings, canCraft = can, custom = r.custom }
    end
    cb({ business = biz.label, recipes = list })
end)

RSGCore.Functions.CreateCallback('grumpy-pob:server:craftStart', function(source, cb, id, index, key, count)
    local src = source
    local biz = POB.Biz(id)
    if not biz or pending[src] or POB.Cooldown(src, 'craft', Config.CraftCooldownMs) then return cb(false) end
    local Player = POB.Require(src, biz, 'craft', Config.RequireDutyForCraft)
    local st = Player and station(biz, index)
    if not st or not POB.Near(src, st) then return cb(false) end
    count = POB.Int(count, 1, 10)
    local r = type(key) == 'string' and count and findRecipe(biz, key)
    if not r then return cb(false) end

    local outQty = r.amount * count
    if not exports['rsg-inventory']:CanAddItem(src, r.item, outQty) then
        POB.Notify(src, locale('inventory_full'), 'error')
        return cb(false)
    end
    for name, amt in pairs(r.ingredients) do
        if (exports['rsg-inventory']:GetItemCount(src, name) or 0) < amt * count then
            POB.Notify(src, locale('missing_ingredients'), 'error')
            return cb(false)
        end
    end
    local taken = {}
    for name, amt in pairs(r.ingredients) do
        if not exports['rsg-inventory']:RemoveItem(src, name, amt * count, nil, 'grumpy-pob-craft') then
            for n, a in pairs(taken) do exports['rsg-inventory']:AddItem(src, n, a, nil, nil, 'grumpy-pob-craft-refund') end
            POB.Notify(src, locale('missing_ingredients'), 'error')
            return cb(false)
        end
        taken[name] = amt * count
    end
    local duration = r.time * count
    local token = ('%d-%d-%d'):format(src, GetGameTimer(), math.random(100000, 999999))
    pending[src] = { token = token, biz = biz.id, item = r.item, label = r.label, amount = outQty, ingredients = taken,
        finishAt = GetGameTimer() + duration, station = st }
    cb(true, { token = token, duration = duration, label = r.label })
end)

local function refund(src, p)
    for n, a in pairs(p.ingredients) do
        if exports['rsg-inventory']:CanAddItem(src, n, a) then
            exports['rsg-inventory']:AddItem(src, n, a, nil, nil, 'grumpy-pob-craft-refund')
        end
    end
end

RegisterNetEvent('grumpy-pob:server:craftFinish', function(token, completed)
    local src = source
    local p = pending[src]
    if not p or p.token ~= token then return end
    pending[src] = nil
    if not RSGCore.Functions.GetPlayer(src) then return end
    if completed ~= true then return refund(src, p) end
    if GetGameTimer() < p.finishAt - 750 or not POB.Near(src, p.station, Config.ServerDistance + 2.0) then
        POB.Debug('craft finished early or away', src)
        return refund(src, p)
    end
    if not exports['rsg-inventory']:AddItem(src, p.item, p.amount, nil, nil, 'grumpy-pob-craft') then
        POB.Notify(src, locale('inventory_full'), 'error')
        return refund(src, p)
    end
    POB.Notify(src, locale('crafted', p.amount, p.label), 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    pending[src] = nil -- ingredients were already taken; a disconnect mid-craft loses them (same as a cancelled job)
end)

---------------------------------------------------------------------
-- Stashes
---------------------------------------------------------------------
function Craft.StashId(biz, index) return ('grumpy_pob_stash_%d_%d'):format(biz.id, index) end

RegisterNetEvent('grumpy-pob:server:openStash', function(id, index)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'stash', 1000) then return end
    index = POB.Int(index, 1, Config.MaxStashes)
    local p = index and biz.points.stash[index]
    if not p then return end
    local Player = POB.Require(src, biz, 'stash', Config.RequireDutyForStash)
    if not Player then return end
    if not POB.Near(src, p) then return POB.Notify(src, locale('too_far'), 'error') end
    exports['rsg-inventory']:OpenStash(src, Craft.StashId(biz, index), {
        label = locale('stash_label', biz.label, index), slots = Config.Stash.Slots, maxWeight = Config.Stash.Weight,
    })
end)

function Craft.WipeStashes(biz)
    for i = 1, Config.MaxStashes do
        pcall(function()
            local sid = Craft.StashId(biz, i)
            exports['rsg-inventory']:RegisterStash(sid, {}) -- loads it so ClearStash can empty and save it
            exports['rsg-inventory']:ClearStash(sid)
        end)
    end
end
