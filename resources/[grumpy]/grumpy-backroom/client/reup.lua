-- Closing-time re-up panel: shown at each warning to players inside, upper-right corner (clear of the card-table UI).
-- It takes the cursor: click a length, then Pay. "Not now" / Esc / timeout / leaving the room gives the cursor back.
-- The server checks the player is still inside and charges them.
local R = Config.Reup
local active -- { id, options, hideAt, zone, busy }

local function hide()
    if not active then return end
    active = nil
    SendNUIMessage({ action = 'hide' })
    SetNuiFocus(false, false)
end

local function roomZone(id)
    for _, r in ipairs(GlobalState.grumpyBackrooms or {}) do
        if r.id == id then return r.zone end
    end
end

local function firstFitting(options)
    for i, o in ipairs(options) do
        if o.fits then return i end
    end
end

RegisterNetEvent('grumpy-backroom:client:reup', function(q)
    if not R.Enabled or type(q) ~= 'table' or type(q.options) ~= 'table' then return end
    local wasActive = active ~= nil
    active = { id = q.id, options = q.options, hideAt = GetGameTimer() + R.ShowSeconds * 1000, zone = roomZone(q.id) }
    local opts = {}
    for i, o in ipairs(q.options) do
        opts[i] = { label = locale('reup_option', o.minutes, o.price), price = o.price, fits = o.fits }
    end
    local idx = firstFitting(q.options)
    SendNUIMessage({
        action = 'show',
        position = R.Position,
        title = locale('title'),
        name = q.name,
        left = q.left,
        options = opts,
        idx = idx,
        text = {
            closes = locale('reup_closes'),
            hint = idx and locale('reup_hint') or locale('reup_full'),
            pay = locale('reup_pay'),
            later = locale('reup_later'),
        },
    })
    SetNuiFocus(true, true)
    PlaySoundFrontend('SELECT', 'RDRO_Character_Creator_Sounds', true, 0) -- as used by rsg-menubase
    if wasActive then return end

    -- auto-hide: timeout, death, or walking out of the room
    CreateThread(function()
        while active do
            local ped = PlayerPedId()
            if GetGameTimer() > active.hideAt or IsEntityDead(ped)
                or (active.zone and not BackroomZone.Contains(active.zone, GetEntityCoords(ped))) then
                hide()
            end
            Wait(250)
        end
    end)
end)

RegisterNUICallback('reupPay', function(data, cb)
    cb('ok')
    local idx = math.tointeger(tonumber(type(data) == 'table' and data.idx))
    local o = active and idx and active.options[idx]
    if not o or not o.fits or active.busy then return end
    active.busy = true
    active.hideAt = GetGameTimer() + R.ShowSeconds * 1000 -- don't vanish while the server answers
    TriggerServerEvent('grumpy-backroom:server:reup', active.id, idx)
    -- the server answers with reupDone (hide) or an error notify: let them try again
    SetTimeout(2500, function()
        if active then
            active.busy = false
            SendNUIMessage({ action = 'ready' })
        end
    end)
end)

RegisterNUICallback('reupClose', function(_, cb)
    cb('ok')
    hide()
end)

RegisterNetEvent('grumpy-backroom:client:reupDone', function(id)
    if active and active.id == id then hide() end
end)

RegisterNetEvent('grumpy-backroom:client:showOut', hide)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then hide() end
end)
