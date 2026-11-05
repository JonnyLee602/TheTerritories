# grumpy-law

Crime **incidents**, **NPC witnesses**, **reports** to the law, and the **heat** check that follows a report. Scripts like grumpy-robbery open an incident when a crime happens. NPCs who see it may run to the law. Once a report lands, on-duty lawmen get an alert and the criminal is "hot" for 10 minutes. Get away with a crime that succeeded and your outlaw name grows. This resource is also where NPC police will live later.

Version 1.0.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core` (OneSync on)
**Optional:** `rsg-lawman` (alert blips), `grumpy-reputation` (escape bonus)
**Used by:** grumpy-robbery

## Features
- **Witnesses**, checked from both sides:
  - **Server:** every 2 s during the crime's hot window, the server counts networked, alive, non-player NPCs near the criminal. NPCs walking past count too. Animals are skipped using a model list generated from `rdr3_discoveries/peds`. NPCs within 8 m count even without a line-of-sight check.
  - **Criminal's game:** every 3 s it checks humans with a clear line of sight (up to the 10 nearest) and sends their network IDs. The server verifies each one (exists, alive, human model, in range).
  - **If the server can't see ambient NPCs at all** (population not networked), the client's line-of-sight count is used, capped at 3.
- **Reports take time:** each witness has a 60% chance to report after 20–60 s. A witness who is **dead or gone** when their report is due never reports. Scripts can also say the **victim** reports (for example, a robbed clerk), with its own short delay.
- **First report:** on-duty law (`job.type == 'leo'`) gets the rsg-lawman alert, the criminal is told "word has reached the law", and the **heat** check starts.
- **Heat (10 minutes):**
  - **Jailed:** no bonus (the `jailed` hook in grumpy-reputation gives its slight gain).
  - **Died:** nothing.
  - **Logged off:** forfeits.
  - **Free and alive at the end, and the crime succeeded:** outlaw bonus (`escaped`, with a daily cap).
  - Failed crimes are still reported, but never pay a bonus.
- **Ready for NPC police:** every report fires `grumpy-law:server:crimeReported(incident, lawOnDutyCount)`. An NPC police module can respond whenever the count is 0.
- **`/witnesstest`** (admin) shows how many NPCs the **server** sees around you next to how many **your game** sees, so you can check your server's population setup.

## Installation
1. Put `grumpy-law` in your resources and add after rsg-core (before grumpy-robbery):
   ```
   ensure grumpy-law
   ```
2. No items and no database.
3. **Run `/witnesstest` in a busy town.**
   - **Server count close to your game's count:** server-side witness checks are active.
   - **Server sees 0:** ambient NPCs aren't networked on your server. grumpy-law falls back to the client's count (weaker against modded clients).
4. If you use grumpy-reputation, update it too: its config now includes the `escaped` action.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.Witness.Radius` / `CloseRadius` | `25.0` / `8.0` | Witness range / range that counts without line of sight |
| `Config.Witness.ScanInterval` / `ClientInterval` / `ClientMaxPeds` | `2` / `3` / `10` | Scan rates and line-of-sight cap |
| `Config.Witness.ClientFallbackMax` | `3` | Most witnesses taken from the client when the server sees no NPCs |
| `Config.Witness.ReportChance` / `ReportDelay` | `60` / `{20, 60}` | % per witness / seconds before the report |
| `Config.Witness.DeadNoReport` | `true` | Dead witnesses don't report |
| `Config.Crimes` | robbery, shoplifting, generic | `hot` seconds, `victimDelay`, `escapeAction`, `escapeMult` |
| `Config.Report.NotifyCriminal` / `UseLawmanAlert` | `true` / `true` | |
| `Config.Heat.Duration` / `CheckInterval` / `NotifyEscaped` | `600` / `5` / `true` | |
| `Config.TestCommand` / `AdminPermission` | `witnesstest` / `admin` | |

## Developer example
```lua
-- server: a crime starts
local id = exports['grumpy-law']:OpenIncident(src, { crime = 'store_robbery', coords = coords, label = 'Valentine', victimReports = true })
-- ...it worked
exports['grumpy-law']:MarkSucceeded(id)

-- future NPC police
AddEventHandler('grumpy-law:server:crimeReported', function(incident, lawOnDuty)
    if lawOnDuty == 0 then -- send deputies to incident.coords
    end
end)
```

## Locales
`locales/en.json` is included. Add other languages (de, el, es, fr, ja, nl, pl, pt-br, ro) as `locales/<code>.json` with the same keys.
