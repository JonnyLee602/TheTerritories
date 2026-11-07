-- [grumpy-maphide patch] Props to hide inside the sdl_tlanding MLO (C'sky / Peashooterrr Thieves Landing).
-- Each entry hides ONE model within `radius` metres of `coords`. Other props stay.
-- Model names: data/rdr3_discoveries/objects/object_list.lua (brain repo).
-- Coords: the_saloon.ytyp local positions + MLO origin (-1395.38, -2316.86, 44.24),
--         origin fitted to the three saloon p_door04x positions in the MLO README (rotation 0).

GrumpyHide = {}

GrumpyHide.Radius      = 0.3   -- default hide radius (m) per entry
GrumpyHide.CheckRange  = 60.0  -- re-apply hides while the player is within this distance of an entry
GrumpyHide.CheckEvery  = 2000  -- ms between distance checks
GrumpyHide.Debug       = false -- print each hide to F8

GrumpyHide.Props = {
    -- Saloon poker table (p_tablepoker01x at -1399.19, -2314.00, 42.53): clear the table top
    { model = 'p_bottleBeer01a',            coords = vector3(-1399.71, -2313.51, 43.33) },
    { model = 'p_bottleBeer01a',            coords = vector3(-1398.49, -2313.85, 43.33) },
    { model = 'p_pokerchipwinningstack01x', coords = vector3(-1399.25, -2314.15, 43.33) },
    { model = 'p_gen_pokerchipante01x',     coords = vector3(-1399.07, -2314.07, 43.33) },
    { model = 'p_gen_pokerchipavarage01x',  coords = vector3(-1399.22, -2313.94, 43.33) },
    { model = 'p_cards_cs01x',              coords = vector3(-1398.74, -2314.46, 43.33) },
    { model = 'p_ashtray01x',               coords = vector3(-1398.58, -2313.72, 43.33) },
}
