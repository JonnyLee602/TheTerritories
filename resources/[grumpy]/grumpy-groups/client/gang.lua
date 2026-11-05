-- Gang boss menu, gang location prompts/blips and "Recruit to gang" on players

local PlayerGang = {}
local gangBlips = {}
local prompts = {}

local function isBoss()
    return PlayerGang and PlayerGang.name and PlayerGang.name ~= 'none' and PlayerGang.isboss
end

-----------------------------------------------------------------------
-- blips
-----------------------------------------------------------------------
local function clearGangBlips()
    for _, blip in ipairs(gangBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    gangBlips = {}
end

local function createGangBlips()
    clearGangBlips()
    local gangName = PlayerGang and PlayerGang.name
    for _, v in ipairs(Config.GangLocations) do
        if v.showblip and (v.blipforall or gangName == v.id) then
            local blip = BlipAddForCoords(1664425300, v.coords) -- BLIP_ADD_FOR_COORDS, style hash as used by rsg-gangmenu
            SetBlipSprite(blip, joaat(Config.Gang.Blip.sprite), true)
            SetBlipScale(blip, Config.Gang.Blip.scale)
            SetBlipName(blip, v.blipname)
            gangBlips[#gangBlips + 1] = blip
        end
    end
end

local function refreshGang()
    PlayerGang = RSGCore.Functions.GetPlayerData().gang or {}
    createGangBlips()
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then refreshGang() end
end)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', refreshGang)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    PlayerGang = {}
    clearGangBlips()
    if UI.panel == 'gang' then UI.Close() end
end)
RegisterNetEvent('RSGCore:Client:OnGangUpdate', function(gang)
    PlayerGang = gang or {}
    createGangBlips()
    if UI.panel == 'gang' and not isBoss() then UI.Close() end
end)

-----------------------------------------------------------------------
-- menu
-----------------------------------------------------------------------
local function openGangMenu(atLocation)
    if not isBoss() then return UI.Notify(locale('gang_not_boss'), 'error') end
    local data = RSGCore.Functions.AwaitCallback('grumpy-groups:server:getGangMenu', 5000, atLocation == true)
    if not data then return UI.Notify(locale('gang_not_boss'), 'error') end
    UI.Open('gang', data)
end

RegisterNetEvent('grumpy-groups:client:openGangLocation', function() openGangMenu(true) end)
RegisterCommand(Config.Gang.Command, function() openGangMenu(false) end, false)

RegisterNUICallback('gangMembers', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('grumpy-groups:server:getGangMembers', 5000) or { members = {}, grades = {} })
end)

RegisterNUICallback('gangNearby', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('grumpy-groups:server:getNearbyRecruits', 5000) or {})
end)

RegisterNUICallback('gangRecruit', function(body, cb)
    TriggerServerEvent('grumpy-groups:server:gangRecruit', tonumber(body and body.source))
    cb('ok')
end)

RegisterNUICallback('gangSetGrade', function(body, cb)
    if type(body) == 'table' then TriggerServerEvent('grumpy-groups:server:gangSetGrade', body.citizenid, tonumber(body.grade)) end
    cb('ok')
end)

RegisterNUICallback('gangFire', function(body, cb)
    if type(body) == 'table' then TriggerServerEvent('grumpy-groups:server:gangFire', body.citizenid) end
    cb('ok')
end)

RegisterNUICallback('gangStash', function(_, cb)
    UI.Close()
    TriggerServerEvent('grumpy-groups:server:openGangStash')
    cb('ok')
end)

RegisterNUICallback('gangMoney', function(body, cb)
    if type(body) == 'table' then
        local amount = math.floor(tonumber(body.amount) or 0)
        if amount >= 1 then
            TriggerServerEvent(body.mode == 'deposit' and 'grumpy-groups:server:gangDeposit' or 'grumpy-groups:server:gangWithdraw', amount)
        end
    end
    -- give the server a moment, then refresh the balance shown
    SetTimeout(600, function()
        if UI.panel == 'gang' then
            local data = RSGCore.Functions.AwaitCallback('grumpy-groups:server:getGangMenu', 5000, true)
            if data then UI.Update('gang', data) end
        end
    end)
    cb('ok')
end)

-----------------------------------------------------------------------
-- gang location prompts + "Recruit to gang" target option
-----------------------------------------------------------------------
CreateThread(function()
    for _, v in ipairs(Config.GangLocations) do
        local name = 'grumpy-groups:gang:' .. v.id
        exports['rsg-core']:createPrompt(name, v.coords, RSGCore.Shared.Keybinds[Config.Gang.Keybind], locale('prompt_open_gang', v.name), {
            type = 'client', event = 'grumpy-groups:client:openGangLocation', args = {},
        })
        prompts[#prompts + 1] = name
    end
end)

if Config.Gang.TargetRecruit then
    exports['rsg-target']:addGlobalPlayer({
        {
            name = 'grumpy-groups:gangRecruit',
            icon = 'fa-solid fa-user-plus',
            label = locale('target_recruit_gang'),
            distance = 3.0,
            canInteract = function() return isBoss() end,
            onSelect = function(data)
                local id = UI.ServerIdFromPed(data and data.entity)
                if id then TriggerServerEvent('grumpy-groups:server:gangRecruit', id) end
            end,
        },
    })
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearGangBlips()
    for _, name in ipairs(prompts) do exports['rsg-core']:deletePrompt(name) end
    if Config.Gang.TargetRecruit then exports['rsg-target']:removeGlobalPlayer('grumpy-groups:gangRecruit') end
end)
