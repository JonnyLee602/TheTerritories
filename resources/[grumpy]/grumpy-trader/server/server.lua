-- grumpy-trader: based on rsg-trader by RexShack (Rexshack-RedM). Legal / illegal traders, honor/infamy
-- prices and laundering added for The Territories.
local RSGCore = exports['rsg-core']:GetCoreObject()

-- rsg-core callback wrapper: handlers return their result instead of calling cb
local function callback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        cb(fn(source, ...))
    end)
end

local cooldowns = {}
local Traders = {} -- traderid -> trader row (loaded from grumpy_trader_npcs)
local launderBusy = {} -- traderid -> true while a wash is being written

---------------------------------------------
-- trader npcs (database)
---------------------------------------------
local function syncTraders()
    local list = {}
    for _, t in pairs(Traders) do
        -- clients only need what spawns the ped and the blip
        list[#list + 1] = { traderid = t.traderid, tradername = t.tradername, npcmodel = t.npcmodel,
            x = t.x, y = t.y, z = t.z, heading = t.heading, showblip = t.showblip, kind = t.kind }
    end
    GlobalState.grumpyTraders = list
end

local function normalize(r)
    r.showblip = r.showblip == 1 or r.showblip == true
    r.launder = r.launder == 1 or r.launder == true
    r.kind = Config.Kinds[r.kind] and r.kind or 'legal'
    r.launder_cut = tonumber(r.launder_cut)
    return r
end

