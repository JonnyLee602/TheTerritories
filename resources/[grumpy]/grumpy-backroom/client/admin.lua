-- /backroom: room list + editor (rsg-menubase), doorman placement (rsg-gizmo), door picker (rsg-doorlock locks),
-- zone corners where the admin stands, kick-out point. The draft is drawn in the world while the editor is open.
local MenuData = BR.MenuData
local RES = GetCurrentResourceName()

local draft          -- room being edited (nil = editor closed)
local doorCache = {} -- rsg-doorlock locks: [id] = { id, name, textCoords }
local drawing = false

---------------------------------------------
-- helpers
---------------------------------------------
local function myPos()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
end

local function textInput(title, default, maxLen)
    AddTextEntry('GRUMPY_BR_INPUT', title)
    DisplayOnscreenKeyboard(0, 'GRUMPY_BR_INPUT', '', default or '', '', '', '', maxLen or 48)
    while UpdateOnscreenKeyboard() == 0 do Wait(0) end
    if UpdateOnscreenKeyboard() ~= 1 then return nil end
    local res = GetOnscreenKeyboardResult()
    if type(res) ~= 'string' then return nil end
    res = res:gsub('^%s+', ''):gsub('%s+$', '')
    return res ~= '' and res or nil
end

local function loadDoors()
    local doors = BR.Await('rsg-doorlock:server:getDoors') or {}
    doorCache = {}
    for id, d in pairs(doors) do
        id = tonumber(d.id) or tonumber(id)
        if id and d.textCoords then doorCache[id] = { id = id, name = d.name, textCoords = d.textCoords } end
    end
end

local function newDraft()
    return { name = locale('admin_default_name'), model = Config.Npc.model, doors = {}, corners = {},
             height = Config.Zone.DefaultHeight, enabled = false }
end

local function fromRoom(r)
    local d = { id = r.id, name = r.name, model = r.model, npc = r.npc, exit = r.exit, enabled = r.enabled,
                doors = {}, corners = {}, height = Config.Zone.DefaultHeight }
    for i, id in ipairs(r.doors or {}) do d.doors[i] = id end
    if BackroomZone.Valid(r.zone) then
        d.height = math.floor(r.zone.maxZ - r.zone.minZ + 0.5)
        for i, p in ipairs(r.zone.points) do d.corners[i] = { x = p.x, y = p.y, z = r.zone.minZ + Config.Zone.FloorOffset } end
    end
    return d
end

-- the zone as the server stores it
local function draftZone(d)
    if #d.corners == 0 then return nil end
    local low = math.huge
    local pts = {}
    for i, c in ipairs(d.corners) do
        pts[i] = { x = c.x, y = c.y }
        if c.z < low then low = c.z end
    end
    local minZ = low - Config.Zone.FloorOffset
    return { points = pts, minZ = minZ, maxZ = minZ + d.height }
end

local function payload(d)
    return { id = d.id, name = d.name, model = d.model, npc = d.npc, exit = d.exit, enabled = d.enabled,
             doors = d.doors, zone = draftZone(d) }
end

local function hasDoor(d, id)
    for i, v in ipairs(d.doors) do if v == id then return i end end
end

---------------------------------------------
-- preview drawing
---------------------------------------------
local function line(a, b, r, g, bl)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, r, g, bl, 255)
end

local function startDrawing()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while draft do
            local zone = draftZone(draft)
            if zone then
                local pts = zone.points
                for i = 1, #pts do
                    local a, b = pts[i], pts[i % #pts + 1]
                    local a1, b1 = vector3(a.x, a.y, zone.minZ), vector3(b.x, b.y, zone.minZ)
                    local a2, b2 = vector3(a.x, a.y, zone.maxZ), vector3(b.x, b.y, zone.maxZ)
                    if #pts >= 3 or i < #pts then line(a1, b1, 255, 60, 40) line(a2, b2, 255, 60, 40) end
                    line(a1, a2, 255, 60, 40)
                end
            end
            local me = GetEntityCoords(PlayerPedId())
            if draft.exit then
                local e = vector3(draft.exit.x, draft.exit.y, draft.exit.z)
                line(e - vector3(0, 0, 1.0), e + vector3(0, 0, 1.0), 80, 220, 90)
            end
            if draft.npc then
                local n = vector3(draft.npc.x, draft.npc.y, draft.npc.z)
                line(n - vector3(0, 0, 1.0), n + vector3(0, 0, 1.2), 240, 200, 60)
            end
            for _, id in ipairs(draft.doors) do
                local door = doorCache[id]
                if door then line(me, door.textCoords, 80, 160, 255) end
            end
            Wait(0)
        end
        drawing = false
    end)
