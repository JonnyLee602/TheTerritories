# grumpy-hotel

Saloon rooms for rent. Admins create hotels in game. Players rent rooms from a bartender (grumpy-bartender, or any script that calls the exports) and enter their own instanced copy of a shared interior. Each room has a shared stash, one spare key, knocking for visitors and law warrants.

Version 1.2.0 · for RSG Framework (rsg-core 3.x) · see [DOCS.md](DOCS.md) for developer and server owner details.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`
**Works with:** `grumpy-bartender` (rental point), `grumpy-pob` (hotel businesses: creates hotels and collects rent), `rsg-voice`, `rsg-medic`

## Features
- **`/hotellist` admin panel**: create, edit and delete hotels, teleport to the door or interior point, list renters and evict them. One command does everything.
- Each hotel has a **name, room count, daily rate, max days paid ahead, a door point, an interior point and an optional stash point**. Admins place the points with **rsg-gizmo**: a ghost person shows where players stand and which way they face, and you can walk while placing. Optional map blip (`blip_hotel_bed`).
- **Renting happens at a rental point** (a grumpy-bartender bartender, or a future saloon NPC) through exports. Rooms are paid in cash, per real day, up to *max days* in advance. Players can rent **one room per hotel**. The rental menu shows how many rooms are free.
- **Door point (outside)**: lists every room.
  - Available rooms show **Available**.
  - Rented rooms show the renter as **J. Smith** (first initial and last name).
  - The renter sees **Enter - Your Room**. The key holder sees **Enter**.
  - Entering plays a key-unlock animation, fades, and puts the player in the room's **own routing bucket** at the shared interior coords.
  - Anyone else can **Knock** (knock animation). Only the renter or key holder **while inside the room** gets the prompt to **Let in** or **Ignore**. If nobody is home, or nobody answers within 20 s, the visitor gets "No answer". Knocking has a cooldown.
- **Room point (inside)**: room menu and **Leave room**.
  - **Storage**: one rsg-inventory stash per room, shared by the renter, the key holder and law with a warrant. Visitors can't open it. If the hotel has a **stash point** (a wardrobe or chest in the room), storage opens there as **Room storage**. Without one, it opens from the room menu.
  - **Spare key**: the renter can give the one spare key to a visitor in the room, and take it back. The key holder can then enter from the door and use the stash.
  - **Show out**: the renter can show out visitors and the key holder. The key holder can show out visitors.
  - Visitors leave automatically when the last renter or key holder leaves.
- **Expiry**:
  - The renter is warned one day before the room expires.
  - On expiry the room locks and everyone inside is put out. A **grace period** follows: 24 hours, or 1 hour after the renter's first login after expiry, whichever comes first. During grace the renter can **Renew** at the bar and keep their things.
  - When grace ends, the **stash is wiped** and the room is freed. Checking out or being evicted also wipes the stash.
- **Instancing and voice**: each room is its own routing bucket, with NPC population off. Each room also gets its **own Mumble voice channel** while you're inside. rsg-voice doesn't respect routing buckets, so without this, people in different rooms would hear each other.
- **Logout, crash or restart safe**: players who log out in a room are put into a private bucket straight away on login. They're put back in the room if they still have access. Otherwise they're moved outside the door. A resource restart rebuilds who is in which room.
- **Dying in a room** moves you out of the instance to the door, so medics can reach you.
- **Law warrants**: an on-duty officer (`job.type = 'leo'`, grade ≥ `MinGrade`) can issue a warrant at the door. The warrant is an item tied to that hotel, room and rental, with an expiry. Holding it lets the officer **Enter (warrant)** and open the stash. Using the item shows what it's for.
- Everything is checked on the server: admin permission, distances, access role, cash, cooldowns, warrant metadata and a double-click lock.
- NUI in the house theme (Roboto, monochrome, no vignette).

## Installation
1. Put `grumpy-hotel` in your resources folder.
2. Add the warrant item to `rsg-core/shared/items.lua` and an image `hotel_warrant.png` to rsg-inventory's images:
   ```lua
   hotel_warrant = { name = 'hotel_warrant', label = 'Room Warrant', weight = 10, type = 'item', image = 'hotel_warrant.png', unique = true, useable = true, shouldClose = true, description = 'A search warrant for a rented room', category = 'law' },
   ```
   If you don't want warrants, set `Config.Warrant.Enabled = false`.
3. Add to `server.cfg` (after its dependencies, before grumpy-bartender):
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure grumpy-hotel
   ensure grumpy-bartender
   ```
