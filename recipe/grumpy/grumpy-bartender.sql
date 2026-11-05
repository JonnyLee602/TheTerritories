-- Only needed when Config.AutoDatabase = false (the tables are created automatically otherwise)

CREATE TABLE IF NOT EXISTS `grumpy_bartenders` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(50) NOT NULL,
    `model` VARCHAR(64) NOT NULL,
    `animation` VARCHAR(50) NOT NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
    `services` LONGTEXT NOT NULL,
    `created_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading from the old built-in hotel: rentals now live in grumpy-hotel. The old table is no longer used:
-- DROP TABLE IF EXISTS `grumpy_bartender_rentals`;
