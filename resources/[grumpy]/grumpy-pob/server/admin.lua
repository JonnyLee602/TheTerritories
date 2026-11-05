-- /pob admin menu: create, edit, delete, reset or set owner, teleport, recipe approval, government account.
local RSGCore = POB.Core()

local Acc = POB.Acc

local function admin(src) return POB.IsAdmin(src) end

local function typeList()
    local out = {}
    for key, t in pairs(Config.Types) do
        out[#out + 1] = {
            key = key, label = t.label, price = t.price or 0, npcModel = t.npcModel, crafting = t.crafting == true,
            hotel = t.hotel and { maxRooms = t.hotel.maxRooms } or nil, stable = t.stable ~= nil,
        }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_admin'), {}, false, function(source)
    if not admin(source) then return POB.Notify(source, locale('no_permission'), 'error') end
    TriggerClientEvent('grumpy-pob:client:openAdmin', source)
end, Config.AdminPermission)

RSGCore.Functions.CreateCallback('grumpy-pob:server:adminData', function(source, cb)
    if not admin(source) then return cb(nil) end
    local list = {}
    for _, biz in pairs(POB.Businesses) do
        list[#list + 1] = {
            id = biz.id, type = biz.type, typeLabel = POB.Type(biz).label, label = biz.label, price = biz.price,
            owner = biz.owner and biz.owner.name or nil, ownerCid = biz.owner and biz.owner.cid or nil,
            npcModel = biz.npcModel, rooms = biz.rooms, points = biz.points,
            balance = Acc.Balance(POB.AccountId(biz)), taxDue = biz.taxDue, taxOwedSince = biz.taxOwedSince,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    cb({
        businesses = list, types = typeList(), now = os.time(),
        limits = { maxCraft = Config.MaxCraftStations, maxStash = Config.MaxStashes, maxPrice = Config.MaxPrice },
        gov = Acc.Balance(Acc.GOV),
    })
end)

---------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------
local function point(p, withHeading)
    if type(p) ~= 'table' then return nil end
    local x, y, z, w = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.w) or 0.0
    if not (POB.Finite(x) and POB.Finite(y) and POB.Finite(z) and POB.Finite(w)) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    local out = { x = x, y = y, z = z }
    if withHeading then out.w = w % 360.0 end
    return out
end

local function sign(p)
    local base = point(p)
    if not base then return nil end
    local rot = exports['rsg-gizmo']:SanitiseRotation(vector3(tonumber(p.rx) or 0.0, tonumber(p.ry) or 0.0, tonumber(p.rz) or 0.0))
    if not rot then return nil end
    base.rx, base.ry, base.rz = rot.x, rot.y, rot.z
    return base
end

local function list(raw, max, withHeading)
    local out = {}
    if type(raw) ~= 'table' then return out end
    for i = 1, math.min(#raw, max) do
        local p = point(raw[i], withHeading)
        if not p then return nil end
        out[#out + 1] = p
    end
    return out
end

local function sanitise(data, existing)
    if type(data) ~= 'table' then return nil, 'invalid_form' end
    local key = existing and existing.type or data.type
    local t = type(key) == 'string' and Config.Types[key]
    if not t then return nil, 'admin_bad_type' end
    local label = POB.Str(data.label, 40)
    if not label or #label < 3 then return nil, 'bad_name' end
    local price = POB.Money(tonumber(data.price))
    if not price or price < 0 or price > Config.MaxPrice then return nil, 'admin_bad_price' end
    local model = type(data.npcModel) == 'string' and data.npcModel:match('^[%w_]+$') and #data.npcModel <= 60 and data.npcModel or t.npcModel
    local pts = data.points or {}
    local points = {
        npc = point(pts.npc, true), manager = point(pts.manager, true), sign = sign(pts.sign),
        craft = list(pts.craft, Config.MaxCraftStations, true), stash = list(pts.stash, Config.MaxStashes, true),
    }
    if not points.npc then return nil, 'admin_need_npc' end
    if not points.manager then return nil, 'admin_need_manager' end
    if not points.sign then return nil, 'admin_need_sign' end
    if not points.craft or not points.stash then return nil, 'invalid_form' end
    if t.crafting and #points.craft < 1 then return nil, 'admin_need_craft' end
    if not t.crafting then points.craft = {} end
    local rooms = 0
    if t.hotel then
        points.door, points.interior = point(pts.door, true), point(pts.interior, true)
        if not points.door then return nil, 'admin_need_door' end
        if not points.interior then return nil, 'admin_need_interior' end
        rooms = POB.Int(data.rooms, 1, t.hotel.maxRooms)
        if not rooms then return nil, 'admin_bad_rooms' end
    end
    if t.stable then
        points.preview = point(pts.preview, true)
    end
    return { type = key, label = label, price = price, npcModel = model, points = points, rooms = rooms }
end

---------------------------------------------------------------------
-- Create / update
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:adminSave', function(id, data)
    local src = source
    if not admin(src) or POB.Cooldown(src, 'adminSave', 1500) then return end
    local existing = id and POB.Biz(id)
    if id and not existing then return end
    local f, err = sanitise(data, existing)
    if not f then return POB.Notify(src, locale(err), 'error') end
    local Player = RSGCore.Functions.GetPlayer(src)

    if existing then
        local biz = existing
        local oldRooms = biz.rooms
        biz.label, biz.price, biz.npcModel, biz.points, biz.rooms = f.label, f.price, f.npcModel, f.points, f.rooms
        POB.SaveBiz(biz)
        POB.Jobs.Ensure(biz)
        POB.Shop.EnsureStore(biz)
        POB.Stable.Register(biz)
        if POB.Type(biz).hotel then
            POB.Hotel.Ensure(biz)
            if f.rooms < oldRooms then POB.Notify(src, locale('admin_rooms_note'), 'inform') end
        end
        POB.Broadcast()
        POB.Notify(src, locale('admin_saved', biz.label), 'success')
    else
        local t = Config.Types[f.type]
        local biz = POB.InsertBiz({
            type = f.type, label = f.label, price = f.price, npcModel = f.npcModel, points = f.points, rooms = f.rooms,
            blip = { sprite = t.blip.sprite, color = t.blip.color or '', enabled = true }, settings = { wages = {}, training = {} },
        }, Player and Player.PlayerData.citizenid)
        if not biz then return POB.Notify(src, locale('db_error'), 'error') end
        Acc.Ensure(POB.AccountId(biz))
        POB.Jobs.Ensure(biz)
        POB.Shop.EnsureStore(biz)
        POB.Hotel.Ensure(biz)
        POB.Stable.Register(biz)
        POB.Broadcast()
        POB.Notify(src, locale('admin_created', biz.label, biz.id), 'success')
        print(('[grumpy-pob] %s created business %d "%s" (%s)'):format(GetPlayerName(src), biz.id, biz.label, biz.type))
    end
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'admin')
end)