local function loadTraders()
    local rows = MySQL.query.await('SELECT * FROM grumpy_trader_npcs') or {}
    Traders = {}
    for _, r in ipairs(rows) do Traders[r.traderid] = normalize(r) end
    syncTraders()
    print(('[%s] ^2Loaded %d traders^7'):format(GetCurrentResourceName(), #rows))
end

AddEventHandler('grumpy-trader:server:databaseReady', loadTraders)

local function makeTraderId(name)
    local base = name:lower():gsub('[^%w]', ''):sub(1, 40)
    if base == '' then base = 'trader' end
    local id, n = base, 1
    while Traders[id] do
        n = n + 1
        id = base .. n
    end
    return id
end

---------------------------------------------
-- helpers
---------------------------------------------
local function copyTable(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function result(ok, msg, extra)
    local r = extra or {}
    r.ok, r.msg = ok, msg
    return r
end

local round2 = Config.Round2

local function isAdmin(src)
    return RSGCore.Functions.GetPlayer(src) ~= nil and RSGCore.Functions.HasPermission(src, 'admin')
end

local function isNearTrader(src, trader)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(trader.x, trader.y, trader.z)) <= Config.InteractDistance
end

local function onCooldown(src)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < Config.Cooldown then return true end
    cooldowns[src] = now
    return false
end

local function toInt(v, min, max)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    v = math.floor(v)
    if (min and v < min) or (max and v > max) then return nil end
    return v
end

local function trim(s)
    return type(s) == 'string' and s:gsub('^%s+', ''):gsub('%s+$', '') or nil
end

-- discord webhook (server/webhooks.lua) + optional rsg-log
local function log(event, src, title, fields, msg)
    Webhook.Send(event, src, title, fields)
    if WebhookConfig.UseRsgLog then
        TriggerEvent('rsg-log:server:CreateLog', 'grumpytrader', 'Grumpy Trader', 'default', msg, false)
    end
end

local function traderLabel(traderid)
    local t = Traders[traderid]
    return t and ('%s (`%s`, %s)'):format(t.tradername, traderid, t.kind) or ('`%s`'):format(tostring(traderid))
end

local function money(n) return ('$%.2f'):format(n) end

local function adminDenied(src, action)
    Webhook.Suspicious(src, locale('wh_reason_no_admin'), action)
end

local function kindOf(trader) return Config.Kinds[trader.kind] or Config.Kinds.legal end

local function lawBlocked(Player, trader)
    if not kindOf(trader).blockLaw then return false end
    local job = Player.PlayerData.job or {}
    return job.type == 'leo' and job.onduty == true
end

---------------------------------------------
-- honor / infamy (grumpy-reputation)
---------------------------------------------
local function repRunning()
    return Config.Standing.Enabled and GetResourceState('grumpy-reputation') == 'started'
end

local function standingMult(src, trader, side)
    local market = kindOf(trader).market
    if not market or not repRunning() then return 1.0 end
    local ok, m = pcall(function() return exports['grumpy-reputation']:GetPriceMultiplier(src, market, side) end)
    m = ok and tonumber(m) or 1.0
    if m ~= m or m <= 0 then return 1.0 end
    return m
end

local function arbitrageFactor()
    local ok, f = pcall(function() return exports['grumpy-reputation']:GetArbitrageFactor() end)
    f = ok and tonumber(f) or nil
    return (f and f > 0) and f or 0.7
end

-- lowest possible buy price (any trader, any stock level) per item, for items some trader sells
local function lowestBuyPrices(items)
    local out = {}
    if #items == 0 then return out end
    local marks = {}
    for i = 1, #items do marks[i] = '?' end
    local rows = MySQL.query.await(([[
        SELECT t.item, MIN(t.baseprice) AS base FROM grumpy_trader t
        JOIN grumpy_trader_npcs n ON n.traderid = t.traderid
        WHERE t.mode <> 'sell' AND t.item IN (%s) GROUP BY t.item
    ]]):format(table.concat(marks, ',')), items) or {}
    for _, r in ipairs(rows) do out[r.item] = Config.GetLowestBuyPrice(tonumber(r.base) or 0) end
    return out
end

-- buy and sell unit prices for this player at this trader
local function pricesFor(src, trader, row, lowest, buyMult, sellMult)
    local buy = round2(Config.GetBuyPrice(row.stock, row.lowstock, row.highstock, row.baseprice) * buyMult)
    local sell = Config.GetSellPrice(row.stock, row.lowstock, row.highstock, row.baseprice) * sellMult
    if repRunning() and lowest then
        -- no buy-low / sell-high loop: never pay more than the cheapest discounted price it can be bought for
        sell = math.min(sell, lowest * arbitrageFactor())
    end
    return buy, round2(sell)
end

---------------------------------------------
-- shared validation for buy/sell; returns Player, trader, row, amount, itemData or nil + message
---------------------------------------------
local function validateTrade(src, traderid, item, amount, max)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(traderid) ~= 'string' or type(item) ~= 'string' then
        Webhook.Suspicious(src, locale('wh_reason_malformed'), ('traderid=%s item=%s'):format(type(traderid), type(item)))
        return
    end
    local trader = Traders[traderid]
    local itemData = RSGCore.Shared.Items[item]
    local qty = toInt(amount, 1, max)
    if not trader or not itemData or not qty then
        Webhook.Suspicious(src, locale('wh_reason_invalid'), ('trader=%s item=%s amount=%s (max %s)'):format(traderid, item, tostring(amount), max))
        return nil, locale('sv_invalid_trade')
    end
    if not isNearTrader(src, trader) then
        local c = GetEntityCoords(GetPlayerPed(src))
        Webhook.Suspicious(src, locale('wh_reason_too_far'), ('trader=%s at %.1f, %.1f, %.1f | player at %.1f, %.1f, %.1f'):format(
            traderid, trader.x, trader.y, trader.z, c.x, c.y, c.z))
        return nil, locale('sv_too_far')
    end
    if lawBlocked(Player, trader) then return nil, locale('sv_law_blocked') end
    if onCooldown(src) then return nil, locale('sv_cooldown') end
    local row = MySQL.single.await('SELECT * FROM grumpy_trader WHERE traderid = ? AND item = ?', { traderid, item })
    if not row then return nil, locale('sv_invalid_trade') end
    row.baseprice = tonumber(row.baseprice) or 0
    return Player, trader, row, qty, itemData
end

---------------------------------------------
-- laundering helpers
---------------------------------------------
local function today() return os.date('%Y-%m-%d') end

local function launderCut(src, trader)
    local L = Config.Laundering
    local cut = trader.launder_cut or L.DefaultCut
    if L.StandingScales then cut = cut * standingMult(src, trader, 'buy') end
    return math.max(L.MinCut, math.min(L.MaxCut, round2(cut)))
end

local function launderLeft(trader, citizenid)
    local L = Config.Laundering
    local day = today()
    local playerLeft, traderLeft = math.huge, math.huge
    if (L.PlayerDailyLimit or 0) > 0 then
        local used = tonumber(MySQL.scalar.await('SELECT amount FROM grumpy_trader_laundering WHERE traderid = ? AND citizenid = ? AND `day` = ?',
            { trader.traderid, citizenid, day })) or 0
        playerLeft = math.max(0, L.PlayerDailyLimit - used)
    end
    if (L.TraderDailyLimit or 0) > 0 then
        local used = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM grumpy_trader_laundering WHERE traderid = ? AND `day` = ?',
            { trader.traderid, day })) or 0
        traderLeft = math.max(0, L.TraderDailyLimit - used)
    end
    return round2(math.min(playerLeft, traderLeft)), playerLeft, traderLeft
