-- Posses: temporary player-made groups with a hard lifetime cap.
-- Kept in server memory (a restart ends every posse). Members are keyed by citizenid so a relog keeps your place.

local Posses = {}        -- [id] = posse
local ByCid = {}         -- [citizenid] = posse id
local SrcToCid = {}      -- [source] = citizenid (still known inside playerDropped)
local nextId = 0

local P = Config.Posse

local function onlineSrc(cid)
    local Player = RSGCore.Functions.GetPlayerByCitizenId(cid)
    return Player and Player.PlayerData.source or nil
end

local function setState(src, id)
    if src then Player(src).state:set('posse', id, true) end
end

local function snapshot(posse, forCid)
    local now = os.time()
    local list = {}
    for _, cid in ipairs(posse.members) do
        list[#list + 1] = {
            citizenid = cid,
            name = posse.names[cid],
            online = onlineSrc(cid) ~= nil,
            isLeader = cid == posse.leader,
            isSelf = cid == forCid,
        }
    end
    return {
        id = posse.id,
        isLeader = forCid == posse.leader,
        canInvite = forCid == posse.leader or P.MembersCanInvite,
        remaining = math.max(0, posse.expiresAt - now),
        max = P.MaxMembers,
        members = list,
    }
end

local function eachOnline(posse, fn)
    for _, cid in ipairs(posse.members) do
        local src = onlineSrc(cid)
        if src then fn(src, cid) end
    end
end

local function sync(posse)
    eachOnline(posse, function(src, cid)
        SrcToCid[src] = cid
        setState(src, posse.id)
        TriggerClientEvent('grumpy-groups:client:posseUpdate', src, snapshot(posse, cid))
    end)
    TriggerEvent('grumpy-groups:server:posseChanged', posse.id)
end

local function notifyAll(posse, msg, nType, exceptCid)
    eachOnline(posse, function(src, cid)
        if cid ~= exceptCid then Groups.Notify(src, msg, nType, locale('title_posse')) end
    end)
end

local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
end

local function firstOnlineOther(posse, notCid)
    for _, cid in ipairs(posse.members) do
        if cid ~= notCid and onlineSrc(cid) then return cid end
    end
end

