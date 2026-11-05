# grumpy-hotel: developer and server owner docs

## Contents
1. Architecture
2. Data formats
3. Exports
4. Events and callbacks
5. Integration examples
6. Persistence
7. Security model
8. Database schema
9. How-tos
10. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | All settings (limits, distances, timers, stash, buckets, voice, anims, blip, warrants) |
| `server/main.lua` | `GH` state table, helpers (names, buckets, state, distance, lock, cooldown, stash wipe), DB load, client sync, `GetHotels`/`GetHotel` |
| `server/rooms.lua` | Access roles, enter/leave, instancing, door list, knocking, room menu, stash, kick, keys, death, login/restart restore, `IsInRoom`/`RemoveFromRoom` |
| `server/rental.lua` | Rental points, rental menu, rent/extend/renew/checkout, revoke key, expiry sweep, grace clock, `GetRental`/`HasKey` |
| `server/warrants.lua` | Warrant permission, issue, validation, usable item |
| `server/admin.lua` | `/hotellist`, create/update/delete, evict, admin teleport |
| `client/main.lua` | Hotel sync, door zones, blips, NUI bridge, door menu, rental menu (`OpenRental`), teleport + animation helpers |
| `client/room.lua` | Inside-room state, room zone, room menu, knock prompt, voice channel, death watch, spawn signal |
| `client/admin.lua` | Admin panel bridge and position capture |
| `html/*` | NUI: door, rental, room, knock prompt, admin list/renters/editor |

## 2. Data formats
Hotel (server): `{ id, label, rooms, price, maxDays, door = vector4, interior = vector4, blip }`.

Rental (server, `GH.Rentals[hotelId][room]`): `{ id, hotel, room, citizenid, name ('J. Smith'), keyCid, keyName, expiresAt (unix), graceLoginAt (unix|nil) }`.

Rental state:
- `active`: `now < expiresAt`.
- `grace`: before `min(expiresAt + Grace.Hours, graceLoginAt + Grace.LoginMinutes)`.
- `ended`: after that.

Roles inside a room: `renter`, `key`, `visitor` (let in after a knock), `law` (holding a valid warrant).

Routing bucket: `BucketBase + hotelId * BucketsPerHotel + room`. Voice channel: `Voice.VoiceChannelBase + bucket`.

Stash id: `grumpy_hotel_<hotelId>_<room>`. There is one per room. It is wiped when a rental ends and before a new rental starts.

Warrant item `info`: `{ hotel, room, rental, expires, hotelLabel, suspect, issuer, description }`. It only works while `rental` matches the current rental id and `expires > now`.

## 3. Exports
**Server**
| Export | Returns | Notes |
|---|---|---|
| `GetHotels()` | `{ id, label, rooms, price, maxDays, free }[]` | |
| `GetHotel(id)` | same shape or `nil` | |
| `SetRentalPoint(key, hotelId, coords)` | bool | Registers a spot where `OpenRental(key)` works. Removed automatically when the calling resource stops |
| `RemoveRentalPoint(key)` | | |
| `GetRental(citizenid, hotelId?)` | `{ hotel, room, state, expiresAt, keyName }` or `nil` | |
| `HasKey(citizenid, hotelId, room)` | bool | Renter or key holder with an active rental |
| `IsInRoom(src)` | `inside, hotelId, room, role` | |
| `RemoveFromRoom(src)` | | Puts the player at the door, bucket 0 |
| `IsReady()` | bool | `true` once hotels and rentals are loaded. Wait for it before creating hotels |
| `CreateHotel(data)` | `id` or `nil, errKey` | `data = { label, rooms, price, maxDays, door = {x,y,z,w}, interior = {x,y,z,w}, blip }`, validated like the admin form |
| `UpdateHotel(id, data)` | `ok, errKey` | Same `data`. Refuses (`rooms_in_use`) to drop below a rented room |
| `DeleteHotel(id)` | bool | Ends every rental (stashes wiped), puts everyone out, deletes the hotel |

**Client**
| Export | Notes |
|---|---|
| `OpenRental(key)` | Opens the rental menu for a registered rental point |
| `GetHotels()` | `{ id, label, rooms }[]` (synced list) |
| `IsInRoom()` | `inside, hotelId, room, role` |

## 4. Events and callbacks
Callbacks (rsg-core):
- `grumpy-hotel:server:getHotels`
- `getDoor(hotelId)`
- `canEnter(hotelId, room)`
- `getRental(key)`
- `roomMenu`
- `adminData` (admins only)

Server net events (all validated):
- Rooms: `enter`, `leave`, `knock`, `answerKnock`, `openStash`, `kick`, `giveKey`, `revokeKey`, `died`, `spawned`
- Rentals: `rent`, `extend`, `checkout`, `rentalRevokeKey`
- Warrants: `issueWarrant`
- Admin: `adminSave`, `adminDelete`, `adminEvict`, `adminTeleport`

Server-only events (other resources may listen, clients cannot trigger them):
- `grumpy-hotel:server:rentPaid(hotelId, src, amount, kind)`: fired after a paid rent (`kind = 'rent'`) or extension (`'extend'`). grumpy-pob uses it to pay hotel businesses.

