Config = {}

Config.Debug = false
Config.AutoDatabase = true          -- create tables on start; set false and import install.sql to do it by hand

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.SpawnDistance    = 40.0      -- bartender peds spawn when a player is this close (metres)
Config.TargetDistance   = 2.5       -- rsg-target reach on the bartender
Config.ServerDistance   = 5.0       -- server-side tolerance: player must be this close to the bartender / room
Config.AdminPermission  = 'admin'   -- rsg-core permission needed to place, edit, move or delete bartenders
Config.PlaceDistance    = 10.0      -- rsg-gizmo max distance while placing / moving
Config.ManageCommand    = 'bartenders'     -- admin manager panel: list, edit, teleport, duplicate, delete
Config.PlaceCommand     = 'placebartender' -- shortcut straight to the "new bartender" form

---------------------------------------------------------------------
-- Ped models admins may pick in the editor (all from data/rdr3_discoveries/peds/peds_list.lua)
---------------------------------------------------------------------
Config.DefaultModel = 'u_m_m_valbartender_01'
Config.Models = {
    'u_m_m_valbartender_01',
    'u_m_o_valbartender_01',
    'u_m_m_rhdbartender_01',
    'u_m_o_blwbartender_01',
    'u_m_o_armbartender_01',
    'u_m_m_tumbartender_01',
    'u_m_m_nbxbartender_01',
    'u_m_m_nbxbartender_02',
    'u_f_m_tljbartender_01',
    'u_f_m_vhtbartender_01',
}

---------------------------------------------------------------------
-- Animations (presets picked per bartender)
--   type = 'scenario' -> name = scenario type (data/rdr3_discoveries/animations/scenarios/scenario_types_with_conditional_anims.lua)
--   type = 'anim'     -> dict + clip (data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua), flag = eScriptedAnimFlags (1 = loop)
--   type = 'none'     -> stands still
---------------------------------------------------------------------
Config.DefaultAnimation = 'bar_front'
Config.Animations = {
    bar_front   = { type = 'scenario', name = 'WORLD_HUMAN_BARTENDER' },
    clean_glass = { type = 'scenario', name = 'WORLD_HUMAN_BARTENDER_CLEAN_GLASS' },
    pre_service = { type = 'anim', dict = 'amb_work@world_human_bartender@pre_service@male_a@idle_a', clip = 'idle_a', flag = 1 },
    none        = { type = 'none' },
}

---------------------------------------------------------------------
-- Automatic bar shop ("Create bar shop" in the editor). Needs part 2 of integrations/rsg-stores.md.
-- Creates a buy-only rsg-stores shop at the bartender with no shopkeeper ped. Edit it later in /createshop.
-- Item names are from rsg-core/shared/items.lua (all consumables in rsg-consume). amount = stock (omit = unlimited).
---------------------------------------------------------------------
Config.BarShop = {
    Enabled             = true,
    DeleteWithBartender = true,     -- deleting a bartender also deletes the shop it created (never a shop you linked by hand)
    Items = {   -- 1890s prices: The Territories pricing doctrine (cheap meal $0.05-0.10)
        { name = 'bottle_beer',      price = 0.10 },
        { name = 'glass_whisky',     price = 0.15 },
        { name = 'glass_gin',        price = 0.15 },
        { name = 'glass_rum',        price = 0.15 },
        { name = 'glass_wine_red',   price = 0.20 },
        { name = 'glass_wine_white', price = 0.20 },
        { name = 'coffee',           price = 0.05 },
        { name = 'water',            price = 0.05 },
        { name = 'stew',             price = 0.10 },
        { name = 'bread',            price = 0.05 },
        { name = 'cooked_meat',      price = 0.10 },
    },
}

---------------------------------------------------------------------
-- Blip shown on every bartender that has `blip = true` in its services
---------------------------------------------------------------------
Config.Blip = {
    sprite = 'blip_saloon',          -- blip sprite name (data/rdr3_discoveries/useful_info_from_rpfs)
    scale  = 0.2,
}

---------------------------------------------------------------------
-- Static bartenders (optional). Admins can also place bartenders in game with /placebartender;
-- those are saved in the database. Get coords with /placebartender (they are printed to F8 when placed).
--   coords   = vector4(x, y, z, heading)   -- ped position as returned by GetEntityCoords (feet + ~1m)
--   services = { store = <rsg-stores NPC id or false>, hotel = <grumpy-hotel id (see /hotellist)> or false,
--                lottery = true/false, loyalty = true/false, blip = true/false }
---------------------------------------------------------------------
Config.Bartenders = {
    -- valentine_saloon = {
    --     label     = 'Smithfield\'s Saloon',
    --     model     = 'u_m_m_valbartender_01',
    --     animation = 'bar_front',
    --     coords    = vector4(0.0, 0.0, 0.0, 0.0), -- replace with your own position
    --     services  = { store = 1, hotel = 1, lottery = true, loyalty = true, blip = true },
    -- },
}

