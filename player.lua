Player = {}
Player.__index = Player

function Player.new(name)
    local self = setmetatable({}, Player)
    self.name = name
    self.hand = {}
    self.startingChips = 10000
    self.chips = self.startingChips
    self.ante = 0
    self.pairPlus = 0
    self.bet = 0
    return self
end

-- Добавление карты в руку
function Player:addCard(card)
    table.insert(self.hand, card)
end

-- Функции для ставок -----------------------------------
function Player:increaseAnte(amount)
    if amount <= self.chips and ((self.ante + amount) <= (self.startingChips / 2)) then
        self.ante = self.ante + amount
        self.chips = self.chips - amount
        local soundIndex = math.random(1, 3)
        chipsBetSounds[soundIndex]:play()
    end
end

function Player:increasePairPlus(amount)
    if amount <= self.chips and (self.chips - amount) >= self.ante then
        self.pairPlus = self.pairPlus + amount
        self.chips = self.chips - amount
        local soundIndex = math.random(1, 3)
        chipsBetSounds[soundIndex]:play()
    end
end

function Player:decreaseAnte(amount)
    if (self.ante - amount) >= 0 then
        self.ante = self.ante - amount
        self.chips = self.chips + amount
        local soundIndex = math.random(1, 3)
        chipsBetSounds[soundIndex]:play()
    end
end

function Player:decreasePairPlus(amount)
    if (self.pairPlus - amount) >= 0 then
        self.pairPlus = self.pairPlus - amount
        self.chips = self.chips + amount
        local soundIndex = math.random(1, 3)
        chipsBetSounds[soundIndex]:play()
    end
end

function Player:placeBet(amount)
    if amount <= self.chips then
        self.bet = amount
        self.chips = self.chips - amount
        local soundIndex = math.random(1, 3)
        chipsBetSounds[soundIndex]:play()
    end
end
---------------------------------------------------------

-- Фунции выплаты
function Player:payAnteBet(multiplier)
    local payout = self.ante + (self.ante * multiplier) + self.bet
    self.chips = self.chips + payout
    return payout
end

function Player:payPairPlus(multiplier)
    local payout = self.pairPlus + (self.pairPlus * multiplier)
    self.chips = self.chips + payout
    return payout
end

-- Для отладки
function Player:__tostring()
    local handStr = {}
    for _, card in ipairs(self.hand) do
        table.insert(handStr, tostring(card))
    end
    return self.name .. ": " .. table.concat(handStr, ", ")
end