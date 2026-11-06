-- Cards, decks and shoes. A card is { r = 2..14, s = 'c'|'d'|'h'|'s' } (11 J, 12 Q, 13 K, 14 A).
local Cards = {}
GGLib.Cards = Cards

Cards.Suits = { 'c', 'd', 'h', 's' }
Cards.RankChars = { [2] = '2', [3] = '3', [4] = '4', [5] = '5', [6] = '6', [7] = '7', [8] = '8', [9] = '9',
    [10] = 'T', [11] = 'J', [12] = 'Q', [13] = 'K', [14] = 'A' }
local fromChar = {}
for r, c in pairs(Cards.RankChars) do fromChar[c] = r end

function Cards.New(r, s) return { r = r, s = s } end

-- 'As' / 'Td' -> card (handy in tests)
function Cards.Parse(str)
    local rc, s = str:sub(1, 1):upper(), str:sub(2, 2):lower()
    local r = fromChar[rc]
    if not r or not (s == 'c' or s == 'd' or s == 'h' or s == 's') then return nil end
    return { r = r, s = s }
end

function Cards.Str(card) return card and (Cards.RankChars[card.r] .. card.s) or '??' end

-- What clients see: rank char + suit, or a face-down card
function Cards.Public(card, faceUp)
    if not card or faceUp == false then return { down = true } end
    return { r = Cards.RankChars[card.r], s = card.s }
end

function Cards.PublicList(list, faceUp)
    local out = {}
    for i, c in ipairs(list or {}) do out[i] = Cards.Public(c, faceUp) end
    return out
end

-- A shuffled shoe of `decks` 52-card decks. Cards are dealt in order; nothing is ever picked at random mid-hand.
local Shoe = {}
Shoe.__index = Shoe

function Cards.NewShoe(decks)
    local cards = {}
    for _ = 1, math.max(1, decks or 1) do
        for _, s in ipairs(Cards.Suits) do
            for r = 2, 14 do cards[#cards + 1] = { r = r, s = s } end
        end
    end
    GGLib.Shuffle(cards)
    return setmetatable({ cards = cards, pos = 1, size = #cards }, Shoe)
end

function Shoe:Draw()
    local c = self.cards[self.pos]
    if not c then return nil end
    self.pos = self.pos + 1
    return c
end

function Shoe:Remaining() return self.size - self.pos + 1 end
