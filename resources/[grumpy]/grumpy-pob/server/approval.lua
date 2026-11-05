-- Approval of custom recipes and their images: in game (/pob), on Discord (bot + ✅/❌ reactions,
-- polled over REST, no gateway needed) or automatically after a timeout.
local RSGCore = POB.Core()

local Approval = {}
POB.Approval = Approval

local A = Config.Approval
local DC = SvConfig.Discord
local API = 'https://discord.com/api/v10'
local YES, NO = '%E2%9C%85', '%E2%9D%8C' -- ✅ ❌ url-encoded

local function discordOn()
    return A.Discord.Enabled and DC.BotToken ~= '' and DC.ChannelId ~= '' and DC.GuildId ~= ''
end

local function discord(method, path, body, cb)
    PerformHttpRequest(API .. path, function(status, text)
        local ok, data = pcall(json.decode, text or '')
        if status < 200 or status >= 300 then POB.Debug('discord', method, path, status, text) end
        if cb then cb(status, ok and data or nil) end
    end, method, body and json.encode(body) or '', {
        ['Authorization'] = 'Bot ' .. DC.BotToken, ['Content-Type'] = 'application/json', ['User-Agent'] = 'DiscordBot (grumpy-pob, 1.0)',
    })
end

local function await(method, path, body)
    local p = promise.new()
    discord(method, path, body, function(status, data) p:resolve({ status = status, data = data }) end)
    return Citizen.Await(p)
end

---------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------
local COLORS = { pending = 0xd9a441, approved = 0x6fbf73, rejected = 0xe0554f }

