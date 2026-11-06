-- grumpy-gambling tables. Created automatically on start unless Config.AutoDatabase = false.
-- Phases 1–2: tables, money. Phase 5: NPC win-cap window and regulars' memory. Business tables come in phase 6.
-- Money columns ending in _c are integer cents.

CREATE TABLE IF NOT EXISTS `grumpy_gambling_tables` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(60) NOT NULL,
  `kind` VARCHAR(10) NOT NULL,
  `source` VARCHAR(10) NOT NULL DEFAULT 'public',
  `model` VARCHAR(60) NOT NULL,
  `bound` TINYINT(1) NOT NULL DEFAULT 0,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `h` DOUBLE NOT NULL DEFAULT 0,
  `currency` VARCHAR(20) NOT NULL DEFAULT 'cash',
  `fixed_tier` VARCHAR(10) DEFAULT NULL,
  `business_id` INT DEFAULT NULL,
  `owner_cid` VARCHAR(50) DEFAULT NULL,
  `seats` LONGTEXT DEFAULT NULL,
  `dealer` LONGTEXT DEFAULT NULL,
  `settings` LONGTEXT DEFAULT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(50) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `business` (`business_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_gambling_models` (
  `model` VARCHAR(60) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Chips at a table. A row holds the stack as of the last settled hand; a crash mid-hand leaves the pre-hand stack.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_stacks` (
  `citizenid` VARCHAR(50) NOT NULL,
  `table_id` INT NOT NULL,
  `currency` VARCHAR(20) NOT NULL,
  `amount_c` BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Money owed to a player who wasn't online to receive it (paid on their next login).
CREATE TABLE IF NOT EXISTS `grumpy_gambling_pending` (
  `citizenid` VARCHAR(50) NOT NULL,
  `currency` VARCHAR(20) NOT NULL,
  `amount_c` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `currency`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One row per settled hand.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_hands` (
  `id` VARCHAR(40) NOT NULL,
  `table_id` INT NOT NULL,
  `game` VARCHAR(32) NOT NULL,
  `tier` VARCHAR(10) NOT NULL,
  `currency` VARCHAR(20) NOT NULL,
  `started_at` INT NOT NULL,
  `settled_at` INT NOT NULL,
  `wagered_c` BIGINT NOT NULL DEFAULT 0,
  `rake_c` BIGINT NOT NULL DEFAULT 0,
  `house_c` BIGINT NOT NULL DEFAULT 0,
  `data` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `table_time` (`table_id`, `settled_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Money in and out of the core: buy-ins, cash-outs, payouts, rake, money created (mint) or destroyed (sink).
CREATE TABLE IF NOT EXISTS `grumpy_gambling_ledger` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `ts` INT NOT NULL,
  `kind` VARCHAR(20) NOT NULL,
  `table_id` INT DEFAULT NULL,
  `hand_id` VARCHAR(40) DEFAULT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `currency` VARCHAR(20) NOT NULL,
  `amount_c` BIGINT NOT NULL,
  `note` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `kind_ts` (`kind`, `ts`),
  KEY `cid_ts` (`citizenid`, `ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Business table banks (filled from phase 6).
CREATE TABLE IF NOT EXISTS `grumpy_gambling_cashboxes` (
  `table_id` INT NOT NULL,
  `currency` VARCHAR(20) NOT NULL,
  `balance_c` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`table_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fractions of a cent of rake carried between hands, per table.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_rake_remainder` (
  `table_id` INT NOT NULL,
  `remainder` DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (`table_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Rake tuner input: play per day, tier, kind and game.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_rake_stats` (
  `day` DATE NOT NULL,
  `tier` VARCHAR(10) NOT NULL,
  `kind` VARCHAR(10) NOT NULL,
  `game` VARCHAR(32) NOT NULL,
  `hands` INT NOT NULL DEFAULT 0,
  `wagered_c` BIGINT NOT NULL DEFAULT 0,
  `player_seconds` BIGINT NOT NULL DEFAULT 0,
  `rake_c` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`day`, `tier`, `kind`, `game`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Rake tuner output: the current rate per tier, kind and game.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_rake_rates` (
  `tier` VARCHAR(10) NOT NULL,
  `kind` VARCHAR(10) NOT NULL,
  `game` VARCHAR(32) NOT NULL,
  `rate` DOUBLE NOT NULL,
  `samples` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`tier`, `kind`, `game`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- NPC win cap (DESIGN.md §8.3): what each player won from (+) or lost to (-) NPCs, per hand, inside the window.
-- Purged once older than Config.Npc.CapWindowMinutes.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_npc_window` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `ts` INT NOT NULL,
  `amount_c` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `player_ts` (`citizenid`, `ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- What each regular NPC remembers about a player (DESIGN.md §8.6). net_c = what the regular won from them (+) or
-- lost to them (-) over hands played together.
CREATE TABLE IF NOT EXISTS `grumpy_gambling_regular_memory` (
  `regular_id` VARCHAR(40) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `hands` INT NOT NULL DEFAULT 0,
  `net_c` BIGINT NOT NULL DEFAULT 0,
  `last_seen` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`regular_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
