-- MLO / custom door hashes that are not in shared/doorhashes.lua
-- Paste entries in the usual door-hash format:
--   [doorHash] = { doorHash, modelHash, "modelName", x, y, z },
-- They are added to the /doorlock editor and locked with the game's door system.
CustomDoorHashes = {
    [1651863461] = { 1651863461, -667091646, "p_door58x", -5528.4658203125, -2953.718994140625, -1.69699990749359 },
    [-867318905] = { -867318905, -1858047034, "p_door54x", 2967.8603515625, 1351.454833984375, 43.91580200195312 }, 
    -- Thieves Landing (sdl_tlanding MLO)
    -- Saloon
    [3563307682] = {3563307682,-542955242,"p_door04x",-1401.037231,-2317.940674,42.627178},
    [2176982368] = {2176982368,-542955242,"p_door04x",-1389.928101,-2312.560791,42.617443},
    [2415507919] = {2415507919,-542955242,"p_door04x",-1389.737183,-2314.751221,42.617443},

    -- Hostel
    [4220931597] = {4220931597,-542955242,"p_door04x",-1429.255981,-2270.907471,42.475727},
    [3924535992] = {3924535992,-542955242,"p_door04x",-1439.367065,-2265.308594,42.452740},
    [2610073095] = {2610073095,-542955242,"p_door04x",-1439.952026,-2275.848877,42.476887},
    [164686466] = {164686466,-542955242,"p_door04x",-1429.688721,-2273.369141,42.476727},
    [3489822438] = {3489822438,-542955242,"p_door04x",-1431.045044,-2273.137695,42.474728},
    [3182744139] = {3182744139,-542955242,"p_door04x",-1430.617676,-2270.696777,42.475727},

    -- Workshed
    [2510878516] = {2510878516,-542955242,"p_door04x",-1446.898071,-2308.284912,43.500137},
    [2184400969] = {2184400969,-542955242,"p_door04x",-1451.774658,-2311.631348,43.519127},
}

-- merge into the editor list (format: { doorHash, modelName, x, y, z })
local known = {}
for _, d in ipairs(DoorHashes) do known[d[1]] = true end
for hash, d in pairs(CustomDoorHashes) do
    if not known[hash] then
        DoorHashes[#DoorHashes + 1] = { hash, d[3], d[4], d[5], d[6] }
        known[hash] = true
    end
end
