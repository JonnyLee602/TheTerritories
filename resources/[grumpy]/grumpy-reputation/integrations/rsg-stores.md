# rsg-stores patch: honor / infamy prices (grumpy-reputation)

Makes rsg-stores **NPC shops** charge and pay by the standing of the player at the counter
(doctrine/pricing.md section 2). Player-owned stores and grumpy-pob businesses are never changed.
Works alongside rsg-stores' own job/gang discount and alongside the grumpy-pob / grumpy-bartender patches.

These are local changes to an RSG resource: re-apply after updating rsg-stores, or offer them upstream.
Don't redistribute a modified rsg-stores. If grumpy-reputation is stopped, the patched code behaves like the original.

## server/server.lua

1. **Above** the line `-- Positive whole number within [1, MAX_QTY], else nil (blocks 1.5 / -1 / NaN / huge).` add:

```lua
-- grumpy-reputation: honor/infamy buy and sell multipliers for an NPC shop (1.0, 1.0 when not running)
local function standingMults(src, npc)
    if not npc or npc.kind ~= 'npc' or not npc.shop or GetResourceState('grumpy-reputation') ~= 'started' then return 1.0, 1.0 end
    local ok, buy, sell = pcall(function() return exports['grumpy-reputation']:GetShopMultipliers(src, npc.shop.name) end)
    if not ok or type(buy) ~= 'number' or type(sell) ~= 'number' then return 1.0, 1.0 end
    return buy, sell
end

-- cheapest price any open store (or wholesale) sells an item for; caps honor sell bonuses
local function cheapestBuy(name)
    local c
    for _, n in ipairs(CachedNPCs) do
        if n.shop and not n.packed and n.shop.type ~= 'sell' then
            for _, it in ipairs(n.shop.items) do
                local p = tonumber(it.price) or 0
                if it.name == name and p > 0 and (not c or p < c) then c = p end
            end
        end
    end
    local w = Config.Wholesale or {}
    local wc = w.Enabled ~= false and w.Items and tonumber(w.Items[name])
    if wc and wc > 0 and (not c or wc < c) then c = wc end
    return c
end

local function arbitrageFactor()
    local ok, f = pcall(function() return exports['grumpy-reputation']:GetArbitrageFactor() end)
    return ok and tonumber(f) or 0.7
end
```

2. In `rsg-stores:server:sellItem`, find:

```lua
    if not isOwned then pct = pct * (1 - discountFor(Player)) end
```

   and **directly below it** add:

```lua
    -- grumpy-reputation: honor/infamy sell multiplier. Honorable players buy at a discount, so no one
    -- (any standing) is paid more per unit than the cheapest discounted price the item sells for anywhere.
    -- Otherwise a player could buy at 75% and sell back at 80%. Items no store sells are never capped.
    if not isOwned and shopItem.price > 0 and GetResourceState('grumpy-reputation') == 'started' then
        local _, sellMult = standingMults(src, npc)
        local unit = shopItem.price * pct * sellMult
        local cheapest = cheapestBuy(itemName)
        if cheapest then unit = math.min(unit, cheapest * arbitrageFactor()) end
        pct = unit / shopItem.price
    end
```

3. In `rsg-stores:server:purchaseCart`, replace:

```lua
        local unit = round2(shopItem.price * (1 - disc))
```

   with:

```lua
        local unit = round2(shopItem.price * (1 - disc) * sBuy)
```

   and **directly above** the line `local disc = npc.kind == 'npc' and discountFor(Player) or 0` add:

```lua
    local sBuy = (standingMults(src, npc))
```

## client/client.lua

1. **Above** `local function formatShopItems(items, discount)` add:

```lua
-- grumpy-reputation: display-only honor/infamy multipliers (the server works out the real price)
local function standingMults(npc)
    if not npc or npc.kind == 'player' or not npc.shop or GetResourceState('grumpy-reputation') ~= 'started' then return 1.0, 1.0 end
    local ok, buy, sell = pcall(function() return exports['grumpy-reputation']:GetShopMultipliers(npc.shop.name) end)
    if not ok or type(buy) ~= 'number' or type(sell) ~= 'number' then return 1.0, 1.0 end
    return buy, sell
end
```

2. In `formatShopItems`, replace `price = d > 0 and` with `price = d ~= 0 and` (a markup is a negative discount).

3. In `OpenCustomShop`, replace:

```lua
    local disc = myDiscount(npcData)
    currentShop.discount = disc
```

   with:

```lua
    local disc = myDiscount(npcData)
    local sBuy, sSell = standingMults(npcData)
    currentShop.discount = 1 - (1 - disc) * sBuy   -- job/gang discount and standing in one factor
    if sBuy ~= 1.0 then pcall(function() exports['grumpy-reputation']:ShopGreeting(npcData.shop.label, sBuy) end) end
```

4. In the same function, replace:

```lua
    local pct = npcData.kind == 'player' and (tonumber(OS.BuyBackPercentage) or SELL_PCT) or SELL_PCT * (1 - disc)
```

   with:

```lua
    local pct = npcData.kind == 'player' and (tonumber(OS.BuyBackPercentage) or SELL_PCT) or SELL_PCT * (1 - disc) * sSell
```

## Check it worked
- `/setstanding <id> 1000`, open a general store: prices show 25% off and a "They know your name here" notice.
- `/setstanding <id> -1000`: prices are 50% higher; selling pays half.
- Name a shop in `Config.Pricing.Shops` as `'underground'` and the effect flips.
- A grumpy-pob business shop (`pob_*`) shows normal prices for everyone.

## Known limits
- **Selling back store goods pays less than before.** While grumpy-reputation runs, an item that any store sells pays
  at most `cheapest price x 0.75 x 0.95` (about 71%, was 80%), whatever the seller's standing. This closes the
  buy-at-75%, sell-at-80% loop. Gathered goods no store sells (pelts, ore, fish) get the full honor bonus.
- The sell preview doesn't know about that cap. The server pays the capped amount and the "Sold ..." message shows it.
  The message shows a negative shop fee when the bonus is bigger than the fee.
- Standing changes while the shop is open apply to the next purchase (the server always uses the current standing).
