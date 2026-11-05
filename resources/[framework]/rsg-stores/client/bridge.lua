-- ============================================
-- GRUMPY_BARTENDER INTEGRATION BRIDGE
-- Separated from core rsg-stores files for easy updates
-- ============================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local function getBridgeUiStrings()
    local code = GetConvar('ox:locale', 'en')
    local function load(lang)
        local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
        local ok, decoded = pcall(json.decode, raw or '')
        return ok and type(decoded) == 'table' and decoded or {}
    end
    local merged = load('en')
    if code ~= 'en' then for k, v in pairs(load(code)) do merged[k] = v end end
    local out = {}
    for k, v in pairs(merged) do
        if type(v) == 'string' and (k:sub(1, 3) == 'ui_' or k:sub(1, 3) == 'cl_') then out[k] = v end
    end
    return code, out
end

local function bridgeGetPlayerMoney()
    local data = RSGCore.Functions.GetPlayerData()
    return data and data.money and data.money.cash or 0
end

local function bridgeGetPlayerItems()
    local items, data = {}, RSGCore.Functions.GetPlayerData()
    for _, item in pairs(data and data.items or {}) do
        if item and item.amount and item.amount > 0 then
            local info = RSGCore.Shared.Items[item.name]
            local label = info and info.label or item.name
            local desc = info and info.description or ''
            local image = info and info.image or (item.name .. '.png')
            local category = info and (info.category or info.type) or 'misc'
            items[#items + 1] = { name = item.name, label = label, amount = item.amount, description = desc, image = image, category = category }
        end
    end
    return items
end

local function bridgeFormatItems(items)
    local out = {}
    for _, item in ipairs(items or {}) do
        local info = RSGCore.Shared.Items[item.name]
        local label = info and info.label or item.name
        local desc = info and info.description or ''
        local image = info and info.image or (item.name .. '.png')
        local category = info and (info.category or info.type) or 'misc'

        out[#out + 1] = {
            name = item.name,
            label = item.label or label,
            price = item.price,
            amount = item.amount,
            description = desc,
            image = image,
            category = category,
        }
    end
    return out
end

local function bridgeCloseShop()
    currentShop = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeShop' })
end

RegisterNetEvent('rsg-stores:client:openShopDirect', function(npcData)
    if not npcData or not npcData.shop then return end
    
    currentShop = npcData
    SetNuiFocus(true, true)

    local code, strings = getBridgeUiStrings()
    SendNUIMessage({
        action         = 'openShop',
        shopName       = npcData.shop.name,
        shopLabel      = npcData.shop.label,
        shopType       = npcData.shop.type,
        items          = bridgeFormatItems(npcData.shop.items),
        playerItems    = bridgeGetPlayerItems(),
        playerMoney    = bridgeGetPlayerMoney(),
        sellPercentage = SELL_PCT,
        feePercent     = FEE_PCT,
        maxStock       = (Config.SellAddsStock ~= false) and (tonumber(Config.MaxShopStock) or 0) or 0,
        locale         = code,
        uiStrings      = strings,
    })

    CreateThread(function()
        while currentShop == npcData do
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                bridgeCloseShop()
                break
            end
            Wait(500)
        end
    end)
end)

RegisterNUICallback('closeShop', function(_, cb)
    bridgeCloseShop()
    cb('ok')
end)

-- Send cart data securely to server without prematurely killing UI
RegisterNUICallback('purchaseCart', function(data, cb)
    cb('ok')
    if not currentShop or not data or type(data.items) ~= 'table' or #data.items == 0 then return end
    TriggerServerEvent('grumpy_bartender:server:processPurchase', currentShop.id, data.items)
end)

RegisterNetEvent('rsg-stores:client:purchaseSuccess', function()
    bridgeCloseShop()
end)