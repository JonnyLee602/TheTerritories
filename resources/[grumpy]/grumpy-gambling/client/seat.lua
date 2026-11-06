-- Seated state: chair scenario, stand / choose-game prompts, the game + tier picker.
local preSeat = nil          -- { x, y, z, h } where the player stood before sitting
local isSetupPlayer = false
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local standPrompt, setupPrompt

local function makePrompt(key, text, holdMs)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetEnabled(p, false)
    PromptSetVisible(p, false)
    if holdMs then PromptSetHoldMode(p, holdMs) else PromptSetStandardMode(p, true) end
    PromptSetGroup(p, promptGroup, 0)
    PromptRegisterEnd(p)
    return p
end

local function showPrompt(p, on)
    PromptSetEnabled(p, on)
    PromptSetVisible(p, on)
end

CreateThread(function()
    standPrompt = makePrompt(Config.Seating.StandKey, locale('prompt_stand'), Config.Seating.StandHoldMs)
    setupPrompt = makePrompt(Config.Seating.SetupKey, locale('prompt_setup'))
end)

local function sitAt(t, seat)
    local ped = PlayerPedId()
    local x, y, z, h = GGC.SeatWorld(t, seat)
    if not x then return end
    local c = GetEntityCoords(ped)
    preSeat = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
    z = z + (t.sitZ or 0.5) + (IsPedMale(ped) and 0.0 or Config.Seating.FemaleZ)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioAtPosition(ped, joaat(Config.Seating.Scenario), x, y, z, h, -1, false, true)
end

local function leaveSeat()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    if preSeat and #(GetEntityCoords(ped) - vector3(preSeat.x, preSeat.y, preSeat.z)) < 10.0 then
        SetEntityCoordsNoOffset(ped, preSeat.x, preSeat.y, preSeat.z, false, false, false)
        SetEntityHeading(ped, preSeat.h)
    end
    preSeat = nil
end

---------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:client:seated', function(id, seat)
    local t = GGC.Tables[id]
    if not t then return end
    GGC.Seat = { id = id, seat = seat }
    sitAt(t, seat)
    GGC.Notify(locale('seated', t.label), 'success')
end)

RegisterNetEvent('grumpy-gambling:client:stood', function()
    if not GGC.Seat then return end
    GGC.Seat = nil
    isSetupPlayer = false
    if GGC.uiOpen == 'setup' then GGC.CloseUI() end
    leaveSeat()
end)

RegisterNetEvent('grumpy-gambling:client:setup', function(options)
    if not GGC.Seat or type(options) ~= 'table' then return end
    isSetupPlayer = true
    if GGC.uiOpen and GGC.uiOpen ~= 'setup' then return end
    GGC.OpenUI('setup', options)
end)

RegisterNetEvent('grumpy-gambling:client:setupClosed', function()
    isSetupPlayer = false
    if GGC.uiOpen == 'setup' then GGC.CloseUI() end
end)

RegisterNUICallback('configure', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    TriggerServerEvent('grumpy-gambling:server:configure', tostring(body.game or ''), tostring(body.tier or ''))
end)

---------------------------------------------------------------------
-- Seated loop: prompts, death, drifting away
---------------------------------------------------------------------
CreateThread(function()
    while true do
        if not GGC.Seat or not standPrompt then
            Wait(500)
        else
            Wait(0)
            local seat = GGC.Seat
            local t = GGC.Tables[seat.id]
            local ped = PlayerPedId()
            if not t or IsEntityDead(ped) then
                TriggerServerEvent('grumpy-gambling:server:stand')
                Wait(1500)
            else
                local x, y, z = GGC.SeatWorld(t, seat.seat)
                if x and #(GetEntityCoords(ped) - vector3(x, y, z)) > Config.ServerSeatDistance then
                    TriggerServerEvent('grumpy-gambling:server:stand')
                    Wait(1500)
                elseif not GGC.uiOpen then
                    local setupOn = isSetupPlayer and t.state == 'setup'
                    showPrompt(standPrompt, true)
                    showPrompt(setupPrompt, setupOn)
                    local title = t.gameLabel and ('%s · %s'):format(t.label, t.gameLabel) or t.label
                    PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', title))
                    if PromptHasHoldModeCompleted(standPrompt) then
                        TriggerServerEvent('grumpy-gambling:server:stand')
                        Wait(1000)
                    elseif setupOn and PromptHasStandardModeCompleted(setupPrompt) then
                        TriggerServerEvent('grumpy-gambling:server:requestSetup')
                        Wait(500)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GGC.Seat then leaveSeat() end
    if standPrompt then PromptDelete(standPrompt) end
    if setupPrompt then PromptDelete(setupPrompt) end
end)
