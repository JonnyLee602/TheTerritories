-- The Territories: base world setup, exported from the dev database by tools/export-base-data.sh
-- on 2026-11-06. GENERATED: re-run the tool instead of editing this file.
--
-- Each table is DROPPED and recreated with the dev schema, then filled. The recipe runs this file
-- LAST, after rsgcore.sql and every grumpy install.sql, on a fresh database. Never run it on a live
-- database that has data you want to keep in these tables.
--
-- rsg_shops_presets includes the 'templates_seeded' marker, so rsg-stores does not add its
-- Config.ShopTemplates on top of the templates below. rsg_doorlocks being filled means rsg-doorlock
-- skips its seed_doors.lua import.
-- Tables: rsg_shops_npcs rsg_shops_items rsg_shops_blips rsg_shops_presets rsg_shops_templates rsg_shops_template_items rsg_doorlocks grumpy_bartenders grumpy_hotels grumpy_backroom_rooms grumpy_robbery_stores grumpy_trader_npcs


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `rsg_shops_npcs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_shops_npcs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `model` varchar(100) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `h` double NOT NULL,
  `shop_name` varchar(100) DEFAULT NULL,
  `shop_label` varchar(100) DEFAULT NULL,
  `shop_type` varchar(10) NOT NULL DEFAULT 'both',
  `store_kind` varchar(10) NOT NULL DEFAULT 'npc',
  `owner_citizenid` varchar(50) DEFAULT NULL,
  `owner_name` varchar(100) DEFAULT NULL,
  `balance` decimal(12,2) NOT NULL DEFAULT 0.00,
  `prop_model` varchar(100) DEFAULT NULL,
  `upkeep_owed` decimal(10,2) NOT NULL DEFAULT 0.00,
  `upkeep_next` int(11) DEFAULT NULL,
  `packed_at` int(11) DEFAULT NULL,
  `template_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_shop_name` (`shop_name`),
  KEY `idx_owner` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_shops_npcs` DISABLE KEYS */;
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (1,'Valentine Store','u_m_m_rhdgenstoreowner_02',-324.13,803.81,116.88,283.1,'valgenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (2,'Valentine Gunsmith','u_m_m_valgunsmith_01',-281.21,778.85,118.5,7.2,'VALGUN','Valentine Gunsmith','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'gunsmith');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (3,'Blackwater Fish Supply','u_m_m_rhdgenstoreowner_02',-756.82,-1360.99,42.72,271.3,'blackwater_fish','Blackwater Fish Supply','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'fishing_supply');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (4,'St.Denis Fishmonger','u_m_m_rhdgenstoreowner_02',2849.25,-1407.84,44.39,229.3,'stdenis_fish','St Denis Fishing Supply','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'fishing_supply');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (5,'St Denis Gunsmith','u_m_m_valgunsmith_01',2717.35,-1286.83,48.64,37.2,'STDNGUN','St Denis Gunsmith','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'gunsmith');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (6,'Rhodes Gunsmith','u_m_m_valgunsmith_01',1322.48,-1323.14,76.89,358.1,'RHDGUN','Rhodes Gunsmith','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'gunsmith');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (7,'Tumbleweed Gunsmith','u_m_m_valgunsmith_01',-5506.36,-2964.01,-1.64,117.1,'TBLWGUN','Tumbleweed Gunsmith','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'gunsmith');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (8,'Strawberry Store','u_m_m_strgenstoreowner_01',-1789.59,-387.96,159.33,57.3,'strawgenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (9,'Annesburg Gunsmith','u_m_m_asbgunsmith_01',2948.4,1319.34,43.82,70.8,'ANNESGUN','Annesburg Gunsmith','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'gunsmith');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (10,'VanHorn Store','u_m_m_rhdgenstoreowner_01',3025.68,562.12,43.72,258.4,'vanhorngenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (11,'St Denis Store','u_m_m_nbxgeneralstoreowner_01',2824.45,-1319.37,45.76,323.2,'stdnsgenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (12,'Rhodes Store','u_m_m_rhdgenstoreowner_02',1329.87,-1294.27,76.02,68.6,'rhodesgenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (13,'Blackwater Store','u_m_m_nbxgeneralstoreowner_01',-785.92,-1322.2,42.88,154.5,'blkwtrgenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (14,'Tumbleweed Store','u_m_m_rhdgenstoreowner_01',-5485.52,-2937.85,-1.4,125,'tmblwdgenstore','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (15,'Blackwater Farmers Supply','u_f_m_tumgeneralstoreowner_01',-840.06,-1359.98,42.53,81.8,'blkwtrfarm','Farmer\'s Supply','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'farmers_supply');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (16,'Produce Vendor','u_m_m_walgeneralstoreowner_01',-733.41,-1257.08,43.78,348.9,'blkwtrproduce','Produce Vendor','sell','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'produce_vendor');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (17,'Produce Vendor','u_m_m_walgeneralstoreowner_01',-177.84,647.19,112.59,61.4,'valproduce','Produce Vendor','sell','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'produce_vendor');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (18,'Farmers Supply','u_f_m_tumgeneralstoreowner_01',-239.66,759.96,116.72,35.3,'valfarm','Farmer\'s Supply','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'farmers_supply');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (20,'Produce Vendor','u_m_m_walgeneralstoreowner_01',-1297.81,412.27,94.38,74.1,'wallaceproduce','Produce Vendor','sell','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'produce_vendor');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (21,'Wallace Station','u_m_m_nbxgeneralstoreowner_01',-1301.46,393.7,94.43,66.2,'wallacesupply','Wallace Station','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (22,'Desert Fish Supply','u_m_m_rhdgenstoreowner_02',-1414.48,-2675.88,41.22,68.5,'desert_fish','Blackwater Fish Supply','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'fishing_supply');
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (23,'Bartender','none',-313.2532958984375,805.6315307617188,118.98051452636719,99.8150634765625,'bar_db_1','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (25,'Bartender','none',1340.35107421875,-1374.8748779296875,80.48064422607422,261.5719791650772,'bar_db_2','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (26,'Bartender','none',-817.4073486328125,-1318.953125,43.678932189941406,267.7194366455078,'bar_db_3','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (27,'Bartender','none',-5517.93603515625,-2906.4296875,-1.7513055801391602,209.3679479956627,'bar_db_4','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (28,'Bartender','none',2639.755126953125,-1224.8475341796875,53.38039016723633,88.51760864257812,'bar_db_5','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (29,'Bartender','none',2957.008544921875,1349.387939453125,44.838802337646484,98.12490844726562,'bar_db_6','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (30,'Bartender','none',-1395.692626953125,-2320.18505859375,43.62717819213867,5.253871917724609,'bar_db_7','Bartender','buy','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,NULL);
INSERT INTO `rsg_shops_npcs` (`id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type`, `store_kind`, `owner_citizenid`, `owner_name`, `balance`, `prop_model`, `upkeep_owed`, `upkeep_next`, `packed_at`, `template_name`) VALUES (31,'General Store','u_f_m_tumgeneralstoreowner_01',-1450.52,-2308.01,43.54,258.5,'thieves_landing1','General Store','both','npc',NULL,NULL,0.00,NULL,0.00,NULL,NULL,'general_store');
/*!40000 ALTER TABLE `rsg_shops_npcs` ENABLE KEYS */;
DROP TABLE IF EXISTS `rsg_shops_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_shops_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `npc_id` int(11) NOT NULL,
  `item_name` varchar(100) NOT NULL,
  `label` varchar(100) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `stock` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_npc_id` (`npc_id`),
  KEY `idx_item_name` (`item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_shops_items` DISABLE KEYS */;
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (18,2,'ammo_box_pistol_express','Ammo Box Pistol (E)',0.38,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (19,2,'ammo_box_pistol_velocity','Ammo Box Pistol (HV)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (20,2,'ammo_box_pistol','Ammo Box Pistol (N)',0.30,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (21,2,'weapon_pistol_m1899','M1899 Pistol',45.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (22,2,'ammo_box_rifle_express','Ammo Box Rifle (E)',0.70,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (23,2,'ammo_box_rifle_velocity','Ammo Box Rifle (HV)',1.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (24,2,'ammo_box_rifle','Ammo Box Rifle (N)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (25,2,'weapon_rifle_boltaction','Boltaction Rifle',10.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (26,2,'weapon_sniperrifle_rollingblock','Rollingblock Sniper Rifle',55.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (27,2,'weapon_rifle_springfield','Springfield Rifle',20.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (28,2,'weapon_rifle_varmint','Varmint Rifle',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (29,2,'ammo_box_varmint','Ammo Box Varmint Rifle (N)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (30,2,'weapon_lasso','Standard Lasso',2.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (31,2,'ammo_arrow','Arrow (N)',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (32,2,'weapon_bow','Standard Bow',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (33,2,'weapon_melee_knife','Hunting Knife',1.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (97,5,'ammo_box_pistol_express','Ammo Box Pistol (E)',0.38,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (98,5,'ammo_box_pistol_velocity','Ammo Box Pistol (HV)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (99,5,'ammo_box_pistol','Ammo Box Pistol (N)',0.30,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (100,5,'weapon_pistol_m1899','M1899 Pistol',45.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (101,5,'ammo_box_rifle_express','Ammo Box Rifle (E)',0.70,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (102,5,'ammo_box_rifle_velocity','Ammo Box Rifle (HV)',1.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (103,5,'ammo_box_rifle','Ammo Box Rifle (N)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (104,5,'weapon_rifle_boltaction','Boltaction Rifle',10.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (105,5,'weapon_sniperrifle_rollingblock','Rollingblock Sniper Rifle',55.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (106,5,'weapon_rifle_springfield','Springfield Rifle',20.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (107,5,'weapon_rifle_varmint','Varmint Rifle',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (108,5,'ammo_box_varmint','Ammo Box Varmint Rifle (N)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (109,5,'weapon_lasso','Standard Lasso',2.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (110,5,'ammo_arrow','Arrow (N)',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (111,5,'weapon_bow','Standard Bow',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (112,5,'weapon_melee_knife','Hunting Knife',1.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (129,6,'ammo_box_pistol_express','Ammo Box Pistol (E)',0.38,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (130,6,'ammo_box_pistol_velocity','Ammo Box Pistol (HV)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (131,6,'ammo_box_pistol','Ammo Box Pistol (N)',0.30,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (132,6,'weapon_pistol_m1899','M1899 Pistol',45.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (133,6,'ammo_box_rifle_express','Ammo Box Rifle (E)',0.70,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (134,6,'ammo_box_rifle_velocity','Ammo Box Rifle (HV)',1.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (135,6,'ammo_box_rifle','Ammo Box Rifle (N)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (136,6,'weapon_rifle_boltaction','Boltaction Rifle',10.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (137,6,'weapon_sniperrifle_rollingblock','Rollingblock Sniper Rifle',55.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (138,6,'weapon_rifle_springfield','Springfield Rifle',20.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (139,6,'weapon_rifle_varmint','Varmint Rifle',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (140,6,'ammo_box_varmint','Ammo Box Varmint Rifle (N)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (141,6,'weapon_lasso','Standard Lasso',2.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (142,6,'ammo_arrow','Arrow (N)',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (143,6,'weapon_bow','Standard Bow',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (144,6,'weapon_melee_knife','Hunting Knife',1.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (161,7,'ammo_box_pistol_express','Ammo Box Pistol (E)',0.38,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (162,7,'ammo_box_pistol_velocity','Ammo Box Pistol (HV)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (163,7,'ammo_box_pistol','Ammo Box Pistol (N)',0.30,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (164,7,'weapon_pistol_m1899','M1899 Pistol',45.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (165,7,'ammo_box_rifle_express','Ammo Box Rifle (E)',0.70,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (166,7,'ammo_box_rifle_velocity','Ammo Box Rifle (HV)',1.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (167,7,'ammo_box_rifle','Ammo Box Rifle (N)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (168,7,'weapon_rifle_boltaction','Boltaction Rifle',10.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (169,7,'weapon_sniperrifle_rollingblock','Rollingblock Sniper Rifle',55.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (170,7,'weapon_rifle_springfield','Springfield Rifle',20.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (171,7,'weapon_rifle_varmint','Varmint Rifle',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (172,7,'ammo_box_varmint','Ammo Box Varmint Rifle (N)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (173,7,'weapon_lasso','Standard Lasso',2.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (174,7,'ammo_arrow','Arrow (N)',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (175,7,'weapon_bow','Standard Bow',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (176,7,'weapon_melee_knife','Hunting Knife',1.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (232,9,'ammo_box_pistol_express','Ammo Box Pistol (E)',0.38,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (233,9,'ammo_box_pistol_velocity','Ammo Box Pistol (HV)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (234,9,'ammo_box_pistol','Ammo Box Pistol (N)',0.30,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (235,9,'weapon_pistol_m1899','M1899 Pistol',45.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (236,9,'ammo_box_rifle_express','Ammo Box Rifle (E)',0.70,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (237,9,'ammo_box_rifle_velocity','Ammo Box Rifle (HV)',1.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (238,9,'ammo_box_rifle','Ammo Box Rifle (N)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (239,9,'weapon_rifle_boltaction','Boltaction Rifle',10.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (240,9,'weapon_sniperrifle_rollingblock','Rollingblock Sniper Rifle',55.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (241,9,'weapon_rifle_springfield','Springfield Rifle',20.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (242,9,'weapon_rifle_varmint','Varmint Rifle',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (243,9,'ammo_box_varmint','Ammo Box Varmint Rifle (N)',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (244,9,'weapon_lasso','Standard Lasso',2.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (245,9,'ammo_arrow','Arrow (N)',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (246,9,'weapon_bow','Standard Bow',5.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (247,9,'weapon_melee_knife','Hunting Knife',1.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (354,12,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (355,12,'water','Water',0.05,10);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (356,12,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (357,12,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (358,12,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (359,12,'canteen','Canteen',0.35,8);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (360,12,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (361,12,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (362,12,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (363,12,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (364,12,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (365,12,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (366,12,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (367,11,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (368,11,'water','Water',0.05,10);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (369,11,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (370,11,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (371,11,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (372,11,'canteen','Canteen',0.35,8);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (373,11,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (374,11,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (375,11,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (376,11,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (377,11,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (378,11,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (379,11,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (380,10,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (381,10,'water','Water',0.05,10);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (382,10,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (383,10,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (384,10,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (385,10,'canteen','Canteen',0.35,8);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (386,10,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (387,10,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (388,10,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (389,10,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (390,10,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (391,10,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (392,10,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (395,8,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (396,8,'water','Water',0.05,10);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (397,8,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (398,8,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (399,8,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (400,8,'canteen','Canteen',0.35,8);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (401,8,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (402,8,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (403,8,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (404,8,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (405,8,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (406,8,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (407,8,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (421,13,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (422,13,'water','Water',0.05,10);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (423,13,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (424,13,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (425,13,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (426,13,'canteen','Canteen',0.35,8);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (427,13,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (428,13,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (429,13,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (430,13,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (431,13,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (432,13,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (433,13,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (449,14,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (450,14,'water','Water',0.05,10);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (451,14,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (452,14,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (453,14,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (454,14,'canteen','Canteen',0.35,8);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (455,14,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (456,14,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (457,14,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (458,14,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (459,14,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (460,14,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (461,14,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (464,4,'weapon_fishingrod','Fishing Rod',0.50,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (465,4,'p_baitbread01x','Bread Bait',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (466,4,'p_baitcheese01x','Cheese Bait',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (467,4,'p_baitcorn01x','Corn Bait',0.07,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (468,4,'p_baitworm01x','Worm Bait',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (469,4,'p_baitcricket01x','Cricket Bait',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (470,4,'p_crawdad01x','Crawfish Bait',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (471,3,'weapon_fishingrod','Fishing Rod',0.50,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (472,3,'p_baitbread01x','Bread Bait',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (473,3,'p_baitcheese01x','Cheese Bait',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (474,3,'p_baitcorn01x','Corn Bait',0.07,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (475,3,'p_baitworm01x','Worm Bait',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (476,3,'p_baitcricket01x','Cricket Bait',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (477,3,'p_crawdad01x','Crawfish Bait',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (478,1,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (479,1,'water','Water',0.05,7);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (480,1,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (481,1,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (482,1,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (483,1,'canteen','Canteen',0.35,7);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (484,1,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (485,1,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (486,1,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (487,1,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (488,1,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (489,1,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (490,1,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (491,1,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (526,15,'seedapple','Apple Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (529,15,'seedcorn','Corn Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (535,15,'seedpotato','Potato Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (537,15,'seedtomato','Tomato Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (538,15,'seedwheat','Wheat Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (539,15,'seedcarrot','Carrot Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (541,15,'bucket','Bucket',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (542,15,'shovel','Shovel',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (543,16,'apple','Apple',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (546,16,'corn','Corn',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (548,16,'lemon','Lemon',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (551,16,'peach','Peach',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (552,16,'potato','Potato',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (554,16,'tomato','Tomato',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (555,16,'wheat','Wheat',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (556,16,'carrot','Carrot',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (571,17,'apple','Apple',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (574,17,'corn','Corn',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (576,17,'lemon','Lemon',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (579,17,'peach','Peach',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (580,17,'potato','Potato',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (582,17,'tomato','Tomato',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (583,17,'wheat','Wheat',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (584,17,'carrot','Carrot',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (602,18,'seedapple','Apple Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (605,18,'seedcorn','Corn Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (611,18,'seedpotato','Potato Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (613,18,'seedtomato','Tomato Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (614,18,'seedwheat','Wheat Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (615,18,'seedcarrot','Carrot Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (617,18,'bucket','Bucket',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (618,18,'shovel','Shovel',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (650,20,'apple','Apple',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (653,20,'corn','Corn',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (655,20,'lemon','Lemon',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (658,20,'peach','Peach',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (659,20,'potato','Potato',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (661,20,'tomato','Tomato',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (662,20,'wheat','Wheat',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (663,20,'carrot','Carrot',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (681,21,'seedapple','Apple Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (684,21,'seedcorn','Corn Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (686,21,'seedlemon','Lemon Seed',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (689,21,'seedpeach','Peach Seed',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (690,21,'seedpotato','Potato Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (692,21,'seedtomato','Tomato Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (693,21,'seedwheat','Wheat Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (694,21,'seedcarrot','Carrot Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (696,21,'bucket','Bucket',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (697,21,'shovel','Shovel',0.45,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (698,21,'bread','Bread',0.05,20);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (699,21,'canteen','Canteen',0.30,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (700,21,'water','Water',0.05,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (701,21,'weapon_fishingrod','Fishing Rod',0.60,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (702,21,'p_baitworm01x','Worm Bait',0.05,19);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (703,21,'canned_apricots','Canned Apricots',0.08,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (767,22,'weapon_fishingrod','Fishing Rod',0.50,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (768,22,'p_baitbread01x','Bread Bait',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (769,22,'p_baitcheese01x','Cheese Bait',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (770,22,'p_baitcorn01x','Corn Bait',0.07,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (771,22,'p_baitworm01x','Worm Bait',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (772,22,'p_baitcricket01x','Cricket Bait',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (773,22,'p_crawdad01x','Crawfish Bait',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (774,23,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (775,23,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (776,23,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (777,23,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (778,23,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (779,23,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (780,23,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (781,23,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (782,23,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (783,23,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (784,23,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (786,2,'ammo_box_revolver_express','Ammo Box Revolver (E)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (787,2,'ammo_box_revolver','Ammo Box Revolver (N)',0.40,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (788,2,'weapon_revolver_cattleman','Cattleman Revolver',15.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (789,2,'weapon_revolver_schofield','Schofield Revolver',35.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (790,5,'ammo_box_revolver_express','Ammo Box Revolver (E)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (791,5,'ammo_box_revolver','Ammo Box Revolver (N)',0.40,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (792,5,'weapon_revolver_cattleman','Cattleman Revolver',15.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (793,5,'weapon_revolver_schofield','Schofield Revolver',35.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (794,6,'ammo_box_revolver_express','Ammo Box Revolver (E)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (795,6,'ammo_box_revolver','Ammo Box Revolver (N)',0.40,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (796,6,'weapon_revolver_cattleman','Cattleman Revolver',15.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (797,6,'weapon_revolver_schofield','Schofield Revolver',35.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (798,7,'ammo_box_revolver_express','Ammo Box Revolver (E)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (799,7,'ammo_box_revolver','Ammo Box Revolver (N)',0.40,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (800,7,'weapon_revolver_cattleman','Cattleman Revolver',15.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (801,7,'weapon_revolver_schofield','Schofield Revolver',35.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (802,9,'ammo_box_revolver_express','Ammo Box Revolver (E)',0.50,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (803,9,'ammo_box_revolver','Ammo Box Revolver (N)',0.40,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (804,9,'weapon_revolver_cattleman','Cattleman Revolver',15.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (805,9,'weapon_revolver_schofield','Schofield Revolver',35.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (806,2,'weapon_revolver_doubleaction_gambler','Double Action Gambler Revolver',27.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (807,5,'weapon_revolver_doubleaction_gambler','Double Action Gambler Revolver',27.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (808,6,'weapon_revolver_doubleaction_gambler','Double Action Gambler Revolver',27.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (809,7,'weapon_revolver_doubleaction_gambler','Double Action Gambler Revolver',27.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (810,9,'weapon_revolver_doubleaction_gambler','Double Action Gambler Revolver',27.00,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (811,15,'seedraspberry','Red Raspberry',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (812,15,'seedorange','Orange Seed',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (813,15,'seedtobacco','Tobacco Seed',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (814,15,'seedsugarcane','Sugarcane Seed',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (815,15,'seedcotton','Cotton Seed',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (816,15,'seedblackberry','Blackberry Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (817,18,'seedraspberry','Red Raspberry',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (818,18,'seedorange','Orange Seed',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (819,18,'seedtobacco','Tobacco Seed',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (820,18,'seedsugarcane','Sugarcane Seed',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (821,18,'seedcotton','Cotton Seed',0.04,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (822,18,'seedblackberry','Blackberry Seed',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (823,1,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (824,8,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (825,8,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (826,10,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (827,10,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (828,11,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (829,11,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (830,12,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (831,12,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (832,13,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (833,13,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (834,14,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (835,14,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (836,16,'orange','Orange',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (837,16,'blackberry','Blackberry',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (838,16,'raspberry','Raspberry',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (839,17,'orange','Orange',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (840,17,'blackberry','Blackberry',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (841,17,'raspberry','Raspberry',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (842,20,'orange','Orange',0.03,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (843,20,'blackberry','Blackberry',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (844,20,'raspberry','Raspberry',0.02,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (845,25,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (846,25,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (847,25,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (848,25,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (849,25,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (850,25,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (851,25,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (852,25,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (853,25,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (854,25,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (855,25,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (856,26,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (857,26,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (858,26,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (859,26,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (860,26,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (861,26,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (862,26,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (863,26,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (864,26,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (865,26,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (866,26,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (867,27,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (868,27,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (869,27,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (870,27,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (871,27,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (872,27,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (873,27,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (874,27,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (875,27,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (876,27,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (877,27,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (878,28,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (879,28,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (880,28,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (881,28,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (882,28,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (883,28,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (884,28,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (885,28,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (886,28,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (887,28,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (888,28,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (889,29,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (890,29,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (891,29,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (892,29,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (893,29,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (894,29,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (895,29,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (896,29,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (897,29,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (898,29,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (899,29,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (900,30,'bottle_beer','Beer',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (901,30,'glass_whisky','Glass of Whisky',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (902,30,'glass_gin','Glass of Gin',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (903,30,'glass_rum','Glass of Rum',0.15,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (904,30,'glass_wine_red','Glass of Red Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (905,30,'glass_wine_white','Glass Of White Wine',0.20,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (906,30,'coffee','Coffee',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (907,30,'water','Water',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (908,30,'stew','Stew',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (909,30,'bread','Bread Bun',0.05,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (910,30,'cooked_meat','Cooked Meat',0.10,NULL);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (911,31,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (912,31,'water','Water',0.05,7);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (913,31,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (914,31,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (915,31,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (916,31,'canteen','Canteen',0.35,7);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (917,31,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (918,31,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (919,31,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (920,31,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (921,31,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (922,31,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (923,31,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (924,31,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_items` (`id`, `npc_id`, `item_name`, `label`, `price`, `stock`) VALUES (925,31,'weapon_kit_metal_detector','Metal Detector',15.00,4);
/*!40000 ALTER TABLE `rsg_shops_items` ENABLE KEYS */;
DROP TABLE IF EXISTS `rsg_shops_blips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_shops_blips` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `sprite` bigint(20) NOT NULL,
  `color` varchar(64) DEFAULT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `associated_npc_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_assoc_npc` (`associated_npc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_shops_blips` DISABLE KEYS */;
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (1,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',-322.19,797.88,116.88,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (2,'Gunsmith',-145868367,'BLIP_MODIFIER_MP_COLOR_8',-281.21,778.85,118.5,2);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (3,'Fishing Supply',-852241114,'BLIP_MODIFIER_MP_COLOR_7',-756.82,-1360.99,42.72,3);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (4,'Fishing Supply',-852241114,'BLIP_MODIFIER_MP_COLOR_7',2849.25,-1407.84,44.39,4);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (5,'Gunsmith',-145868367,'BLIP_MODIFIER_MP_COLOR_8',2717.35,-1286.83,48.64,5);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (6,'Gunsmith',-145868367,'BLIP_MODIFIER_MP_COLOR_8',1322.48,-1323.14,76.89,6);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (7,'Gunsmith',-145868367,'BLIP_MODIFIER_MP_COLOR_8',-5506.36,-2964.01,-1.64,7);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (9,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',-1791.09,-386.84,159.33,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (11,'Gunsmith',-145868367,'BLIP_MODIFIER_MP_COLOR_8',2948.4,1319.34,43.82,9);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (12,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',3025.678955078125,562.1181640625,43.72246170043945,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (13,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',2824.4521484375,-1319.3670654296875,45.75567626953125,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (14,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',1329.8658447265625,-1294.2677001953125,76.02174377441406,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (15,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',-785.9169311523438,-1322.195556640625,42.884159088134766,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (16,'General Store',819673798,'BLIP_MODIFIER_MP_COLOR_8',-5485.5224609375,-2937.8525390625,-1.3988580703735352,NULL);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (17,'Farmer\'s Supply',552659337,'BLIP_MODIFIER_MP_COLOR_8',-840.06,-1359.98,42.53,15);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (18,'Produce Vendor',-1656531561,'BLIP_MODIFIER_MP_COLOR_4',-733.41,-1257.08,43.78,16);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (19,'Produce Vendor',-1656531561,'BLIP_MODIFIER_MP_COLOR_4',-177.84,647.19,112.59,17);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (20,'Farmer\'s Supply',552659337,'BLIP_MODIFIER_MP_COLOR_8',-239.66,759.96,116.72,18);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (22,'Produce Vendor',-1656531561,'BLIP_MODIFIER_MP_COLOR_4',-1297.81,412.27,94.38,20);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (23,'Farmer\'s Supply',1475879922,'BLIP_MODIFIER_MP_COLOR_8',-1301.46,393.7,94.43,21);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (24,'Fishing Supply',-852241114,'BLIP_MODIFIER_MP_COLOR_7',-1414.48,-2675.88,41.22,22);
INSERT INTO `rsg_shops_blips` (`id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`) VALUES (25,'General Store',1475879922,'BLIP_MODIFIER_MP_COLOR_8',-1446.21,-2308.89,43.51,NULL);
/*!40000 ALTER TABLE `rsg_shops_blips` ENABLE KEYS */;
DROP TABLE IF EXISTS `rsg_shops_presets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_shops_presets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kind` varchar(10) NOT NULL,
  `label` varchar(100) NOT NULL,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_kind_value` (`kind`,`value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_shops_presets` DISABLE KEYS */;
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (1,'model','cfg_model_tumbleweed_store','u_f_m_tumgeneralstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (2,'model','cfg_model_armadillo_store','u_m_m_armgeneralstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (3,'model','cfg_model_saintdenis_store','u_m_m_nbxgeneralstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (4,'model','cfg_model_rhodes_store_1','u_m_m_rhdgenstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (5,'model','cfg_model_rhodes_store_2','u_m_m_rhdgenstoreowner_02');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (6,'model','cfg_model_strawberry_store','u_m_m_strgenstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (7,'model','cfg_model_valentine_store','u_m_m_valgenstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (8,'model','cfg_model_wallace_store','u_m_m_walgeneralstoreowner_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (9,'model','cfg_model_annesburg_gunsmith','u_m_m_asbgunsmith_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (10,'model','cfg_model_saintdenis_gunsmith','u_m_m_nbxgunsmith_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (11,'model','cfg_model_rhodes_gunsmith','u_m_m_rhdgunsmith_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (12,'model','cfg_model_tumbleweed_gunsmith','u_m_m_tumgunsmith_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (13,'model','cfg_model_valentine_gunsmith','u_m_m_valgunsmith_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (14,'model','cfg_model_generic_butcher','s_m_m_unibutchers_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (15,'model','cfg_model_tumbleweed_butcher','u_m_m_tumbutcher_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (16,'model','cfg_model_valentine_butcher','u_m_m_valbutcher_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (17,'model','cfg_model_saintdenis_trapper','u_m_m_sdtrapper_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (18,'model','cfg_model_thieveslanding_bartender','u_f_m_tljbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (19,'model','cfg_model_vanhorn_bartender','u_f_m_vhtbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (20,'model','cfg_model_saintdenis_bartender_1','u_m_m_nbxbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (21,'model','cfg_model_saintdenis_bartender_2','u_m_m_nbxbartender_02');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (22,'model','cfg_model_rhodes_bartender','u_m_m_rhdbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (23,'model','cfg_model_armadillo_bartender','u_m_o_armbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (24,'model','cfg_model_blackwater_bartender','u_m_o_blwbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (25,'model','cfg_model_valentine_bartender','u_m_o_valbartender_01');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (26,'blip','cfg_blip_general_store','1475879922');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (27,'blip','cfg_blip_gunsmith','-145868367');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (28,'blip','cfg_blip_butcher','-1665418949');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (29,'blip','cfg_blip_saloon','1879260108');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (30,'blip','Farm Supply','552659337');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (31,'blip','Fish Supply','-852241114');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (32,'blip','Buyer','-1656531561');
INSERT INTO `rsg_shops_presets` (`id`, `kind`, `label`, `value`) VALUES (33,'meta','Shop templates seeded','templates_seeded');
/*!40000 ALTER TABLE `rsg_shops_presets` ENABLE KEYS */;
DROP TABLE IF EXISTS `rsg_shops_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_shops_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_template_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_shops_templates` DISABLE KEYS */;
INSERT INTO `rsg_shops_templates` (`id`, `name`, `label`) VALUES (1,'general_store','General Store');
INSERT INTO `rsg_shops_templates` (`id`, `name`, `label`) VALUES (2,'gunsmith','Gunsmith');
INSERT INTO `rsg_shops_templates` (`id`, `name`, `label`) VALUES (3,'fishing_supply','Fishing Supply');
INSERT INTO `rsg_shops_templates` (`id`, `name`, `label`) VALUES (4,'farmers_supply','Farmer\'s Supply');
INSERT INTO `rsg_shops_templates` (`id`, `name`, `label`) VALUES (5,'produce_vendor','Produce Vendor');
/*!40000 ALTER TABLE `rsg_shops_templates` ENABLE KEYS */;
DROP TABLE IF EXISTS `rsg_shops_template_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_shops_template_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `template_id` int(11) NOT NULL,
  `item_name` varchar(100) NOT NULL,
  `label` varchar(100) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `stock` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_shops_template_items` DISABLE KEYS */;
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (31,3,'weapon_fishingrod','Fishing Rod',0.50,15);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (32,3,'p_baitbread01x','Bread Bait',0.05,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (33,3,'p_baitcheese01x','Cheese Bait',0.10,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (34,3,'p_baitcorn01x','Corn Bait',0.07,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (35,3,'p_baitworm01x','Worm Bait',0.05,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (36,3,'p_baitcricket01x','Cricket Bait',0.20,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (37,3,'p_crawdad01x','Crawfish Bait',0.50,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (115,2,'ammo_box_pistol_express','Ammo Box Pistol (E)',0.38,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (116,2,'ammo_box_pistol_velocity','Ammo Box Pistol (HV)',0.45,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (117,2,'ammo_box_pistol','Ammo Box Pistol (N)',0.30,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (118,2,'weapon_pistol_m1899','M1899 Pistol',45.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (119,2,'ammo_box_rifle_express','Ammo Box Rifle (E)',0.70,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (120,2,'ammo_box_rifle_velocity','Ammo Box Rifle (HV)',1.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (121,2,'ammo_box_rifle','Ammo Box Rifle (N)',0.50,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (122,2,'weapon_rifle_boltaction','Boltaction Rifle',10.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (123,2,'weapon_sniperrifle_rollingblock','Rollingblock Sniper Rifle',55.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (124,2,'weapon_rifle_springfield','Springfield Rifle',20.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (125,2,'weapon_rifle_varmint','Varmint Rifle',5.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (126,2,'ammo_box_varmint','Ammo Box Varmint Rifle (N)',0.45,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (127,2,'weapon_lasso','Standard Lasso',2.50,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (128,2,'ammo_arrow','Arrow (N)',0.20,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (129,2,'weapon_bow','Standard Bow',5.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (130,2,'weapon_melee_knife','Hunting Knife',1.50,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (131,2,'ammo_box_revolver_express','Ammo Box Revolver (E)',0.50,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (132,2,'ammo_box_revolver','Ammo Box Revolver (N)',0.40,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (133,2,'weapon_revolver_cattleman','Cattleman Revolver',15.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (134,2,'weapon_revolver_schofield','Schofield Revolver',35.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (135,2,'weapon_revolver_doubleaction_gambler','Double Action Gambler Revolver',27.00,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (165,1,'bread','Bread',0.05,15);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (166,1,'water','Water',0.05,7);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (167,1,'axe','Axe',0.75,5);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (168,1,'weapon_kit_binoculars','Binoculars',3.50,3);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (169,1,'bucket','Bucket',0.20,5);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (170,1,'canteen','Canteen',0.35,7);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (171,1,'bandage','Bandage',0.08,25);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (172,1,'canned_apricots','Canned Apricots',0.10,12);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (173,1,'horse_apple','Horse Apple',0.05,15);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (174,1,'horse_brush','Horse Brush',0.50,6);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (175,1,'horse_carrot','Horse Carrot',0.04,15);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (176,1,'horse_reviver','Horse Reviver',1.00,4);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (177,1,'sugarcube','Sugar Cube',0.05,24);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (178,1,'shovel','Shovel',0.55,5);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (179,1,'weapon_kit_metal_detector','Metal Detector',15.00,4);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (215,4,'seedapple','Apple Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (216,4,'seedcorn','Corn Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (217,4,'seedpotato','Potato Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (218,4,'seedtomato','Tomato Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (219,4,'seedwheat','Wheat Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (220,4,'seedcarrot','Carrot Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (221,4,'bucket','Bucket',0.15,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (222,4,'shovel','Shovel',0.45,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (223,4,'seedraspberry','Red Raspberry',0.03,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (224,4,'seedorange','Orange Seed',0.04,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (225,4,'seedtobacco','Tobacco Seed',0.05,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (226,4,'seedsugarcane','Sugarcane Seed',0.05,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (227,4,'seedcotton','Cotton Seed',0.04,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (228,4,'seedblackberry','Blackberry Seed',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (229,5,'apple','Apple',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (230,5,'corn','Corn',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (231,5,'lemon','Lemon',0.04,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (232,5,'peach','Peach',0.03,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (233,5,'potato','Potato',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (234,5,'tomato','Tomato',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (235,5,'wheat','Wheat',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (236,5,'carrot','Carrot',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (237,5,'orange','Orange',0.03,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (238,5,'blackberry','Blackberry',0.02,NULL);
INSERT INTO `rsg_shops_template_items` (`id`, `template_id`, `item_name`, `label`, `price`, `stock`) VALUES (239,5,'raspberry','Raspberry',0.02,NULL);
/*!40000 ALTER TABLE `rsg_shops_template_items` ENABLE KEYS */;
DROP TABLE IF EXISTS `rsg_doorlocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rsg_doorlocks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `doors` longtext NOT NULL,
  `text_coords` longtext NOT NULL,
  `jobs` longtext NOT NULL,
  `distance` float NOT NULL DEFAULT 1.25,
  `locked` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `rsg_doorlocks` DISABLE KEYS */;
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (1,'Imported door 1988748538','[{\"coords\":{\"y\":802.591064453125,\"x\":-276.0126037597656,\"z\":118.41165161132813},\"hash\":1988748538}]','{\"y\":802.591064453125,\"x\":-276.0126037597656,\"z\":119.41165161132813}','[\"vallaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (2,'Imported door 395506985','[{\"coords\":{\"y\":812.0270385742188,\"x\":-275.8447570800781,\"z\":118.41483306884766},\"hash\":395506985}]','{\"y\":812.0270385742188,\"x\":-275.8447570800781,\"z\":119.41483306884766}','[\"vallaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (3,'Imported door 1508776842','[{\"coords\":{\"y\":810.0264892578125,\"x\":-270.76641845703127,\"z\":118.39580535888672},\"hash\":1508776842}]','{\"y\":810.0264892578125,\"x\":-270.76641845703127,\"z\":119.39580535888672}','[\"vallaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (4,'Imported door 535323366','[{\"coords\":{\"y\":809.2740478515625,\"x\":-275.0232849121094,\"z\":118.36856842041016},\"hash\":535323366}]','{\"y\":809.2740478515625,\"x\":-275.0232849121094,\"z\":119.36856842041016}','[\"vallaw\"]',2,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (5,'Imported door 295355979','[{\"coords\":{\"y\":809.966064453125,\"x\":-273.4643249511719,\"z\":118.36823272705078},\"hash\":295355979}]','{\"y\":809.966064453125,\"x\":-273.4643249511719,\"z\":119.36823272705078}','[\"vallaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (6,'Imported door 193903155','[{\"coords\":{\"y\":808.25830078125,\"x\":-272.0520935058594,\"z\":118.36851501464844},\"hash\":193903155}]','{\"y\":808.25830078125,\"x\":-272.0520935058594,\"z\":119.36851501464844}','[\"vallaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (7,'Imported door 349074475','[{\"coords\":{\"y\":-1305.9600830078126,\"x\":1359.710205078125,\"z\":76.76842498779297},\"hash\":349074475}]','{\"y\":-1305.9600830078126,\"x\":1359.710205078125,\"z\":77.76842498779297}','[\"rholaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (8,'Imported door 1614494720','[{\"coords\":{\"y\":-1297.5343017578126,\"x\":1359.097900390625,\"z\":76.78761291503906},\"hash\":1614494720}]','{\"y\":-1297.5343017578126,\"x\":1359.097900390625,\"z\":77.78761291503906}','[\"rholaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (9,'Imported door 1878514758','[{\"coords\":{\"y\":-1302.4530029296876,\"x\":1357.3343505859376,\"z\":76.76018524169922},\"hash\":1878514758}]','{\"y\":-1302.4530029296876,\"x\":1357.3343505859376,\"z\":76.76018524169922}','[\"rholaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (10,'Imported door 3410720590','[{\"coords\":{\"y\":-1268.485107421875,\"x\":-757.0421752929688,\"z\":43.068603515625},\"hash\":3410720590},{\"coords\":{\"y\":-1269.9234619140626,\"x\":-757.0421142578125,\"z\":43.06863021850586},\"hash\":3821185084}]','{\"y\":-1269.3399658203126,\"x\":-757.27001953125,\"z\":44.04000091552734}','[\"blklaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (11,'Imported door 2810801921','[{\"coords\":{\"y\":-1268.7451171875,\"x\":-769.1370849609375,\"z\":43.0400390625},\"hash\":2810801921}]','{\"y\":-1268.7451171875,\"x\":-769.1370849609375,\"z\":44.0400390625}','[\"blklaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (12,'Imported door 2167775834','[{\"coords\":{\"y\":-1262.4608154296876,\"x\":-763.52783203125,\"z\":43.02327346801758},\"hash\":2167775834}]','{\"y\":-1262.4608154296876,\"x\":-763.52783203125,\"z\":44.02327346801758}','[\"blklaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (13,'Imported door 2514996159','[{\"coords\":{\"y\":-1264.7044677734376,\"x\":-765.8607788085938,\"z\":43.02326965332031},\"hash\":2514996159}]','{\"y\":-1264.7044677734376,\"x\":-765.8607788085938,\"z\":44.02326965332031}','[\"blklaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (14,'Imported door 1821044729','[{\"coords\":{\"y\":-350.31280517578127,\"x\":-1806.6751708984376,\"z\":163.64759826660157},\"hash\":1821044729}]','{\"y\":-350.31280517578127,\"x\":-1806.6751708984376,\"z\":164.64759826660157}','[\"strlaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (15,'Imported door 902070893','[{\"coords\":{\"y\":-353.1470947265625,\"x\":-1814.400390625,\"z\":160.44180297851563},\"hash\":902070893}]','{\"y\":-353.1470947265625,\"x\":-1814.400390625,\"z\":161.44180297851563}','[\"strlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (16,'Imported door 1207903970','[{\"coords\":{\"y\":-351.92095947265627,\"x\":-1812.0101318359376,\"z\":160.46839904785157},\"hash\":1207903970}]','{\"y\":-351.92095947265627,\"x\":-1812.0101318359376,\"z\":161.46839904785157}','[\"strlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (17,'Imported door 1514359658','[{\"coords\":{\"y\":-345.08489990234377,\"x\":-1812.669189453125,\"z\":163.64759826660157},\"hash\":1514359658}]','{\"y\":-345.08489990234377,\"x\":-1812.669189453125,\"z\":164.64759826660157}','[\"strlaw\"]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (18,'Imported door 417663242','[{\"coords\":{\"y\":-1309.9276123046876,\"x\":2516.144287109375,\"z\":47.95257186889648},\"hash\":417663242},{\"coords\":{\"y\":-1307.724853515625,\"x\":2516.14453125,\"z\":47.95257186889648},\"hash\":1611175760}]','{\"y\":-1309.9276123046876,\"x\":2516.144287109375,\"z\":48.95257186889648}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (19,'Imported door 3601535313','[{\"coords\":{\"y\":-1312.2154541015626,\"x\":2510.90771484375,\"z\":47.95257186889648},\"hash\":3601535313},{\"coords\":{\"y\":-1310.4840087890626,\"x\":2510.90771484375,\"z\":47.95257186889648},\"hash\":3430284519}]','{\"y\":-1312.2154541015626,\"x\":2510.90771484375,\"z\":48.95257186889648}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (20,'Imported door 3124713594','[{\"coords\":{\"y\":-1307.141357421875,\"x\":2510.90771484375,\"z\":47.95716857910156},\"hash\":3124713594},{\"coords\":{\"y\":-1305.41162109375,\"x\":2510.90771484375,\"z\":47.95716857910156},\"hash\":1879655431}]','{\"y\":-1307.141357421875,\"x\":2510.90771484375,\"z\":48.95716857910156}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (21,'Imported door 1020479727','[{\"coords\":{\"y\":-1317.2796630859376,\"x\":2508.337646484375,\"z\":47.95257186889648},\"hash\":1020479727},{\"coords\":{\"y\":-1317.2796630859376,\"x\":2506.606201171875,\"z\":47.95257186889648},\"hash\":603068205}]','{\"y\":-1317.2796630859376,\"x\":2508.337646484375,\"z\":48.95257186889648}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (22,'Imported door 305296302','[{\"coords\":{\"y\":-1317.28271484375,\"x\":2497.684814453125,\"z\":47.95257186889648},\"hash\":305296302},{\"coords\":{\"y\":-1317.28271484375,\"x\":2495.953369140625,\"z\":47.95257186889648},\"hash\":2503834054}]','{\"y\":-1317.28271484375,\"x\":2497.684814453125,\"z\":48.95257186889648}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (23,'Imported door 1992193795','[{\"coords\":{\"y\":-1311.95654296875,\"x\":2493.37255859375,\"z\":47.95257186889648},\"hash\":1992193795},{\"coords\":{\"y\":-1310.2252197265626,\"x\":2493.37255859375,\"z\":47.95257186889648},\"hash\":1694749582}]','{\"y\":-1311.95654296875,\"x\":2493.37255859375,\"z\":48.95257186889648}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (24,'Imported door 1979938193','[{\"coords\":{\"y\":-1307.41845703125,\"x\":2493.37255859375,\"z\":47.95257186889648},\"hash\":1979938193},{\"coords\":{\"y\":-1305.68701171875,\"x\":2493.37255859375,\"z\":47.95257186889648},\"hash\":1674105116}]','{\"y\":-1307.41845703125,\"x\":2493.37255859375,\"z\":48.95257186889648}','[\"stdenlaw\"]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (25,'Imported door 3365520707','[{\"coords\":{\"y\":-1307.85595703125,\"x\":2498.5,\"z\":47.95327377319336},\"hash\":3365520707}]','{\"y\":-1307.85595703125,\"x\":2498.5,\"z\":48.95327377319336}','[\"stdenlaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (26,'Imported door 1995743734','[{\"coords\":{\"y\":-1309.8763427734376,\"x\":2499.752197265625,\"z\":47.95327377319336},\"hash\":1995743734}]','{\"y\":-1309.8763427734376,\"x\":2499.752197265625,\"z\":48.95327377319336}','[\"stdenlaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (27,'Imported door 1711767580','[{\"coords\":{\"y\":-1307.85595703125,\"x\":2502.4296875,\"z\":47.95327377319336},\"hash\":1711767580}]','{\"y\":-1307.85595703125,\"x\":2502.4296875,\"z\":48.95327377319336}','[\"stdenlaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (28,'Imported door 2515591150','[{\"coords\":{\"y\":-1309.8763427734376,\"x\":2503.638671875,\"z\":47.95327377319336},\"hash\":2515591150}]','{\"y\":-1309.8763427734376,\"x\":2503.638671875,\"z\":48.95327377319336}','[\"stdenlaw\"]',1,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (29,'Imported door 1692000954','[{\"coords\":{\"y\":-700.0700073242188,\"x\":3331.85009765625,\"z\":43.09000015258789},\"hash\":1692000954}]','{\"y\":-700.0700073242188,\"x\":3331.85009765625,\"z\":43.09000015258789}','[]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (30,'Imported door -1819721708','[{\"coords\":{\"y\":-702.02001953125,\"x\":3333.60009765625,\"z\":43.09000015258789},\"hash\":-1819721708}]','{\"y\":-702.02001953125,\"x\":3333.60009765625,\"z\":43.09000015258789}','[]',3,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (31,'Imported door 559643844','[{\"coords\":{\"y\":-648.0,\"x\":3350.699951171875,\"z\":44.4000015258789},\"hash\":559643844}]','{\"y\":-648.0,\"x\":3350.699951171875,\"z\":44.4000015258789}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (32,'Imported door 559643844','[{\"coords\":{\"y\":-645.280029296875,\"x\":3349.9599609375,\"z\":44.40999984741211},\"hash\":559643844}]','{\"y\":-645.280029296875,\"x\":3349.9599609375,\"z\":44.40999984741211}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (33,'Imported door 4249790129','[{\"coords\":{\"y\":-639.477783203125,\"x\":3384.615478515625,\"z\":45.4660758972168},\"hash\":4249790129}]','{\"y\":-639.477783203125,\"x\":3384.615478515625,\"z\":45.4660758972168}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (34,'Imported door 559643844','[{\"coords\":{\"y\":-680.1199951171875,\"x\":3366.449951171875,\"z\":45.4900016784668},\"hash\":559643844}]','{\"y\":-680.1199951171875,\"x\":3366.449951171875,\"z\":45.4900016784668}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (35,'Imported door 559643844','[{\"coords\":{\"y\":-723.5900268554688,\"x\":3369.56005859375,\"z\":44.31000137329101},\"hash\":559643844}]','{\"y\":-723.5900268554688,\"x\":3369.56005859375,\"z\":44.31000137329101}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (36,'Imported door 559643844','[{\"coords\":{\"y\":-677.719970703125,\"x\":3407.31005859375,\"z\":45.5},\"hash\":559643844}]','{\"y\":-677.719970703125,\"x\":3407.31005859375,\"z\":45.5}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (37,'Imported door -1694920053','[{\"coords\":{\"y\":-658.0032348632813,\"x\":3318.453125,\"z\":44.8508186340332},\"hash\":-1694920053}]','{\"y\":-658.0032348632813,\"x\":3318.453125,\"z\":44.8508186340332}','[]',1.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (38,'Theatre Main Doors','[{\"coords\":{\"x\":2547.550048828125,\"y\":-1289.8310546875,\"z\":48.21599960327148},\"hash\":544106233},{\"coords\":{\"x\":2545.345947265625,\"y\":-1289.8310546875,\"z\":48.21599960327148},\"hash\":340151973}]','{\"x\":2546.447998046875,\"y\":-1289.8310546875,\"z\":49.21599960327148}','[]',1.25,0);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (39,'Theatre Side Door 1','[{\"coords\":{\"x\":2537.594970703125,\"y\":-1294.47802734375,\"z\":48.21599960327148},\"hash\":534819197},{\"coords\":{\"x\":2537.594970703125,\"y\":-1295.8360595703126,\"z\":48.21599960327148},\"hash\":836064614}]','{\"x\":2537.594970703125,\"y\":-1295.156982421875,\"z\":49.21599960327148}','[]',1.25,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (40,'Theatre Side Door 2','[{\"coords\":{\"x\":2537.594970703125,\"y\":-1299.5899658203126,\"z\":48.21599960327148},\"hash\":1449678065},{\"coords\":{\"x\":2537.594970703125,\"y\":-1298.2330322265626,\"z\":48.21599960327148},\"hash\":2053545201}]','{\"x\":2537.594970703125,\"y\":-1298.9114990234376,\"z\":49.21599960327148}','[]',1.25,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (41,'Theatre Side Door 3','[{\"coords\":{\"x\":2537.594970703125,\"y\":-1303.3360595703126,\"z\":48.21599960327148},\"hash\":627391959},{\"coords\":{\"x\":2537.594970703125,\"y\":-1301.97802734375,\"z\":48.21599960327148},\"hash\":3468071035}]','{\"x\":2537.594970703125,\"y\":-1302.656982421875,\"z\":49.21599960327148}','[]',1.25,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (42,'rhodeshotel','[{\"hash\":2812328251,\"coords\":{\"z\":79.48400115966797,\"y\":-1376.865966796875,\"x\":1335.10498046875}}]','{\"z\":80.48400115966797,\"y\":-1376.865966796875,\"x\":1335.10498046875}','[]',0.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (43,'Blackwater Room','[{\"hash\":254520182,\"coords\":{\"z\":46.89699935913086,\"y\":-1323.594970703125,\"x\":-818.6270141601563}}]','{\"z\":47.89699935913086,\"y\":-1323.594970703125,\"x\":-818.6270141601563}','[]',0.5,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (44,'Tumbleweed Card Room','[{\"coords\":{\"z\":0.65100002288818,\"y\":-2917.08203125,\"x\":-5515.39013671875},\"hash\":4292889829},{\"coords\":{\"z\":0.65100002288818,\"y\":-2917.654052734375,\"x\":-5513.26708984375},\"hash\":223504277},{\"coords\":{\"z\":0.67900002002716,\"y\":-2913.166015625,\"x\":-5514.9912109375},\"hash\":1322586500}]','{\"z\":1.66033339500427,\"y\":-2915.967529296875,\"x\":-5514.54931640625}','[]',1,0);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (45,'St. Denise Cardroom','[{\"hash\":1180868565,\"coords\":{\"y\":-1293.083984375,\"x\":2711.43701171875,\"z\":59.45800018310547}}]','{\"y\":-1293.083984375,\"x\":2711.43701171875,\"z\":60.45800018310547}','[]',1.25,0);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (46,'Annsberg Room Rent','[{\"heading\":251.1480407714844,\"hash\":1776010093,\"coords\":{\"y\":1349.845458984375,\"x\":2964.015625,\"z\":47.03580093383789},\"object\":-1858047034}]','{\"y\":1349.845458984375,\"x\":2964.015625,\"z\":48.03580093383789}','[]',1.25,1);
INSERT INTO `rsg_doorlocks` (`id`, `name`, `doors`, `text_coords`, `jobs`, `distance`, `locked`) VALUES (47,'Annesburg2','[{\"heading\":251.15597534179688,\"hash\":2070563237,\"coords\":{\"y\":1347.6143798828126,\"x\":2963.169677734375,\"z\":47.03580093383789},\"object\":-1858047034}]','{\"y\":1347.6143798828126,\"x\":2963.169677734375,\"z\":48.03580093383789}','[]',1.25,1);
/*!40000 ALTER TABLE `rsg_doorlocks` ENABLE KEYS */;
DROP TABLE IF EXISTS `grumpy_bartenders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grumpy_bartenders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `label` varchar(50) NOT NULL,
  `model` varchar(64) NOT NULL,
  `animation` varchar(50) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `h` double NOT NULL DEFAULT 0,
  `services` longtext NOT NULL,
  `created_by` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `grumpy_bartenders` DISABLE KEYS */;
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (1,'Bartender','u_m_m_valbartender_01','bar_front',-313.2532958984375,805.6315307617188,119.030517578125,279.81505584716797,'{\"store\":23,\"hotel\":false,\"lottery\":true,\"blip\":true,\"autoStore\":true,\"loyalty\":true}','AXO47166','2026-11-05 23:01:15');
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (2,'Bartender','u_m_m_valbartender_01','bar_front',1340.35107421875,-1374.8748779296875,80.48064422607422,261.5719791650772,'{\"store\":25,\"hotel\":1,\"blip\":true,\"lottery\":true,\"autoStore\":true,\"loyalty\":true}','LCE05773','2026-11-06 22:19:50');
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (3,'Bartender','u_m_m_valbartender_01','bar_front',-817.4073486328125,-1318.953125,43.678932189941406,267.7194366455078,'{\"store\":26,\"hotel\":2,\"blip\":true,\"lottery\":true,\"autoStore\":true,\"loyalty\":true}','LCE05773','2026-11-06 22:45:04');
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (4,'Bartender','u_m_m_valbartender_01','bar_front',-5517.93603515625,-2906.4296875,-1.7513055801391602,209.3679479956627,'{\"store\":27,\"hotel\":false,\"blip\":true,\"lottery\":true,\"autoStore\":true,\"loyalty\":true}','LCE05773','2026-11-06 23:03:22');
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (5,'Bartender','u_m_m_valbartender_01','bar_front',2639.755126953125,-1224.8475341796875,53.38039016723633,88.51760864257812,'{\"hotel\":false,\"loyalty\":true,\"lottery\":true,\"store\":28,\"autoStore\":true,\"blip\":true}','LCE05773','2026-11-07 00:23:51');
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (6,'Bartender','u_m_m_valbartender_01','bar_front',2957.008544921875,1349.387939453125,44.838802337646484,98.12490844726562,'{\"hotel\":3,\"loyalty\":true,\"lottery\":true,\"store\":29,\"autoStore\":true,\"blip\":true}','LCE05773','2026-11-07 00:40:56');
INSERT INTO `grumpy_bartenders` (`id`, `label`, `model`, `animation`, `x`, `y`, `z`, `h`, `services`, `created_by`, `created_at`) VALUES (7,'Bartender','u_m_m_valbartender_01','bar_front',-1395.692626953125,-2320.18505859375,43.62717819213867,5.253871917724609,'{\"lottery\":true,\"blip\":true,\"autoStore\":true,\"hotel\":false,\"store\":30,\"loyalty\":true}','LCE05773','2026-11-07 01:18:51');
/*!40000 ALTER TABLE `grumpy_bartenders` ENABLE KEYS */;
DROP TABLE IF EXISTS `grumpy_hotels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grumpy_hotels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `label` varchar(50) NOT NULL,
  `rooms` int(11) NOT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `max_days` int(11) NOT NULL DEFAULT 1,
  `door_x` double NOT NULL,
  `door_y` double NOT NULL,
  `door_z` double NOT NULL,
  `door_h` double NOT NULL DEFAULT 0,
  `int_x` double NOT NULL,
  `int_y` double NOT NULL,
  `int_z` double NOT NULL,
  `int_h` double NOT NULL DEFAULT 0,
  `stash_x` double DEFAULT NULL,
  `stash_y` double DEFAULT NULL,
  `stash_z` double DEFAULT NULL,
  `stash_h` double DEFAULT NULL,
  `blip` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `grumpy_hotels` DISABLE KEYS */;
INSERT INTO `grumpy_hotels` (`id`, `label`, `rooms`, `price`, `max_days`, `door_x`, `door_y`, `door_z`, `door_h`, `int_x`, `int_y`, `int_z`, `int_h`, `stash_x`, `stash_y`, `stash_z`, `stash_h`, `blip`, `created_by`, `created_at`) VALUES (1,'Rhodes Rooms for Rent',4,2.00,7,1334.67236328125,-1377.2860107421875,80.49856567382812,35.240142822265625,1334.3792724609375,-1376.81591796875,80.48347473144531,38.5731201171875,1332.47119140625,-1375.3890380859375,80.50474548339844,79.19798278808594,0,'LCE05773','2026-11-06 22:23:06');
INSERT INTO `grumpy_hotels` (`id`, `label`, `rooms`, `price`, `max_days`, `door_x`, `door_y`, `door_z`, `door_h`, `int_x`, `int_y`, `int_z`, `int_h`, `stash_x`, `stash_y`, `stash_z`, `stash_h`, `blip`, `created_by`, `created_at`) VALUES (2,'Blackwater Rooms for Rent',4,2.00,7,-818.0687866210938,-1324.1988525390625,47.87800979614258,269.8273010253906,-818.9906005859375,-1324.2005615234375,47.87825393676758,90.1146240234375,-820.2337646484375,-1322.8094482421875,47.88105010986328,0.1146240234375,0,'LCE05773','2026-11-06 22:43:20');
INSERT INTO `grumpy_hotels` (`id`, `label`, `rooms`, `price`, `max_days`, `door_x`, `door_y`, `door_z`, `door_h`, `int_x`, `int_y`, `int_z`, `int_h`, `stash_x`, `stash_y`, `stash_z`, `stash_h`, `blip`, `created_by`, `created_at`) VALUES (3,'Annesburg Rooms',4,2.00,7,2963.49560546875,1349.448486328125,47.97314453125,69.23480224609375,2964.198486328125,1349.2991943359375,47.97314453125,256.73480224609375,2965.04736328125,1350.8934326171875,48.23999786376953,249.23480224609375,0,'LCE05773','2026-11-07 00:36:12');
/*!40000 ALTER TABLE `grumpy_hotels` ENABLE KEYS */;
DROP TABLE IF EXISTS `grumpy_backroom_rooms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grumpy_backroom_rooms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(48) NOT NULL,
  `npc_model` varchar(64) NOT NULL,
  `npc` longtext DEFAULT NULL,
  `doors` longtext NOT NULL,
  `zone` longtext DEFAULT NULL,
  `exit_point` longtext DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 0,
  `open_until` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `grumpy_backroom_rooms` DISABLE KEYS */;
INSERT INTO `grumpy_backroom_rooms` (`id`, `name`, `npc_model`, `npc`, `doors`, `zone`, `exit_point`, `enabled`, `open_until`) VALUES (1,'Tumbleweed Saloon','u_m_m_gamdoorman_01','{\"z\":1.66966891288757,\"y\":-2911.688232421875,\"x\":-5513.59228515625,\"w\":28.41154479980468}','[44]','{\"points\":[{\"x\":-5516.04931640625,\"y\":-2916.427490234375},{\"x\":-5512.55908203125,\"y\":-2917.09912109375},{\"x\":-5507.216796875,\"y\":-2913.492919921875},{\"x\":-5509.345703125,\"y\":-2909.1552734375},{\"x\":-5516.64501953125,\"y\":-2914.913330078125}],\"maxZ\":2.48409287929534,\"minZ\":0.48409287929534}','{\"z\":1.68624436855316,\"y\":-2919.459716796875,\"x\":-5514.79931640625,\"w\":308.700439453125}',1,0);
INSERT INTO `grumpy_backroom_rooms` (`id`, `name`, `npc_model`, `npc`, `doors`, `zone`, `exit_point`, `enabled`, `open_until`) VALUES (2,'St Denise Card Room','u_m_m_gamdoorman_01','{\"y\":-1295.1998291015626,\"z\":60.33775329589844,\"w\":25.45526885986328,\"x\":2711.009033203125}','[45]','{\"minZ\":59.18776397705078,\"points\":[{\"y\":-1294.898681640625,\"x\":2711.764892578125},{\"y\":-1289.0966796875,\"x\":2710.82763671875},{\"y\":-1289.418701171875,\"x\":2722.975341796875},{\"y\":-1282.304931640625,\"x\":2719.821044921875},{\"y\":-1284.2298583984376,\"x\":2714.263671875}],\"maxZ\":63.18776397705078}','{\"y\":-1289.176025390625,\"z\":60.38774108886719,\"w\":32.65586471557617,\"x\":2708.369873046875}',1,0);
/*!40000 ALTER TABLE `grumpy_backroom_rooms` ENABLE KEYS */;
DROP TABLE IF EXISTS `grumpy_robbery_stores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grumpy_robbery_stores` (
  `npc_id` int(11) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `shelves` longtext DEFAULT NULL,
  `safe` longtext DEFAULT NULL,
  PRIMARY KEY (`npc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `grumpy_robbery_stores` DISABLE KEYS */;
INSERT INTO `grumpy_robbery_stores` (`npc_id`, `enabled`, `shelves`, `safe`) VALUES (1,1,'[{\"z\":117.75167083740235,\"y\":801.2946166992188,\"x\":-319.8691101074219},{\"z\":117.68206024169922,\"y\":799.796630859375,\"x\":-319.5680236816406},{\"z\":117.77994537353516,\"y\":799.7776489257813,\"x\":-322.1563415527344},{\"z\":117.60490417480469,\"y\":797.0531005859375,\"x\":-322.29071044921877}]',NULL);
/*!40000 ALTER TABLE `grumpy_robbery_stores` ENABLE KEYS */;
DROP TABLE IF EXISTS `grumpy_trader_npcs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grumpy_trader_npcs` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `grumpy_trader_npcs` DISABLE KEYS */;
INSERT INTO `grumpy_trader_npcs` (`traderid`, `tradername`, `npcmodel`, `x`, `y`, `z`, `heading`, `showblip`, `kind`, `launder`, `launder_cut`, `template`) VALUES ('valfence2','ValFence2','rces_beechers1_males_01',-315.758,819.1,121.854,14.5296,0,'illegal',1,30.00,NULL);
/*!40000 ALTER TABLE `grumpy_trader_npcs` ENABLE KEYS */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

