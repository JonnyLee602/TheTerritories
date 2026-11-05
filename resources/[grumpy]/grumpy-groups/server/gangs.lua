-- Gang management: a port of rsg-gangmenu (same stash names and management_funds rows, so data carries over)

local GangAccounts = {}

local function gangDef(name) return RSGCore.Shared.Gangs[name] end

-- returns Player if src is the boss of a real gang
local function GetBoss(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local gang = Player.PlayerData.gang
    if not gang or gang.name == 'none' or not gang.isboss or not gangDef(gang.name) then return end
    return Player
end

local function IsNearGangLocation(src, gangName)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, v in ipairs(Config.GangLocations) do
        if v.id == gangName and #(coords - v.coords) <= Config.Gang.InteractDistance then return true end
    end
    return false
end

local function SanitizeAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount then return end
    amount = math.floor(amount)
    if amount < 1 or amount > Config.Gang.MaxTransaction then return end
    return amount
end

local function gradeInfo(gangName, level)
    local def = gangDef(gangName)
    if not def or not level then return end
    return def.grades[tostring(level)] or def.grades[level]
end

-----------------------------------------------------------------------
-- accounts
-----------------------------------------------------------------------
local function SaveAccount(account)
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (?, ?, "gang") ON DUPLICATE KEY UPDATE amount = VALUES(amount)',
        { account, GangAccounts[account] })
end

function Groups.GetGangAccount(account)
    return GangAccounts[account] or 0
end

function Groups.AddGangMoney(account, amount)
    amount = tonumber(amount)
    if type(account) ~= 'string' or not amount or amount ~= amount or amount <= 0 then return false end
    GangAccounts[account] = (GangAccounts[account] or 0) + math.floor(amount)
    SaveAccount(account)
    return true
end

function Groups.RemoveGangMoney(account, amount)
    amount = tonumber(amount)
    if type(account) ~= 'string' or not amount or amount ~= amount or amount <= 0 then return false end
    amount = math.floor(amount)
    local balance = GangAccounts[account] or 0
    if balance < amount then return false end
    GangAccounts[account] = balance - amount
    SaveAccount(account)
    return true
end

MySQL.ready(function()
    Wait(500) -- let AutoDatabase create the table first
    local rows = MySQL.query.await('SELECT job_name, amount FROM management_funds WHERE type = "gang"')
    for _, v in ipairs(rows or {}) do GangAccounts[v.job_name] = v.amount end
end)

-----------------------------------------------------------------------
-- menu data
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-groups:server:getGangMenu', function(src, cb, atLocation)
    local Player = GetBoss(src)
    if not Player then return cb(nil) end
    local gang = Player.PlayerData.gang
    local here = atLocation == true and IsNearGangLocation(src, gang.name)
    cb({
        label = gang.label,
        atLocation = here,
        balance = here and Groups.GetGangAccount(gang.name) or nil,
        cash = Player.PlayerData.money.cash or 0,
        maxTransaction = Config.Gang.MaxTransaction,
    })
end)

