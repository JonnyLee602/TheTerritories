-- Hotel businesses run through grumpy-hotel: one hotel per business (rooms set by the admin,
-- rate set by the owner). Rent is paid into the business account.
local RSGCore = POB.Core()

local Hotel = {}
POB.Hotel = Hotel

local HOTEL = 'grumpy-hotel'

local function call(fn, ...)
    local args = { ... }
    local ok, a, b = pcall(function() return exports[HOTEL][fn](exports[HOTEL], table.unpack(args)) end)
    if not ok then
        print(('^1[grumpy-pob] grumpy-hotel export %s failed (grumpy-hotel 1.1+ started?): %s^7'):format(fn, tostring(a)))
        return nil
    end
    return a, b
end

function Hotel.Key(biz) return 'grumpy-pob:' .. biz.id end

function Hotel.Rate(biz)
    local h = POB.Type(biz).hotel
    return tonumber(biz.settings.hotelRate) or h.defaultRate
end

local function data(biz)
    local h = POB.Type(biz).hotel
    return {
        label = biz.label, rooms = biz.rooms, price = Hotel.Rate(biz), maxDays = h.maxDays,
        door = biz.points.door, interior = biz.points.interior, blip = false,
    }
end

function Hotel.Ensure(biz)
    local t = POB.Type(biz)
    if not t or not t.hotel or not biz.points.door or not biz.points.interior or (biz.rooms or 0) < 1 then return end
    if biz.hotelId and call('GetHotel', biz.hotelId) then
        local ok, err = call('UpdateHotel', biz.hotelId, data(biz))
        if ok == false then print(('^3[grumpy-pob] UpdateHotel %d: %s^7'):format(biz.hotelId, tostring(err))) end
    else
        local id = call('CreateHotel', data(biz))
        if not id then return end
        biz.hotelId = id
        POB.SaveBiz(biz)
    end
    if biz.owner then
        call('SetRentalPoint', Hotel.Key(biz), biz.hotelId, POB.Vec(biz.points.npc))
    else
        call('RemoveRentalPoint', Hotel.Key(biz))
    end
end

function Hotel.Remove(biz)
    if not biz.hotelId then return end
    call('RemoveRentalPoint', Hotel.Key(biz))
    call('DeleteHotel', biz.hotelId)
    biz.hotelId = nil
end

-- grumpy-hotel fires this (server-only) after a successful rent or extension
AddEventHandler('grumpy-hotel:server:rentPaid', function(hotelId, src, amount, kind)
    for _, biz in pairs(POB.Businesses) do
        if biz.hotelId == hotelId then
            local Player = RSGCore.Functions.GetPlayer(src)
            local account = biz.owner and POB.AccountId(biz) or POB.Acc.GOV
            POB.Acc.Add(account, amount, 'rent', Player and POB.Acc.Who(Player) or nil, locale('ledger_rent', kind == 'extend' and locale('extend') or locale('rent')))
            return
        end
    end
end)

RegisterNetEvent('grumpy-pob:server:setHotelRate', function(id, rate)
    local src = source
    local biz = POB.Biz(id)
    local t = POB.Type(biz)
    if not biz or not t or not t.hotel or POB.Cooldown(src, 'hotelrate', 1000) then return end
    local Player = POB.Require(src, biz, 'hotelRate')
    if not Player or not POB.Near(src, biz.points.manager) then return end
    rate = POB.Money(tonumber(rate))
    if not rate or rate < 0 or rate > t.hotel.maxRate then return POB.Notify(src, locale('price_range', 0, t.hotel.maxRate), 'error') end
    biz.settings.hotelRate = rate
    POB.SaveBiz(biz)
    Hotel.Ensure(biz)
    POB.Acc.Log(POB.AccountId(biz), 'settings', 0, POB.Acc.Who(Player), locale('ledger_hotel_rate', rate))
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager')
end)

local function syncAll()
    CreateThread(function()
        local any = false
        for _, biz in pairs(POB.Businesses) do if POB.Type(biz).hotel then any = true break end end
        if not any or not POB.WaitReady(HOTEL) then return end -- hotels must be loaded, or we'd create duplicates
        for _, biz in pairs(POB.Businesses) do Hotel.Ensure(biz) end
    end)
end
POB.AfterLoad(syncAll)
AddEventHandler('onResourceStart', function(res)
    if res == HOTEL and POB.Ready then syncAll() end
end)
