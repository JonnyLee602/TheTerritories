-- Business tables (DESIGN.md §9): placing one from the item, and the owner's panel ("Manage table" on the table).
local RSGCore = exports['rsg-core']:GetCoreObject()
GGC.MyTables = {}
local placing = nil   -- what the server allowed: { kind, model, businessId, npc, maxDistance, ... }
local busy = false

local function setMine(list)
    GGC.MyTables = {}
    for _, id in ipairs(list or {}) do GGC.MyTables[id] = true end
end
RegisterNetEvent('grumpy-gambling:client:myTables', setMine)

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    CreateThread(function() setMine(RSGCore.Functions.AwaitCallback('grumpy-gambling:server:bizMine', 10000)) end)
end)
CreateThread(function()
    Wait(3000)
    if LocalPlayer.state.isLoggedIn then setMine(RSGCore.Functions.AwaitCallback('grumpy-gambling:server:bizMine', 10000)) end
end)

local function v(c) return { x = c.x, y = c.y, z = c.z } end

local function gizmo(fn)
    if busy or exports['rsg-gizmo']:IsActive() then return end
    busy = true
    GGC.HideUI()
    CreateThread(function()
        local ok, err = pcall(fn)
        if not ok then print('^1[grumpy-gambling] ' .. tostring(err) .. '^7') end
        busy = false
        GGC.ShowUI() -- back to the panel (if one was open)
    end)
end

---------------------------------------------------------------------
-- Placing (the server checked ownership, the NPC distance and the limits; it checks them all again on save)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:client:bizPlace', function(d)
    if type(d) ~= 'table' or GGC.uiOpen then return end
    placing = d
    GGC.OpenUI('bizPlace', d)
end)

RegisterNUICallback('bizPlace', function(body, cb)
    cb('ok')
    local d = placing
    if not d or type(body) ~= 'table' then return end
    local label = type(body.label) == 'string' and body.label or d.label
    local currency = body.currency == 'bloodmoney' and 'bloodmoney' or 'cash'
    GGC.CloseUI()
    gizmo(function()
        local npc = vector3(d.npc.x + 0.0, d.npc.y + 0.0, d.npc.z + 0.0)
        local res = exports['rsg-gizmo']:Place(d.model, {
            title = locale('biz_place_title'), maxDistance = Config.PlaceDistance, rotation = 'z', allowInterior = true,
            -- the ghost turns red outside the business (same rule as the server)
            validate = function(pos)
                local dx, dy = pos.x - npc.x, pos.y - npc.y
                if math.sqrt(dx * dx + dy * dy) > d.maxDistance then return false, locale('biz_too_far_npc', math.floor(d.maxDistance)) end
                return true
            end,
        })
        placing = nil
        if not res then return end
        TriggerServerEvent('grumpy-gambling:server:bizCreate', {
            kind = d.kind, businessId = d.businessId, label = label, currency = currency,
            coords = v(res.coords), heading = res.heading or res.rotation.z,
        })
    end)
end)

---------------------------------------------------------------------
-- The owner's panel
---------------------------------------------------------------------
function GGC.OpenBizPanel(tableId)
    if GGC.uiOpen then return end
    CreateThread(function()
        local data = RSGCore.Functions.AwaitCallback('grumpy-gambling:server:bizPanel', 10000, tableId)
        if data then GGC.OpenUI('biz', data) end
    end)
end

RegisterNetEvent('grumpy-gambling:client:bizPanel', function(data)
    if GGC.uiOpen ~= 'biz' then return end
    if not data then return GGC.CloseUI() end
    GGC.UpdateUI('biz', data)
end)

RegisterNUICallback('bizAction', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' or type(body.action) ~= 'string' then return end
    TriggerServerEvent('grumpy-gambling:server:bizAction', tonumber(body.id), body.action, body.value)
end)

RegisterNUICallback('bizMove', function(body, cb)
    cb('ok')
    local id = type(body) == 'table' and tonumber(body.id)
    local t = id and GGC.Tables[id]
    local ent = id and GGC.TableEntity(id)
    if not t or not ent then return end
    gizmo(function()
        local res = exports['rsg-gizmo']:Edit(ent, { maxDistance = Config.PlaceDistance, rotation = 'z', allowInterior = true })
        if res then TriggerServerEvent('grumpy-gambling:server:bizMove', id, v(res.coords), res.heading or res.rotation.z) end
    end)
end)
