-- Polygon zone test shared by the server (who gets shown out) and the client (editor preview).
-- zone = { points = { {x, y}, ... }, minZ, maxZ } — a flat polygon extruded from minZ to maxZ.
BackroomZone = {}

function BackroomZone.Valid(zone)
    return type(zone) == 'table' and type(zone.points) == 'table' and #zone.points >= 3
        and type(zone.minZ) == 'number' and type(zone.maxZ) == 'number' and zone.maxZ > zone.minZ
end

function BackroomZone.Contains(zone, c)
    if not BackroomZone.Valid(zone) or not c then return false end
    if c.z < zone.minZ or c.z > zone.maxZ then return false end
    local pts, inside = zone.points, false
    local x, y = c.x, c.y
    local j = #pts
    for i = 1, #pts do
        local a, b = pts[i], pts[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then
            inside = not inside
        end
        j = i
    end
    return inside
end

function BackroomZone.Centre(zone)
    local sx, sy = 0.0, 0.0
    for _, p in ipairs(zone.points) do sx, sy = sx + p.x, sy + p.y end
    local n = #zone.points
    return vector3(sx / n, sy / n, (zone.minZ + zone.maxZ) / 2)
end