---------------------------------------------------------------------
-- Delete / owner tools
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:adminDelete', function(id)
    local src = source
    local biz = admin(src) and POB.Biz(id)
    if not biz or POB.Cooldown(src, 'adminDelete', 1500) then return end
    if biz.owner then POB.Repossess(biz, locale('ledger_deleted')) end
    Acc.Drain(POB.AccountId(biz), Acc.GOV, 'deleted', locale('ledger_deleted'))
    POB.Craft.WipeStashes(biz)
    POB.Shop.RemoveStore(biz)
    POB.Hotel.Remove(biz)
    POB.Stable.Remove(biz)
    POB.Jobs.Delete(biz)
    for _, r in pairs(POB.Recipes.All()) do
        if r.biz == biz.id then
            if r.status == 'approved' then r.status = 'retired' elseif r.status ~= 'retired' then r.status = 'deleted' end
            POB.Recipes.Save(r)
        end
    end
    MySQL.update.await('DELETE FROM grumpy_pob_stock WHERE business_id = ?', { biz.id })
    MySQL.update.await('DELETE FROM grumpy_pob_applications WHERE business_id = ?', { biz.id })
    MySQL.update.await('DELETE FROM grumpy_pob_withdrawals WHERE business_id = ?', { biz.id })
    MySQL.update.await('DELETE FROM grumpy_pob_businesses WHERE id = ?', { biz.id })
    POB.Businesses[biz.id] = nil
    POB.Broadcast()
    POB.Notify(src, locale('admin_deleted', biz.label), 'success')
    print(('[grumpy-pob] %s deleted business %d "%s"'):format(GetPlayerName(src), biz.id, biz.label))
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'admin')
end)

RegisterNetEvent('grumpy-pob:server:adminReset', function(id)
    local src = source
    local biz = admin(src) and POB.Biz(id)
    if not biz or not biz.owner or POB.Cooldown(src, 'adminReset', 1500) then return end
    POB.Repossess(biz, locale('ledger_reset_admin', GetPlayerName(src)))
    POB.Notify(src, locale('admin_reset', biz.label), 'success')
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'admin')
end)

RegisterNetEvent('grumpy-pob:server:adminSetOwner', function(id, target)
    local src = source
    local biz = admin(src) and POB.Biz(id)
    target = POB.Int(target)
    local T = target and RSGCore.Functions.GetPlayer(target)
    if not biz or not T or POB.Cooldown(src, 'adminOwner', 1500) then return end
    if biz.owner then POB.Repossess(biz, locale('ledger_reset_admin', GetPlayerName(src))) end
    if not POB.Jobs.Give(target, biz, Config.OwnerGrade, true) then return POB.Notify(src, locale('cannot_take_job'), 'error') end
    local who = Acc.Who(T)
    biz.owner = { cid = who.cid, name = who.name }
    biz.taxDue = os.time() + Config.Tax.IntervalDays * 86400
    biz.taxOwedSince = nil
    POB.SaveBiz(biz)
    Acc.Ensure(POB.AccountId(biz))
    Acc.Log(POB.AccountId(biz), 'owner', 0, who, locale('ledger_given', GetPlayerName(src)))
    POB.Refresh(biz)
    POB.Notify(src, locale('admin_owner_set', who.name, biz.label), 'success')
    POB.Notify(target, locale('you_own', biz.label), 'success')
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'admin')
end)

RegisterNetEvent('grumpy-pob:server:adminTeleport', function(id)
    local src = source
    local biz = admin(src) and POB.Biz(id)
    if not biz or not biz.points.npc then return end
    local p = biz.points.npc
    SetEntityCoords(GetPlayerPed(src), p.x, p.y, p.z, false, false, false, false)
end)

-- Sign placement result from rsg-gizmo (client), validated before the editor keeps it
RSGCore.Functions.CreateCallback('grumpy-pob:server:adminCheckSign', function(source, cb, coords)
    if not admin(source) or type(coords) ~= 'vector3' then return cb(false) end
    cb(exports['rsg-gizmo']:IsPlacementValid(source, coords, 15.0) == true)
end)
