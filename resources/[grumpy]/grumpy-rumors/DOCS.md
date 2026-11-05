# grumpy-rumors developer and server owner docs

## Contents
1. Architecture
2. Data formats
3. Server exports
4. Events
5. Writing a job type
6. Persistence
7. Security model
8. Database
9. Server owner how-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest |
| `shared/config.lua` | Item, limits, informants, rumors, built-in mark type |
| `server/main.lua` | Item registration, job-type registry, informant asks, note reading, acting, expiry sweep, exports |
| `server/builtin.lua` | Built-in job types: `item` (give a whitelisted item) and `mark` (timed area blip) |
| `client/main.lua` | Informant peds + rsg-target, note NUI, mark blips |
| `html/` | The note panel |
| `locales/en.json` | All text, including rumor titles and stories |

Flow: **ask** (server picks a rumor the player qualifies for, charges, gives a note) → **use the note** (server checks it and sends the text) → **Act on it** (server re-checks the note, the reader's tier and the job, gets members from grumpy-groups, removes the note, calls the job type's `start`).

## 2. Data formats
**Note item info** (set by the server, never trusted from the client):
```lua
info = {
  ['Rumor'] = 'An Old Camp Stash',        -- shown in the inventory tooltip (key = locale info_rumor)
  ['Good until'] = 'Nov 05, 21:30',       -- shown in the tooltip (key = locale info_good_until)
  rumor = { id = 'old_camp_stash', serial = '6729f1a2c3b4d5', expires = 1730842200, issuedTo = 'ABC12345' },
}
```
`rumor` is a table, so the inventory tooltip hides it.

**Rumor config:**
```lua
{ id, category, tiers = { 'outlaw', ... }, weight, lifetime, cooldown, title, text,
  job = { type, args, group = 'auto'|'posse'|'gang'|'job'|'solo', radius } }
```
A rumor without `job` is flavour only.

**Informant config:** `{ id, enabled, model, coords = vector4, scenario, categories = { 'illegal' }, price, cooldown }`.

## 3. Server exports
| Export | Returns | Notes |
|---|---|---|
| `RegisterJobType(name, def)` | boolean | `def` is a `start` function or `{ start, canStart?, available? }`. Removed automatically when the registering resource stops |
| `GiveRumor(src, rumorId)` | boolean | Hands a note directly (loot, quest rewards). No tier check, no charge |
| `GetRumor(id)` | rumor config or nil | |
| `CountNotes(src)` | number | Notes in the player's pockets |

## 4. Events
| Event | Side | Args |
|---|---|---|
| `grumpy-rumors:server:acted` | server-local | `src, rumorId, members, ctx` after a job started |

Internal net events (validated): `grumpy-rumors:server:ask(informantId)`, `grumpy-rumors:server:act(slot, serial)`.
Client events: `grumpy-rumors:client:read`, `grumpy-rumors:client:mark`.

## 5. Writing a job type
```lua
exports['grumpy-rumors']:RegisterJobType('chop_wagon', {
    -- optional: informants skip the rumor while this returns false
    available = function(args) return GetDutyCountSomehow() >= 0 end,

    -- optional: checked when a player presses Act on it. Return false plus a message to keep the note
    canStart = function(src, args, members, ctx)
        if Cooldowns[args.yard] then return false, 'The yard is lying low for now.' end
        return true
    end,

    -- required: start your job. Return false to hand the note back
    start = function(src, args, members, ctx)
        -- src: who read the note. members: server ids incl. src (fixed list, snapshot at start)
        -- ctx: { rumorId, kind = 'posse'|'gang'|'job'|nil, groupId, reader }
        for _, id in ipairs(members) do TriggerClientEvent('my-chop:client:start', id, args) end
        return true
    end,
})
```
Rules for job types:
- Everything after `start` belongs to your resource: blips, NPCs, timers, payouts, cooldowns and cleanup. grumpy-rumors never calls it again.
- Snapshot `members`. Posses can expire mid-job; your job should keep going.
- Pay out with a reason that grumpy-reputation hooks, or call `exports['grumpy-reputation']:Action(...)`, so finishing an illegal job moves standing.
- Register on resource start. If your resource restarts, register again (the old registration is removed when it stops).

### Built-in `item` type
`job = { type = 'item', group = 'solo', args = { item = 'treasure_map', amount = 1, info = nil, message = 'locale_key' } }`
- The item must be in `Config.BuiltinItem.allowed` and exist in rsg-core's items.
- It goes to the **reader** only. The note is spent once the item is added (`CanAddItem` is checked first).
- `needsResource[item]` hides the rumor from informants while that resource isn't started.
- **Dig sites:** `treasure_map` hands off to rsg-treasure, which picks the dig spot from its own `Config.Locations` and runs the hunt (solo, keyed to the character).
- **Legendary maps:** rsg-legendary needs `info = { animal = '<key from its Config.Animals>', description = '<label>' }`. Add `legendary_map = true` to `allowed` and set `needsResource.legendary_map = 'rsg-legendary'`.

## 6. Persistence
- Notes are normal rsg-inventory items and save with the inventory. Expiry is an absolute timestamp, so it survives restarts.
- Ask cooldowns and rumor cooldowns are in memory and reset on restart.
- Job types are in memory. Each job resource registers on start.

## 7. Security model
What this resource checks:
- Asking: player exists, informant exists and is enabled, server-side distance to the informant, per-player informant cooldown, note limit, rumor eligibility (category, tier, rumor cooldown, job available, not already holding it), cash before `RemoveMoney`, `CanAddItem` before `AddItem`, refund if `AddItem` fails.
- Acting: the item in that slot must be a `rumor_note` with the **same serial** the server sent when it was read. The note must not be expired, the **reader's** tier must be allowed and the job type must be registered. `canStart` runs before the note is removed, and the note is returned if `start` fails or errors.
- The client only sends an informant id or a slot plus serial. Rumor ids, members, args and rewards all come from server config and state.
- Rate limit: 2 s between ask/act per player.

What job types must check themselves: anything about the job (locations, items, distance, payouts, cooldowns). `members` says who is grouped, not who is eligible.

## 8. Database
None.

## 9. Server owner how-tos
- **Add an informant:** copy an entry in `Config.Informants`, set coords (vector4 with heading), a model from `data/rdr3_discoveries/peds/peds_list.lua` and a scenario, then set `enabled = true`.
- **Add a flavour rumor:** add an entry without `job` and two locale strings.
- **Add a job rumor:** make sure a resource registers the job type, then add the entry with `job = { type = ..., args = ... }`.
- **Legal-only informant:** `categories = { 'legal' }`, with legal rumors that have `tiers = { 'neutral', 'respected', 'upstanding' }`.
- **Change the brush-off line:** `nothing_<first category>` in locales.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| Informant never spawns | `enabled = true`, real coords, and a valid model (console prints "invalid model") |
| Always "nothing for the likes of you" | No rumor fits: check the category, the player's tier (`/rep`), rumor cooldowns, and that its job type is registered (`Config.Debug` prints registrations) |
| "Nothing comes of it right now" | The job type isn't registered, `canStart` failed, or `start` returned false/errored (see server console) |
| Note image missing | Add `rumor_note.png` to rsg-inventory's images |
| Members don't get the job | grumpy-groups isn't started, the rumor uses `group = 'solo'`, or they're outside `radius` (gang/job) |
