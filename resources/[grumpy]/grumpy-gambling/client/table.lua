-- Table UI bridge (DESIGN.md §10): the panel shown while seated. It draws the game's view (cards, pot, seats,
-- timer, feed) without taking the mouse, and takes it when it's this player's turn so they can click an action.
-- Esc gives the mouse back; G (the seat prompt) takes it again.
local focused = false
local shown = false
local wasMyTurn, lastWin = false, nil

-- Frontend sounds for this player (Config.Sounds)
local function sound(name)
    local S = Config.Sounds
    if not S.Enabled or not name then return end
    Citizen.InvokeNative(0x67C540AA08E4A6F5, name, S.Set, true, 0) -- PLAY_SOUND_FRONTEND
end

-- Moves this player can make right now (from the game's private view)
function GGC.MyTurn()
    local v = GGC.View
    local acts = v and v.private and v.private.actions
    return type(acts) == 'table' and #acts > 0
end

function GGC.TableFocused() return focused end

local function setFocus(on)
    if on and GGC.uiOpen then return end       -- a window (chips, picker, admin) has the mouse
    if on == focused then return end
    focused = on
    SetNuiFocus(on, on)
    SendNUIMessage({ action = 'tableFocus', on = on })
end
GGC.SetTableFocus = setFocus

local function show(view)
    shown = true
    SendNUIMessage({ action = 'table', view = view, feedLines = Config.TableUI.FeedLines, locale = GGC.UiLocale() })
end

local function hide()
    if not shown then return end
    shown = false
    setFocus(false)
    SendNUIMessage({ action = 'tableHide' })
end

AddEventHandler('grumpy-gambling:client:viewUpdated', function(view)
    show(view)
    local mine = GGC.MyTurn()
    if mine and not wasMyTurn then sound(Config.Sounds.Turn) end
    wasMyTurn = mine
    -- a pot (or payout) of ours on show: once per result
    local results = view.public and view.public.results
    if type(results) == 'table' then
        for _, r in ipairs(results) do
            if r.seat == view.seat and r.amount and r.amount > 0 then
                local key = tostring(view.public.game) .. ':' .. tostring(r.amount) .. ':' .. tostring(view.public._now)
                if lastWin ~= key then lastWin = key; sound(Config.Sounds.Win) end
            end
        end
    end
    if mine then
        if Config.TableUI.AutoFocus then setFocus(true) end
    else
        setFocus(false)
    end
end)

AddEventHandler('grumpy-gambling:client:feed', function(text)
    SendNUIMessage({ action = 'tableFeed', text = text })
end)

RegisterNetEvent('grumpy-gambling:client:stood', function()
    wasMyTurn, lastWin = false, nil
    hide()
end)

-- A window closed: if it's still our turn, take the mouse back for the table
AddEventHandler('grumpy-gambling:client:uiClosed', function()
    if shown and GGC.MyTurn() and Config.TableUI.AutoFocus then setFocus(true) end
end)

RegisterNUICallback('act', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' or type(body.id) ~= 'string' then return end
    local amount = body.amount and math.floor(tonumber(body.amount) or 0) or nil
    sound(body.id == 'fold' and Config.Sounds.Fold or Config.Sounds.Bet)
    TriggerServerEvent('grumpy-gambling:server:action', body.id, amount)
end)

RegisterNUICallback('tableBlur', function(_, cb)
    cb('ok')
    setFocus(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and focused then SetNuiFocus(false, false) end
end)
