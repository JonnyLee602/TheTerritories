-- Table model profiles (DESIGN.md §5.3). All models verified in data/rdr3_discoveries/objects/object_list.lua.
--
-- Offsets are table-local (see shared/geometry.lua): x right, y forward, z up from the table origin, h relative heading.
--   seats[i]  where chair i stands (on the floor) and the heading a seated player faces
--   sitZ      height above the chair position where the seated scenario runs
--   chair     chair prop spawned at each seat; nil when the table model already includes its chairs
--   ghostChair  model shown while calibrating when `chair` is nil
--   chairYaw  degrees added to a seat's heading to rotate the chair prop (180 if the chair model faces backwards)
--   dealer    the dealer's spot (PVD), facing the players. Seated dealer (Config.Dealer.Seated): x/y is the chair,
--             on the table's floor (z ignored). Standing dealer: z is the ped's root (about 1 m above the floor)
--   spawn     true = offered when placing a new table; false = only recognised when binding a map table
--   autoChairs  map tables only: when an admin binds this model, every `chair` model within `radius` m of the
--             table becomes a seat automatically (facing the table centre), so map tables need no calibration
--
-- SEED VALUES: derived from Nt_Blackjack / Nt_Holdem world coords (reference only), not measured on these models.
-- Measure each model in game with /gambling -> table -> Calibrate, then either keep the result in the database
-- ("Save as model default") or paste the Lua it prints over the entry below.
Models = {
    ---------------------------------------------------------------------------------------------------------------
    -- Spawnable (offered in /gambling -> New -> Place new table)
    ---------------------------------------------------------------------------------------------------------------
    -- PVP: the saloon card table used on the map (Smithfields, Valentine: 0x64029C9A) with its own chairs,
    -- p_windsorchair03x (0x1362F745). NT Smithfields: chairs ~1.23 m from the centre, 60° apart.
    -- When bound to a map table, the map's chairs become the seats (autoChairs).
    p_tablepoker01x = {
        kind = 'pvp', label = 'Saloon card table', spawn = true,
        chair = 'p_windsorchair03x', sitZ = 0.5, chairYaw = 180.0, -- windsor chair model faces backwards (seen in game)
        seats = Geo.Ring(6, 1.23, 0.0, 60.0, 0.0),
        autoChairs = { radius = 1.7 },
        -- TUMBLEWEED SALOON CARDROOM PVP TABLE (map table). Measured in game by the owner 2026-11-06 with "Calibrate
        -- this table". Reference only: it lives in that table's own calibration in the database. If the table is ever
        -- re-bound, Calibrate this table (not the model default) to these values:
        --   seats = {
        --       { x = 0.4019, y = -1.1029, z = -0.0100, h = 20.0219 },
        --       { x = 1.1523, y = -0.1866, z = 0.0000, h = 80.8015 },
        --       { x = 0.7531, y = 0.9375, z = 0.0000, h = 141.2249 },
        --       { x = -0.4673, y = 1.1861, z = 0.0000, h = -158.4965 },
        --       { x = -1.1458, y = 0.2306, z = 0.0000, h = -101.3792 },
        --       { x = -0.7673, y = -0.8985, z = 0.0000, h = -40.4966 },
        --   },
    },
    -- PVD: four-seat blackjack table. Players sit on the curved side (-y), the dealer stands at the straight edge (+y)
    -- facing them. The model comes WITH its own four windsor chairs, so no chair props are spawned (chair = nil).
    -- MEASURED in game 2026-11-05 (Calibrate model default over the built-in chairs, seats facing the table centre;
    -- second pass with the seated dealer's chair).
    p_blackjacktable01x = {
        kind = 'pvd', label = 'Blackjack table', spawn = true,
        chipForward = 0.42,  -- the player's chips right in front of them; cards and the bet lie further in (grumpy-blackjack)
        chair = nil, ghostChair = 'p_windsorchair03x', sitZ = 0.5, chairYaw = 0.0,
        seats = {
            -- measured in game by the owner (2026-11-06, recalibrated)
            { x = 1.1291, y = 0.1701, z = 0.0000, h = 98.5672 },
            { x = 0.5917, y = -0.5665, z = 0.0000, h = 46.2464 },
            { x = -0.5911, y = -0.5234, z = 0.0000, h = -48.4761 },
            { x = -1.1484, y = 0.1851, z = 0.0000, h = -99.1562 },
        },
        dealer = { x = 0.0180, y = 0.7344, z = 0.0000, h = 178.5960 },   -- seated dealer's chair
        -- binding a map table of this shape by hand (Blackwater saloon: built into the interior with loose windsor
        -- chairs): the ghostChair chairs around it become the seats, the one behind the straight edge the dealer's
        autoChairs = { radius = 1.7 },
        -- BLACKWATER SALOON PVD TABLE (map table, bound by hand as this model). Measured in game by the owner
        -- 2026-11-06 with "Calibrate this table". Reference only: it lives in that table's own calibration in the
        -- database. If the table is ever re-bound, Calibrate this table (not the model default) to these values:
        --   seats = {
        --       { x = 1.2254, y = 0.0177, z = -0.0500, h = 90.8275 },
        --       { x = 0.5719, y = -0.7217, z = -0.0400, h = 38.3945 },
        --       { x = -0.4225, y = -0.8031, z = -0.0100, h = -27.7482 },
        --       { x = -1.1949, y = -0.1278, z = -0.0200, h = -83.8952 },
        --   },
        --   dealer = { x = -0.0911, y = 1.0146, z = 0.0000, h = -174.8692 },
    },

    ---------------------------------------------------------------------------------------------------------------
    -- Bind only (recognised as map tables by "Use the map table I'm next to", never spawned)
    ---------------------------------------------------------------------------------------------------------------
    p_pokertable01x = {
        kind = 'pvp', label = 'Poker table',
        chair = 'p_chairpokerfancy01x', sitZ = 0.5, chairYaw = 0.0,
        seats = Geo.Ring(6, 1.28, 0.0, 60.0, 0.0),
    },
    p_gen_tablepoker01x = {
        kind = 'pvp', label = 'Poker table (plain)',
        chair = 'p_gen_chairpokerfancy01x', sitZ = 0.5, chairYaw = 0.0,
        seats = Geo.Ring(6, 1.28, 0.0, 60.0, 0.0),
    },
    -- Saint Denis-style fancy poker tables (two variants of the same table) with p_chairpokerfancy01x (map chairs)
    p_tablepoker04x = {
        kind = 'pvp', label = 'Fancy poker table',
        chair = 'p_chairpokerfancy01x', sitZ = 0.5, chairYaw = 0.0,
        seats = Geo.Ring(6, 1.35, 0.0, 60.0, 0.0),
        autoChairs = { radius = 1.9 },
    },
    p_tablepoker04ax = {
        kind = 'pvp', label = 'Fancy poker table (alt)',
        chair = 'p_chairpokerfancy01x', sitZ = 0.5, chairYaw = 0.0,
        seats = Geo.Ring(6, 1.35, 0.0, 60.0, 0.0),
        autoChairs = { radius = 1.9 },
    },
    -- Fancy blackjack table, sat on the map with p_chaircomfy04x armchairs
    p_blackjacktable02x = {
        kind = 'pvd', label = 'Blackjack table (fancy)',
        chipForward = 0.42,
        chair = 'p_chaircomfy04x', sitZ = 0.5, chairYaw = 0.0,
        seats = Geo.Ring(4, 1.377, 67.5, -45.0, 0.0),
        dealer = { x = 0.0, y = 1.0, z = 1.0, h = 180.0 },  -- moved back 0.43 m (seen in game 2026-11-06: was inside the table)
        autoChairs = { radius = 1.9 },
    },
    -- Roulette: no chairs on the map (players stand). SEED seats along the front edge and the croupier behind the
    -- wheel: calibrate in game. No game uses it until the roulette module exists.
    p_roulettetable01x = {
        kind = 'pvd', label = 'Roulette table',
        chair = nil, ghostChair = 'p_chairpokerfancy01x', sitZ = 0.5, chairYaw = 0.0,
        seats = {
            { x = -0.60, y = -0.85, z = 0.0, h = 0.0 },
            { x = 0.00, y = -0.85, z = 0.0, h = 0.0 },
            { x = 0.60, y = -0.85, z = 0.0, h = 0.0 },
            { x = 1.20, y = -0.85, z = 0.0, h = 0.0 },
        },
        dealer = { x = 0.0, y = 0.75, z = 1.0, h = 180.0 },
    },
}

-- Spawnable model names of one kind, sorted, for the admin panel.
function ModelsOfKind(kind)
    local list = {}
    for name, m in pairs(Models) do
        if m.kind == kind and m.spawn then list[#list + 1] = { name = name, label = m.label } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end
