-- Only needed when Config.AutoDatabase = false.
-- Standing itself lives in players.metadata (rsg-core rep). This table only queues changes for offline characters.
CREATE TABLE IF NOT EXISTS `grumpy_reputation_pending` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `action` VARCHAR(50) NOT NULL,
  `mult` FLOAT NOT NULL DEFAULT 1,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
);
