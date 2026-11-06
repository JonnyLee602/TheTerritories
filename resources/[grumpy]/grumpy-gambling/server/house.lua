-- The house at PVD tables (DESIGN.md §7.6). Public and Micro tables: the server (wins are created, losses
-- destroyed). Business tables (phase 6): the owner's cashbox, which must cover every bet before it's taken.
local House = { boxes = {} }
GG.House = House

function House.IsCashbox(t) return t.source == 'business' end

function House.Balance(t)
    if not House.IsCashbox(t) then return math.maxinteger end
    if House.boxes[t.id] == nil then House.boxes[t.id] = GG.DB.CashboxGet(t.id) end
    return House.boxes[t.id]
end

-- Can the house take on `extraC` more worst-case exposure on top of what open hands already reserved?
function House.CanCover(t, extraC)
    if not House.IsCashbox(t) then return true end
    return House.Balance(t) - GG.Hands.Reserved(t.id) >= extraC
end

-- After a settlement committed: keep the cached balance in step with the database
function House.Applied(t, deltaC)
    if House.IsCashbox(t) and House.boxes[t.id] then House.boxes[t.id] = House.boxes[t.id] + deltaC end
end
