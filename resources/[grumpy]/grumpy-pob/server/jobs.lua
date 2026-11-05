-- One rsg-core multi-job per business (pob_<id>). Grades come from Config.Grades and pay nothing
-- through rsg-core: wages are paid from the business account (server/upkeep.lua).
local RSGCore = POB.Core()

local Jobs = {}
POB.Jobs = Jobs

local patchWarned = false

local function definition(biz)
    local grades = {}
    for lvl, gname in pairs(Config.Grades) do
        grades[tostring(lvl)] = { name = gname, payment = 0, isboss = lvl == Config.OwnerGrade or nil }
    end
    return {
        name = biz.job, label = biz.label, type = Config.JobType, icon = 'store',
        defaultDuty = false, offDutyPay = false, grades = grades,
    }
end

-- Creates or updates the job. Uses the rsg-core patch (integrations/rsg-core.md) when present.
function Jobs.Ensure(biz)
    local def = definition(biz)
    local ok, res, err = pcall(function() return exports['rsg-core']:SaveJobDefinition(def) end)
    if ok and res then return true end
    if ok and not res then print(('^1[grumpy-pob] SaveJobDefinition(%s) failed: %s^7'):format(biz.job, tostring(err))) return false end

    -- Fallback without the patch: write the row and push to rsg-core. The multi-job registry only
    -- reads the table on start, so hiring into a NEW business works after the next restart.
    if not patchWarned then
        patchWarned = true
        print('^3[grumpy-pob] rsg-core SaveJobDefinition export missing: apply integrations/rsg-core.md. New business jobs need a restart before hiring.^7')
    end
    MySQL.query.await([[INSERT INTO multijob_jobs (name, label, type, icon, default_duty, off_duty_pay, grades) VALUES (?, ?, ?, ?, 0, 0, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), grades = VALUES(grades)]],
        { def.name, def.label, def.type, def.icon, json.encode(def.grades) })
    local core = { name = def.name, label = def.label, type = def.type, defaultDuty = false, offDutyPay = false, grades = def.grades }
    if RSGCore.Shared.Jobs[def.name] then exports['rsg-core']:UpdateJob(def.name, core) else exports['rsg-core']:AddJob(def.name, core) end
    return true
end

function Jobs.Delete(biz)
    local ok, res = pcall(function() return exports['rsg-core']:DeleteJobDefinition(biz.job) end)
    if ok and res ~= nil then return end
    for _, row in ipairs(MySQL.query.await('SELECT citizenid FROM player_jobs WHERE job = ?', { biz.job }) or {}) do
        exports['rsg-core']:RemovePlayerJob(row.citizenid, biz.job)
    end
    MySQL.update.await('DELETE FROM multijob_jobs WHERE name = ?', { biz.job })
    pcall(function() exports['rsg-core']:RemoveJob(biz.job) end)
end

function Jobs.Staff(biz)
    local rows = MySQL.query.await([[SELECT pj.citizenid, pj.grade, p.charinfo FROM player_jobs pj
        LEFT JOIN players p ON p.citizenid = pj.citizenid WHERE pj.job = ? ORDER BY pj.grade DESC]], { biz.job }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local src = POB.SrcByCid(r.citizenid)
        local onDuty = false
        if src then
            local P = RSGCore.Functions.GetPlayer(src)
            local j = P and P.PlayerData.job or {}
            onDuty = j.name == biz.job and j.onduty == true
        end
        out[#out + 1] = {
            cid = r.citizenid, name = POB.ShortName(r.charinfo), grade = tonumber(r.grade) or 0,
            gradeLabel = Config.Grades[tonumber(r.grade) or 0] or '?', online = src ~= nil, onDuty = onDuty,
        }
    end
    return out
end

local function changed(identifier)
    local src = type(identifier) == 'number' and identifier or POB.SrcByCid(identifier)
    if src then TriggerClientEvent('grumpy-pob:client:employmentChanged', src) end
end

-- identifier = server id or citizenid
function Jobs.Give(identifier, biz, grade, bypassMax)
    local ok, err = exports['rsg-core']:AddPlayerJob(identifier, biz.job, grade, bypassMax == true)
    if ok then changed(identifier) end
    return ok, err
end

function Jobs.Take(identifier, biz)
    local ok, err = exports['rsg-core']:RemovePlayerJob(identifier, biz.job)
    if ok then changed(identifier) end
    return ok, err
end

-- Businesses this character works at (drives which target options the client shows; the server re-checks everything)
RSGCore.Functions.CreateCallback('grumpy-pob:server:myEmployment', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    local out = {}
    for _, row in ipairs(MySQL.query.await("SELECT job, grade FROM player_jobs WHERE citizenid = ? AND job LIKE ?",
        { Player.PlayerData.citizenid, Config.JobPrefix .. '%' }) or {}) do
        local id = tonumber(row.job:sub(#Config.JobPrefix + 1))
        if id and POB.Businesses[id] then out[#out + 1] = { id = id, grade = tonumber(row.grade) or 0 } end
    end
    cb(out)
end)

function Jobs.RemoveAll(biz)
    for _, row in ipairs(MySQL.query.await('SELECT citizenid FROM player_jobs WHERE job = ?', { biz.job }) or {}) do
        Jobs.Take(row.citizenid, biz)
        if POB.StableEvict then POB.StableEvict(biz, row.citizenid) end
    end
end

POB.AfterLoad(function()
    for _, biz in pairs(POB.Businesses) do Jobs.Ensure(biz) end
end)
