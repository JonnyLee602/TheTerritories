# rsg-doorlock hook (`[grumpy-backroom hook]`)

rsg-doorlock 3.2.0 has no export to lock or unlock a door from another resource. grumpy-backroom needs one,
so add this to `rsg-doorlock/server/main.lua`, just above `AddEventHandler('playerDropped', ...)` at the end.
On The Territories it is already applied in `territories-server` (`main` branch).

```lua
---------------------------------------------
-- [grumpy-backroom hook] lock / unlock a door from another resource.
-- The state is NOT saved: a restart restores the database state (grumpy-backroom re-applies its open rooms).
---------------------------------------------
exports('SetDoorState', function(doorID, locked)
    local door = ready and Doors[tonumber(doorID) or -1]
    if not door then return false end
    locked = locked == true
    if door.locked ~= locked then
        door.locked = locked
        TriggerClientEvent('rsg-doorlock:client:setState', -1, door.id, locked)
    end
    return true
end)
```

**Without the hook** grumpy-backroom still works: it prints one warning and sends `rsg-doorlock:client:setState`
to every client itself. The catch: rsg-doorlock's server still thinks the door is locked, so a player who joins
while a room is open sees it locked until it next changes.
