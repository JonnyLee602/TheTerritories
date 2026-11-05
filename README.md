# The Territories: server copy

The latest RSG framework plus every Territories customization, kept in git so RSG updates can be pulled in
without losing our changes.

```
resources/[framework]/   68 rsg-* resources: RSG's latest code + our edits
resources/[grumpy]/      our own scripts (copied from rsg-redm-brain/builds)
tools/rsg-update.sh      pulls RSG updates and merges them in
upstream.lock            which RSG commit each resource is on
```

## How updates work

There are two branches:

| Branch | Holds |
|---|---|
| `upstream` | RSG's code, exactly as Rexshack released it. Never edit it by hand. |
| `main` | `upstream` + our customizations. This is what the server runs. |

`tools/rsg-update.sh` refreshes `upstream` from GitHub, then merges it into `main`. Git compares both sides
against the version they share. Lines only RSG changed come from RSG; lines only we changed stay ours.
Lines both sides changed are reported as **conflicts** and get resolved by hand.

Run it from Git Bash (or ask Claude to "update the server"):

```bash
bash tools/rsg-update.sh            # every resource
bash tools/rsg-update.sh rsg-core   # just one
```

The commit message on `upstream` lists what RSG changed in each resource. To undo an update that broke something:
`git reset --hard HEAD~1` on `main` (ask Claude first if unsure).

## Our customizations to RSG resources

| Resource | Change | Why |
|---|---|---|
| rsg-core | `shared/items.lua`: `cooked_poultry`, `cooked_game_meat`, `hardtack`, `blank_paper`, `custom_note` | Custom items |
| rsg-inventory | ~56 custom images in `html/images` (seeds, meats, custom items, `legendary_pelt.png`) | Item icons |
| rsg-doorlock | `shared/doorhashes_custom.lua`: 2 custom doors | New doors |
| rsg-lottery | Ticket-seller NPCs commented out, blip off; `OpenLottery` export | grumpy-bartender sells tickets |
| rsg-loyalty | Loyalty NPCs commented out; `SetRedeemPoint` / `RemoveRedeemPoint` exports | grumpy-bartender serves loyalty |
| rsg-stores | Access points, `OpenShop`, `CreateShop` / `ShopExists` / `DeleteShop`, `'none'` model | grumpy-bartender shops |

Every edit made for a grumpy script is marked `[grumpy-bartender hook]` in the code. The full patch
instructions live in each script's `integrations/` folder.

**Not applied yet:** the hooks for grumpy-pob (rsg-consume, rsg-core, rsg-inventory, rsg-stables, rsg-stores part 3)
and grumpy-reputation (rsg-stores honor/infamy prices). Until they are applied, those parts of grumpy-pob and
grumpy-reputation will not work.

## Adding a new customization

Edit the file on `main`, then commit it. That's all: the next update keeps it automatically.

## Not in this copy

rsg-target, rsg-gizmo and other non-framework resources the grumpy scripts use live elsewhere on the server,
along with server.cfg and the database.