-----------------------------------------------------------------------
-- core operations
-----------------------------------------------------------------------
local function disband(posse, reasonKey)
    if not Posses[posse.id] then return end
    Posses[posse.id] = nil
    local cids = {}
    for _, cid in ipairs(posse.members) do
        ByCid[cid] = nil
        cids[#cids + 1] = cid
        local src = onlineSrc(cid)
        if src then
            setState(src, nil)
            TriggerClientEvent('grumpy-groups:client:posseUpdate', src, nil)
            Groups.Notify(src, locale(reasonKey), 'inform', locale('title_posse'))
        end
    end
    TriggerEvent('grumpy-groups:server:posseDisbanded', posse.id, cids, reasonKey)
end

local function create(leaderCid, leaderName)
    nextId = nextId + 1
    local now = os.time()
    local posse = {
        id = nextId,
        leader = leaderCid,
        members = { leaderCid },
        names = { [leaderCid] = leaderName },
        createdAt = now,
        expiresAt = now + P.MaxLifetime, -- fixed for life: nothing below ever changes it
        warned = false,
        leaderOfflineSince = nil,
    }
    Posses[posse.id] = posse
    ByCid[leaderCid] = posse.id
    return posse
end

local function setLeader(posse, cid)
    posse.leader = cid
    posse.leaderOfflineSince = onlineSrc(cid) and nil or os.time()
    notifyAll(posse, locale('posse_new_leader', posse.names[cid]), 'inform')
end

local function removeMember(posse, cid, reasonKey)
    local i = indexOf(posse.members, cid)
    if not i then return end
    table.remove(posse.members, i)
    ByCid[cid] = nil
    local name = posse.names[cid]
    posse.names[cid] = nil

    local src = onlineSrc(cid)
    if src then
        setState(src, nil)
        TriggerClientEvent('grumpy-groups:client:posseUpdate', src, nil)
        Groups.Notify(src, locale(reasonKey), 'inform', locale('title_posse'))
    end

    if #posse.members < 2 then return disband(posse, 'posse_disbanded_small') end
    notifyAll(posse, locale('posse_member_left', name), 'inform')
    if posse.leader == cid then setLeader(posse, firstOnlineOther(posse, cid) or posse.members[1]) end
    sync(posse)
end

-----------------------------------------------------------------------
-- invite
-----------------------------------------------------------------------
local function canInviteFrom(cid)
    local id = ByCid[cid]
    if not id then return true end -- no posse yet: accepting creates one with the inviter as leader
    local posse = Posses[id]
    if posse.leader ~= cid and not P.MembersCanInvite then return false, 'posse_only_leader' end
    if #posse.members >= P.MaxMembers then return false, 'posse_full' end
    return true
end

RegisterNetEvent('grumpy-groups:server:posseInvite', function(target)
    local src = source
    target = tonumber(target)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not target or target == src then return end
    if Groups.OnCooldown(src, 'posseInvite', P.InviteCooldown) then return Groups.Notify(src, locale('slow_down'), 'error') end

    local Target = RSGCore.Functions.GetPlayer(target)
    if not Target then return Groups.Notify(src, locale('player_not_found'), 'error') end
    if Groups.Dist(src, target) > P.InviteDistance then return Groups.Notify(src, locale('too_far'), 'error') end

    local cid, targetCid = Player.PlayerData.citizenid, Target.PlayerData.citizenid
    local ok, why = canInviteFrom(cid)
    if not ok then return Groups.Notify(src, locale(why), 'error') end
    if ByCid[targetCid] then return Groups.Notify(src, locale('posse_target_in_posse'), 'error') end
    if Groups.Asking[target] then return Groups.Notify(src, locale('invite_pending'), 'error') end

    Groups.Notify(src, locale('invite_sent'), 'inform')
    local accepted = Groups.AskPlayer(target, 'posse', locale('posse_label'), Groups.FullName(Player.PlayerData.charinfo), P.InviteTimeout)

    -- re-validate everything after the async prompt
    Player, Target = RSGCore.Functions.GetPlayer(src), RSGCore.Functions.GetPlayer(target)
    if not Player or not Target then return end
    if Player.PlayerData.citizenid ~= cid or Target.PlayerData.citizenid ~= targetCid then return end -- someone switched character
    if not accepted then return Groups.Notify(src, locale('invite_declined'), 'error') end
    ok, why = canInviteFrom(cid)
    if not ok then return Groups.Notify(src, locale(why), 'error') end
    if ByCid[targetCid] then return Groups.Notify(src, locale('posse_target_in_posse'), 'error') end

    local posse = ByCid[cid] and Posses[ByCid[cid]]
    if not posse then
        posse = create(cid, Groups.FullName(Player.PlayerData.charinfo))
        Groups.Notify(src, locale('posse_formed', math.floor(P.MaxLifetime / 60)), 'success', locale('title_posse'))
    end
    posse.members[#posse.members + 1] = targetCid
    posse.names[targetCid] = Groups.FullName(Target.PlayerData.charinfo)
    ByCid[targetCid] = posse.id

    notifyAll(posse, locale('posse_member_joined', posse.names[targetCid]), 'success', targetCid)
    Groups.Notify(target, locale('posse_you_joined'), 'success', locale('title_posse'))
    sync(posse)
end)

-----------------------------------------------------------------------
-- member actions
-----------------------------------------------------------------------
local function myPosse(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local id = ByCid[cid]
    return id and Posses[id], cid
end

RegisterNetEvent('grumpy-groups:server:posseLeave', function()
    local src = source
    if Groups.OnCooldown(src, 'posseAction', 1) then return end
    local posse, cid = myPosse(src)
    if posse then removeMember(posse, cid, 'posse_you_left') end
end)

RegisterNetEvent('grumpy-groups:server:posseKick', function(targetCid)
    local src = source
    if Groups.OnCooldown(src, 'posseAction', 1) or type(targetCid) ~= 'string' then return end
    local posse, cid = myPosse(src)
    if not posse or posse.leader ~= cid then return Groups.Notify(src, locale('posse_only_leader'), 'error') end
    if targetCid == cid or not indexOf(posse.members, targetCid) then return end
    removeMember(posse, targetCid, 'posse_you_were_kicked')
end)

RegisterNetEvent('grumpy-groups:server:posseSetLeader', function(targetCid)
    local src = source
    if Groups.OnCooldown(src, 'posseAction', 1) or type(targetCid) ~= 'string' then return end
    local posse, cid = myPosse(src)
    if not posse or posse.leader ~= cid then return Groups.Notify(src, locale('posse_only_leader'), 'error') end
    if targetCid == cid or not indexOf(posse.members, targetCid) then return end
    if not onlineSrc(targetCid) then return Groups.Notify(src, locale('posse_member_offline'), 'error') end
    setLeader(posse, targetCid)
    sync(posse)
end)

RegisterNetEvent('grumpy-groups:server:posseDisband', function()
    local src = source
    if Groups.OnCooldown(src, 'posseAction', 1) then return end
    local posse, cid = myPosse(src)
    if not posse or posse.leader ~= cid then return Groups.Notify(src, locale('posse_only_leader'), 'error') end
    disband(posse, 'posse_disbanded_leader')
end)

RSGCore.Functions.CreateCallback('grumpy-groups:server:getPosse', function(src, cb)
    local posse, cid = myPosse(src)
    cb(posse and snapshot(posse, cid) or nil)
end)

-----------------------------------------------------------------------
-- login / logout
-----------------------------------------------------------------------
local function onLoaded(Player)
    if not Player then return end
    local src, cid = Player.PlayerData.source, Player.PlayerData.citizenid
    SrcToCid[src] = cid
    local id = ByCid[cid]
    local posse = id and Posses[id]
    if not posse then return setState(src, nil) end
    if posse.leader == cid then posse.leaderOfflineSince = nil end
    sync(posse)
end

local function onGone(src)
    local cid = SrcToCid[src]
    SrcToCid[src] = nil
    local id = cid and ByCid[cid]
    local posse = id and Posses[id]
    if not posse then return end
    if posse.leader == cid then posse.leaderOfflineSince = os.time() end
    SetTimeout(500, function() if Posses[posse.id] then sync(posse) end end) -- let core finish logging them out
end

AddEventHandler('RSGCore:Server:PlayerLoaded', onLoaded)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) onGone(src) end)
AddEventHandler('playerDropped', function() onGone(source) end)

-----------------------------------------------------------------------
-- lifetime, warning and leader hand-off
-----------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(P.TickInterval * 1000)
        local now = os.time()
        for _, posse in pairs(Posses) do
            if now >= posse.expiresAt then
                disband(posse, 'posse_expired')
            else
                if not posse.warned and now >= posse.expiresAt - P.WarningTime then
                    posse.warned = true
                    notifyAll(posse, locale('posse_warning', math.ceil((posse.expiresAt - now) / 60)), 'warning')
                end
                if posse.leaderOfflineSince and now - posse.leaderOfflineSince >= P.LeaderGrace then
                    local nextLeader = firstOnlineOther(posse, posse.leader)
                    if nextLeader then
                        setLeader(posse, nextLeader)
                        sync(posse)
                    else
                        disband(posse, 'posse_disbanded_empty')
                    end
                end
            end
        end
    end
end)

