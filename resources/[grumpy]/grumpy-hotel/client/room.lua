-- Inside a room: interior zone, room menu, knock prompts, voice channel, death watch, spawn restore.
local RSGCore = exports['rsg-core']:GetCoreObject()

local roomZone, stashZone = nil, nil
local currentKnock = nil

-- renter, key holder and law with a warrant (the server re-checks on open)
local STASH_ROLES = { renter = true, key = true, law = true }

local function removeRoomZone()
    if roomZone then pcall(function() exports['rsg-target']:removeZone(roomZone) end) end
    if stashZone then pcall(function() exports['rsg-target']:removeZone(stashZone) end) end
    roomZone, stashZone = nil, nil
end

-- pos = interior point (room menu + leave); stash = optional stash point (its own Storage target)
local function addRoomZone(pos, stash)
    removeRoomZone()
    if stash then
        stashZone = exports['rsg-target']:addSphereZone({
            coords = vector3(stash.x, stash.y, stash.z),
            radius = Config.StashRadius,
            debug = Config.Debug,
            options = {
                { name = 'grumpy-hotel:stash', icon = 'fa-solid fa-box-archive', label = locale('opt_stash'),
                  distance = Config.StashRadius + 1.0,
                  canInteract = function() return InRoom ~= nil and STASH_ROLES[InRoom.role] == true end,
                  onSelect = function() TriggerServerEvent('grumpy-hotel:server:openStash') end },
            },
        })
    end
    roomZone = exports['rsg-target']:addSphereZone({
        coords = vector3(pos.x, pos.y, pos.z),
        radius = Config.RoomRadius,
        debug = Config.Debug,
        options = {
            { name = 'grumpy-hotel:room', icon = 'fa-solid fa-bed', label = locale('opt_room'),
              distance = Config.RoomRadius + 1.0, canInteract = function() return InRoom ~= nil end,
              onSelect = function() CreateThread(OpenRoomMenu) end },
            { name = 'grumpy-hotel:leave', icon = 'fa-solid fa-door-open', label = locale('opt_leave'),
              distance = Config.RoomRadius + 1.0, canInteract = function() return InRoom ~= nil end,
              onSelect = function() TriggerServerEvent('grumpy-hotel:server:leave') end },
        },
    })
end

local function setVoice(channel)
    if not Config.Voice.Enabled then return end
    if channel then MumbleSetVoiceChannel(channel) else MumbleClearVoiceChannel() end
end

---------------------------------------------------------------------
-- Death watch: dying in a room puts you outside the door for medics
---------------------------------------------------------------------
local function watchDeath()
    CreateThread(function()
        local sent = 0
        while InRoom do
            local ped = PlayerPedId()
            local pd = RSGCore.Functions.GetPlayerData()
            local dead = IsEntityDead(ped) or (pd and pd.metadata and pd.metadata.isdead)
            if dead and GetGameTimer() - sent > 5000 then
                sent = GetGameTimer()
                TriggerServerEvent('grumpy-hotel:server:died')
            end
            Wait(1000)
        end
    end)
end

---------------------------------------------------------------------
-- Server moved us in / out
---------------------------------------------------------------------
RegisterNetEvent('grumpy-hotel:client:entered', function(data, noTeleport)
    InRoom = data
    CloseUI()
    setVoice(data.voice)
    addRoomZone(data.interior, data.stash)
    watchDeath()
    if noTeleport then
        if IsScreenFadedOut() then DoScreenFadeIn(500) end
    else
        CreateThread(function() TeleportTo(data.interior) end)
    end
end)

RegisterNetEvent('grumpy-hotel:client:left', function(door)
    InRoom = nil
    CloseUI()
    if currentKnock then HideKnock(currentKnock) currentKnock = nil end
    setVoice(nil)
    removeRoomZone()
    if door then
        CreateThread(function()
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                -- a dead ped can't be faded/frozen through the normal flow: just move the body
                SetEntityCoords(ped, door.x, door.y, door.z - 1.0, false, false, false, false)
            else
                TeleportTo(vector4(door.x, door.y, door.z, ((door.w or 0.0) + 180.0) % 360.0))
            end
        end)
    end
end)

RegisterNetEvent('grumpy-hotel:client:role', function(role)
    if InRoom then InRoom.role = role end
end)

-- An admin moved this hotel's interior / stash point while we're inside
RegisterNetEvent('grumpy-hotel:client:roomPoints', function(interior, stash)
    if not InRoom then return end
    InRoom.interior, InRoom.stash = interior, stash
    addRoomZone(interior, stash)
end)

---------------------------------------------------------------------
-- Room menu
---------------------------------------------------------------------
local function fetchRoom() return RSGCore.Functions.AwaitCallback('grumpy-hotel:server:roomMenu') end

function OpenRoomMenu()
    if UI.open or not InRoom then return end
    local data = fetchRoom()
    if data then OpenUI('room', data) end
