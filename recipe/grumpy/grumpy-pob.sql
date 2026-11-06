-- grumpy-pob tables. Created automatically on start unless Config.AutoDatabase = false.

CREATE TABLE IF NOT EXISTS `grumpy_pob_businesses` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(50) NOT NULL,
  `label` VARCHAR(60) NOT NULL,
  `price` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `owner_cid` VARCHAR(50) DEFAULT NULL,
  `owner_name` VARCHAR(100) DEFAULT NULL,
  `npc_model` VARCHAR(60) NOT NULL,
  `blip` LONGTEXT DEFAULT NULL,
  `points` LONGTEXT NOT NULL,
  `settings` LONGTEXT DEFAULT NULL,
  `shop_id` INT DEFAULT NULL,
  `hotel_id` INT DEFAULT NULL,
  `rooms` INT NOT NULL DEFAULT 0,
  `tax_due` INT DEFAULT NULL,
  `tax_owed_since` INT DEFAULT NULL,
  `created_by` VARCHAR(50) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_accounts` (
  `account` VARCHAR(30) NOT NULL,
  `balance` DECIMAL(14,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_ledger` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `account` VARCHAR(30) NOT NULL,
  `ts` INT NOT NULL,
  `kind` VARCHAR(30) NOT NULL,
  `amount` DECIMAL(14,2) NOT NULL DEFAULT 0,
  `balance` DECIMAL(14,2) DEFAULT NULL,
  `who_cid` VARCHAR(50) DEFAULT NULL,
  `who_name` VARCHAR(100) DEFAULT NULL,
  `note` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `account_ts` (`account`, `ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_withdrawals` (
  `business_id` INT NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `day` INT NOT NULL,
  `amount` DECIMAL(14,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (`business_id`, `citizenid`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_stock` (
  `business_id` INT NOT NULL,
  `item` VARCHAR(100) NOT NULL,
  `qty` INT NOT NULL DEFAULT 0,
  `price` DECIMAL(10,2) DEFAULT NULL,
  PRIMARY KEY (`business_id`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_applications` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_id` INT NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `message` TEXT NOT NULL,
  `created_at` INT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_per_player` (`business_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_recipes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_id` INT NOT NULL,
  `item_name` VARCHAR(100) DEFAULT NULL,
  `label` VARCHAR(60) NOT NULL,
  `description` VARCHAR(255) NOT NULL DEFAULT '',
  `base_item` VARCHAR(100) NOT NULL,
  `ingredients` LONGTEXT NOT NULL,
  `amount` INT NOT NULL DEFAULT 1,
  `craft_time` INT NOT NULL DEFAULT 5000,
  `image_url` VARCHAR(255) DEFAULT NULL,
  `image_id` VARCHAR(100) DEFAULT NULL,
  `image_status` VARCHAR(20) NOT NULL DEFAULT 'none',
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `discord_msg` VARCHAR(40) DEFAULT NULL,
  `created_by` VARCHAR(50) DEFAULT NULL,
  `created_at` INT NOT NULL,
  `decided_by` VARCHAR(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `business` (`business_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_pob_launder` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_id` INT NOT NULL,
  `ts` INT NOT NULL,
  `dirty` DECIMAL(14,2) NOT NULL,
  `clean` DECIMAL(14,2) NOT NULL,
  `business_cut` DECIMAL(14,2) NOT NULL DEFAULT 0,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `seized` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `business_ts` (`business_id`, `ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
