-- Law warrants: an item whose metadata ties it to one hotel, one room and one rental, with an expiry.
local RSGCore = exports['rsg-core']:GetCoreObject()

local W = Config.Warrant

function GH.CanIssueWarrant(Player)
    if not W.Enabled then return false end
    local job = Player.PlayerData.job or {}
    if not W.JobTypes[job.type] then return false end
    if W.RequireOnDuty and not job.onduty then return false end
    local grade = job.grade and tonumber(job.grade.level) or 0
    return grade >= W.MinGrade
end

-- A matching, unexpired warrant for this exact rental (a new tenant needs a new warrant)
function GH.HasWarrant(src, hotelId, room, rentalId)
    if not W.Enabled then return false end
    local ok, items = pcall(function() return exports['rsg-inventory']:GetItemsByName(src, W.Item) end)
    if not ok or type(items) ~= 'table' then return false end
    local now = os.time()
    for _, it in ipairs(items) do
        local i = it.info
        if type(i) == 'table' and i.hotel == hotelId and i.room == room and i.rental == rentalId and (tonumber(i.expires) or 0) > now then
            return true
        end
    end
    return false
end

RegisterNetEvent('grumpy-hotel:server:issueWarrant', function(hotelId, room)
    local src = source
    GH.Lock(src, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or not GH.CanIssueWarrant(Player) then return GH.Notify(src, locale('no_permission'), 'error') end
        local h
        h, room = GH.ValidRoom(math.tointeger(tonumber(hotelId)) or -1, room)
        if not h then return end
        if not GH.NearDoor(src, h) then return GH.Notify(src, locale('too_far'), 'error') end
        local r = GH.Rental(h.id, room)
        if not r or GH.State(r) == 'ended' then return GH.Notify(src, locale('warrant_no_rental'), 'error') end
        if r.citizenid == Player.PlayerData.citizenid then return end
        if GH.OnCooldown(src, 'warrant', W.Cooldown) then return GH.Notify(src, locale('warrant_cooldown'), 'error') end
        if not exports['rsg-inventory']:CanAddItem(src, W.Item, 1) then return GH.Notify(src, locale('inventory_full'), 'error') end

        local expires = os.time() + W.Minutes * 60
        local info = {
            hotel = h.id, room = room, rental = r.id, expires = expires,
            hotelLabel = h.label, suspect = r.name, issuer = GH.PlayerName(Player),
            description = locale('warrant_description', room, h.label, r.name, os.date('%Y-%m-%d %H:%M', expires)),
        }
        if not exports['rsg-inventory']:AddItem(src, W.Item, 1, info, nil, 'grumpy-hotel:warrant') then
            return GH.Notify(src, locale('inventory_full'), 'error')
        end
        GH.Notify(src, locale('warrant_issued', room, h.label, W.Minutes), 'success')
        print(('[grumpy-hotel] %s (%s) issued a warrant for %s room %d (rental %d, renter %s)'):format(
            GetPlayerName(src), Player.PlayerData.citizenid, h.label, room, r.id, r.citizenid))
    end)
end)

-- Using the warrant shows what it is for
if W.Enabled then
    RSGCore.Functions.CreateUseableItem(W.Item, function(source, item)
        local i = item and item.info
        if type(i) ~= 'table' or not i.hotel then return GH.Notify(source, locale('warrant_blank'), 'error') end
        local left = (tonumber(i.expires) or 0) - os.time()
        if left <= 0 then return GH.Notify(source, locale('warrant_expired', i.room or '?', i.hotelLabel or '?'), 'error') end
        GH.Notify(source, locale('warrant_info', i.room or '?', i.hotelLabel or '?', i.suspect or '?', math.ceil(left / 60)), 'inform')
    end)
end
