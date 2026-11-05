-- Public server API. Other resources (grumpy-rumors, job scripts) only ever talk to this file.

local M = Config.Members

local function inRange(src, other, radius)
    return not radius or Groups.Dist(src, other) <= radius
end

-- resolve the radius for a kind: opts.radius wins (false = no check), else config default
local function radiusFor(kind, opts)
    if opts.radius ~= nil then return opts.radius or nil end
    return M.Radius[kind] or nil
end

local function posseMembers(Player)
    local posse = Groups.Posse.ByCitizenId(Player.PlayerData.citizenid)
    if not posse then return end
    return Groups.Posse.OnlineMembers(posse), posse.id
end

local function gangMembers(src, Player, opts)
    local gang = Player.PlayerData.gang
    if not gang or gang.name == 'none' then return end
    local radius, out = radiusFor('gang', opts), {}
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        local Other = RSGCore.Functions.GetPlayer(id)
        if Other and Other.PlayerData.gang.name == gang.name and (id == src or inRange(src, id, radius)) then
            out[#out + 1] = id
        end
    end
    return out, gang.name
end

local function jobMembers(src, Player, opts)
    local job = Player.PlayerData.job
    if not job or not job.name or M.IgnoreJobs[job.name] then return end
    local onDuty = opts.onDuty
    if onDuty == nil then onDuty = M.JobOnDuty end
    if onDuty and not job.onduty then return end -- an off-duty caller has no job group
    local radius, out = radiusFor('job', opts), {}
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        local Other = RSGCore.Functions.GetPlayer(id)
        local oj = Other and Other.PlayerData.job
        if oj and oj.name == job.name and (not onDuty or oj.onduty) and (id == src or inRange(src, id, radius)) then
            out[#out + 1] = id
        end
    end
    return out, job.name
end

---Online members of a player's group, always including the player.
---@param src number
---@param kind 'auto'|'posse'|'gang'|'job'|nil  auto = posse, else gang, else job
---@param opts table|nil { radius = number|false, onDuty = boolean }  posses ignore both
---@return number[] members, string|nil kind, string|number|nil groupId
function Groups.GetMembers(src, kind, opts)
    kind, opts = kind or 'auto', type(opts) == 'table' and opts or {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {}, nil, nil end

    local order = kind == 'auto' and { 'posse', 'gang', 'job' } or { kind }
    for _, k in ipairs(order) do
        local list, id
        if k == 'posse' then list, id = posseMembers(Player)
        elseif k == 'gang' then list, id = gangMembers(src, Player, opts)
        elseif k == 'job' then list, id = jobMembers(src, Player, opts) end
        if list then return list, k, id end
    end
    return { src }, nil, nil
end

---Which group 'auto' would pick, without the member list.
function Groups.GetGroup(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local posse = Groups.Posse.ByCitizenId(Player.PlayerData.citizenid)
    if posse then
        return { kind = 'posse', id = posse.id, leader = posse.leader, expiresAt = posse.expiresAt, size = #posse.members }
    end
    local gang = Player.PlayerData.gang
    if gang and gang.name ~= 'none' then return { kind = 'gang', id = gang.name, label = gang.label, isBoss = gang.isboss } end
    local job = Player.PlayerData.job
    if job and job.name and not M.IgnoreJobs[job.name] then return { kind = 'job', id = job.name, label = job.label, onDuty = job.onduty } end
    return nil
end

local function GetPosse(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local posse = Player and Groups.Posse.ByCitizenId(Player.PlayerData.citizenid)
    if not posse then return nil end
    local members = {}
    for _, cid in ipairs(posse.members) do members[#members + 1] = { citizenid = cid, name = posse.names[cid] } end
    return { id = posse.id, leader = posse.leader, createdAt = posse.createdAt, expiresAt = posse.expiresAt, members = members }
end

local function IsInPosse(src) return GetPosse(src) ~= nil end

local function ArePosseMates(a, b)
    local pa, pb = GetPosse(a), GetPosse(b)
    return pa ~= nil and pb ~= nil and pa.id == pb.id
end

local function DisbandPosse(id)
    local posse = Groups.Posse.ById(tonumber(id))
    if not posse then return false end
    Groups.Posse.Disband(posse, 'posse_disbanded_admin')
    return true
end

exports('GetMembers', Groups.GetMembers)
exports('GetGroup', Groups.GetGroup)
exports('GetPosse', GetPosse)
exports('IsInPosse', IsInPosse)
exports('ArePosseMates', ArePosseMates)
exports('DisbandPosse', DisbandPosse)
exports('GetGangAccount', Groups.GetGangAccount)
exports('AddGangMoney', Groups.AddGangMoney)
exports('RemoveGangMoney', Groups.RemoveGangMoney)

-- old scripts that call exports['rsg-gangmenu']:AddGangMoney(...) keep working (rsg-gangmenu must be removed)
for name, fn in pairs({ GetGangAccount = Groups.GetGangAccount, AddGangMoney = Groups.AddGangMoney, RemoveGangMoney = Groups.RemoveGangMoney }) do
    AddEventHandler(('__cfx_export_rsg-gangmenu_%s'):format(name), function(setCB) setCB(fn) end)
end
