Game = {}
Game.__index = Game

-- Функции основного потока игры -----------------------------------
function Game.new(playerName)
    local self = setmetatable({}, Game)
    self.deck = Deck.new()
    self.player = Player.new(playerName)
    self.dealer = Player.new("Dealer")
    self.result = ""
    self.state = "menu"
    self.currentPhase = "ante"
    self.timer = 0
    return self
end

function Game:start()
    self.deck:shuffle()
    self.player.hand = {}
    self.dealer.hand = {}

    for i = 1, 3 do
        self.player:addCard(self.deck:drawCard())
        self.dealer:addCard(self.deck:drawCard())
    end

    -- Начальные позиции карт
    local startX = 50
    local startY = 40

    -- Целевые позиции карт игрока
    for i = 1, 3 do
        table.insert(cardAnimation.playerCards, {
            startX = startX,
            startY = startY,
            targetX = 217 + (i - 1) * 72,
            targetY = 228
        })
    end
    
    -- Целевые позиции карт дилера
    for i = 1, 3 do
        table.insert(cardAnimation.dealerCards, {
            startX = startX,
            startY = startY,
            targetX = 217 + (i - 1) * 72,
            targetY = 40
        })
    end
    
    self:determineWinner()
end

function Game:resetGame()
    self:returnCardsToDeck()

    for i = 1, 3 do
        self.player:addCard(self.deck:drawCard())
        self.dealer:addCard(self.deck:drawCard())
    end
    
    -- Сброс анимации карт
    cardAnimation.playerCards = {}
    cardAnimation.dealerCards = {}
    cardAnimation.timer = 0
    cardAnimation.currentCard = 1

    -- Начальные позиции карт
    local startX = 50
    local startY = 40

    -- Целевые позиции карт игрока
    for i = 1, 3 do
        table.insert(cardAnimation.playerCards, {
            startX = startX,
            startY = startY,
            targetX = 217 + (i - 1) * 72,
            targetY = 228
        })
    end
    
    -- Целевые позиции карт дилера
    for i = 1, 3 do
        table.insert(cardAnimation.dealerCards, {
            startX = startX,
            startY = startY,
            targetX = 217 + (i - 1) * 72,
            targetY = 40
        })
    end

    self.player.startingChips = self.player.chips
    self.player.ante = 0
    self.player.pairPlus = 0
    self.player.bet = 0
    
    self.result = ""
    self.currentPhase = "ante"
    
    self.timer = 0
end
--------------------------------------------------------------------

-- Функция возврата карт
function Game:returnCardsToDeck()
    for _, card in ipairs(self.player.hand) do
        table.insert(self.deck.cards, card)
    end
    self.player.hand = {}

    for _, card in ipairs(self.dealer.hand) do
        table.insert(self.deck.cards, card)
    end
    self.dealer.hand = {}

    self.deck:shuffle()
end

-- Функция для получения значения пары
function Game:getPairValue(values)
    local count = {}
    for _, value in ipairs(values) do
        count[value] = (count[value] or 0) + 1
    end
    for value, cnt in pairs(count) do
        if cnt == 2 then
            return value
        end
    end
    return nil
end

-- Функция для получения кикера
function Game:getKicker(values, pairValue)
    for _, value in ipairs(values) do
        if value ~= pairValue then
            return value
        end
    end
    return nil
end

-- Функция сравнивания рук
function Game:compareHands(playerHand, dealerHand)
    local playerStrength, playerValues = self:evaluateHand(playerHand)
    local dealerStrength, dealerValues = self:evaluateHand(dealerHand)

    if playerStrength > dealerStrength then
        return "player"
    elseif playerStrength < dealerStrength then
        return "dealer"
    elseif playerStrength == 2 and dealerStrength == 2 then
        local playerPairValue = self:getPairValue(playerValues)
        local dealerPairValue = self:getPairValue(dealerValues)
        
        if playerPairValue > dealerPairValue then
            return "player"
        elseif playerPairValue < dealerPairValue then
            return "dealer"
        else
            -- Если пары равны, сравниваем кикер
            local playerKicker = self:getKicker(playerValues, playerPairValue)
            local dealerKicker = self:getKicker(dealerValues, dealerPairValue)

            if playerKicker > dealerKicker then
                return "player"
            elseif playerKicker < dealerKicker then
                return "dealer"
            else
                return "tie"
            end
        end
    else
        for i = 1, #playerValues do
            if playerValues[i] > dealerValues[i] then
                return "player"
            elseif playerValues[i] < dealerValues[i] then
                return "dealer"
            end
        end
        return "tie"
    end
end

