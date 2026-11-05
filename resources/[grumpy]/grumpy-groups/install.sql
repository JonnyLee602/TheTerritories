-- Only needed when Config.AutoDatabase = false. Same table rsg-gangmenu / rsg-bossmenu use, so existing gang funds carry over.
CREATE TABLE IF NOT EXISTS `management_funds` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_name` (`job_name`),
  KEY `type` (`type`)
);
