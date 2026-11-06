-- grumpy-backroom: created automatically on start; import by hand only if you prefer
CREATE TABLE IF NOT EXISTS `grumpy_backroom_rooms` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(48) NOT NULL,
    `npc_model` VARCHAR(64) NOT NULL,
    `npc` LONGTEXT NULL,
    `doors` LONGTEXT NOT NULL,
    `zone` LONGTEXT NULL,
    `exit_point` LONGTEXT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `open_until` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