-- member positions for posse blips (server-side so members out of render range still show)
if P.Blips.enabled then
    CreateThread(function()
        while true do
            Wait(P.Blips.interval * 1000)
            for _, posse in pairs(Posses) do
                local list = {}
                eachOnline(posse, function(src, cid)
                    local c = GetEntityCoords(GetPlayerPed(src))
                    list[#list + 1] = { src = src, x = c.x, y = c.y, z = c.z, name = posse.names[cid], leader = cid == posse.leader }
                end)
                if #list > 1 then
                    for _, m in ipairs(list) do TriggerClientEvent('grumpy-groups:client:posseBlips', m.src, list) end
                end
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(SrcToCid) do setState(src, nil) end
end)

-----------------------------------------------------------------------
-- read access for api.lua
-----------------------------------------------------------------------
Groups.Posse = {}

function Groups.Posse.ById(id) return Posses[id] end

function Groups.Posse.ByCitizenId(cid)
    local id = ByCid[cid]
    return id and Posses[id] or nil
end

function Groups.Posse.OnlineMembers(posse)
    local out = {}
    eachOnline(posse, function(src) out[#out + 1] = src end)
    return out
end

function Groups.Posse.Disband(posse, reasonKey) disband(posse, reasonKey or 'posse_disbanded_leader') end