local function embed(r, biz, submitter, statusText, color)
    local ings = {}
    for n, a in pairs(r.ingredients) do ings[#ings + 1] = ('%dx %s'):format(a, POB.ItemLabel(n)) end
    local e = {
        title = locale('dc_title', r.label),
        description = r.description ~= '' and r.description or nil,
        color = color,
        fields = {
            { name = locale('dc_business'), value = ('%s (#%d)'):format(biz and biz.label or '?', r.biz), inline = true },
            { name = locale('dc_submitted'), value = submitter or r.createdBy or '?', inline = true },
            { name = locale('dc_base'), value = POB.ItemLabel(r.base), inline = true },
            { name = locale('dc_ingredients'), value = table.concat(ings, '\n'), inline = true },
            { name = locale('dc_output'), value = ('%dx, %.1fs'):format(r.amount, r.time / 1000), inline = true },
            { name = locale('dc_status'), value = statusText },
        },
        footer = { text = locale('dc_footer') },
    }
    if r.imageUrl and r.imageUrl:find('^https://') then e.image = { url = r.imageUrl } end
    return e
end

local function statusText(r)
    if r.status == 'pending' then return locale('dc_pending') end
    local s = locale(r.status == 'approved' and 'dc_approved' or 'dc_rejected', r.decidedBy or '?')
    if r.status == 'approved' and r.imageStatus == 'pending' then s = s .. '\n' .. locale('dc_image_pending') end
    if r.imageStatus == 'approved' then s = s .. '\n' .. locale('dc_image_approved') end
    if r.imageStatus == 'rejected' then s = s .. '\n' .. locale('dc_image_rejected') end
    return s
end

local function post(r, biz, submitter)
    if not discordOn() then return end
    CreateThread(function()
        local res = await('POST', ('/channels/%s/messages'):format(DC.ChannelId), {
            embeds = { embed(r, biz, submitter, statusText(r), COLORS.pending) },
        })
        local msgId = res.data and res.data.id
        if not msgId then return end
        r.discordMsg = msgId
        POB.Recipes.Save(r)
        await('PUT', ('/channels/%s/messages/%s/reactions/%s/@me'):format(DC.ChannelId, msgId, YES))
        Wait(500)
        await('PUT', ('/channels/%s/messages/%s/reactions/%s/@me'):format(DC.ChannelId, msgId, NO))
    end)
end

local function updateMessage(r)
    if not discordOn() or not r.discordMsg then return end
    local color = r.status == 'approved' and COLORS.approved or r.status == 'rejected' and COLORS.rejected or COLORS.pending
    discord('PATCH', ('/channels/%s/messages/%s'):format(DC.ChannelId, r.discordMsg),
        { embeds = { embed(r, POB.Biz(r.biz), nil, statusText(r), color) } })
end

---------------------------------------------------------------------
-- Decisions
---------------------------------------------------------------------
local function tellBusiness(r, key, ...)
    local biz = POB.Biz(r.biz)
    if not biz then return end
    local args = { ... }
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        local held, grade = exports['rsg-core']:HasPlayerJob(P.PlayerData.source, biz.job)
        if held and POB.HasPerm(grade, 'recipes') then POB.Notify(P.PlayerData.source, locale(key, table.unpack(args)), 'inform') end
    end
end

function Approval.ApproveItem(r, by, withImage)
    if r.status ~= 'pending' then return end
    r.status, r.decidedBy = 'approved', by
    if r.imageStatus == 'pending' and withImage then r.imageStatus = 'approved' end
    POB.Recipes.Save(r)
    POB.Recipes.Register(r)
    updateMessage(r)
    tellBusiness(r, 'recipe_approved', r.label)
    print(('[grumpy-pob] recipe %d "%s" approved by %s'):format(r.id, r.label, by))
end

function Approval.RejectItem(r, by)
    if r.status ~= 'pending' then return end
    r.status, r.decidedBy = 'rejected', by
    if r.imageId then POB.Recipes.DeleteImage(r.imageId) end
    if r.imageStatus == 'pending' then r.imageStatus = 'rejected' end
    POB.Recipes.Save(r)
    updateMessage(r)
    tellBusiness(r, 'recipe_rejected', r.label)
end

function Approval.ApproveImage(r, by)
    if r.imageStatus ~= 'pending' then return end
    r.imageStatus = 'approved'
    r.decidedBy = r.decidedBy or by
    POB.Recipes.Save(r)
    if r.status == 'approved' or r.status == 'retired' then POB.Recipes.Register(r) end
    updateMessage(r)
    tellBusiness(r, 'image_approved', r.label)
end

function Approval.RejectImage(r, by)
    if r.imageStatus ~= 'pending' then return end
    if r.imageId then POB.Recipes.DeleteImage(r.imageId) end
    r.imageStatus, r.imageUrl, r.imageId = 'rejected', nil, nil
    POB.Recipes.Save(r)
    if r.status == 'approved' or r.status == 'retired' then POB.Recipes.Register(r) end
    updateMessage(r)
    tellBusiness(r, 'image_rejected', r.label)
end

local function blocked(r)
    local text = (r.label .. ' ' .. r.description):lower()
    for _, w in ipairs(Config.CustomRecipes.BlockedWords or {}) do
        if w ~= '' and text:find(w:lower(), 1, true) then return true end
    end
    return false
end

local function adminsOnline()
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        if POB.IsAdmin(P.PlayerData.source) then return true end
    end
    return false
end

function Approval.Submit(r, biz, submitter)
    if blocked(r) then return Approval.RejectItem(r, locale('by_filter')) end
    if A.Mode == 'auto' then
        Approval.ApproveItem(r, locale('by_auto'), not A.ImagesNeedHuman)
        if r.imageStatus == 'pending' then post(r, biz, submitter) end
        return
    end
    post(r, biz, submitter)
    tellBusiness(r, 'recipe_submitted', r.label)
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        if POB.IsAdmin(P.PlayerData.source) then POB.Notify(P.PlayerData.source, locale('admin_recipe_waiting', r.label, biz.label), 'inform') end
    end
end

---------------------------------------------------------------------
-- Timed auto-approval
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        if POB.Ready and A.Mode == 'timed' then
            local now, admins = os.time(), nil
            for _, r in pairs(POB.Recipes.All()) do
                if r.status == 'pending' and now - r.createdAt >= A.AutoApproveMinutes * 60 then
                    if admins == nil then admins = adminsOnline() end
                    if not (A.AutoApproveOnlyIfNoAdminOnline and admins) then
                        Approval.ApproveItem(r, locale('by_auto'), not A.ImagesNeedHuman)
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Discord reaction polling
---------------------------------------------------------------------
local roleCache = {} -- [userId] = { ok = bool, at = os.time() }

local function isApprover(userId)
    local c = roleCache[userId]
    if c and os.time() - c.at < 300 then return c.ok end
    local res = await('GET', ('/guilds/%s/members/%s'):format(DC.GuildId, userId))
    local ok = false
    for _, role in ipairs(res.data and res.data.roles or {}) do
        for _, want in ipairs(DC.ApproverRoles) do if tostring(role) == tostring(want) then ok = true end end
    end
    roleCache[userId] = { ok = ok, at = os.time() }
    return ok
end

local function firstApprover(msgId, emoji)
    local res = await('GET', ('/channels/%s/messages/%s/reactions/%s?limit=50'):format(DC.ChannelId, msgId, emoji))
    if type(res.data) ~= 'table' then return nil end
    for _, user in ipairs(res.data) do
        if type(user) == 'table' and not user.bot and user.id and isApprover(user.id) then
            return 'Discord: ' .. (user.global_name or user.username or user.id)
        end
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(math.max(10, A.Discord.PollSeconds) * 1000)
        if POB.Ready and discordOn() then
            local now = os.time()
            for _, r in pairs(POB.Recipes.All()) do
                local watching = r.discordMsg and (r.status == 'pending'
                    or (r.status == 'approved' and r.imageStatus == 'pending' and now - r.createdAt < A.Discord.ImagePollHours * 3600))
                if watching then
                    local no = firstApprover(r.discordMsg, NO)
                    local yes = not no and firstApprover(r.discordMsg, YES)
                    if r.status == 'pending' then
                        if no then Approval.RejectItem(r, no) elseif yes then Approval.ApproveItem(r, yes, true) end
                    else
                        if no then Approval.RejectImage(r, no) elseif yes then Approval.ApproveImage(r, yes) end
                    end
                    Wait(1000) -- stay well under Discord rate limits
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- In-game admin approval (/pob -> Recipes)
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-pob:server:adminRecipes', function(source, cb)
    if not POB.IsAdmin(source) then return cb(nil) end
    local out = {}
    for _, r in pairs(POB.Recipes.All()) do
        if r.status == 'pending' or (r.status == 'approved' and r.imageStatus == 'pending') then
            local ings = {}
            for n, a in pairs(r.ingredients) do ings[#ings + 1] = ('%dx %s'):format(a, POB.ItemLabel(n)) end
            local biz = POB.Biz(r.biz)
            out[#out + 1] = { id = r.id, label = r.label, description = r.description, base = POB.ItemLabel(r.base),
                business = biz and biz.label or '?', status = r.status, imageStatus = r.imageStatus,
                image = r.imageStatus == 'pending' and r.imageUrl or nil, ingredients = table.concat(ings, ', '),
                amount = r.amount, time = r.time }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    cb(out)
end)

RegisterNetEvent('grumpy-pob:server:adminRecipeDecide', function(rid, what, approve)
    local src = source
    if not POB.IsAdmin(src) or POB.Cooldown(src, 'decide', 500) then return end
    local r = POB.Recipes.Get(rid)
    if not r then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local by = Player and POB.PlayerName(Player) or GetPlayerName(src)
    if what == 'item' then
        if approve == true then Approval.ApproveItem(r, by, true) else Approval.RejectItem(r, by) end
    elseif what == 'image' then
        if approve == true then Approval.ApproveImage(r, by) else Approval.RejectImage(r, by) end
    end
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'admin')
end)
