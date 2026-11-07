-- grumpy-livery: horse theft reports (DESIGN.md §13). When the player mounts a horse that is neither wild nor a
-- livery horse, the server is told; it decides whether that's a theft and opens a grumpy-law incident.
-- _GET_ANIMAL_IS_WILD = 0x3B005FF0538ED2A9 (natives/db/FLOCK.md): wild horses buck and flee; ambient owned horses don't.
if not (Config.Theft and Config.Theft.enabled) then return end

local lastMount = 0

CreateThread(function()
    while true do
        local mount = GetMount(PlayerPedId())
        if mount ~= 0 and mount ~= lastMount then
            lastMount = mount
            local owned = Entity(mount).state.rsgStablesOwned
            local wild = Citizen.InvokeNative(0x3B005FF0538ED2A9, mount, Citizen.ResultAsInteger()) == 1 -- _GET_ANIMAL_IS_WILD
            if not owned and not wild and NetworkGetEntityIsNetworked(mount) then
                TriggerServerEvent('grumpy-livery:server:horseTaken', NetworkGetNetworkIdFromEntity(mount))
            end
        elseif mount == 0 then
            lastMount = 0
        end
        Wait(500)
    end
end)