end

local function canLaunder(trader) return trader.kind == 'illegal' and trader.launder end

local function launderInfo(src, Player, trader)
    if not canLaunder(trader) then return nil end
    local left = launderLeft(trader, Player.PlayerData.citizenid)
    return {
        cut = launderCut(src, trader),
        left = left ~= math.huge and left or -1, -- -1 = no limit
        min = Config.Laundering.MinAmount,
    }
end

---------------------------------------------
-- shop: trader stock with server-calculated prices for this player
---------------------------------------------
callback('grumpy-trader:server:traderdata', function(source, traderid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local trader = type(traderid) == 'string' and Traders[traderid]
    if not Player or not trader then return result(false, locale('sv_not_found')) end
    if lawBlocked(Player, trader) then return result(false, locale('sv_law_blocked')) end

    local rows = MySQL.query.await('SELECT item, stock, lowstock, highstock, baseprice, mode FROM grumpy_trader WHERE traderid = ? ORDER BY item', { traderid }) or {}
    local names = {}
    for _, r in ipairs(rows) do names[#names + 1] = r.item end
    local lowest = repRunning() and lowestBuyPrices(names) or {}
    local buyMult, sellMult = standingMult(src, trader, 'buy'), standingMult(src, trader, 'sell')

    local list = {}
    for _, r in ipairs(rows) do
        if RSGCore.Shared.Items[r.item] then
            r.baseprice = tonumber(r.baseprice) or 0
            r.mode = Config.ItemModes[r.mode] and r.mode or 'both'
            r.buyprice, r.sellprice = pricesFor(src, trader, r, lowest[r.item], buyMult, sellMult)
            r.baseprice = nil -- the player sees their price, not the base
            list[#list + 1] = r
        end
    end
    local k = kindOf(trader)
    local m = Player.PlayerData.money or {}
    return result(true, nil, {
        items = list,
        kind = trader.kind,
        payWith = k.payWith,
        payOut = k.payOut,
        money = { cash = m.cash or 0, bloodmoney = m.bloodmoney or 0 },
        buyMult = buyMult,
        launder = launderInfo(src, Player, trader),
    })
end)

---------------------------------------------
-- shop: player buys from the trader
---------------------------------------------
callback('grumpy-trader:server:buy', function(source, traderid, item, amount)
    local src = source
    local Player, trader, row, qty, itemData = validateTrade(src, traderid, item, amount, Config.MaxBuyAmount)
    if not Player then return result(false, trader) end
    if row.mode == 'sell' then return result(false, locale('sv_invalid_trade')) end
    if row.stock < qty then return result(false, locale('sv_not_enough_stock', row.stock)) end

    local unit = round2(Config.GetBuyPrice(row.stock, row.lowstock, row.highstock, row.baseprice) * standingMult(src, trader, 'buy'))
    local total = round2(unit * qty)
    local k = kindOf(trader)
    local payType
    for _, mt in ipairs(k.payWith) do
        if (Player.Functions.GetMoney(mt) or 0) >= total then payType = mt break end
    end
    if not payType then return result(false, locale('sv_not_enough_money')) end
    if not exports['rsg-inventory']:CanAddItem(src, item, qty) then return result(false, locale('sv_inventory_full')) end

    -- atomic stock reservation (prevents two players buying the same stock)
    local affected = MySQL.update.await('UPDATE grumpy_trader SET stock = stock - ? WHERE traderid = ? AND item = ? AND stock >= ?', { qty, traderid, item, qty })
    if not affected or affected < 1 then return result(false, locale('sv_stock_changed')) end

    local reason = Config.Reasons[trader.kind].buy
    if total > 0 and not Player.Functions.RemoveMoney(payType, total, reason) then
        MySQL.update('UPDATE grumpy_trader SET stock = stock + ? WHERE traderid = ? AND item = ?', { qty, traderid, item })
        return result(false, locale('sv_not_enough_money'))
    end

    if not exports['rsg-inventory']:AddItem(src, item, qty, nil, nil, reason) then
        -- refund if the inventory rejected the item after payment
        if total > 0 then Player.Functions.AddMoney(payType, total, 'grumpy-trader-refund') end
        MySQL.update('UPDATE grumpy_trader SET stock = stock + ? WHERE traderid = ? AND item = ?', { qty, traderid, item })
        return result(false, locale('sv_inventory_full'))
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemData, 'add', qty)
    log('buy', src, locale('wh_title_buy'), {
        { name = locale('wh_trader'), value = traderLabel(traderid) },
        { name = locale('wh_item'), value = ('%dx %s (`%s`)'):format(qty, itemData.label, item) },
        { name = locale('wh_total'), value = ('%s (%s)'):format(money(total), payType) },
        { name = locale('wh_stock_left'), value = tostring(row.stock - qty) },
    }, ('%s bought %sx %s from %s for %s %s'):format(GetPlayerName(src), qty, itemData.label, traderid, money(total), payType))
    if WebhookConfig.LargeTradeAmount > 0 and total >= WebhookConfig.LargeTradeAmount then
        Webhook.Send('buy', src, locale('wh_title_large_buy'), { { name = locale('wh_total'), value = money(total) } }, nil, WebhookConfig.LargeTradePing)
    end
    return result(true, locale(payType == 'bloodmoney' and 'sv_bought_dirty' or 'sv_bought', qty, itemData.label, ('%.2f'):format(total)))
end)

---------------------------------------------
-- shop: player sells to the trader
---------------------------------------------
callback('grumpy-trader:server:sell', function(source, traderid, item, amount)
    local src = source
    local Player, trader, row, qty, itemData = validateTrade(src, traderid, item, amount, Config.MaxSellAmount)
    if not Player then return result(false, trader) end
    if row.mode == 'buy' then return result(false, locale('sv_invalid_trade')) end

    local lowest = repRunning() and lowestBuyPrices({ item })[item] or nil
    local _, unit = pricesFor(src, trader, row, lowest, 1.0, standingMult(src, trader, 'sell'))
    local total = round2(unit * qty)
    if total <= 0 then return result(false, locale('sv_invalid_trade')) end
    local reason = Config.Reasons[trader.kind].sell
    if not exports['rsg-inventory']:RemoveItem(src, item, qty, nil, reason) then
        return result(false, locale('sv_not_enough_items'))
    end

    local payOut = kindOf(trader).payOut
    Player.Functions.AddMoney(payOut, total, reason)
    MySQL.update.await('UPDATE grumpy_trader SET stock = stock + ? WHERE traderid = ? AND item = ?', { qty, traderid, item })
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemData, 'remove', qty)
    log('sell', src, locale('wh_title_sell'), {
        { name = locale('wh_trader'), value = traderLabel(traderid) },
        { name = locale('wh_item'), value = ('%dx %s (`%s`)'):format(qty, itemData.label, item) },
        { name = locale('wh_total'), value = ('%s (%s)'):format(money(total), payOut) },
        { name = locale('wh_stock_now'), value = tostring(row.stock + qty) },
    }, ('%s sold %sx %s to %s for %s %s'):format(GetPlayerName(src), qty, itemData.label, traderid, money(total), payOut))
    if WebhookConfig.LargeTradeAmount > 0 and total >= WebhookConfig.LargeTradeAmount then
        Webhook.Send('sell', src, locale('wh_title_large_sell'), { { name = locale('wh_total'), value = money(total) } }, nil, WebhookConfig.LargeTradePing)
    end
    return result(true, locale(payOut == 'bloodmoney' and 'sv_sold_dirty' or 'sv_sold', qty, itemData.label, ('%.2f'):format(total)))
end)

---------------------------------------------
-- laundering: bloodmoney -> cash at an illegal trader, for a cut
---------------------------------------------
callback('grumpy-trader:server:launder', function(source, traderid, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return result(false) end
    local trader = type(traderid) == 'string' and Traders[traderid]
    amount = tonumber(amount)
    if not trader or not amount or amount ~= amount then
        Webhook.Suspicious(src, locale('wh_reason_malformed'), ('launder trader=%s amount=%s'):format(tostring(traderid), tostring(amount)))
        return result(false, locale('sv_invalid_trade'))
    end
    if not canLaunder(trader) then return result(false, locale('sv_no_laundering')) end
    if not isNearTrader(src, trader) then return result(false, locale('sv_too_far')) end
    if lawBlocked(Player, trader) then return result(false, locale('sv_law_blocked')) end
    if onCooldown(src) then return result(false, locale('sv_cooldown')) end

    amount = round2(amount)
    local L = Config.Laundering
    if amount < L.MinAmount or amount > 1000000 then return result(false, locale('sv_launder_min', ('%.2f'):format(L.MinAmount))) end
    if (Player.Functions.GetMoney('bloodmoney') or 0) < amount then return result(false, locale('sv_not_enough_dirty')) end

    if launderBusy[traderid] then return result(false, locale('sv_stock_changed')) end
    launderBusy[traderid] = true
    local ok, res = pcall(function()
        local cid = Player.PlayerData.citizenid
        local left = launderLeft(trader, cid)
        if amount > left then
            return result(false, left > 0 and locale('sv_launder_limit', ('%.2f'):format(left)) or locale('sv_launder_none_left'))
        end
        local cut = launderCut(src, trader)
        local clean = round2(amount * (1 - cut / 100))
        if clean < 0.01 then return result(false, locale('sv_invalid_trade')) end

        if not Player.Functions.RemoveMoney('bloodmoney', amount, Config.Reasons.launder) then
            return result(false, locale('sv_not_enough_dirty'))
        end
        if not Player.Functions.AddMoney('cash', clean, Config.Reasons.launder) then
            Player.Functions.AddMoney('bloodmoney', amount, 'grumpy-trader-refund')
            return result(false, locale('sv_invalid_trade'))
        end
        MySQL.query.await([[INSERT INTO grumpy_trader_laundering (traderid, citizenid, `day`, amount) VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)]], { traderid, cid, today(), amount })

        log('launder', src, locale('wh_title_launder'), {
            { name = locale('wh_trader'), value = traderLabel(traderid) },
            { name = locale('wh_dirty'), value = money(amount) },
            { name = locale('wh_clean'), value = money(clean) },
            { name = locale('wh_cut'), value = ('%.2f%%'):format(cut) },
        }, ('%s laundered %s into %s at %s (%.2f%% cut)'):format(GetPlayerName(src), money(amount), money(clean), traderid, cut))
        if WebhookConfig.LargeTradeAmount > 0 and amount >= WebhookConfig.LargeTradeAmount then
            Webhook.Send('launder', src, locale('wh_title_large_launder'), { { name = locale('wh_dirty'), value = money(amount) } }, nil, WebhookConfig.LargeTradePing)
        end
        return result(true, locale('sv_laundered', ('%.2f'):format(amount), ('%.2f'):format(clean)))
    end)
    launderBusy[traderid] = nil
    if not ok then
        print(('[%s] ^1launder failed: %s^7'):format(GetCurrentResourceName(), tostring(res)))
        return result(false, locale('sv_invalid_trade'))
    end
    return res
end)

---------------------------------------------
-- admin panel
---------------------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('sv_cmd_admin'), {}, false, function(source)
    TriggerClientEvent('grumpy-trader:client:openAdmin', source)
end, 'admin')

