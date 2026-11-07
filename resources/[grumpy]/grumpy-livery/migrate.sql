-- grumpy-livery: copy horses, breeding, race times and wagons from rsg-stables / rsg-wagons.
-- You normally don't need this: on start, grumpy-livery copies them itself (server/migrate.lua) when its own
-- tables are empty. Use this file only if you want to do it by hand. Run it ONCE, after install.sql, while
-- the grumpy-livery tables are still empty. The old tables are left untouched.
-- Row ids are kept, so saddlebag stashes (horse_<id>) and wagon stashes (wagon_<id>) still match.
-- Written for rsg-stables 3.4.0 and rsg-wagons 3.0.0 (same columns as grumpy-livery 1.0.0).

INSERT INTO `grumpy_livery_horses`
  (`id`, `citizenid`, `stable`, `model`, `breed_label`, `gender`, `breed_cooldown`, `died_of_age`, `name`, `outfit`,
   `tack`, `shoe_wear`, `coat`, `health`, `stamina`, `hunger`, `thirst`, `bonding`, `training`, `speed`, `accel`,
   `handling`, `maxhealth`, `alive`, `insured`, `active`, `pos_x`, `pos_y`, `pos_z`, `pos_h`, `created_at`)
SELECT
   `id`, `citizenid`, `stable`, `model`, `breed_label`, `gender`, `breed_cooldown`, `died_of_age`, `name`, `outfit`,
   `tack`, `shoe_wear`, `coat`, `health`, `stamina`, `hunger`, `thirst`, `bonding`, `training`, `speed`, `accel`,
   `handling`, `maxhealth`, `alive`, `insured`, `active`, `pos_x`, `pos_y`, `pos_z`, `pos_h`, `created_at`
FROM `rsg_stables_horses`;

INSERT INTO `grumpy_livery_breeding`
  (`id`, `citizenid`, `stable`, `parent_a`, `parent_b`, `ready_at`, `collected`, `created_at`)
SELECT `id`, `citizenid`, `stable`, `parent_a`, `parent_b`, `ready_at`, `collected`, `created_at`
FROM `rsg_stables_breeding`;

INSERT INTO `grumpy_livery_races` (`citizenid`, `race`, `rider`, `horse`, `best_ms`, `updated_at`)
SELECT `citizenid`, `race`, `rider`, `horse`, `best_ms`, `updated_at`
FROM `rsg_stables_races`;

INSERT INTO `grumpy_livery_wagons`
  (`id`, `citizenid`, `model`, `name`, `wagon_condition`, `store`, `active`, `livery`, `tint`, `propset`, `lantern`,
   `cargo`, `created_at`)
SELECT `id`, `citizenid`, `model`, `name`, `wagon_condition`, `store`, `active`, `livery`, `tint`, `propset`, `lantern`,
   `cargo`, `created_at`
FROM `player_wagons`;
