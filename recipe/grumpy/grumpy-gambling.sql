-- grumpy-gambling tables. Created automatically on start unless Config.AutoDatabase = false.
-- Phase 1 (foundation). Money, hands, NPC and business tables are added in later phases (DESIGN.md §13).

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
