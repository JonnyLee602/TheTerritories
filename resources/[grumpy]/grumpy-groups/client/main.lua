RSGCore = exports['rsg-core']:GetCoreObject()

-- shared client NUI bridge for gang.lua and posse.lua
UI = { panel = nil, invite = nil }

local function refreshFocus()
    local focus = UI.panel ~= nil or UI.invite ~= nil
    SetNuiFocus(focus, focus)
end

function UI.Open(view, data)
    UI.panel = view
    SendNUIMessage({ action = 'open', view = view, data = data, locale = UI.Strings() })
    refreshFocus()
end

function UI.Update(view, data)
    if UI.panel ~= view then return end
    SendNUIMessage({ action = 'update', view = view, data = data })
end

function UI.Close()
    if not UI.panel then return end
    UI.panel = nil
    SendNUIMessage({ action = 'close' })
    refreshFocus()
end

function UI.Notify(description, nType)
    RSGCore.Functions.Notify({ title = locale('title_groups'), description = description, type = nType or 'inform', duration = 5000 })
end

-- every string the NUI shows, so the html has no hard-coded text
function UI.Strings()
    local keys = {
        'ui_gang_subtitle', 'ui_members', 'ui_recruit', 'ui_stash', 'ui_bank', 'ui_balance', 'ui_deposit', 'ui_withdraw',
        'ui_amount', 'ui_confirm', 'ui_cancel', 'ui_back', 'ui_online', 'ui_offline', 'ui_you', 'ui_set_rank', 'ui_remove',
        'ui_remove_confirm', 'ui_no_members', 'ui_no_nearby', 'ui_recruit_btn', 'ui_posse_title', 'ui_posse_subtitle',
        'ui_posse_none', 'ui_time_left', 'ui_leader', 'ui_make_leader', 'ui_kick', 'ui_leave', 'ui_disband',
        'ui_disband_confirm', 'ui_leave_confirm', 'ui_invite_gang', 'ui_invite_posse', 'ui_accept', 'ui_decline',
        'ui_your_cash', 'ui_current', 'ui_size',
    }
    local t = {}
    for _, k in ipairs(keys) do t[k] = locale(k) end
    return t
end

RegisterNUICallback('close', function(_, cb) UI.Close(); cb('ok') end)

-- target helper: server id of a targeted player ped (or nil)
function UI.ServerIdFromPed(ped)
    if not ped or ped == 0 or not IsPedAPlayer(ped) then return end
    local player = NetworkGetPlayerIndexFromPed(ped)
    if player == -1 then return end
    return GetPlayerServerId(player)
end

-----------------------------------------------------------------------
-- invite card (gang recruit + posse invite). The server awaits our answer.
-----------------------------------------------------------------------
local pendingInvite

RSGCore.Functions.CreateClientCallback('grumpy-groups:client:confirmInvite', function(cb, data)
    if pendingInvite then return cb(false) end -- already answering one
    pendingInvite = cb
    UI.invite = true
    SendNUIMessage({ action = 'invite', data = data, locale = UI.Strings() })
    refreshFocus()
end)

local function answerInvite(answer)
    if pendingInvite then pendingInvite(answer == true) end
    pendingInvite = nil
    UI.invite = nil
    SendNUIMessage({ action = 'closeInvite' })
    refreshFocus()
end

RegisterNUICallback('inviteAnswer', function(body, cb)
    answerInvite(type(body) == 'table' and body.accept == true)
    cb('ok')
end)

RegisterNetEvent('grumpy-groups:client:closeInvite', function()
    if UI.invite then answerInvite(false) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