callback('grumpy-trader:server:admin:isAdmin', function(source)
    return isAdmin(source)
end)

callback('grumpy-trader:server:admin:traders', function(source)
    if not isAdmin(source) then return nil end
    local counts = {}
    for _, r in ipairs(MySQL.query.await('SELECT traderid, COUNT(*) AS c FROM grumpy_trader GROUP BY traderid') or {}) do
        counts[r.traderid] = r.c
    end
    local list = {}
    for _, t in pairs(Traders) do
        local copy = copyTable(t)
        copy.itemcount = counts[t.traderid] or 0
        list[#list + 1] = copy
    end
    table.sort(list, function(a, b) return a.tradername < b.tradername end)
    return list
end)

-- create (no traderid) or update (traderid) a trader
callback('grumpy-trader:server:admin:saveTrader', function(source, data)
    local src = source
    if not isAdmin(src) then adminDenied(src, 'saveTrader'); return result(false, locale('sv_no_permission')) end
    if type(data) ~= 'table' then return result(false, locale('sv_invalid_trade')) end

    local name = trim(data.tradername)
    if not name or #name < 2 or #name > 50 then return result(false, locale('sv_invalid_name')) end

    local model = trim(data.npcmodel)
    model = (model and model ~= '') and model:lower() or Config.DefaultModel
    if #model > 60 or model:find('[^%w_]') then return result(false, locale('sv_invalid_model')) end

    local kind = type(data.kind) == 'string' and Config.Kinds[data.kind] and data.kind or nil
    if not kind then return result(false, locale('sv_invalid_kind')) end

    local L = Config.Laundering
    local launder = kind == 'illegal' and data.launder == true
    local cut = nil
    if launder and data.launderCut ~= nil and data.launderCut ~= '' then
        cut = tonumber(data.launderCut)
        if not cut or cut ~= cut or cut < L.MinCut or cut > L.MaxCut then
            return result(false, locale('sv_invalid_cut', L.MinCut, L.MaxCut))
        end
        cut = round2(cut)
    end

    if data.traderid ~= nil and type(data.traderid) ~= 'string' then return result(false, locale('sv_invalid_trade')) end
    local existing = data.traderid and Traders[data.traderid]
    if data.traderid and not existing then return result(false, locale('sv_not_found')) end

    local trader = existing and copyTable(existing) or { traderid = makeTraderId(name) }
    trader.tradername = name
    trader.npcmodel = model
    trader.showblip = data.showblip and true or false
    trader.kind = kind
    trader.launder = launder
    trader.launder_cut = cut

    -- position from the admin's rsg-gizmo placement (new trader, or "Move trader" ticked), checked here
    if not existing or data.move then
        local p = type(data.pos) == 'table' and data.pos or {}
        local x, y, z, w = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.w)
        local function finite(n) return n ~= nil and n == n and n ~= math.huge and n ~= -math.huge end
        if not (finite(x) and finite(y) and finite(z) and finite(w))
            or not exports['rsg-gizmo']:IsPlacementValid(src, vector3(x, y, z), Config.PlaceDistance) then
            return result(false, locale('sv_invalid_position'))
        end
        trader.x, trader.y, trader.z, trader.heading = x, y, z, w % 360.0
    end

    MySQL.query.await([[
        INSERT INTO grumpy_trader_npcs (traderid, tradername, npcmodel, x, y, z, heading, showblip, kind, launder, launder_cut)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE tradername = VALUES(tradername), npcmodel = VALUES(npcmodel), x = VALUES(x), y = VALUES(y),
        z = VALUES(z), heading = VALUES(heading), showblip = VALUES(showblip), kind = VALUES(kind), launder = VALUES(launder),
        launder_cut = VALUES(launder_cut)
    ]], { trader.traderid, trader.tradername, trader.npcmodel, trader.x, trader.y, trader.z, trader.heading,
          trader.showblip and 1 or 0, trader.kind, trader.launder and 1 or 0, trader.launder_cut })

    Traders[trader.traderid] = trader
    syncTraders()
    log(existing and 'trader_updated' or 'trader_created', src, locale(existing and 'wh_title_trader_updated' or 'wh_title_trader_created'), {
        { name = locale('wh_trader'), value = traderLabel(trader.traderid) },
        { name = locale('wh_model'), value = trader.npcmodel },
        { name = locale('wh_blip'), value = locale(trader.showblip and 'wh_yes' or 'wh_no') },
        { name = locale('wh_launder'), value = trader.launder and ('%s%%'):format(trader.launder_cut or L.DefaultCut) or locale('wh_no') },
        { name = locale('wh_position'), value = ('%.2f, %.2f, %.2f (h %.1f)'):format(trader.x, trader.y, trader.z, trader.heading), inline = false },
        existing and existing.tradername ~= name and { name = locale('wh_renamed_from'), value = existing.tradername } or nil,
    }, ('%s %s trader %s'):format(GetPlayerName(src), existing and 'updated' or 'created', trader.traderid))
    return result(true, locale(existing and 'sv_trader_updated' or 'sv_trader_added', name))
end)

