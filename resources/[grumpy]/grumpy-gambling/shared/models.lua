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
    p_blackjacktable02x = {
        kind = 'pvd', label = 'Blackjack table (alt)',
        chipForward = 0.42,
        chair = 'p_chairpokerfancy01x', sitZ = 0.5, chairYaw = 0.0,
        seats = Geo.Ring(4, 1.377, 67.5, -45.0, 0.0),
        dealer = { x = 0.0, y = 0.574, z = 1.0, h = 180.0 },
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