Client events (sent by the server):
- `sync`, `entered(data, noTeleport)`, `left(door)`, `role`
- `knock`, `knockClosed`, `roomRefresh`, `rentalRefresh`
- `openAdmin`, `adminRefresh`, `adminTeleport`

## 5. Integration examples
grumpy-bartender registers each bartender with a hotel as rental point `grumpy-bartender:<bartenderId>`. It calls `SetRentalPoint` on load, on save and when grumpy-hotel restarts, and `RemoveRentalPoint` on delete. Its target option calls `OpenRental`.

grumpy-pob creates one hotel per hotel business with `CreateHotel` (after waiting for `IsReady`), keeps it in step with `UpdateHotel` (rate, rooms, name), registers its NPC as rental point `grumpy-pob:<businessId>` and listens to `rentPaid` to put the rent into the business account.

A future player-owned saloon does the same with its own key:
```lua
-- server
exports['grumpy-hotel']:SetRentalPoint('my-saloon:' .. saloonId, hotelId, npcCoords)
-- client (target option on the NPC)
exports['grumpy-hotel']:OpenRental('my-saloon:' .. saloonId)
```

## 6. Persistence
- Hotels, rentals and occupants live in MySQL and are cached in memory.
- Rental changes are written immediately.
- The expiry sweep runs every `SweepInterval` seconds:
  - One day before expiry, it warns an online renter.
  - When a room expires, it puts everyone out (law with a warrant may stay) and starts the grace clock if the renter is online.
  - When grace ends, it wipes the stash and deletes the rental.
- On login, an expired rental starts its 1-hour grace clock (once) and the renter is told.
- `grumpy_hotel_occupants` records who is in which room. On login, that player goes into the room's bucket before spawning. Once the client reports it has spawned, the server either keeps them in the room (still has access and is near the interior) or moves them to the door in bucket 0. A 2-minute fallback runs the same check if the client never reports.
- A resource restart rebuilds who is inside from the occupant rows and the players' current buckets.

## 7. Security model
- **The client never decides access.** Every action re-derives the player's role from server data (rental, key, warrant item in their inventory) and checks distance to the door, interior or rental point.
- Rent and extend:
  - Price and max days come from the DB.
  - The day count is range-checked.
  - The `RemoveMoney` result is checked, and the money is refunded if the insert fails.
  - `UNIQUE` keys enforce one renter per room and one room per character per hotel.
  - A per-player lock blocks double clicks.
- Knocks: only renters and key holders who are inside get the prompt, and the answer must come from one of them. The visitor must still be at the door.
- Keys: only the renter can give or take back the key. One key per room. Only a visitor already in the room can receive it.
- Warrants:
  - The issuer's job type, grade and duty status are checked.
  - The warrant only works for that hotel, room and rental id, until it expires.
  - Officers can't be shown out by occupants.
- Death: the server confirms the player is dead (metadata `isdead` or ped health) before moving them.
- Admin: every event re-checks `Config.AdminPermission`. Form fields are sanitised and range-checked, and coords must be finite and in the map range.
- Calling scripts must register rental points only at trusted positions. Anyone within `RentalDistance` of a point can rent there.

## 8. Database schema
```
grumpy_hotels          (id PK, label, rooms, price DECIMAL, max_days, door_x/y/z/h, int_x/y/z/h, blip, created_by, created_at)
grumpy_hotel_rentals   (id PK, hotel_id, room, citizenid, renter_name, key_citizenid, key_name, expires_at INT, grace_login_at INT NULL,
                        UNIQUE(hotel_id, room), UNIQUE(hotel_id, citizenid))
grumpy_hotel_occupants (citizenid PK, hotel_id, room, role, updated_at)
inventories            (rsg-inventory) rows grumpy_hotel_<hotel>_<room>
```

## 9. How-tos
- **New hotel:**
  1. `/hotellist` → **New hotel**.
  2. Door point: stand outside the door, facing it.
  3. Interior point: stand where players should appear inside.
  4. Save, then link it to a bartender in `/bartenders`.
- **Several hotels, one interior:** use the same interior point for each. Buckets keep them apart.
- **Lower the room count:** first evict any rented room above the new count. Save refuses otherwise.
- **Move a point:** Edit → **Place** (the ghost starts at the current point) → Save. Players already inside are not moved.
- **Turn off warrants:** `Config.Warrant.Enabled = false`.
- **Upgrading grumpy-bartender from its built-in hotel:**
  - Old `Config.Hotels` rentals are not migrated.
  - Create the hotels with `/hotellist` and re-link each bartender.
  - The `grumpy_bartender_rentals` table can be dropped.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| "No rooms are for rent here right now" | The bartender's hotel id doesn't exist. Re-pick the hotel in `/bartenders` |
| Rent option missing on bartender | grumpy-hotel not started, or the bartender has no hotel set |
| Players in different rooms hear each other | `Config.Voice.Enabled` is off, or your voice resource overrides Mumble channels. Test with two players |
| Players fall through / invisible in the room | The interior point is outside the interior's bounds or too high/low. Re-capture it standing on the floor |
| Stash is empty after renewing | Renewal only keeps items during the grace period. After grace the stash is wiped |
| Warrant doesn't open the room | Expired, issued for a previous tenant (rental id changed), or a different room |
| Logged out in a room and spawned outside | Access was lost (expired, key taken back, visitor), or you picked a different spawn point |
