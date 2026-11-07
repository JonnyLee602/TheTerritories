#!/usr/bin/env bash
# Export the hand-placed world setup from the DEV database into recipe/territories_base.sql,
# so a fresh recipe install (prod) starts with the same shops, templates, doors, bartenders,
# hotels and back rooms. Gambling tables are NOT here: grumpy-gambling seeds its own defaults
# (server/defaults.lua, written by tools/export-gambling-defaults.py).
#
# Usage:  bash tools/export-base-data.sh
# Needs a read-only MySQL login in an option file ([client] user/password/host, [mysql] database).
#   CNF=/path/to/file.cnf DB=dbname MYSQLDUMP=/path/to/mysqldump bash tools/export-base-data.sh
# After running: commit, then python tools/build-recipe.py, commit the recipe, push.
set -euo pipefail
cd "$(dirname "$0")/.."

CNF="${CNF:-/c/Users/cntry/.territories-db/claude_ro.cnf}"
DB="${DB:-theterritories_ecdd83}"
MYSQLDUMP="${MYSQLDUMP:-/c/xampp/mysql/bin/mysqldump.exe}"
OUT=recipe/territories_base.sql

# Setup tables only: no players, ledgers, rentals, balances or history.
# IDs are kept: bartenders point at store + hotel IDs, back rooms at door IDs, robbery at store IDs.
TABLES=(
  rsg_shops_npcs rsg_shops_items rsg_shops_blips rsg_shops_presets
  rsg_shops_templates rsg_shops_template_items
  rsg_doorlocks
  grumpy_bartenders grumpy_hotels grumpy_backroom_rooms grumpy_robbery_stores grumpy_trader_npcs
)

{
  cat <<EOF
-- The Territories: base world setup, exported from the dev database by tools/export-base-data.sh
-- on $(date +%Y-%m-%d). GENERATED: re-run the tool instead of editing this file.
--
-- Each table is DROPPED and recreated with the dev schema, then filled. The recipe runs this file
-- LAST, after rsgcore.sql and every grumpy install.sql, on a fresh database. Never run it on a live
-- database that has data you want to keep in these tables.
--
-- rsg_shops_presets includes the 'templates_seeded' marker, so rsg-stores does not add its
-- Config.ShopTemplates on top of the templates below. rsg_doorlocks being filled means rsg-doorlock
-- skips its seed_doors.lua import.
-- Tables: ${TABLES[*]}

EOF
  "$MYSQLDUMP" --defaults-extra-file="$CNF" --default-character-set=utf8mb4 \
    --no-tablespaces --single-transaction --skip-lock-tables --skip-add-locks --skip-triggers \
    --skip-comments --skip-extended-insert --complete-insert --skip-dump-date \
    "$DB" "${TABLES[@]}"
} | tr -d '\r' | sed -E 's/ AUTO_INCREMENT=[0-9]+//' > "$OUT.tmp"

mv "$OUT.tmp" "$OUT"
echo "$OUT: $(grep -c '^INSERT INTO' "$OUT") rows from ${#TABLES[@]} tables"
for t in "${TABLES[@]}"; do printf '  %-28s %s\n' "$t" "$(grep -c "^INSERT INTO \`$t\`" "$OUT")"; done
