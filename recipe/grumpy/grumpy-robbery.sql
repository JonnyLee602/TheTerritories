-- Only needed when Config.AutoDatabase = false.
-- Stores themselves come from rsg-stores (rsg_shops_npcs); this only holds robbery settings per NPC shop.
CREATE TABLE IF NOT EXISTS `grumpy_robbery_stores` (
  `npc_id` INT NOT NULL,              -- rsg_shops_npcs.id
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `shelves` LONGTEXT NULL,            -- JSON [{x,y,z}, ...] (max 4)
  `safe` LONGTEXT NULL,               -- JSON {x,y,z,h,prop,rx,ry,rz} or NULL
  PRIMARY KEY (`npc_id`)
);
