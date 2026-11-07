-- grumpy-livery: one-time copy from the rsg-stables / rsg-wagons tables it replaces.
-- Runs on start. For each pair, rows are copied only when the new table is EMPTY and the old one exists,
-- so it never runs twice and never touches the old tables. Row ids are kept: saddlebag stashes
-- (horse_<id>), wagon stashes (wagon_<id>) and breeding parent ids keep pointing at the right rows.
-- Same as migrate.sql, for servers that prefer doing it by hand.

local PAIRS = {
    { from = 'rsg_stables_horses',   to = 'grumpy_livery_horses' },
    { from = 'rsg_stables_breeding', to = 'grumpy_livery_breeding' },
    { from = 'rsg_stables_races',    to = 'grumpy_livery_races' },
    { from = 'player_wagons',        to = 'grumpy_livery_wagons' },
}

local function columns(tbl)
    local rows = MySQL.query.await([[SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tbl }) or {}
    local set, list = {}, {}
    for _, r in ipairs(rows) do set[r.c] = true; list[#list + 1] = r.c end
    return set, list
end

local function migrate()
    -- wait for server.lua / wagons.lua to create the new tables
    for _ = 1, 60 do
        local n = 0
        for _, p in ipairs(PAIRS) do
            local _, list = columns(p.to)
            if #list > 0 then n = n + 1 end
        end
        if n == #PAIRS then break end
        Wait(1000)
    end

    for _, p in ipairs(PAIRS) do
        local oldSet = columns(p.from)
        local _, newList = columns(p.to)
        if next(oldSet) and #newList > 0 then
            local count = tonumber(MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(p.to))) or 0
            if count == 0 then
                local shared = {}
                for _, c in ipairs(newList) do
                    if oldSet[c] then shared[#shared + 1] = '`' .. c .. '`' end
                end
                local cols = table.concat(shared, ', ')
                local ok, res = pcall(MySQL.update.await,
                    ('INSERT INTO `%s` (%s) SELECT %s FROM `%s`'):format(p.to, cols, cols, p.from))
                if ok then
                    print(('^2[grumpy-livery] migrated %s rows from %s to %s^7'):format(tostring(res), p.from, p.to))
                else
                    print(('^1[grumpy-livery] migration %s -> %s failed: %s^7'):format(p.from, p.to, tostring(res)))
                end
            end
        end
    end
end

MySQL.ready(function() CreateThread(migrate) end)