4. Database: the tables are created automatically. To install them by hand, set `Config.AutoDatabase = false` and import `install.sql`.
5. In game: `/hotellist` → **New hotel**. Click **Place** under *Door point* and put the ghost outside the door, facing it. Click **Place** under *Interior point* and put the ghost inside the room where players should appear (walk there while placing, or stand in the room first). Optionally click **Place** under *Stash point* and put the ghost standing at the wardrobe or chest (it must be within `StashMaxDistance` of the interior point). Fill in the rest and **Save**.
6. In `/bartenders`, edit the bartender and set **Hotel** to the new hotel.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AdminPermission` / `AdminCommand` | `'admin'` / `hotellist` | Permission and command for the admin panel |
| `MaxRooms` / `MaxDaysLimit` / `MaxDailyRate` | `50` / `30` / `5` | Upper limits admins can enter |
| `BucketCommand` / `BucketPermission` | `hotelbucket` / `'admin'` | Test command that shows your routing bucket and voice channel. `false` turns it off |
| `PlaceModel` / `PlaceDistance` | `u_m_m_valhotelowner_01` / `30.0` | Ghost ped and range for placing points with rsg-gizmo |
| `DoorRadius` / `RoomRadius` | `1.5` | rsg-target zone sizes at the door and interior point |
| `StashRadius` / `StashMaxDistance` | `1.2` / `25.0` | rsg-target zone at the stash point / how far it may be from the interior point |
| `ServerDistance` / `RentalDistance` | `4.0` / `5.0` | Server-side distance tolerance at the points / rental point |
| `RestoreDistance` | `40.0` | On login, how close to the interior counts as "still in the room" |
| `DaySeconds` | `86400` | Length of one rental day |
| `SweepInterval` | `60` | Seconds between expiry checks |
| `WarnBefore` | `86400` | Warn the renter this long before expiry |
| `Grace.Hours` / `Grace.LoginMinutes` | `24` / `60` | Grace period: whichever comes first |
| `Stash.slots` / `Stash.maxweight` | `100` / `1000000` | Room stash size (clamped by rsg-inventory's limits) |
| `BucketBase` / `BucketsPerHotel` | `60000` / `100` | Routing buckets: `base + hotelId * perHotel + room` |
| `Voice.Enabled` / `Voice.VoiceChannelBase` | `true` / `0` | Per-room Mumble voice channel |
| `Knock.Timeout` / `Knock.Cooldown` | `20` / `15` | Seconds to answer / between knocks |
| `Anims.unlock` / `Anims.knock` | `script_mp@player@unlockdoor`, `amb_misc@world_human_door_knock@male_a@idle_a` | Door animations |
| `Blip.sprite` / `Blip.scale` | `blip_hotel_bed` / `0.2` | Hotel blip |
| `Warrant.Enabled` / `Item` | `true` / `hotel_warrant` | Law warrants |
| `Warrant.JobTypes` / `MinGrade` / `RequireOnDuty` | `{ leo = true }` / `2` / `true` | Who may issue warrants |
| `Warrant.Minutes` / `Cooldown` | `60` / `30` | Warrant lifetime / seconds between warrants per officer |

## How to use
- **Players**:
  - Rent at the bartender (**Rent a room**): pick a room and the number of days, then **Rent**.
  - In the same menu: **Extend**, **Renew** (during grace), **Take back** the spare key, or **Check out** (click twice; this clears the room).
  - Go to the hotel door and target **Hotel rooms**.
  - Inside, target the room point for **Room** (key, visitors, and storage when there is no stash point) or **Leave room**. Target the wardrobe or chest for **Room storage** when the hotel has a stash point.
- **Visitors**: target the door, then **Knock** on a rented room.
- **Law**: target the door, then **Issue warrant** on a rented room. Then **Enter (warrant)**.
- **Admins**: `/hotellist` (permission `Config.AdminPermission`).
- **Testing**: `/hotelbucket` (permission `Config.BucketPermission`) shows your routing bucket, which hotel room it belongs to, how many players share it and your Mumble voice channel. Run it outside (expect bucket 0) and inside a room (expect `BucketBase + hotelId * BucketsPerHotel + room` and the matching voice channel). Anything wrong shows as a red notification and is also printed to the F8 console and the server console.

## Developer examples
```lua
-- server: make any NPC / spot a rental point for hotel 1
exports['grumpy-hotel']:SetRentalPoint('my-saloon:npc1', 1, vector3(x, y, z))
-- client: open the rental menu at that point (the server checks the player is near it)
exports['grumpy-hotel']:OpenRental('my-saloon:npc1')
-- server: is this player inside a hotel room?
local inside, hotelId, room, role = exports['grumpy-hotel']:IsInRoom(source)
```

## Locales
`locales/en.json` is included. Add other languages (de, el, es, fr, ja, nl, pl, pt-br, ro) as `locales/<code>.json` with the same keys.
