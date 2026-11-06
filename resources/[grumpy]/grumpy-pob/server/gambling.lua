-- "Gambling" manager tab (owner only, needs grumpy-gambling 0.6.0+): buy the table items grumpy-gambling places in a
-- business. Paid from the business account to the government ("Furnishings" in the ledger), like the back room.
-- grumpy-gambling owns the rules (items, per-business limits); this file only sells the items.
local RSGCore = POB.Core()
local Acc = POB.Acc
local G = Config.Gambling

local Gambling = {}
POB.Gambling = Gambling

local function gamblingUp() return G and G.Enabled and GetResourceState(G.Resource) == 'started' end

local function limits(biz)
    if not gamblingUp() then return nil end
    local ok, res = pcall(function() return exports[G.Resource]:GetTableLimits(biz.id) end)
    return ok and res or nil
end

-- The real owner standing at the desk
local function ownerAt(src, biz)
    local Player, grade = POB.Employment(src, biz)
    if not Player or not biz.owner or grade ~= Config.OwnerGrade then return nil end
    if Player.PlayerData.citizenid ~= biz.owner.cid then return nil end
    if not POB.Near(src, biz.points.manager) then POB.Notify(src, locale('too_far'), 'error') return nil end
    return Player
end

local function carried(src, item)
    local ok, n = pcall(function() return exports['rsg-inventory']:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

-- Manager screen data for the owner (nil for everyone else, or when grumpy-gambling isn't running)
function Gambling.ManagerData(src, biz, Player)
    if not biz.owner or Player.PlayerData.citizenid ~= biz.owner.cid then return nil end
    local lim = limits(biz)
    if not lim then return nil end
    local list = {}
    for _, kind in ipairs({ 'pvp', 'pvd' }) do
        local l, price = lim[kind], G.Prices[kind]
        if l and price then
            local have = carried(src, l.item)
            list[#list + 1] = { kind = kind, label = POB.ItemLabel(l.item), price = price, placed = l.placed, carried = have,
                max = l.max, canBuy = l.placed + have < l.max }
        end
    end
    return { tables = list, balance = Acc.Balance(POB.AccountId(biz)),
        backroom = POB.Launder ~= nil and POB.Launder.HasBackroom(biz) or false }
end

RegisterNetEvent('grumpy-pob:server:buyGamblingTable', function(id, kind)
    local src = source
    local biz = POB.Biz(id)
    if not biz or (kind ~= 'pvp' and kind ~= 'pvd') or POB.Cooldown(src, 'gamblingTable', 3000) then return end
    POB.Lock('money:' .. biz.id, function()
        local Player = ownerAt(src, biz)
        if not Player then return POB.Notify(src, locale('no_permission'), 'error') end
        local lim = limits(biz)
        local l, price = lim and lim[kind], G.Prices[kind]
        if not l or not price then return POB.Notify(src, locale('gt_not_available'), 'error') end
        if l.placed + carried(src, l.item) >= l.max then return POB.Notify(src, locale('gt_limit', l.max), 'error') end
        -- CanAddItem says why: the item isn't set up yet, it's too heavy to carry, or there's no free slot
        local canAdd, why = exports['rsg-inventory']:CanAddItem(src, l.item, 1)
        if not canAdd then
            local key = why == 'invalid_item' and 'gt_item_missing' or why == 'too_heavy' and 'gt_too_heavy' or 'inventory_full'
            if why == 'invalid_item' then print(('^3[grumpy-pob] item %s is not in rsg-core/shared/items.lua (or the server was not restarted)^7'):format(l.item)) end
            return POB.Notify(src, locale(key), 'error')
        end
        local who = Acc.Who(Player)
        if not Acc.Transfer(POB.AccountId(biz), Acc.GOV, price, 'furnishing', who, locale('ledger_furnishing', POB.ItemLabel(l.item))) then
            return POB.Notify(src, locale('not_enough_funds'), 'error')
        end
        if not exports['rsg-inventory']:AddItem(src, l.item, 1, nil, nil, 'grumpy-pob:gambling-table') then
            Acc.Transfer(Acc.GOV, POB.AccountId(biz), price, 'furnishing', who, locale('ledger_furnishing_refund'))
            return POB.Notify(src, locale('inventory_full'), 'error')
        end
        POB.Notify(src, locale('gt_bought', POB.ItemLabel(l.item), price), 'success')
        print(('[grumpy-pob] %s bought a %s table for business %d "%s" ($%s)'):format(who.name, kind, biz.id, biz.label, price))
    end)
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager')
end)
