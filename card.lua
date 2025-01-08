Card = {}
Card.__index = Card

function Card.new(suit, rank)
    local self = setmetatable({}, Card)
    self.suit = suit
    self.rank = rank
    return self
end

function Card:__tostring()
    return self.rank .. " " .. self.suit
end