end

RegisterNetEvent('grumpy-hotel:client:roomRefresh', function()
    if not (UI.open and UI.view == 'room') then return end
    local data = fetchRoom()
    if data then UpdateUI('room', data) else CloseUI() end
end)

RegisterNUICallback('roomStash', function(_, cb)
    cb('ok')
    CloseUI()
    TriggerServerEvent('grumpy-hotel:server:openStash')
end)

RegisterNUICallback('roomLeave', function(_, cb)
    cb('ok')
    CloseUI()
    TriggerServerEvent('grumpy-hotel:server:leave')
end)

RegisterNUICallback('roomKick', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-hotel:server:kick', tonumber(body.src)) end
end)

RegisterNUICallback('roomGiveKey', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-hotel:server:giveKey', tonumber(body.src)) end
end)

RegisterNUICallback('roomRevokeKey', function(_, cb)
    cb('ok')
    TriggerServerEvent('grumpy-hotel:server:revokeKey')
end)

---------------------------------------------------------------------
-- Knocks (only ever sent to renters / key holders who are inside)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-hotel:client:knock', function(data)
    if not InRoom or type(data) ~= 'table' then return end
    currentKnock = data.id
    NotifyLocal(locale('someone_knocking', data.name), 'inform')
    ShowKnock(data)
end)

RegisterNetEvent('grumpy-hotel:client:knockClosed', function(id)
    if currentKnock == id then
        HideKnock(id)
        currentKnock = nil
    end
end)

RegisterNUICallback('knockAnswer', function(body, cb)
    cb('ok')
    local id = currentKnock
    currentKnock = nil
    HideKnock(id)
    if id and type(body) == 'table' then TriggerServerEvent('grumpy-hotel:server:answerKnock', id, body.allow == true) end
end)

---------------------------------------------------------------------
-- Login restore: tell the server once we've actually spawned so it can decide
-- whether we're still in the room (renter / key / warrant) or go back outside
---------------------------------------------------------------------
local function waitForSpawn()
    local deadline, stableSince = GetGameTimer() + 90000, nil
    while GetGameTimer() < deadline do
        local ped = PlayerPedId()
        local ready = IsScreenFadedIn() and IsEntityVisible(ped) and HasCollisionLoadedAroundEntity(ped)
        if ready then
            stableSince = stableSince or GetGameTimer()
            if GetGameTimer() - stableSince >= 3000 then break end
        else
            stableSince = nil
        end
        Wait(500)
    end
    TriggerServerEvent('grumpy-hotel:server:spawned')
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() CreateThread(waitForSpawn) end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    InRoom = nil
    setVoice(nil)
    removeRoomZone()
    if currentKnock then HideKnock(currentKnock) currentKnock = nil end
    CloseUI()
end)

---------------------------------------------------------------------
-- /hotelbucket result (server sends the bucket; the voice channel is read here)
-- MUMBLE_GET_VOICE_CHANNEL_FROM_SERVER_ID 0x221C09F1 (natives/db/INDEX.tsv, CFX)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-hotel:client:bucketInfo', function(d)
    if type(d) ~= 'table' then return end
    local voice = MumbleGetVoiceChannelFromServerId(GetPlayerServerId(PlayerId()))
    local lines = {}
    if d.inside then
        lines[#lines + 1] = locale('bucket_inside', d.bucket, d.label, d.room, locale('ui_role_' .. tostring(d.role)))
    elseif d.bucket == 0 then
        lines[#lines + 1] = locale('bucket_world')
    elseif d.bucketLabel then
        lines[#lines + 1] = locale('bucket_stray_room', d.bucket, d.bucketLabel, d.bucketRoom)
    else
        lines[#lines + 1] = locale('bucket_other', d.bucket)
    end
    lines[#lines + 1] = locale('bucket_players', d.players)
    if d.inside and d.bucket ~= d.expected then lines[#lines + 1] = locale('bucket_mismatch', d.expected) end
    -- in a room the channel must be the room's; outside it's whatever rsg-voice uses, so just show it
    local voiceOk = not d.voice or voice == d.voice
    if d.voice then
        lines[#lines + 1] = locale(voiceOk and 'bucket_voice_ok' or 'bucket_voice_bad', voice, d.voice)
    else
        lines[#lines + 1] = locale('bucket_voice', voice)
    end
    local ok = (not d.inside or d.bucket == d.expected) and voiceOk
    local msg = table.concat(lines, ' · ')
    print('[grumpy-hotel] ' .. msg)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = ok and 'inform' or 'error', duration = 12000 })
end)

---------------------------------------------------------------------
-- Exports + cleanup
---------------------------------------------------------------------
exports('IsInRoom', function()
    if not InRoom then return false end
    return true, InRoom.hotel, InRoom.room, InRoom.role
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeRoomZone()
    if InRoom then setVoice(nil) end
end)
