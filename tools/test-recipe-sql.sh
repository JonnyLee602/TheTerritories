#!/usr/bin/env bash
# Run the recipe's database steps against a throwaway database on a local MariaDB/MySQL, then drop it.
#   bash tools/test-recipe-sql.sh            (user root, prompts for the password)
#   MYSQL=/path/to/mysql DBUSER=me bash tools/test-recipe-sql.sh
set -uo pipefail
cd "$(dirname "$0")/.."
MYSQL="${MYSQL:-/c/xampp/mysql/bin/mysql.exe}"
DBUSER="${DBUSER:-root}"
DB="zz_territories_recipe_test"
read -rsp "MySQL password for $DBUSER (empty for none): " PW; echo
export MYSQL_PWD="$PW"
run() { "$MYSQL" -u "$DBUSER" "$@"; }

run -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB CHARACTER SET utf8mb4;" || exit 1
ok=1
for f in recipe/rsg/rsgcore.sql recipe/territories_stores.sql recipe/territories_stores.sql resources/\[grumpy\]/*/install.sql; do
  if run "$DB" < "$f"; then echo "OK    $f"; else echo "FAIL  $f"; ok=0; fi
done
run "$DB" -e "SELECT (SELECT COUNT(*) FROM rsg_shops_npcs) shops, (SELECT COUNT(*) FROM rsg_shops_items) items,
  (SELECT COUNT(*) FROM rsg_shops_blips) blips, (SELECT COUNT(*) FROM rsg_shops_presets) presets;"
run -e "DROP DATABASE $DB;"
[ $ok = 1 ] && echo "All database steps passed (stores ran twice to prove re-running is safe)." || exit 1
