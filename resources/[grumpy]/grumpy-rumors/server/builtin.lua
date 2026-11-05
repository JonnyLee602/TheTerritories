-- Built-in job types. They only hand off; the real work belongs to other resources.
--   'item' : turns the note into an item another resource uses (treasure_map -> rsg-treasure dig site)
--   'mark' : puts a timed search-area blip on the map for everyone included

-----------------------------------------------------------------------
-- 'item': args = { item = 'treasure_map', amount = 1, info = { ... } }. Goes to the reader only.
-----------------------------------------------------------------------
if Config.BuiltinItem.enabled then
    local function validItem(args)
        local name = type(args.item) == 'string' and args.item
        return name and Config.BuiltinItem.allowed[name] and RSGCore.Shared.Items[name] and name or nil
    end

    Rumors.RegisterJobType('item', {
        available = function(args)
            local name = validItem(args)
            local needs = name and Config.BuiltinItem.needsResource[name]
            return name ~= nil and (not needs or GetResourceState(needs) == 'started')
        end,
        canStart = function(src, args)
            local name = validItem(args)
            if not name then return false, locale('job_unavailable') end
            if not exports['rsg-inventory']:CanAddItem(src, name, math.max(1, tonumber(args.amount) or 1)) then
                return false, locale('inventory_full')
            end
            return true
        end,
        start = function(src, args)
            local name = validItem(args)
            if not name then return false end
            local info = type(args.info) == 'table' and args.info or nil
            local ok = exports['rsg-inventory']:AddItem(src, name, math.max(1, tonumber(args.amount) or 1), info, nil, 'grumpy-rumors-item')
            if not ok then return false end
            TriggerClientEvent('RSGCore:Client:Notify', src, {
                title = locale('title'), description = locale(args.message or 'item_received', RSGCore.Shared.Items[name].label),
                type = 'success', duration = 6000,
            })
            return true
        end,
    })
end

-----------------------------------------------------------------------
-- 'mark'
-----------------------------------------------------------------------
if not Config.BuiltinMark.enabled then return end

Rumors.RegisterJobType('mark', {
    canStart = function(_, args)
        if not args.coords or (args.coords.x == 0.0 and args.coords.y == 0.0) then
            return false, locale('job_unavailable')
        end
        return true
    end,
    start = function(_, args, members)
        local data = {
            coords = args.coords, radius = tonumber(args.radius) or 100.0,
            duration = tonumber(args.duration) or 1800,
            label = args.label and locale(args.label) or locale('title'),
        }
        for _, id in ipairs(members) do TriggerClientEvent('grumpy-rumors:client:mark', id, data) end
        return true
    end,
})
