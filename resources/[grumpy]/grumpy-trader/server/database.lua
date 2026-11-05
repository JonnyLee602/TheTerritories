---------------------------------------------
-- automatic database setup
-- creates / upgrades the grumpy_trader tables on resource start, and on the first start copies
-- traders and stock from rsg-trader (Config.ImportRsgTrader).
-- disable with Config.AutoDatabase = false and import install.sql manually.
---------------------------------------------
local function log(msg, color)
    print(('[%s] %s%s^7'):format(GetCurrentResourceName(), color or '^2', msg))
end

if not Config.AutoDatabase then
    MySQL.ready(function() TriggerEvent('grumpy-trader:server:databaseReady') end)
    return
end

local function tableExists(name)
    return (MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) or 0) > 0
end

local function columnExists(tbl, col)
    return (MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, col }) or 0) > 0
end

MySQL.ready(function()
    local ok, err = pcall(function()
        local itemsCreated = not tableExists('grumpy_trader')
        local npcsCreated = not tableExists('grumpy_trader_npcs')

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `grumpy_trader` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `traderid` varchar(50) NOT NULL,
              `item` varchar(50) NOT NULL,
              `stock` int(11) NOT NULL DEFAULT 0,
              `lowstock` int(11) NOT NULL DEFAULT 0,
              `highstock` int(11) NOT NULL DEFAULT 0,
              `baseprice` decimal(11,2) NOT NULL DEFAULT 0.00,
              `mode` varchar(4) NOT NULL DEFAULT 'both',
              PRIMARY KEY (`id`),
              UNIQUE KEY `trader_item` (`traderid`, `item`),
              KEY `item` (`item`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `grumpy_trader_npcs` (
              `traderid` varchar(50) NOT NULL,
              `tradername` varchar(50) NOT NULL,
              `npcmodel` varchar(60) NOT NULL,
              `x` float NOT NULL,
              `y` float NOT NULL,
              `z` float NOT NULL,
              `heading` float NOT NULL DEFAULT 0,
              `showblip` tinyint(1) NOT NULL DEFAULT 1,
              `kind` varchar(10) NOT NULL DEFAULT 'legal',
              `launder` tinyint(1) NOT NULL DEFAULT 0,
              `launder_cut` decimal(5,2) DEFAULT NULL,
              PRIMARY KEY (`traderid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `grumpy_trader_laundering` (
              `traderid` varchar(50) NOT NULL,
              `citizenid` varchar(50) NOT NULL,
              `day` date NOT NULL,
              `amount` decimal(11,2) NOT NULL DEFAULT 0.00,
              PRIMARY KEY (`traderid`, `citizenid`, `day`),
              KEY `trader_day` (`traderid`, `day`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])

        -- upgrades for tables made by an earlier version
        if not columnExists('grumpy_trader', 'mode') then
            MySQL.query.await("ALTER TABLE `grumpy_trader` ADD COLUMN `mode` varchar(4) NOT NULL DEFAULT 'both'")
        end
        for col, def in pairs({ kind = "varchar(10) NOT NULL DEFAULT 'legal'", launder = 'tinyint(1) NOT NULL DEFAULT 0', launder_cut = 'decimal(5,2) DEFAULT NULL' }) do
            if not columnExists('grumpy_trader_npcs', col) then
                MySQL.query.await(('ALTER TABLE `grumpy_trader_npcs` ADD COLUMN `%s` %s'):format(col, def))
            end
        end

        -- first start: bring over rsg-trader's traders and stock (all as legal traders)
        local imported = false
        if npcsCreated and Config.ImportRsgTrader and tableExists('rsg_trader_npcs') then
            MySQL.query.await([[
                INSERT IGNORE INTO grumpy_trader_npcs (traderid, tradername, npcmodel, x, y, z, heading, showblip)
                SELECT traderid, tradername, npcmodel, x, y, z, heading, showblip FROM rsg_trader_npcs
            ]])
            if itemsCreated and tableExists('rsg_trader') then
                MySQL.query.await([[
                    INSERT IGNORE INTO grumpy_trader (traderid, item, stock, lowstock, highstock, baseprice)
                    SELECT traderid, item, stock, lowstock, highstock, baseprice FROM rsg_trader
                ]])
            end
            imported = true
            log('Imported traders and stock from rsg-trader. Stop rsg-trader so traders don\'t spawn twice.', '^3')
        end

        if npcsCreated and not imported then
            for _, t in ipairs(Config.DefaultTraders or {}) do
                MySQL.insert.await(
                    'INSERT IGNORE INTO grumpy_trader_npcs (traderid, tradername, npcmodel, x, y, z, heading, showblip, kind) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    { t.traderid, t.tradername, t.npcmodel or Config.DefaultModel, t.coords.x, t.coords.y, t.coords.z, t.coords.w,
                      (Config.Kinds[t.kind or 'legal'] or Config.Kinds.legal).defaultBlip and 1 or 0, Config.Kinds[t.kind] and t.kind or 'legal' })
            end
        end
        if itemsCreated and not imported then
            for _, row in ipairs(Config.DefaultItems or {}) do
                MySQL.insert.await(
                    'INSERT IGNORE INTO grumpy_trader (traderid, item, stock, lowstock, highstock, baseprice, mode) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    { row.traderid, row.item, row.stock or 0, row.lowstock, row.highstock, row.baseprice, Config.ItemModes[row.mode] and row.mode or 'both' })
            end
        end

        -- old laundering rows aren't needed after a week
        MySQL.query.await('DELETE FROM grumpy_trader_laundering WHERE `day` < (CURDATE() - INTERVAL 7 DAY)')
    end)

    if not ok then log('Database setup failed: ' .. tostring(err), '^1') end
    -- still try to load traders if the tables already exist
    if ok or tableExists('grumpy_trader_npcs') then TriggerEvent('grumpy-trader:server:databaseReady') end
end)
