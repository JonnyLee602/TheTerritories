-- The Territories: doctrine prices for RSG values that live in the database (doctrine/pricing.md).
-- The recipe runs this after rsgcore.sql. On an existing server, run it once by hand (safe to re-run).

-- rsg-housing: rent is $40 a month (only empty houses; a tenant keeps the rent they agreed to)
UPDATE `rsg_housing` SET `rent` = 40 WHERE `rented` = 0;

-- rsg-boats: rowboat $15 (Config.DefaultBoats only seeds a fresh table)
UPDATE `rsg_boats_models` SET `price` = 15 WHERE `model` = 'rowboat';

-- rsg-lottery: $1 tickets, $25 base jackpot. Resets a jackpot still sitting on the old $100 base.
UPDATE `rsg_lottery_config` SET `value` = '25'
 WHERE `setting` = 'current_jackpot' AND CAST(`value` AS DECIMAL(12,2)) >= 100;