callback('grumpy-trader:server:admin:deleteTrader', function(source, traderid, removeItems)
    local src = source
    if not isAdmin(src) then adminDenied(src, 'deleteTrader'); return result(false, locale('sv_no_permission')) end
    local trader = type(traderid) == 'string' and Traders[traderid]
    if not trader then return result(false, locale('sv_not_found')) end
    removeItems = removeItems == true

    MySQL.query.await('DELETE FROM grumpy_trader_npcs WHERE traderid = ?', { traderid })
    MySQL.query.await('DELETE FROM grumpy_trader_laundering WHERE traderid = ?', { traderid })
    if removeItems then
        MySQL.query.await('DELETE FROM grumpy_trader WHERE traderid = ?', { traderid })
    end
    Traders[traderid] = nil
    syncTraders()
    log('trader_deleted', src, locale('wh_title_trader_deleted'), {
        { name = locale('wh_trader'), value = ('%s (`%s`)'):format(trader.tradername, traderid) },
        { name = locale('wh_items_deleted'), value = locale(removeItems and 'wh_yes' or 'wh_no') },
    }, ('%s removed trader %s'):format(GetPlayerName(src), traderid))
    return result(true, locale('sv_trader_removed', trader.tradername))
end)

callback('grumpy-trader:server:admin:items', function(source, traderid)
    if not isAdmin(source) or not Traders[traderid] then return nil end
    return MySQL.query.await('SELECT item, stock, lowstock, highstock, baseprice, mode FROM grumpy_trader WHERE traderid = ? ORDER BY item', { traderid }) or {}
end)