-- Функция определения победителя
function Game:determineWinner()
    -- Проверка квалификации дилера
    local dealerQualifies = self:dealerQualifies(self.dealer.hand)

    -- Выплата pair-plus
    local playerStrength, _ = self:evaluateHand(self.player.hand)
    if playerStrength > 1 then
        local pairPlusMultiplier = self:getPairPlusMultiplier(playerStrength)
        PairPlusPayout = self.player:payPairPlus(pairPlusMultiplier)
    end

    if not dealerQualifies then
        -- Дилер не квалифицируется, игрок выигрывает
        local anteBetPayout = self.player:payAnteBet(1)
        self.result = self.player.name .. " won!\n\nPaycheck: " .. anteBetPayout
        return
    end

    -- Если дилер квалифицируется, сравниваем руки
    local winner = self:compareHands(self.player.hand, self.dealer.hand)

    if winner == "player" then
        local multiplier = self:getAnteBetMultiplier(playerStrength)
        local anteBetPayout = self.player:payAnteBet(multiplier)
        self.result = self.player.name .. " won!\n\nPaycheck: " .. (anteBetPayout + PairPlusPayout)
    elseif winner == "dealer" then
        self.result = self.dealer.name .. " won!"
    else
        self.player:payAnteBet(1)
        self.result = "Tie!\n\nYou get your chips back"
    end
end

-- Функция квалификации дилера
function Game:dealerQualifies(hand)
    -- Проверка есть ли у дилера хотя бы дама (Q)
    local hasQueenOrHigher = false
    for _, card in ipairs(hand) do
        local value = self:getCardValue(card.rank)
        if value >= 12 then
            hasQueenOrHigher = true
            break
        end
    end

    -- Проверка есть ли у дилера комбинация от пары и выше
    local strength, _ = self:evaluateHand(hand)
    local hasCombination = strength > 1

    -- Дилер квалифицируется, если выполняется хотя бы одно из условий
    return hasQueenOrHigher or hasCombination
end


-- Функция оценки руки
function Game:evaluateHand(hand)
    local values = {}
    local suits = {}
    for _, card in ipairs(hand) do
        local value = self:getCardValue(card.rank)
        table.insert(values, value)
        table.insert(suits, card.suit)
    end
    table.sort(values, function(a, b) return a > b end)
    
    local isFlush = self:isFlush(suits)
    local isStraight, isSmallStraight = self:isStraight(values)
    local counts = self:countValues(values)
    
    if isStraight and isFlush then
        return 6, values -- Стрит-флэш
    elseif self:isThreeOfAKind(counts) then
        return 5, values -- Тройка
    elseif isStraight then
        if isSmallStraight then
            -- Малый стрит: туз считается как 1
            return 4, {3, 2, 1}
        else
            -- Обычный стрит
            return 4, values
        end
    elseif isFlush then
        return 3, values -- Флэш
    elseif self:isPair(counts) then
        return 2, values -- Пара
    else
        return 1, values -- Старшая карта
    end
end

-- Функции для проверки на комбинации ---------------------------------
function Game:isFlush(suits)
    return suits[1] == suits[2] and suits[2] == suits[3]
end

function Game:isStraight(values)
    -- Проверка обычного стрита
    if values[1] - values[2] == 1 and values[2] - values[3] == 1 then
        return true, false
    end
    
    -- Проверка малого стрита (A, 2, 3)
    if values[1] == 14 and values[2] == 3 and values[3] == 2 then
        return true, true
    end
    
    return false, false
end

function Game:countValues(values)
    local counts = {}
    for _, value in ipairs(values) do
        counts[value] = (counts[value] or 0) + 1
    end
    return counts
end

function Game:isThreeOfAKind(counts)
    for _, count in pairs(counts) do
        if count == 3 then
            return true
        end
    end
    return false
end

function Game:isPair(counts)
    for _, count in pairs(counts) do
        if count == 2 then
            return true
        end
    end
    return false
end
-----------------------------------------------------------------------

-- Расчёт выплаты Pair-Plus
function Game:getPairPlusMultiplier(strength)
    if strength == 2 then
        return 1 -- Пара
    elseif strength == 3 then
        return 4 -- Флэш
    elseif strength == 4 then
        return 5 -- Стрит
    elseif strength == 5 then
        return 20 -- Тройка
    elseif strength == 6 then
        return 40 -- Стрит-флэш
    else
        return 0 -- Нет комбинации
    end
end

-- Расчёт выплаты Ante
function Game:getAnteBetMultiplier(strength)
    if strength == 5 then
        return 3 -- Тройка
    elseif strength == 6 then
        return 5 -- Стрит-флэш
    else
        return 1 -- Нет комбинации
    end
end

-- Функция получения достоинства карты
function Game:getCardValue(rank)
    local cardValues = {
        ["2"] = 2,
        ["3"] = 3,
        ["4"] = 4,
        ["5"] = 5,
        ["6"] = 6,
        ["7"] = 7,
        ["8"] = 8,
        ["9"] = 9,
        ["10"] = 10,
        ["jack"] = 11,
        ["queen"] = 12,
        ["king"] = 13,
        ["ace"] = 14
    }
    return cardValues[string.lower(rank)] or 0
end

-- Для отладки
function Game:getSortedValues(hand)
    local values = {}
    for _, card in ipairs(hand) do
        local value = self:getCardValue(card.rank)
        table.insert(values, value)
    end
    table.sort(values, function(a, b) return a > b end)
    return values
end
