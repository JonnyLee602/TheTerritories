RSGCore = exports['rsg-core']:GetCoreObject()

-- shared server helpers for gangs.lua, posse.lua and api.lua
Groups = {}

function Groups.Notify(src, description, nType, title)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title or locale('title_groups'), description = description, type = nType or 'inform', duration = 5000,
    })
end

function Groups.FullName(charinfo)
    charinfo = charinfo or {}
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

function Groups.Log(title, colour, message)
    TriggerEvent('rsg-log:server:CreateLog', 'grumpygroups', title, colour, message, false)
end

function Groups.Dist(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b)))
end

-- per-player, per-action rate limit (seconds may be fractional)
local cooldowns = {}
function Groups.OnCooldown(src, key, seconds)
    local now = GetGameTimer()
    cooldowns[src] = cooldowns[src] or {}
    local last = cooldowns[src][key]
    if last and now - last < (seconds * 1000) then return true end
    cooldowns[src][key] = now
    return false
end

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
    Groups.Asking[source] = nil
end)

-- players currently answering an invite (gang or posse). rsg-core keys client callbacks by player + name,
-- so only one invite per player may be open at a time.
Groups.Asking = {}

-- ask a player yes/no through the NUI invite card. Returns true only on an explicit accept.
function Groups.AskPlayer(target, kind, label, fromName, timeout)
    if Groups.Asking[target] then return false end
    Groups.Asking[target] = true
    local answer = RSGCore.Functions.AwaitClientCallback('grumpy-groups:client:confirmInvite', target, (timeout + 2) * 1000, {
        kind = kind, label = label, from = fromName, timeout = timeout,
    })
    Groups.Asking[target] = nil
    TriggerClientEvent('grumpy-groups:client:closeInvite', target)
    return answer == true
end

if Config.AutoDatabase then
    MySQL.ready(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `management_funds` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `job_name` VARCHAR(50) NOT NULL,
                `amount` INT NOT NULL DEFAULT 0,
                `type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
                PRIMARY KEY (`id`),
                UNIQUE KEY `job_name` (`job_name`),
                KEY `type` (`type`)
            )
        ]])
    end)
end
