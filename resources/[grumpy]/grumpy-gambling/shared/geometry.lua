-- Table-local <-> world maths, shared by client and server.
-- Local offsets: x = right of the table, y = forward (the table's heading), z = up, h = heading relative to the table.
-- RedM headings: 0 = north, counter-clockwise; forward = (-sin h, cos h), right = (cos h, sin h).
Geo = {}

local rad, sin, cos = math.rad, math.sin, math.cos

function Geo.Wrap(h)
    h = (tonumber(h) or 0.0) % 360.0
    if h < 0 then h = h + 360.0 end
    return h
end

-- origin: { x, y, z }, heading: degrees, off: { x, y, z, h } -> x, y, z, heading
function Geo.ToWorld(origin, heading, off)
    local a = rad(heading or 0.0)
    local s, c = sin(a), cos(a)
    local ox, oy, oz = off.x or 0.0, off.y or 0.0, off.z or 0.0
    return origin.x + ox * c - oy * s,
           origin.y + ox * s + oy * c,
           origin.z + oz,
           Geo.Wrap((heading or 0.0) + (off.h or 0.0))
end

-- world point + heading -> local offset { x, y, z, h }
function Geo.ToLocal(origin, heading, wx, wy, wz, wh)
    local a = rad(heading or 0.0)
    local s, c = sin(a), cos(a)
    local dx, dy = wx - origin.x, wy - origin.y
    local function r4(n) return math.floor(n * 10000 + 0.5) / 10000 end
    local h = Geo.Wrap((wh or 0.0) - (heading or 0.0))
    if h > 180.0 then h = h - 360.0 end
    return { x = r4(dx * c + dy * s), y = r4(-dx * s + dy * c), z = r4(wz - origin.z), h = r4(h) }
end

-- Seats facing the table centre, evenly spaced on a circle. startH/stepH are headings relative to the table.
function Geo.Ring(count, radius, startH, stepH, z)
    local seats = {}
    for i = 1, count do
        local h = (startH or 0.0) + (stepH or (360.0 / count)) * (i - 1)
        local a = rad(h)
        -- a seat facing heading h sits "behind" the centre along that heading
        seats[i] = { x = radius * sin(a), y = -radius * cos(a), z = z or 0.0, h = h }
    end
    return seats
end
