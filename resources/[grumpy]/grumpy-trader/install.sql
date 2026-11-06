-- grumpy-trader tables. Only needed with Config.AutoDatabase = false.
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  `template` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`traderid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_trader_laundering` (
  `traderid` varchar(50) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `day` date NOT NULL,
  `amount` decimal(11,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`traderid`, `citizenid`, `day`),
  KEY `trader_day` (`traderid`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- trader templates: default stock lists copied into traders and pushed to the traders that follow them
CREATE TABLE IF NOT EXISTS `grumpy_trader_templates` (
  `name` varchar(50) NOT NULL,
  `label` varchar(50) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_trader_template_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `template` varchar(50) NOT NULL,
  `item` varchar(50) NOT NULL,
  `stock` int(11) NOT NULL DEFAULT 0,
  `lowstock` int(11) NOT NULL DEFAULT 0,
  `highstock` int(11) NOT NULL DEFAULT 0,
  `baseprice` decimal(11,2) NOT NULL DEFAULT 0.00,
  `mode` varchar(4) NOT NULL DEFAULT 'both',
  PRIMARY KEY (`id`),
  UNIQUE KEY `template_item` (`template`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- optional: copy rsg-trader's traders and stock (all become legal traders)
-- INSERT IGNORE INTO grumpy_trader_npcs (traderid, tradername, npcmodel, x, y, z, heading, showblip)
--   SELECT traderid, tradername, npcmodel, x, y, z, heading, showblip FROM rsg_trader_npcs;
-- INSERT IGNORE INTO grumpy_trader (traderid, item, stock, lowstock, highstock, baseprice)
--   SELECT traderid, item, stock, lowstock, highstock, baseprice FROM rsg_trader;
