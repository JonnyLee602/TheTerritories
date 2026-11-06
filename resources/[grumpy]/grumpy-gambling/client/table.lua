-- Table UI bridge (DESIGN.md §10): the panel shown while seated. It draws the game's view (cards, pot, seats,
-- timer, feed) without taking the mouse, and takes it when it's this player's turn so they can click an action.
-- Esc gives the mouse back; G (the seat prompt) takes it again.
local focused = false
local shown = false

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
    if GGC.MyTurn() then
        if Config.TableUI.AutoFocus then setFocus(true) end
    else
        setFocus(false)
    end
end)

AddEventHandler('grumpy-gambling:client:feed', function(text)
    SendNUIMessage({ action = 'tableFeed', text = text })
end)

RegisterNetEvent('grumpy-gambling:client:stood', hide)

-- A window closed: if it's still our turn, take the mouse back for the table
AddEventHandler('grumpy-gambling:client:uiClosed', function()
    if shown and GGC.MyTurn() and Config.TableUI.AutoFocus then setFocus(true) end
end)

RegisterNUICallback('act', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' or type(body.id) ~= 'string' then return end
    local amount = body.amount and math.floor(tonumber(body.amount) or 0) or nil
    TriggerServerEvent('grumpy-gambling:server:action', body.id, amount)
end)

RegisterNUICallback('tableBlur', function(_, cb)
    cb('ok')
    setFocus(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and focused then SetNuiFocus(false, false) end
end)
