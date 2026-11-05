-- Shoplifting: a target zone on each admin-set shelf point.

local SL = Config.Shoplift
local zones = {}
local lifting = false

local function clerkCanSee(store)
    local clerk = GRC.FindClerk(store)
    if not clerk then return false end
    local me = PlayerPedId()
    if #(GetEntityCoords(clerk) - GetEntityCoords(me)) > 15.0 then return false end
    return HasEntityClearLosToEntityInFront(clerk, me) -- HAS_ENTITY_CLEAR_LOS_TO_ENTITY_IN_FRONT
end

local function lift(store, index)
    if lifting then return end
    lifting = true
    local ok, msg = RSGCore.Functions.AwaitCallback('grumpy-robbery:server:shopliftStart', 5000, store.id, index)
    if not ok then
        lifting = false
        if msg then GRC.Notify(msg, 'error') end
        return
    end

    local done = RSGCore.Functions.ProgressBar({
        duration = SL.Time, label = locale('lift_progress'), useWhileDead = false, canCancel = true,
        disable = { move = true, sprint = true, mount = true, combat = true },
        anim = { dict = SL.Anim.dict, clip = SL.Anim.clip }, -- rsg-core default flag 49 (upper body loop)
    })
    if done then
        TriggerServerEvent('grumpy-robbery:server:shopliftFinish', clerkCanSee(store))
    else
        TriggerServerEvent('grumpy-robbery:server:shopliftCancel')
    end
    lifting = false
end

local function clear()
    for _, id in ipairs(zones) do exports['rsg-target']:removeZone(id) end
    zones = {}
end

local function build()
    clear()
    if not SL.Enabled then return end
    for _, s in ipairs(GRC.Stores) do
        for i, p in ipairs(s.shelves or {}) do
            local store, index = s, i
            zones[#zones + 1] = exports['rsg-target']:addSphereZone({
                coords = vector3(p.x, p.y, p.z), radius = 0.8, debug = Config.Debug,
                options = {{
                    name = ('grumpy-robbery:shelf:%s:%s'):format(s.id, i), icon = 'fa-solid fa-hand-sparkles',
                    label = locale('target_shelf'), distance = SL.Distance,
                    canInteract = function() return not lifting end,
                    onSelect = function() CreateThread(function() lift(store, index) end) end,
                }},
            })
        end
    end
end
GRC.OnStores(build)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() end
end)
