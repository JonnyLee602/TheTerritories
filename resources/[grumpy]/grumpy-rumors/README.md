# grumpy-rumors

Informants around the map sell **rumors** as notes that go stale. What you hear depends on your reputation: an outlaw won't get tips from the sheriff's clerk, and a respected citizen gets nothing from the drifter behind the saloon. Some notes are just talk. Others **start a job** for you and your posse, gang or on-duty colleagues.

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `grumpy-reputation`
**Optional:** `grumpy-groups` (without it, every job is solo)

## Features
- **Informant NPCs** (config: model, coords, scenario, categories, price, cooldown). Target one and choose **Ask about rumors**.
- **Reputation-gated**: each rumor lists the grumpy-reputation tiers allowed to hear it and to act on it. If nothing fits, the informant brushes you off.
- **Rumor notes** (`rumor_note`, unique item):
  - The inventory tooltip shows the rumor name and "Good until".
  - Using the note opens it: the story, a live "goes stale in" timer and, for job rumors, who would come along.
  - Expired notes are removed from pockets every 5 minutes and on login. Notes in stashes go stale when read.
  - Notes can be traded or sold. Whoever **acts** on a note must have the right reputation.
- **Act on it** starts a job. grumpy-rumors only starts jobs and never runs them. The job resource registers a job type and gets `(reader, args, members)`.
  - **Members** come from grumpy-groups: the posse (no distance check), otherwise gang members nearby, otherwise on-duty colleagues nearby. Each rumor can set `group` and `radius`.
  - The note is used up only when the job actually starts. If the job refuses (for example, it's on cooldown), the player keeps the note.
- **Limits**: max notes per player, a per-informant ask cooldown, and a per-rumor cooldown after someone acts on it. Informants skip rumors whose job type isn't loaded or isn't available.
- Built-in job types:
  - **`item`** turns the note into an item another resource runs. The sample **dig-site** rumor gives a `treasure_map`, so **rsg-treasure** runs the hunt (solo, its own random spot). Only whitelisted items can be given.
  - **`mark`** only puts a timed search-area blip on everyone's map. Good for testing and simple tips.
- The item registers itself with rsg-core on start. You only need to add the image.

## Installation
1. Put `grumpy-rumors` in your resources folder and add after rsg-core, rsg-inventory, rsg-target, grumpy-reputation (and grumpy-groups):
   ```
   ensure grumpy-rumors
   ```
2. Add an image named `rumor_note.png` to `rsg-inventory/html/images/` (or point `Config.Item.image` at an existing one).
3. Set real coords for the sample informants in `shared/config.lua` and set `enabled = true`.
4. Set real coords on the sample `mark` rumors (they refuse to start at 0,0,0), or replace them with your own.
5. No database tables.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.Item` | `rumor_note` | Item name, label, weight, image, description |
| `Config.MaxNotes` | `3` | Notes one player can carry |
| `Config.SweepInterval` | `300` | Seconds between expired-note sweeps |
| `Config.SpawnDistance` | `60.0` | Informant peds spawn within this range |
| `Config.AskDistance` | `3.0` | Server-checked distance to ask |
| `Config.NothingCooldown` | `120` | Wait after being brushed off |
| `Config.Informants` | 2 samples (disabled) | `{ id, enabled, model, coords (vector4), scenario, categories, price, cooldown }` |
| `Config.Rumors` | 3 samples | `{ id, category, tiers, weight, lifetime, cooldown, title, text, job? }` |
| `Config.BuiltinItem` | on, `treasure_map` | The `item` job type: `allowed` whitelist, `needsResource` (rumor skipped while that resource is stopped) |
| `Config.BuiltinMark` | on, `BLIP_STYLE_AREA` | The built-in `mark` job type |

Rumor `job`: `{ type = 'registered-type', args = { ... }, group = 'auto'|'posse'|'gang'|'job'|'solo', radius = 75.0 }`.

## How to use
1. Find an informant and choose **Ask about rumors** (pay their price if they charge).
2. Open the note from your inventory to read it.
3. For job rumors, press **Act on it** before it goes stale. Your posse, or nearby gang members or colleagues, get the job too.

## Developer example
```lua
-- in your job resource (server): register a job type once
exports['grumpy-rumors']:RegisterJobType('bank_robbery', {
    available = function(args) return not RobberyActive[args.bank] end,   -- informants skip the rumor when false
    canStart  = function(src, args, members) return #members >= 2, 'You need at least two riders.' end,
    start     = function(src, args, members, ctx)
        StartRobbery(args.bank, members)  -- your job: blips, NPCs, payouts, cooldowns
        return true                       -- false hands the note back
    end,
})
```
```lua
-- in grumpy-rumors config
{ id = 'valentine_bank', category = 'illegal', tiers = { 'outlaw', 'notorious' }, weight = 3, lifetime = 5400, cooldown = 7200,
  title = 'rumor_bank_title', text = 'rumor_bank_text',
  job = { type = 'bank_robbery', group = 'auto', radius = 75.0, args = { bank = 'valentine' } } },
```

## Locales
`locales/en.json` is included. Add other languages (de, el, es, fr, ja, nl, pl, pt-br, ro) as `locales/<code>.json` with the same keys. Rumor titles and texts are locale keys too.
