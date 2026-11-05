#!/usr/bin/env bash
# Pull the latest RSG releases and merge them into the Territories server copy,
# keeping every customization made on the main branch.
#
#   bash tools/rsg-update.sh            # update every resource listed in upstream.lock
#   bash tools/rsg-update.sh rsg-core   # update only the named resources
#
# How it works:
#   branch "upstream" = pristine RSG code, exactly as Rexshack released it
#   branch "main"     = upstream + our customizations (items, configs, doors, images...)
#   1. refresh a full clone of each RSG repo in .cache/
#   2. on "upstream", replace each changed resource with RSG's latest version and commit
#   3. merge "upstream" into "main": git keeps our edits and takes RSG's
#   4. anything both sides changed is reported as a conflict to resolve by hand
set -euo pipefail
SV="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$SV/.cache/upstream"
FW="resources/[framework]"
cd "$SV"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree has uncommitted changes. Commit them first."; exit 1
fi
if [ "$(git branch --show-current)" != "main" ]; then
  echo "Run this from the main branch."; exit 1
fi

if [ $# -gt 0 ]; then names="$*"; else names=$(git show upstream:upstream.lock | awk '{print $1}'); fi

# 1. refresh clones
mkdir -p "$CACHE"
printf '%s\n' $names | xargs -P 8 -I{} sh -c '
  d="'"$CACHE"'/{}"
  if [ -d "$d/.git" ]; then git -C "$d" fetch -q origin && git -C "$d" reset -q --hard origin/HEAD
  else git clone -q https://github.com/Rexshack-RedM/{}.git "$d"; fi || echo "!! could not fetch {}"'

# 2. rebuild changed resources on the upstream branch
git checkout -q upstream
report=""
for n in $names; do
  d="$CACHE/$n"; [ -d "$d/.git" ] || continue
  old=$(awk -v n="$n" '$1==n{print $2}' upstream.lock)
  new=$(git -C "$d" rev-parse HEAD)
  [ "$old" = "$new" ] && continue
  if [ "$n" = "txAdminRecipe" ]; then
    # RSG's own recipe: we only use its database file and logo (recipe/rsg/), our recipe does the rest
    rm -rf recipe/rsg; mkdir -p recipe/rsg
    git -c core.autocrlf=false -C "$d" archive HEAD rsgcore.sql myLogo.png | tar -x -C recipe/rsg
  else
    rm -rf "$FW/$n"; mkdir -p "$FW/$n"
    git -c core.autocrlf=false -C "$d" archive HEAD | tar -x -C "$FW/$n"
  fi
  if [ -n "$old" ]; then
    sed -i "s/^$n .*/$n $new/" upstream.lock
    log=$(git -C "$d" log --format='    - %s' "$old..$new" 2>/dev/null | head -15)
  else
    echo "$n $new" >> upstream.lock; log="    - newly added"
  fi
  report="$report
$n ($(git -C "$d" rev-list --count "${old:-$new}..$new" 2>/dev/null || echo new) commits):
$log"
done

if [ -z "$report" ]; then
  git checkout -q main; echo "Everything is already up to date."; exit 0
fi
git add -A "$FW" upstream.lock
[ -d recipe/rsg ] && git add -A recipe/rsg
git commit -q -m "RSG update $(date +%Y-%m-%d)" -m "$report"
git checkout -q main

# 3. merge into main
echo "Updated from RSG:$report"
echo
if git merge --no-edit -q upstream; then
  echo "Merged cleanly. Your customizations are kept."
else
  echo "CONFLICTS (RSG and Territories both changed these lines):"
  git diff --name-only --diff-filter=U | sed 's/^/  /'
  echo "Resolve them, then: git add -A && git commit"
  exit 2
fi
