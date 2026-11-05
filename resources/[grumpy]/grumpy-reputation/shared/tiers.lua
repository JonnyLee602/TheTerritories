-- shared helpers (client + server)
Rep = Rep or {}

function Rep.Clamp(v)
    v = tonumber(v) or Config.Standing.Start
    return math.max(Config.Standing.Min, math.min(Config.Standing.Max, math.floor(v + 0.5)))
end

---@return string name, number index
function Rep.TierFor(value)
    value = tonumber(value) or 0
    for i, t in ipairs(Config.Tiers) do
        if value >= t.min then return t.name, i end
    end
    local last = #Config.Tiers
    return Config.Tiers[last].name, last
end

function Rep.TierRange(name)
    for i, t in ipairs(Config.Tiers) do
        if t.name == name then
            local above = Config.Tiers[i - 1]
            return t.min, above and (above.min - 1) or Config.Standing.Max
        end
    end
end
