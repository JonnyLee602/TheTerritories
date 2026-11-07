-- [grumpy-maphide patch] Hides map/MLO props listed in grumpy_hide_config.lua.
-- Client only. Uses the game's model-hide natives (natives/db/ENTITY.md):
--   CREATE_MODEL_HIDE 0x069848B3FB3C4426 (x, y, z, radius, model, p5)
--   REMOVE_MODEL_HIDE 0x3F38A98576F6213A (same arguments)

local CREATE_MODEL_HIDE = 0x069848B3FB3C4426
local REMOVE_MODEL_HIDE = 0x3F38A98576F6213A

local entries = {}

for i, p in ipairs(GrumpyHide.Props) do
    entries[i] = {
        hash   = GetHashKey(p.model),
        model  = p.model,
        coords = p.coords,
        radius = p.radius or GrumpyHide.Radius,
    }
end

local function applyHide(e)
    local c = e.coords
    Citizen.InvokeNative(CREATE_MODEL_HIDE, c.x, c.y, c.z, e.radius, e.hash, true)
    if GrumpyHide.Debug then
        print(('[grumpy-maphide] hide %s at %.2f %.2f %.2f'):format(e.model, c.x, c.y, c.z))
    end
end

local function removeHide(e)
    local c = e.coords
    Citizen.InvokeNative(REMOVE_MODEL_HIDE, c.x, c.y, c.z, e.radius, e.hash, false)
end

-- Hide once on start, then re-apply while the player is nearby:
-- interior props stream in and out, so a hide set far away may not stick.
CreateThread(function()
    for _, e in ipairs(entries) do applyHide(e) end

    local inRange = {}
    while true do
        Wait(GrumpyHide.CheckEvery)
        local pos = GetEntityCoords(PlayerPedId())
        for i, e in ipairs(entries) do
            local near = #(pos - e.coords) < GrumpyHide.CheckRange
            if near and not inRange[i] then
                applyHide(e)
            end
            inRange[i] = near
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in ipairs(entries) do removeHide(e) end
end)
