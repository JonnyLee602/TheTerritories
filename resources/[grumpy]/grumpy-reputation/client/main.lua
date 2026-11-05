local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false

local function strings()
    local keys = { 'ui_title', 'ui_subtitle', 'ui_standing', 'ui_outlaw', 'ui_legit', 'ui_skills', 'ui_no_skills' }
    local t = {}
    for _, k in ipairs(keys) do t[k] = locale(k) end
    return t
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function open()
    if isOpen then return end
    local data = RSGCore.Functions.AwaitCallback('grumpy-reputation:server:getPanel', 5000)
    if not data then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data, locale = strings() })
end

RegisterCommand(Config.Command, open, false)
RegisterNUICallback('close', function(_, cb) close(); cb('ok') end)

-- refresh an open panel when standing changes
RegisterNetEvent('grumpy-reputation:client:changed', function()
    if not isOpen then return end
    local data = RSGCore.Functions.AwaitCallback('grumpy-reputation:server:getPanel', 5000)
    if data then SendNUIMessage({ action = 'update', data = data }) end
end)

-- client exports (read-only, from synced player data)
local function standing()
    local meta = RSGCore.Functions.GetPlayerData().metadata or {}
    local rep = type(meta.rep) == 'table' and meta.rep or {}
    return Rep.Clamp(rep[Config.Standing.RepKey] or Config.Standing.Start)
end
exports('GetStanding', standing)
exports('GetTier', function() return (Rep.TierFor(standing())) end)

-- honor / infamy prices for UIs (display only; the server works out the real price)
exports('GetPriceMultiplier', function(market, side) return Rep.PriceMultiplier(standing(), market, side) end)
exports('GetShopMultipliers', function(shopName) return Rep.ShopMultipliers(standing(), shopName) end)

-- one line when a shop's prices differ for this player (called by the rsg-stores patch)
exports('ShopGreeting', function(title, buyMult)
    buyMult = tonumber(buyMult) or 1.0
    local pct = math.floor(math.abs(1 - buyMult) * 100 + 0.5)
    if pct < 1 then return end
    RSGCore.Functions.Notify({
        title = title or locale('title'),
        description = locale(buyMult < 1 and 'shop_trusted' or 'shop_distrusted', pct),
        type = buyMult < 1 and 'success' or 'warning', duration = 5000,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