RSGCore.Functions.CreateCallback('grumpy-groups:server:getGangMembers', function(src, cb)
    local Player = GetBoss(src)
    if not Player then return cb(nil) end
    local gangName = Player.PlayerData.gang.name
    local myLevel = tonumber(Player.PlayerData.gang.grade.level) or 0
    local members = {}

    local rows = MySQL.query.await("SELECT citizenid, charinfo, gang FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(gang, '$.name')) = ?", { gangName }) or {}
    for _, row in ipairs(rows) do
        local online = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
        local gang = online and online.PlayerData.gang or json.decode(row.gang) or {}
        local charinfo = online and online.PlayerData.charinfo or json.decode(row.charinfo) or {}
        if gang.name == gangName then
            members[#members + 1] = {
                citizenid = row.citizenid,
                name = Groups.FullName(charinfo),
                gradeName = gang.grade and gang.grade.name or '?',
                gradeLevel = gang.grade and tonumber(gang.grade.level) or 0,
                online = online ~= nil,
                isSelf = row.citizenid == Player.PlayerData.citizenid,
            }
        end
    end
    table.sort(members, function(a, b)
        if a.gradeLevel ~= b.gradeLevel then return a.gradeLevel > b.gradeLevel end
        return a.name < b.name
    end)

    local grades = {}
    for k, g in pairs(gangDef(gangName).grades) do
        local lvl = tonumber(k)
        if lvl then grades[#grades + 1] = { level = lvl, name = g.name, allowed = lvl <= myLevel } end
    end
    table.sort(grades, function(a, b) return a.level < b.level end)

    cb({ members = members, grades = grades })
end)

RSGCore.Functions.CreateCallback('grumpy-groups:server:getNearbyRecruits', function(src, cb)
    local Player = GetBoss(src)
    if not Player then return cb(nil) end
    local gangName = Player.PlayerData.gang.name
    local players = {}
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        if id ~= src and Groups.Dist(src, id) <= Config.Gang.HireDistance then
            local Target = RSGCore.Functions.GetPlayer(id)
            if Target and Target.PlayerData.gang.name ~= gangName then
                players[#players + 1] = { source = id, name = Groups.FullName(Target.PlayerData.charinfo) }
            end
        end
    end
    table.sort(players, function(a, b) return a.name < b.name end)
    cb(players)
end)

-----------------------------------------------------------------------
-- stash (name derived server-side, location-locked)
-----------------------------------------------------------------------
RegisterNetEvent('grumpy-groups:server:openGangStash', function()
    local src = source
    local Player = GetBoss(src)
    if not Player or Groups.OnCooldown(src, 'stash', 1) then return end
    local gang = Player.PlayerData.gang.name
    if not IsNearGangLocation(src, gang) then return Groups.Notify(src, locale('gang_too_far'), 'error') end
    exports['rsg-inventory']:OpenInventory(src, 'gang_' .. gang, {
        label = locale('gang_storage'), maxweight = Config.Gang.StorageMaxWeight, slots = Config.Gang.StorageMaxSlots,
    })
end)

-----------------------------------------------------------------------
-- money
-----------------------------------------------------------------------
RegisterNetEvent('grumpy-groups:server:gangWithdraw', function(amount)
    local src = source
    local Player = GetBoss(src)
    if not Player or Groups.OnCooldown(src, 'money', 1) then return end
    amount = SanitizeAmount(amount)
    if not amount then return Groups.Notify(src, locale('gang_bad_amount'), 'error') end
    local gang = Player.PlayerData.gang.name
    if not IsNearGangLocation(src, gang) then return Groups.Notify(src, locale('gang_too_far'), 'error') end

    if Groups.RemoveGangMoney(gang, amount) then
        Player.Functions.AddMoney('cash', amount, 'grumpy-groups-gang-withdraw')
        Groups.Log(locale('log_withdraw'), 'yellow', locale('log_withdraw_msg', Groups.FullName(Player.PlayerData.charinfo), amount, gang))
        Groups.Notify(src, locale('gang_withdrew', amount), 'success')
    else
        Groups.Notify(src, locale('gang_not_enough_funds'), 'error')
    end
end)

RegisterNetEvent('grumpy-groups:server:gangDeposit', function(amount)
    local src = source
    local Player = GetBoss(src)
    if not Player or Groups.OnCooldown(src, 'money', 1) then return end
    amount = SanitizeAmount(amount)
    if not amount then return Groups.Notify(src, locale('gang_bad_amount'), 'error') end
    local gang = Player.PlayerData.gang.name
    if not IsNearGangLocation(src, gang) then return Groups.Notify(src, locale('gang_too_far'), 'error') end

    if (Player.PlayerData.money.cash or 0) >= amount and Player.Functions.RemoveMoney('cash', amount, 'grumpy-groups-gang-deposit') then
        Groups.AddGangMoney(gang, amount)
        Groups.Log(locale('log_deposit'), 'yellow', locale('log_deposit_msg', Groups.FullName(Player.PlayerData.charinfo), amount, gang))
        Groups.Notify(src, locale('gang_deposited', amount), 'success')
    else
        Groups.Notify(src, locale('gang_not_enough_cash'), 'error')
    end
end)

-----------------------------------------------------------------------
-- members
-----------------------------------------------------------------------
-- returns online Player (or nil) plus gang/charinfo for a member of gangName
local function GetMember(citizenid, gangName)
    if type(citizenid) ~= 'string' then return end
    local online = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if online then
        if online.PlayerData.gang.name ~= gangName then return end
        return online, online.PlayerData.gang, online.PlayerData.charinfo
    end
    local row = MySQL.single.await('SELECT gang, charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return end
    local gang, charinfo = json.decode(row.gang) or {}, json.decode(row.charinfo) or {}
    if gang.name ~= gangName then return end
    return nil, gang, charinfo
end

RegisterNetEvent('grumpy-groups:server:gangSetGrade', function(citizenid, grade)
    local src = source
    local Player = GetBoss(src)
    if not Player or Groups.OnCooldown(src, 'manage', 1) then return end
    local myGang = Player.PlayerData.gang
    local myLevel = tonumber(myGang.grade.level) or 0
    grade = tonumber(grade)
    local info = gradeInfo(myGang.name, grade)

    if not info then return Groups.Notify(src, locale('gang_bad_grade'), 'error') end
    if citizenid == Player.PlayerData.citizenid or grade > myLevel then return Groups.Notify(src, locale('gang_no_permission'), 'error') end

    local Member, gang = GetMember(citizenid, myGang.name)
    if not gang then return Groups.Notify(src, locale('gang_not_member'), 'error') end
    if (tonumber(gang.grade and gang.grade.level) or 0) > myLevel then return Groups.Notify(src, locale('gang_outranks_you'), 'error') end
    if not Member then return Groups.Notify(src, locale('gang_member_offline'), 'error') end

    if Member.Functions.SetGang(myGang.name, grade) then
        Groups.Notify(src, locale('gang_grade_set'), 'success')
        Groups.Notify(Member.PlayerData.source, locale('gang_grade_changed', info.name), 'inform')
    else
        Groups.Notify(src, locale('gang_bad_grade'), 'error')
    end
end)

RegisterNetEvent('grumpy-groups:server:gangFire', function(citizenid)
    local src = source
    local Player = GetBoss(src)
    if not Player or Groups.OnCooldown(src, 'manage', 1) then return end
    local myGang = Player.PlayerData.gang
    if citizenid == Player.PlayerData.citizenid then return Groups.Notify(src, locale('gang_cant_fire_self'), 'error') end

    local Member, gang, charinfo = GetMember(citizenid, myGang.name)
    if not gang then return Groups.Notify(src, locale('gang_not_member'), 'error') end
    if (tonumber(gang.grade and gang.grade.level) or 0) > (tonumber(myGang.grade.level) or 0) then
        return Groups.Notify(src, locale('gang_outranks_you'), 'error')
    end

    if Member then
        if not Member.Functions.SetGang('none', 0) then return Groups.Notify(src, locale('gang_error'), 'error') end
        Groups.Notify(Member.PlayerData.source, locale('gang_you_were_removed'), 'error')
    else
        local none = { name = 'none', label = 'No Affiliation', isboss = false, grade = { name = 'none', level = 0 } }
        MySQL.update.await('UPDATE players SET gang = ? WHERE citizenid = ?', { json.encode(none), citizenid })
    end

    Groups.Notify(src, locale('gang_member_removed'), 'success')
    Groups.Log(locale('log_fire'), 'orange', locale('log_fire_msg', Groups.FullName(Player.PlayerData.charinfo), Groups.FullName(charinfo), myGang.name))
end)

-----------------------------------------------------------------------
-- recruit
-----------------------------------------------------------------------
RegisterNetEvent('grumpy-groups:server:gangRecruit', function(recruit)
    local src = source
    local Player = GetBoss(src)
    recruit = tonumber(recruit)
    if not Player or not recruit or recruit == src or Groups.OnCooldown(src, 'recruit', 2) then return end
    local Target = RSGCore.Functions.GetPlayer(recruit)
    if not Target then return Groups.Notify(src, locale('player_not_found'), 'error') end

    local myGang = Player.PlayerData.gang
    if Groups.Dist(src, recruit) > Config.Gang.HireDistance then return Groups.Notify(src, locale('too_far'), 'error') end
    if Target.PlayerData.gang.name == myGang.name then return Groups.Notify(src, locale('gang_already_member'), 'error') end
    if Groups.Asking[recruit] then return Groups.Notify(src, locale('invite_pending'), 'error') end

    local targetCid = Target.PlayerData.citizenid
    Groups.Notify(src, locale('invite_sent'), 'inform')
    local accepted = Groups.AskPlayer(recruit, 'gang', myGang.label, Groups.FullName(Player.PlayerData.charinfo), Config.Gang.InviteTimeout)

    -- re-validate after the async prompt
    Player, Target = GetBoss(src), RSGCore.Functions.GetPlayer(recruit)
    if not Player or not Target or Player.PlayerData.gang.name ~= myGang.name then return end
    if Target.PlayerData.citizenid ~= targetCid then return end -- recruit switched character
    if not accepted then return Groups.Notify(src, locale('invite_declined'), 'error') end

    if Target.Functions.SetGang(myGang.name, 0) then
        local bossName, targetName = Groups.FullName(Player.PlayerData.charinfo), Groups.FullName(Target.PlayerData.charinfo)
        Groups.Notify(src, locale('gang_recruited', targetName, myGang.label), 'success')
        Groups.Notify(recruit, locale('gang_joined', myGang.label), 'success')
        Groups.Log(locale('log_recruit'), 'yellow', locale('log_recruit_msg', bossName, targetName, myGang.name))
    end
end)

-----------------------------------------------------------------------
-- admin: /removegang [id]
-----------------------------------------------------------------------
RSGCore.Commands.Add('removegang', locale('cmd_removegang'), { { name = 'id', help = locale('cmd_arg_id') } }, true, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then return Groups.Notify(src, locale('player_not_found'), 'error') end
    Player.Functions.SetGang('none', 0)
    Groups.Notify(src, locale('admin_gang_removed'), 'success')
    Groups.Notify(Player.PlayerData.source, locale('gang_you_were_removed'), 'inform')
end, 'admin')
