-- Posse panel, "Invite to posse" on players and posse member blips

local posse = nil        -- latest snapshot from the server (nil = not in a posse)
local blips = {}         -- [serverId] = blip
local blipIsLeader = {}  -- [serverId] = bool
local B = Config.Posse.Blips

local function clearBlips()
    for id, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[id], blipIsLeader[id] = nil, nil
    end
end

RegisterNetEvent('grumpy-groups:client:posseUpdate', function(data)
    posse = data
    if not data then
        clearBlips()
        if UI.panel == 'posse' then UI.Update('posse', { none = true }) end
        return
    end
    if UI.panel == 'posse' then UI.Update('posse', data) end
end)

RegisterNetEvent('grumpy-groups:client:posseBlips', function(list)
    if not B.enabled or not posse or type(list) ~= 'table' then return end
    local me, seen = GetPlayerServerId(PlayerId()), {}
    for _, m in ipairs(list) do
        if m.src ~= me then
            seen[m.src] = true
            local blip = blips[m.src]
            -- leadership changed: rebuild so the leader sprite moves with it
            if blip and blipIsLeader[m.src] ~= (m.leader == true) then
                if DoesBlipExist(blip) then RemoveBlip(blip) end
                blip = nil
            end
            if not blip or not DoesBlipExist(blip) then
                blip = BlipAddForCoords(joaat(B.style), m.x, m.y, m.z) -- BLIP_ADD_FOR_COORDS
                BlipAddModifier(blip, joaat(B.modifier))              -- BLIP_ADD_MODIFIER
                if m.leader then SetBlipSprite(blip, joaat(B.leaderSprite), true) end
                SetBlipName(blip, m.name or '')
                blips[m.src], blipIsLeader[m.src] = blip, m.leader == true
            else
                SetBlipCoords(blip, m.x, m.y, m.z)                     -- SET_BLIP_COORDS
            end
        end
    end
    for id, blip in pairs(blips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            blips[id], blipIsLeader[id] = nil, nil
        end
    end
end)

-----------------------------------------------------------------------
-- panel
-----------------------------------------------------------------------
RegisterCommand(Config.Posse.Command, function()
    local data = RSGCore.Functions.AwaitCallback('grumpy-groups:server:getPosse', 5000)
    posse = data
    UI.Open('posse', data or { none = true })
end, false)

RegisterNUICallback('posseLeave', function(_, cb) TriggerServerEvent('grumpy-groups:server:posseLeave'); cb('ok') end)
RegisterNUICallback('posseDisband', function(_, cb) TriggerServerEvent('grumpy-groups:server:posseDisband'); cb('ok') end)
RegisterNUICallback('posseKick', function(body, cb)
    if type(body) == 'table' then TriggerServerEvent('grumpy-groups:server:posseKick', body.citizenid) end
    cb('ok')
end)
RegisterNUICallback('posseSetLeader', function(body, cb)
    if type(body) == 'table' then TriggerServerEvent('grumpy-groups:server:posseSetLeader', body.citizenid) end
    cb('ok')
end)

-----------------------------------------------------------------------
-- "Invite to posse" on any player
-----------------------------------------------------------------------
exports['rsg-target']:addGlobalPlayer({
    {
        name = 'grumpy-groups:posseInvite',
        icon = 'fa-solid fa-people-group',
        label = locale('target_invite_posse'),
        distance = Config.Posse.InviteDistance,
        canInteract = function()
            return not posse or posse.canInvite
        end,
        onSelect = function(data)
            local id = UI.ServerIdFromPed(data and data.entity)
            if id then TriggerServerEvent('grumpy-groups:server:posseInvite', id) end
        end,
    },
})

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    posse = nil
    clearBlips()
    if UI.panel == 'posse' then UI.Close() end
end)

-- client exports for other scripts
exports('IsInPosse', function() return LocalPlayer.state.posse ~= nil end)
exports('GetPosse', function() return posse end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    exports['rsg-target']:removeGlobalPlayer('grumpy-groups:posseInvite')
end)
