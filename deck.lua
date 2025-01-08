Deck = {}
Deck.__index = Deck

function Deck.new()
    local self = setmetatable({}, Deck)
    self.cards = {}
    local suits = {"hearts", "diamonds", "clubs", "spades"}
    local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"}

    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            table.insert(self.cards, Card.new(suit, rank))
        end
    end

    return self
end

function Deck:shuffle()
    for i = #self.cards, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function Deck:drawCard()
    if #self.cards == 0 then
        error("Deck is empty!")
    end
    return table.remove(self.cards)
end