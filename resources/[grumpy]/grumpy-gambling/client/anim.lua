-- Seated animations (Config.Anim): a looping upper-body poker idle over the chair scenario, swapped now and then, and
-- one-off clips for moves, wins and NPC tells. Runs for the local player's own ped (other clients see it through the
-- network) and for the local NPC peds this client spawned.
local A = Config.Anim
local peds = {}   -- [ped] = { female, busyUntil, nextIdleAt }
GGC.Anim = {}

local function now() return GetGameTimer() end

local function playIdle(ped, st)
    if not GGC.LoadDict(A.Dict) or not DoesEntityExist(ped) then return end
    local clip = A.Idles[math.random(#A.Idles)]
    TaskPlayAnim(ped, A.Dict, clip, 1.0, 1.0, -1, A.IdleFlag, 0.0, false, 0, false, 0, false)
    st.nextIdleAt = now() + math.random(A.IdleSwapMs[1], A.IdleSwapMs[2])
end

-- Start animating a seated ped (after the chair scenario has settled)
function GGC.Anim.Start(ped)
    if not A.Enabled or not ped or ped == 0 then return end
    local st = { female = not IsPedMale(ped), busyUntil = 0, nextIdleAt = now() + (A.StartDelayMs or 600) }
    peds[ped] = st
end

function GGC.Anim.Stop(ped)
    if not ped or not peds[ped] then return end
    peds[ped] = nil
    if DoesEntityExist(ped) then ClearPedSecondaryTask(ped) end
end

-- A one-off clip (a move, a win, a tell); the idle comes back when it ends
function GGC.Anim.Play(ped, cue)
    local st = ped and peds[ped]
    local def = A.Cues[cue]
    if not st or not def then return end
    local dict, clips = def.dict or A.Dict, def.clips
    if st.female and A.Female and A.Female.Cues[cue] then dict, clips = A.Female.dict, A.Female.Cues[cue] end
    st.busyUntil = now() + def.ms
    st.nextIdleAt = st.busyUntil
    CreateThread(function()
        if not GGC.LoadDict(dict) or not DoesEntityExist(ped) or peds[ped] ~= st then return end
        TaskPlayAnim(ped, dict, clips[math.random(#clips)], 4.0, -2.0, def.ms, A.Flag, 0.0, false, 0, false, 0, false)
        if Config.Debug then print('[grumpy-gambling] cue', cue, ped) end
    end)
end

-- One light loop for every animated ped: idles start, swap, and come back after a clip
CreateThread(function()
    while true do
        local sleep = 1000
        local t = now()
        for ped, st in pairs(peds) do
            if not DoesEntityExist(ped) then
                peds[ped] = nil
            else
                sleep = 250
                if t >= st.busyUntil and t >= st.nextIdleAt then
                    st.nextIdleAt = t + 60000 -- claimed; playIdle sets the real time
                    CreateThread(function() playIdle(ped, st) end)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for ped in pairs(peds) do if DoesEntityExist(ped) then ClearPedSecondaryTask(ped) end end
end)
