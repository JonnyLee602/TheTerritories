-- Only needed when Config.AutoDatabase = false (the tables are created automatically otherwise)

CREATE TABLE IF NOT EXISTS `grumpy_hotels` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(50) NOT NULL,
    `rooms` INT NOT NULL,
    `price` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `max_days` INT NOT NULL DEFAULT 1,
    `door_x` DOUBLE NOT NULL, `door_y` DOUBLE NOT NULL, `door_z` DOUBLE NOT NULL, `door_h` DOUBLE NOT NULL DEFAULT 0,
    `int_x` DOUBLE NOT NULL, `int_y` DOUBLE NOT NULL, `int_z` DOUBLE NOT NULL, `int_h` DOUBLE NOT NULL DEFAULT 0,
    `stash_x` DOUBLE DEFAULT NULL, `stash_y` DOUBLE DEFAULT NULL, `stash_z` DOUBLE DEFAULT NULL, `stash_h` DOUBLE DEFAULT NULL,
    `blip` TINYINT(1) NOT NULL DEFAULT 1,
    `created_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading from v1.1 (table already exists without the stash point)? Run this once:
-- ALTER TABLE `grumpy_hotels`
--     ADD COLUMN `stash_x` DOUBLE DEFAULT NULL AFTER `int_h`, ADD COLUMN `stash_y` DOUBLE DEFAULT NULL AFTER `stash_x`,
--     ADD COLUMN `stash_z` DOUBLE DEFAULT NULL AFTER `stash_y`, ADD COLUMN `stash_h` DOUBLE DEFAULT NULL AFTER `stash_z`;

CREATE TABLE IF NOT EXISTS `grumpy_hotel_rentals` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `hotel_id` INT NOT NULL,
    `room` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `renter_name` VARCHAR(60) NOT NULL,
    `key_citizenid` VARCHAR(50) DEFAULT NULL,
    `key_name` VARCHAR(60) DEFAULT NULL,
    `expires_at` INT NOT NULL,
    `grace_login_at` INT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_room` (`hotel_id`, `room`),
    UNIQUE KEY `uniq_renter` (`hotel_id`, `citizenid`),
    KEY `idx_key` (`key_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `grumpy_hotel_occupants` (
    `citizenid` VARCHAR(50) NOT NULL,
    `hotel_id` INT NOT NULL,
    `room` INT NOT NULL,
    `role` VARCHAR(10) NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