-- add or update an item on a trader
callback('grumpy-trader:server:admin:saveItem', function(source, data)
    local src = source
    if not isAdmin(src) then adminDenied(src, 'saveItem'); return result(false, locale('sv_no_permission')) end
    if type(data) ~= 'table' then return result(false, locale('sv_invalid_trade')) end
    if type(data.traderid) ~= 'string' or not Traders[data.traderid] then return result(false, locale('sv_not_found')) end

    local item = trim(data.item)
    item = item and item:lower()
    if not item or not RSGCore.Shared.Items[item] then return result(false, locale('sv_item_missing')) end

    local stock     = toInt(data.stock, 0, 1000000)
    local lowstock  = toInt(data.lowstock, 0, 1000000)
    local highstock = toInt(data.highstock, 1, 1000000)
    local baseprice = tonumber(data.baseprice)
    local mode      = type(data.mode) == 'string' and Config.ItemModes[data.mode] and data.mode or nil
    if not stock or not lowstock or not highstock or not baseprice or baseprice ~= baseprice or highstock <= lowstock
        or baseprice <= 0 or baseprice > 1000000 or not mode then
        return result(false, locale('sv_invalid_input'))
    end
    baseprice = round2(baseprice)

    if data.isNew then
        local exists = MySQL.scalar.await('SELECT COUNT(*) FROM grumpy_trader WHERE traderid = ? AND item = ?', { data.traderid, item })
        if exists and exists > 0 then return result(false, locale('sv_already_exists')) end
        MySQL.insert.await('INSERT INTO grumpy_trader (traderid, item, stock, lowstock, highstock, baseprice, mode) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { data.traderid, item, stock, lowstock, highstock, baseprice, mode })
    else
        local affected = MySQL.update.await('UPDATE grumpy_trader SET stock = ?, lowstock = ?, highstock = ?, baseprice = ?, mode = ? WHERE traderid = ? AND item = ?',
            { stock, lowstock, highstock, baseprice, mode, data.traderid, item })
        if not affected or affected < 1 then return result(false, locale('sv_invalid_trade')) end
    end
    log(data.isNew and 'item_added' or 'item_updated', src, locale(data.isNew and 'wh_title_item_added' or 'wh_title_item_updated'), {
        { name = locale('wh_trader'), value = traderLabel(data.traderid) },
        { name = locale('wh_item'), value = ('%s (`%s`)'):format(RSGCore.Shared.Items[item].label, item) },
        { name = locale('wh_stock'), value = tostring(stock) },
        { name = locale('wh_low_high'), value = ('%d / %d'):format(lowstock, highstock) },
        { name = locale('wh_baseprice'), value = money(baseprice) },
        { name = locale('wh_mode'), value = mode },
    }, ('%s %s item %s on %s'):format(GetPlayerName(src), data.isNew and 'added' or 'updated', item, data.traderid))
    return result(true, locale(data.isNew and 'sv_added' or 'sv_item_updated'))
end)

callback('grumpy-trader:server:admin:deleteItem', function(source, traderid, item)
    local src = source
    if not isAdmin(src) then adminDenied(src, 'deleteItem'); return result(false, locale('sv_no_permission')) end
    if type(traderid) ~= 'string' or not Traders[traderid] or type(item) ~= 'string' then return result(false, locale('sv_invalid_trade')) end
    local affected = MySQL.update.await('DELETE FROM grumpy_trader WHERE traderid = ? AND item = ?', { traderid, item })
    if not affected or affected < 1 then return result(false, locale('sv_not_found')) end
    log('item_removed', src, locale('wh_title_item_removed'), {
        { name = locale('wh_trader'), value = traderLabel(traderid) },
        { name = locale('wh_item'), value = ('`%s`'):format(item) },
    }, ('%s removed item %s from %s'):format(GetPlayerName(src), item, traderid))
    return result(true, locale('sv_item_removed'))
end)

---------------------------------------------
-- rumors (grumpy-rumors): legal traders share legal tips, fences sell illegal ones for a bribe.
-- This side checks the trader, the distance and the law; grumpy-rumors picks the rumor by standing,
-- charges only when a note is handed over, and keeps the per-trader cooldown.
---------------------------------------------
RegisterNetEvent('grumpy-trader:server:askRumor', function(traderid)
    local src = source
    local cfg = Config.Rumors
    local Player = RSGCore.Functions.GetPlayer(src)
    local trader = type(traderid) == 'string' and Traders[traderid]
    if not cfg.Enabled or not Player or not trader then return end
    if GetResourceState('grumpy-rumors') ~= 'started' then return end
    local kc = cfg.Kinds[trader.kind]
    if not kc then return end
    if not isNearTrader(src, trader) then return end
    if lawBlocked(Player, trader) then
        return TriggerClientEvent('RSGCore:Client:Notify', src, { title = trader.tradername, description = locale('sv_law_blocked'), type = 'error', duration = 5000 })
    end

    local price = tonumber(kc.price) or 0
    if price > 0 and kc.standingScales then price = price * standingMult(src, trader, 'buy') end
    exports['grumpy-rumors']:Ask(src, {
        key = 'trader:' .. traderid,
        categories = kc.categories,
        price = round2(price),
        payWith = kc.payWith or { 'cash' },
        cooldown = kc.cooldown,
        reason = cfg.Reason,
        noMoney = trader.kind == 'illegal' and 'no_bribe' or nil,
    })
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
