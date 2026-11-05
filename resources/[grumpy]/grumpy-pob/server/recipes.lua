-- Owner-made recipes. An approved recipe becomes a real rsg-core item (pob<business>_<recipe>) built on a
-- base consumable: same weight/category/effects, its own name, description and image.
-- Needs integrations/rsg-inventory.md (items added while running + image URLs) and
-- integrations/rsg-consume.md (the item uses its base item's effects).
local RSGCore = POB.Core()

local Recipes = {}
POB.Recipes = Recipes

local cache = {}      -- [id] = recipe
local byItem = {}     -- [itemName] = businessId
local CR = Config.CustomRecipes

local function decode(s) local ok, d = pcall(json.decode, s or '') return ok and type(d) == 'table' and d or {} end

local function rowToRecipe(row)
    return {
        id = row.id, biz = row.business_id, item = row.item_name, label = row.label, description = row.description or '',
        base = row.base_item, ingredients = decode(row.ingredients), amount = tonumber(row.amount) or 1,
        time = tonumber(row.craft_time) or 5000, imageUrl = row.image_url, imageId = row.image_id,
        imageStatus = row.image_status or 'none', status = row.status, discordMsg = row.discord_msg,
        createdBy = row.created_by, createdAt = tonumber(row.created_at) or 0, decidedBy = row.decided_by,
    }
end

function Recipes.Get(id) return cache[POB.Int(id) or -1] end
function Recipes.All() return cache end
function Recipes.ItemName(r) return ('pob%d_%d'):format(r.biz, r.id) end
POB.CustomItemOwner = function(name) return byItem[name] end

function Recipes.Save(r)
    MySQL.update.await([[UPDATE grumpy_pob_recipes SET item_name = ?, label = ?, description = ?, image_url = ?, image_id = ?,
        image_status = ?, status = ?, discord_msg = ?, decided_by = ? WHERE id = ?]],
        { r.item, r.label, r.description, r.imageUrl, r.imageId, r.imageStatus, r.status, r.discordMsg, r.decidedBy, r.id })
end

-- Craft-menu shape for approved recipes of a business
function Recipes.Approved(biz)
    local out = {}
    for _, r in pairs(cache) do
        if r.biz == biz.id and r.status == 'approved' and r.item then
            out[#out + 1] = { key = 'custom:' .. r.id, item = r.item, label = r.label, amount = r.amount, time = r.time,
                ingredients = r.ingredients, custom = true }
        end
    end
    return out
end

---------------------------------------------------------------------
-- Item registration
---------------------------------------------------------------------
local function imageFor(r, base)
    if r.imageStatus == 'approved' and r.imageUrl then return r.imageUrl end
    if r.imageStatus == 'gallery' and r.imageUrl then return r.imageUrl end
    return base.image
end

function Recipes.Register(r)
    if r.status ~= 'approved' and r.status ~= 'retired' then return false end
    local base = RSGCore.Shared.Items[r.base]
    if not base then
        print(('^3[grumpy-pob] recipe %d: base item %s no longer exists^7'):format(r.id, tostring(r.base)))
        return false
    end
    r.item = r.item or Recipes.ItemName(r)
    local data = {
        name = r.item, label = r.label, weight = base.weight or 100, type = 'item', image = imageFor(r, base),
        unique = false, useable = base.useable, shouldClose = base.shouldClose ~= false,
        description = r.description ~= '' and r.description or base.description, category = base.category,
    }
    local ok, err
    if RSGCore.Shared.Items[r.item] then ok, err = exports['rsg-core']:UpdateItem(r.item, data)
    else ok, err = exports['rsg-core']:AddItem(r.item, data) end
    if not ok then print(('^1[grumpy-pob] could not register %s: %s^7'):format(r.item, tostring(err))) return false end
    byItem[r.item] = r.biz
    if base.useable then
        local aliased = pcall(function() exports['rsg-consume']:RegisterAlias(r.item, r.base) end)
        if not aliased then print(('^3[grumpy-pob] %s is not usable: apply integrations/rsg-consume.md^7'):format(r.item)) end
    end
    return true
end

---------------------------------------------------------------------
-- Fivemanage
---------------------------------------------------------------------
local FM = SvConfig.Fivemanage

local function fmRequest(method, path, body, cb)
    if not Config.Images.Enabled or FM.ApiKey == '' then return cb(nil) end
    PerformHttpRequest(FM.BaseUrl .. path, function(status, text)
        if status < 200 or status >= 300 then
            POB.Debug('fivemanage', method, path, status, text)
            return cb(nil)
        end
        local ok, data = pcall(json.decode, text or '')
        cb(ok and data or {})
    end, method, body or '', { ['Authorization'] = FM.ApiKey, ['Content-Type'] = 'application/json', ['User-Agent'] = 'grumpy-pob' })
end

function Recipes.DeleteImage(imageId)
    if type(imageId) ~= 'string' or imageId == '' then return end
    fmRequest('DELETE', '/file/' .. imageId, nil, function() end)
end

-- Verifies an uploaded file with Fivemanage and returns its URL (never trusts the client's URL)
local function verifyImage(imageId)
    if type(imageId) ~= 'string' or not imageId:match('^[%w%-_]+$') or #imageId > 100 then return nil end
    local p = promise.new()
    fmRequest('GET', '/file/' .. imageId, nil, function(data) p:resolve(data) end)
    local data = Citizen.Await(p)
    local d = data and (data.data or data)
    local url = type(d) == 'table' and d.url
    if type(url) ~= 'string' or url:sub(1, #Config.Images.AllowedPrefix) ~= Config.Images.AllowedPrefix then return nil end
    local size = tonumber(d.size)
    if size and size > Config.Images.MaxKB * 1024 then Recipes.DeleteImage(imageId) return nil end
    return url
end

RSGCore.Functions.CreateCallback('grumpy-pob:server:presign', function(source, cb, id)
    local biz = POB.Biz(id)
    if not biz or not Config.Images.Enabled then return cb(nil) end
    local Player = POB.Require(source, biz, 'recipes')
    if not Player or POB.Cooldown(source, 'presign', Config.Images.PresignCooldown * 1000) then return cb(nil) end
    fmRequest('GET', '/file/presigned-url', nil, function(data)
        local url = data and data.data and data.data.presignedUrl
        cb(type(url) == 'string' and url or nil)
    end)
end)

---------------------------------------------------------------------
-- Manager screen
---------------------------------------------------------------------
local function itemInfo(name)
    local it = RSGCore.Shared.Items[name]
    return it and { name = name, label = it.label, image = it.image } or nil
end

function Recipes.Rules(biz)
    local t = POB.Type(biz)
    local c = t.custom
    if not CR.Enabled or not c then return nil end
    local bases, ings = {}, {}
    for _, n in ipairs(c.bases or {}) do local i = itemInfo(n) if i then bases[#bases + 1] = i end end
    for _, n in ipairs(c.ingredients or {}) do local i = itemInfo(n) if i then ings[#ings + 1] = i end end
    return {
        bases = bases, ingredients = ings, maxIngredients = CR.MaxIngredients, maxAmount = CR.MaxIngredientAmount,
        maxOutput = CR.MaxOutput, time = CR.CraftTime, nameMin = CR.NameMin, nameMax = CR.NameMax,
        descMax = CR.DescriptionMax, images = Config.Images.Enabled and FM.ApiKey ~= '',
        maxKB = Config.Images.MaxKB, types = Config.Images.Types, max = CR.MaxPerBusiness,
    }
end

function Recipes.ListFor(biz)
    local out = {}
    for _, r in pairs(cache) do
        if r.biz == biz.id and r.status ~= 'deleted' then
            local ings = {}
            for n, a in pairs(r.ingredients) do ings[#ings + 1] = { label = POB.ItemLabel(n), amount = a } end
            out[#out + 1] = { id = r.id, label = r.label, description = r.description, base = POB.ItemLabel(r.base),
                status = r.status, imageStatus = r.imageStatus, image = r.imageUrl, amount = r.amount, time = r.time, ingredients = ings }
        end
    end
    table.sort(out, function(a, b) return a.id > b.id end)
    return out
end

local function countFor(biz)
    local n = 0
    for _, r in pairs(cache) do if r.biz == biz.id and (r.status == 'pending' or r.status == 'approved') then n = n + 1 end end
    return n
end

local function inList(list, v) for _, x in ipairs(list or {}) do if x == v then return true end end return false end

local function sanitise(biz, data)
    local c = POB.Type(biz).custom
    if type(data) ~= 'table' or not c then return nil, 'invalid_form' end
    local label = POB.Str(data.label, CR.NameMax)
    if not label or #label < CR.NameMin then return nil, 'recipe_bad_name' end
    local desc = POB.Str(data.description, CR.DescriptionMax) or ''
    if type(data.base) ~= 'string' or not inList(c.bases, data.base) or not RSGCore.Shared.Items[data.base] then return nil, 'recipe_bad_base' end
    if type(data.ingredients) ~= 'table' then return nil, 'recipe_bad_ingredients' end
    local ings, n = {}, 0
    for _, row in ipairs(data.ingredients) do
        local name = type(row) == 'table' and row.name
        local amt = type(row) == 'table' and POB.Int(row.amount, 1, CR.MaxIngredientAmount)
        if type(name) ~= 'string' or not amt or not inList(c.ingredients, name) or not RSGCore.Shared.Items[name] or ings[name] then
            return nil, 'recipe_bad_ingredients'
        end
        ings[name] = amt
        n = n + 1
    end
    if n < 1 or n > CR.MaxIngredients then return nil, 'recipe_bad_ingredients' end
    local amount = POB.Int(data.amount, 1, CR.MaxOutput)
    local time = POB.Int(data.time, CR.CraftTime.min, CR.CraftTime.max)
    if not amount or not time then return nil, 'invalid_form' end
    local gallery
    if type(data.gallery) == 'string' and data.gallery ~= '' then
        if not (inList(c.bases, data.gallery) or inList(c.ingredients, data.gallery)) or not RSGCore.Shared.Items[data.gallery] then
            return nil, 'invalid_form'
        end
        gallery = RSGCore.Shared.Items[data.gallery].image
    end
    return { label = label, description = desc, base = data.base, ingredients = ings, amount = amount, time = time,
        gallery = gallery, imageId = type(data.imageId) == 'string' and data.imageId or nil }
end

RSGCore.Functions.CreateCallback('grumpy-pob:server:submitRecipe', function(source, cb, id, data)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'recipe', 5000) then return cb(false) end
    local Player = POB.Require(src, biz, 'recipes')
    if not Player or not POB.Near(src, biz.points.manager) then return cb(false) end
    if not Recipes.Rules(biz) then return cb(false) end
    if countFor(biz) >= CR.MaxPerBusiness then POB.Notify(src, locale('recipe_limit', CR.MaxPerBusiness), 'error') return cb(false) end
    local f, err = sanitise(biz, data)
    if not f then POB.Notify(src, locale(err), 'error') return cb(false) end

    local imageUrl, imageStatus = nil, 'none'
    if f.imageId then
        imageUrl = verifyImage(f.imageId)
        if imageUrl then imageStatus = 'pending' else POB.Notify(src, locale('image_rejected_upload'), 'error') f.imageId = nil end
    elseif f.gallery then
        imageUrl, imageStatus = f.gallery, 'gallery'
    end

    local rid = MySQL.insert.await([[INSERT INTO grumpy_pob_recipes (business_id, label, description, base_item, ingredients, amount,
        craft_time, image_url, image_id, image_status, status, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)]],
        { biz.id, f.label, f.description, f.base, json.encode(f.ingredients), f.amount, f.time, imageUrl, f.imageId,
          imageStatus, Player.PlayerData.citizenid, os.time() })
    if not rid then return cb(false) end
    local r = rowToRecipe(MySQL.single.await('SELECT * FROM grumpy_pob_recipes WHERE id = ?', { rid }))
    r.item = Recipes.ItemName(r)
    Recipes.Save(r)
    cache[rid] = r
    POB.Acc.Log(POB.AccountId(biz), 'recipe', 0, POB.Acc.Who(Player), locale('ledger_recipe_submitted', r.label))
    POB.Approval.Submit(r, biz, POB.PlayerName(Player))
    cb(true)
end)

RegisterNetEvent('grumpy-pob:server:deleteRecipe', function(id, rid)
    local src = source
    local biz = POB.Biz(id)
    local r = Recipes.Get(rid)
    if not biz or not r or r.biz ~= biz.id or POB.Cooldown(src, 'recipe', 1500) then return end
    local Player = POB.Require(src, biz, 'recipes')
    if not Player then return end
    if r.status == 'approved' then
        r.status = 'retired' -- the item stays registered so existing copies keep working; it can no longer be crafted
    else
        r.status = 'deleted'
        if r.imageId then Recipes.DeleteImage(r.imageId) end
    end
    Recipes.Save(r)
    POB.Acc.Log(POB.AccountId(biz), 'recipe', 0, POB.Acc.Who(Player), locale('ledger_recipe_removed', r.label))
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager')
end)

---------------------------------------------------------------------
-- Load
---------------------------------------------------------------------
POB.AfterLoad(function()
    local rows = MySQL.query.await("SELECT * FROM grumpy_pob_recipes WHERE status <> 'deleted'") or {}
    local n = 0
    for _, row in ipairs(rows) do
        local r = rowToRecipe(row)
        r.item = r.item or Recipes.ItemName(r)
        cache[r.id] = r
        if Recipes.Register(r) then n = n + 1 end
    end
    if n > 0 then print(('^2[grumpy-pob] %d custom items registered^7'):format(n)) end
end)

-- rsg-consume restarted: re-register the aliases
AddEventHandler('onResourceStart', function(res)
    if res ~= 'rsg-consume' or not POB.Ready then return end
    SetTimeout(2000, function()
        for _, r in pairs(cache) do if r.status == 'approved' or r.status == 'retired' then Recipes.Register(r) end end
    end)
end)
