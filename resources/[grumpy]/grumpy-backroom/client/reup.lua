-- Closing-time re-up panel: shown at each warning to players inside, upper-right corner, no NUI focus.
-- Arrow up/down (or a tap of the key) = pick a length, hold the key = pay. The server checks the player is still inside and charges them.
local R = Config.Reup
local active -- { id, options, idx, hideAt, zone }

local function fits(i)
    local o = active and active.options[i]
    return o and o.fits
end

-- first option that still fits, starting at `from` and walking in `dir` (1 = down, -1 = up), wrapping round
local function firstFitting(from, dir)
    dir = dir or 1
    local n = #active.options
    for step = 0, n - 1 do
        local i = (from - 1 + step * dir) % n + 1
        if fits(i) then return i end
    end
end

-- move the highlight one fitting option up (-1) or down (1)
local function move(dir)
    if not active.idx then return end
    local n = #active.options
    local nxt = firstFitting((active.idx - 1 + dir) % n + 1, dir)
    if nxt and nxt ~= active.idx then
        active.idx = nxt
        PlaySoundFrontend('NAV_LEFT', 'PAUSE_MENU_SOUNDSET', true, 0) -- as used by rsg-menubase
        push()
    end
end

local function push(extra)
    local msg = { action = 'update', idx = active.idx, hold = 0 }
    for k, v in pairs(extra or {}) do msg[k] = v end
    SendNUIMessage(msg)
end

local function hide()
    if not active then return end
    active = nil
    SendNUIMessage({ action = 'hide' })
end

local function roomZone(id)
    for _, r in ipairs(GlobalState.grumpyBackrooms or {}) do
        if r.id == id then return r.zone end
    end
end

RegisterNetEvent('grumpy-backroom:client:reup', function(q)
    if not R.Enabled or type(q) ~= 'table' or type(q.options) ~= 'table' then return end
    local wasActive = active ~= nil
    active = { id = q.id, options = q.options, hideAt = GetGameTimer() + R.ShowSeconds * 1000, zone = roomZone(q.id) }
    active.idx = firstFitting(1)
    local opts = {}
    for i, o in ipairs(q.options) do
        opts[i] = { label = locale('reup_option', o.minutes, o.price), fits = o.fits }
    end
    SendNUIMessage({
        action = 'show',
        position = R.Position,
        title = locale('title'),
        name = q.name,
        left = q.left,
        options = opts,
        idx = active.idx,
        text = {
            closes = locale('reup_closes'),
            hint = active.idx and locale('reup_hint', R.KeyLabel, R.KeyLabel) or locale('reup_full'),
        },
    })
    PlaySoundFrontend('SELECT', 'RDRO_Character_Creator_Sounds', true, 0) -- sounds as used by rsg-menubase
    if wasActive then return end

    CreateThread(function()
        local pressedAt, paid = nil, false
        while active do
            DisableControlAction(0, R.Key, true) -- keep the journal shut while the panel is up
            local now = GetGameTimer()
            -- another UI has the mouse (the card table on your turn): leave every key to it
            local free = not IsNuiFocused()
            if free and active.idx then
                if IsControlJustPressed(0, R.UpKey) or IsDisabledControlJustPressed(0, R.UpKey) then move(-1)
                elseif IsControlJustPressed(0, R.DownKey) or IsDisabledControlJustPressed(0, R.DownKey) then move(1) end
            end
            local down = free and IsDisabledControlPressed(0, R.Key)
            if down and active.idx and not paid then
                pressedAt = pressedAt or now
                local held = now - pressedAt
                push({ hold = math.min(1.0, held / R.HoldMs) })
                if held >= R.HoldMs then
                    paid = true
                    TriggerServerEvent('grumpy-backroom:server:reup', active.id, active.idx)
                    push({ hold = 1.0, busy = true })
                end
            elseif not down and pressedAt then
                if not paid and now - pressedAt < R.HoldMs and active.idx then
                    move(1) -- a tap on the pay key also steps down
                elseif paid then
                    paid = false -- the server answers with reupDone (hide) or an error notify (try again)
                    if active then push() end
                end
                pressedAt = nil
            end
            local ped = PlayerPedId()
            if now > (active and active.hideAt or 0) or IsEntityDead(ped)
                or (active and active.zone and not BackroomZone.Contains(active.zone, GetEntityCoords(ped))) then
                hide()
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('grumpy-backroom:client:reupDone', function(id)
    if active and active.id == id then hide() end
end)

RegisterNetEvent('grumpy-backroom:client:showOut', hide)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then hide() end
end)