end

---------------------------------------------
-- doorman placement (rsg-gizmo Place() only takes props: a local ghost ped is moved with Edit(), like grumpy-pob)
---------------------------------------------
local function placeDoorman(d)
    if exports['rsg-gizmo']:IsActive() then return end
    local hash = joaat(d.model)
    if not IsModelValid(hash) or not IsModelAPed(hash) then return BR.Notify('err_model', 'error') end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then return BR.Notify('err_model', 'error') end

    local me = PlayerPedId()
    local start = d.npc and vector3(d.npc.x, d.npc.y, d.npc.z) or GetOffsetFromEntityInWorldCoords(me, 0.0, 1.5, 0.0)
    local heading = d.npc and d.npc.w or (GetEntityHeading(me) + 180.0)
    local ghost = CreatePed(hash, start.x, start.y, start.z, heading, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ghost or ghost == 0 then return end
    SetRandomOutfitVariation(ghost, true) -- RedM: otherwise peds can spawn invisible
    SetEntityInvincible(ghost, true)
    SetBlockingOfNonTemporaryEvents(ghost, true)
    FreezeEntityPosition(ghost, true)
    local res = exports['rsg-gizmo']:Edit(ghost, {
        title = locale('gizmo_doorman'),
        maxDistance = Config.PlaceDistance, rotation = 'z', startMode = 'free',
    })
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    if res and res.coords then
        d.npc = { x = res.coords.x, y = res.coords.y, z = res.coords.z, w = (res.heading or 0.0) % 360.0 }
    end
end

---------------------------------------------
-- menus
---------------------------------------------
local openList, openEditor

local function openDoorPicker()
    loadDoors()
    local me = GetEntityCoords(PlayerPedId())
    local list = {}
    for id, door in pairs(doorCache) do
        local dist = #(me - door.textCoords)
        if dist <= Config.DoorPickRange or hasDoor(draft, id) then list[#list + 1] = { door = door, dist = dist } end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    local elements = {}
    for _, e in ipairs(list) do
        local on = hasDoor(draft, e.door.id) ~= nil
        elements[#elements + 1] = {
            label = locale(on and 'admin_door_on' or 'admin_door_off', e.door.name or '?', e.door.id, math.floor(e.dist + 0.5)),
            value = e.door.id, desc = locale('admin_door_desc'),
        }
    end
    if #elements == 0 then elements[1] = { label = locale('admin_no_doors'), value = 'none', desc = locale('admin_no_doors_desc') } end

    MenuData.CloseAll()
    MenuData.Open('default', RES, 'doors', {
        title = locale('admin_doors_title'), subtext = locale('admin_doors_sub'), align = 'top-left', elements = elements,
    }, function(data, menu)
        local id = data.current.value
        if type(id) ~= 'number' then return end
        local i = hasDoor(draft, id)
        if i then table.remove(draft.doors, i)
        elseif #draft.doors >= Config.MaxDoors then return BR.Notify('err_doors', 'error')
        else draft.doors[#draft.doors + 1] = id end
        menu.close()
        openDoorPicker()
    end, function(_, menu)
        menu.close()
        openEditor()
    end)
end

local function readHeight(menu)
    for _, el in ipairs(menu.data.elements) do
        if el.value_name == 'height' then draft.height = tonumber(el.value) or draft.height end
    end
end

local function save()
    local ok, res = BR.Await('grumpy-backroom:server:adminSave', payload(draft))
    if ok then
        draft.id = res
        BR.Notify('admin_saved', 'success')
        return true
    end
    BR.Notify(res or 'err_invalid', 'error')
end

openEditor = function()
    if not draft then return end
    startDrawing()
    local d = draft
    local elements = {
        { label = locale('admin_name', d.name), value = 'name', desc = locale('admin_name_desc') },
        { label = locale(d.npc and 'admin_npc_set' or 'admin_npc_unset'), value = 'npc', desc = locale('admin_npc_desc') },
        { label = locale('admin_model', d.model), value = 'model', desc = locale('admin_model_desc') },
        { label = locale('admin_doors', #d.doors), value = 'doors', desc = locale('admin_doors_desc') },
        { label = locale('admin_corner_add', #d.corners), value = 'corner_add', desc = locale('admin_corner_desc') },
        { label = locale('admin_corner_undo'), value = 'corner_undo', desc = '' },
        { label = locale('admin_corner_clear'), value = 'corner_clear', desc = '' },
        { label = locale('admin_height'), type = 'slider', value = d.height, min = Config.Zone.MinHeight,
          max = Config.Zone.MaxHeight, hop = 1, value_name = 'height', desc = locale('admin_height_desc') },
        { label = locale(d.exit and 'admin_exit_set' or 'admin_exit_unset'), value = 'exit', desc = locale('admin_exit_desc') },
        { label = locale(d.enabled and 'admin_enabled_on' or 'admin_enabled_off'), value = 'enabled', desc = locale('admin_enabled_desc') },
        { label = locale('admin_save'), value = 'save', desc = '' },
    }
    if d.id then
        elements[#elements + 1] = { label = locale('admin_test'), value = 'test', desc = locale('admin_test_desc', Config.TestSeconds) }
        elements[#elements + 1] = { label = locale('admin_close_now'), value = 'close', desc = locale('admin_close_desc') }
        elements[#elements + 1] = { label = locale('admin_delete'), value = 'delete', desc = locale('admin_delete_desc') }
    end

    MenuData.CloseAll()
    MenuData.Open('default', RES, 'editor', {
        title = d.id and locale('admin_edit_title', d.id) or locale('admin_new_title'),
        subtext = locale('admin_editor_sub'), align = 'top-left', elements = elements,
    }, function(data, menu)
        readHeight(menu)
        local v = data.current.value
        if data.current.value_name == 'height' then return end -- the slider only changes on left/right
        menu.close()
        CreateThread(function()
            if v == 'name' then
                d.name = textInput(locale('admin_name_prompt'), d.name, 48) or d.name
            elseif v == 'model' then
                local m = textInput(locale('admin_model_prompt'), d.model, 64)
                if m then
                    local hash = joaat(m)
                    if IsModelValid(hash) and IsModelAPed(hash) then d.model = m else BR.Notify('err_model', 'error') end
                end
            elseif v == 'npc' then
                placeDoorman(d)
            elseif v == 'doors' then
                return openDoorPicker()
            elseif v == 'corner_add' then
                if #d.corners >= Config.Zone.MaxCorners then BR.Notify('err_zone', 'error') else
                    local p = myPos()
                    d.corners[#d.corners + 1] = { x = p.x, y = p.y, z = p.z }
                end
            elseif v == 'corner_undo' then
                d.corners[#d.corners] = nil
            elseif v == 'corner_clear' then
                d.corners = {}
            elseif v == 'exit' then
                d.exit = myPos()
            elseif v == 'enabled' then
                d.enabled = not d.enabled
            elseif v == 'save' then
                save()
            elseif v == 'test' or v == 'close' then
                local ok, err = BR.Await('grumpy-backroom:server:adminSetOpen', d.id, v == 'test')
                if ok then BR.Notify(v == 'test' and 'admin_test_done' or 'admin_close_done', 'success', Config.TestSeconds)
                else BR.Notify(err or 'err_invalid', 'error') end
            elseif v == 'delete' then
                if BR.Await('grumpy-backroom:server:adminDelete', d.id) then
                    BR.Notify('admin_deleted', 'success')
                    draft = nil
                    return openList()
                end
            end
            openEditor()
        end)
    end, function(_, menu)
        readHeight(menu)
        menu.close()
        draft = nil
        openList()
    end, function(_, menu)
        readHeight(menu)
    end)
end

openList = function()
    local rooms = BR.Await('grumpy-backroom:server:adminRooms')
    if not rooms then return end
    local elements = { { label = locale('admin_new'), value = 'new', desc = locale('admin_new_desc') } }
    for _, r in ipairs(rooms) do
        local state = not r.usable and locale('admin_state_unfinished')
            or r.left > 0 and locale('admin_state_open', BR.FmtLeft(r.left))
            or locale('admin_state_locked')
        elements[#elements + 1] = { label = ('#%d %s'):format(r.id, r.name), value = r.id, desc = state, room = r }
    end
    MenuData.CloseAll()
    MenuData.Open('default', RES, 'list', {
        title = locale('admin_title'), subtext = locale('admin_sub'), align = 'top-left', elements = elements,
    }, function(data, menu)
        menu.close()
        CreateThread(function()
            loadDoors()
            draft = data.current.value == 'new' and newDraft() or fromRoom(data.current.room)
            openEditor()
        end)
    end, function(_, menu)
        menu.close()
    end)
end

RegisterNetEvent('grumpy-backroom:client:openAdmin', function()
    CreateThread(openList)
end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then draft = nil end
end)
