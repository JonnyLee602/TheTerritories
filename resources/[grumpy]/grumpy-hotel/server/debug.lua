-- /hotelbucket: shows which routing bucket you are in, which hotel room it belongs to,
-- and whether that matches what grumpy-hotel expects. For testing alone.
local RSGCore = exports['rsg-core']:GetCoreObject()

if not Config.BucketCommand then return end

-- hotel / room a bucket number belongs to (nil for buckets outside the hotel range)
local function roomOfBucket(bucket)
    local offset = bucket - Config.BucketBase
    if offset < Config.BucketsPerHotel then return nil end
    local hotelId, room = offset // Config.BucketsPerHotel, offset % Config.BucketsPerHotel
    local h = GH.Hotels[hotelId]
    if not h or room < 1 or room > h.rooms then return nil end
    return h, room
end

RSGCore.Commands.Add(Config.BucketCommand, locale('cmd_bucket_help'), {}, false, function(source)
    local src = source
    local bucket = GetPlayerRoutingBucket(src)
    local players = 0
    for _, id in ipairs(GetPlayers()) do
        if GetPlayerRoutingBucket(id) == bucket then players = players + 1 end
    end

    local info = GH.Inside[src]
    local h = info and GH.Hotels[info.hotel]
    local expected = h and GH.Bucket(info.hotel, info.room) or 0
    local bh, broom = roomOfBucket(bucket)

    local data = {
        bucket = bucket, expected = expected, players = players,
        inside = h ~= nil, label = h and h.label or nil, room = info and info.room or nil, role = info and info.role or nil,
        bucketLabel = bh and bh.label or nil, bucketRoom = broom,
        voice = (h and Config.Voice.Enabled) and (Config.Voice.VoiceChannelBase + expected) or nil,
    }
    print(('[grumpy-hotel] %s (%d) bucket %d, expected %d, inside: %s'):format(
        GetPlayerName(src), src, bucket, expected, h and ('%s room %d (%s)'):format(h.label, info.room, info.role) or 'no'))
    TriggerClientEvent('grumpy-hotel:client:bucketInfo', src, data)
end, Config.BucketPermission)
