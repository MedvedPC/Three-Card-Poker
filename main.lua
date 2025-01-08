---@diagnostic disable: lowercase-global
require "card"
require "deck"
require "player"
require "game"
Push = require("lib.push")

-- Параметры окна
REAL_WIDTH, REAL_HEIGHT = love.window.getDesktopDimensions()
REAL_WIDTH, REAL_HEIGHT = REAL_WIDTH * 0.8, REAL_HEIGHT * 0.8

VIRTUAL_WIDTH, VIRTUAL_HEIGHT = 640, 360

-- Параметры времени отображения текста
local showText = true
local textDuration = 6
local timer = 0

-- Загрузка
function love.load()
    math.randomseed(os.time())

    -- Настройка окна ---------------------------------------------------------------------------------------
    love.window.setTitle("Three Card Poker")

    love.graphics.setDefaultFilter("nearest", "nearest") -- Обработка изображения для OpenGL, а вообще чтобы не мылило арты

    Push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, REAL_WIDTH, REAL_HEIGHT, {fullscreen = true, vsync = true, resizable = true})
    isFullscreen = love.window.getFullscreen()
    ---------------------------------------------------------------------------------------------------------

    -- Загрузка изображений
    menuImage = love.graphics.newImage("assets/backgrounds/menu.png")
    tableImage = love.graphics.newImage("assets/backgrounds/table.png")
    cardBack = love.graphics.newImage("assets/cards/card_back.png")
    cardImages = {}
    local suits = {"hearts", "diamonds", "clubs", "spades"}
    local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"}
    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            local cardName = rank .. "_" .. suit
            cardImages[cardName] = love.graphics.newImage("assets/cards/" .. cardName .. ".png")
        end
    end

    -- Загрузка звуков
    cardDealSounds = {}
    for i = 1, 6 do
        cardDealSounds[i] = love.audio.newSource("assets/sounds/card_deal" .. i .. ".mp3", "static")
    end
    chipsBetSounds = {}
    for i = 1, 3 do
        chipsBetSounds[i] = love.audio.newSource("assets/sounds/bet" .. i .. ".mp3", "static")
        chipsBetSounds[i]:setVolume(0.5)
    end
    cardFlip = love.audio.newSource("assets/sounds/card_roll.mp3", "static")
    cardShuffle = love.audio.newSource("assets/sounds/shuffle.mp3", "static")
    cardShuffle:setVolume(0.4)

    -- Шрифт
    font = love.graphics.newFont("assets/fonts/pcsenior.ttf", 8) or love.graphics.newFont(12)
    love.graphics.setFont(font)

    -- Переменные
    PairPlusPayout = 0 -- Надо бы в другое место передвинуть
    
    menu = {
        items = {"Play", "Options", "Exit"},
        selected = 1,
        startX = 300,
        startY = 80
    }
    
    menu.maxTextWidth = 0
    for i, item in ipairs(menu.items) do
        local itemWidth = font:getWidth(item)
        if itemWidth > menu.maxTextWidth then
            menu.maxTextWidth = itemWidth
        end
    end

    cardAnimation = {
        playerCards = {}, -- Позиции карт игрока
        dealerCards = {}, -- Позиции карт дилера
        duration = 0.3,   -- Длительность анимации одной карты в секундах
        timer = 0,        -- Таймер для анимации
        currentCard = 1,  -- Текущая карта, которую анимируем
        delay = 0.2       -- Задержка между анимациями карт
    }

    cardFlipAnimation = {
        cards = {}, -- Состояние анимации для каждой карты
        duration = 0.5, -- Длительность анимации в секундах
        timer = 0, -- Таймер для анимации
        isComplete = false, -- Флаг завершения анимации
    }

    -- Инициализация игры
    game = Game.new("Player")
    game:start()
end

local function updateCardAnimation(dt)
    if cardAnimation.timer < cardAnimation.duration then
        cardAnimation.timer = cardAnimation.timer + dt
        local progress = math.min(cardAnimation.timer / cardAnimation.duration, 1) -- Ограничиваем прогресс до 1

        -- Анимируем текущую карту
        if cardAnimation.currentCard % 2 == 1 then
            -- Карта игрока
            local cardIndex = math.ceil(cardAnimation.currentCard / 2)
            local cardPos = cardAnimation.playerCards[cardIndex]
            if cardPos then
                cardPos.x = cardPos.startX + (cardPos.targetX - cardPos.startX) * progress
                cardPos.y = cardPos.startY + (cardPos.targetY - cardPos.startY) * progress
                cardPos.isAnimating = true
            end
        else
            -- Карта дилера
            local cardIndex = math.ceil(cardAnimation.currentCard / 2)
            local cardPos = cardAnimation.dealerCards[cardIndex]
            if cardPos then
                cardPos.x = cardPos.startX + (cardPos.targetX - cardPos.startX) * progress
                cardPos.y = cardPos.startY + (cardPos.targetY - cardPos.startY) * progress
                cardPos.isAnimating = true
            end
        end
    else
        -- Переходим к следующей карте после задержки
        cardAnimation.timer = 0
        cardAnimation.currentCard = cardAnimation.currentCard + 1
    end

    if cardAnimation.timer == dt then
        local soundIndex = math.random(1, 6) -- Случайный выбор звука
        cardDealSounds[soundIndex]:play()    -- Воспроизведение звука
    end
end

local function updateCardFlipAnimation(dt, phase)
    -- Сама анимация
    cardFlipAnimation.timer = cardFlipAnimation.timer + dt
    for i, cardAnim in ipairs(cardFlipAnimation.cards) do
        if not cardAnim.isFlipped then
            cardAnim.isFlipping = true
            cardAnim.progress = math.min(cardFlipAnimation.timer / cardFlipAnimation.duration, 1)
            if cardAnim.progress >= 1 then
                cardAnim.isFlipped = true
            elseif cardAnim.progress >= 0.5 then
                cardFlip:play()
            end
        end
    end
    
    -- Проверка, завершена ли анимация
    cardFlipAnimation.isComplete = true
    for i, cardAnim in ipairs(cardFlipAnimation.cards) do
        if not cardAnim.isFlipped then
            cardFlipAnimation.isComplete = false
            break
        end
    end
    
    -- Смена фазы в зависимости от текущей
    if cardFlipAnimation.isComplete and phase == "blindFold" then
        game.currentPhase = "showDealer"
        cardFlipAnimation.timer = 0
    elseif cardFlipAnimation.isComplete and phase == "showPlayer" then
        game.currentPhase = "decideBet"
        cardFlipAnimation.timer = 0
    elseif cardFlipAnimation.isComplete and phase == "showDealer" then
        cardFlipAnimation.timer = 0
    end

end

local function resetCardFlipAnimation(phase)
    cardFlipAnimation.cards = {} -- Очистка

    if phase == "blindFold" then
        hands = {}

        for i = 1, #game.player.hand do
            hands[i] = game.player.hand[i]
        end
        
        for i = 1, #game.dealer.hand do
            hands[#game.player.hand + i] = game.dealer.hand[i]
        end

        for i = 1, #hands do
            cardFlipAnimation.cards[i] = {
                isFlipping = false,
                progress = 0,
                isFlipped = false
            }
        end
    elseif phase == "showPlayer" then
        for i = 1, #game.player.hand do
            cardFlipAnimation.cards[i] = {
                isFlipping = false,
                progress = 0,
                isFlipped = false
            }
        end
    elseif phase == "showDealer" then
        for i = 1, #game.dealer.hand do
            cardFlipAnimation.cards[i] = {
                isFlipping = false,
                progress = 0,
                isFlipped = false
            }
        end
    end
end

function love.update(dt)
    if game then
        if showText then -- Обновление таймера отображения текста
            timer = timer + dt
            if timer >= textDuration then
                showText = false
            end
        end
        if game.currentPhase == "showDealer" then
            game.timer = game.timer + dt
            if game.timer >= 10 then
                game:resetGame()
            end
        else
            game.timer = 0
        end
        if game.currentPhase == "deal" then
            updateCardAnimation(dt)
            -- Если все карты анимированы, переходим к следующей фазе
            if cardAnimation.currentCard > 6 then
                game.currentPhase = "decideBetBlind"
            end
        end

        -- Анимации переворота карт
        if game.currentPhase == "blindFold" then
            updateCardFlipAnimation(dt, game.currentPhase)
        elseif game.currentPhase == "showPlayer" then
            updateCardFlipAnimation(dt, game.currentPhase)
        elseif game.currentPhase == "showDealer" then
            updateCardFlipAnimation(dt, game.currentPhase)
        end
    end
end

function love.resize(w, h) -- Для смены размера окна
    Push:resize(w, h)
end

-- Графика
function love.draw()
    Push:start()
    if game.state == "menu" then
        -- Отрисовка меню
        love.graphics.draw(menuImage, 0, 0)
        
        for i, item in ipairs(menu.items) do
            local itemWidth = font:getWidth(item)
            local offsetX = (menu.maxTextWidth - itemWidth) / 2
            local itemX = menu.startX + offsetX
            local itemY = menu.startY + i * 40

            -- Размеры прямоугольника
            local rectWidth = menu.maxTextWidth + 20
            local rectHeight = 18
            local rectX = menu.startX - 10
            local rectY = itemY - 5

            -- Отрисовка прямоугольника под текстом
            if i == menu.selected then
                love.graphics.setColor(0, 0, 0, 0.8)
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
            end
            love.graphics.rectangle("fill", rectX, rectY, rectWidth, rectHeight, 5, 5) -- Прямоугольник с закруглёнными углами

            -- Отрисовка текста
            if i == menu.selected then
                love.graphics.setColor(1, 0, 0) -- Выделенный текст красным
            else
                love.graphics.setColor(1, 1, 1) -- Обычный текст белым
            end
            love.graphics.print(item, itemX, itemY)
        end

    elseif game.state == "options" then
        -- Отрисовка экрана опций
        love.graphics.draw(menuImage, 0, 0)

        love.graphics.setColor(0.1, 0.1, 0.1, 0.5) -- Цвет фона опций
        love.graphics.rectangle("fill", 100, 50, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 100, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Options", 150, 70)

        local fullscreenText = "Fullscreen mode"
        local fullscreenTextX = 150
        local fullscreenTextY = 100
        love.graphics.print(fullscreenText, fullscreenTextX, fullscreenTextY)

        local toggleSize = 10 -- Размер квадрата
        local toggleX = fullscreenTextX + font:getWidth(fullscreenText) + 10 -- Позиция справа от текста
        local toggleY = fullscreenTextY
        love.graphics.setColor(1, 1, 1) -- Белый цвет рамки
        love.graphics.rectangle("line", toggleX, toggleY, toggleSize, toggleSize, 3, 3) -- Рамка квадрата

        if isFullscreen then
            love.graphics.setColor(1, 1, 1) -- Белый цвет для заполненного квадрата
            love.graphics.rectangle("fill", toggleX + 2, toggleY + 2, toggleSize - 4, toggleSize - 4, 3, 3) -- Заливка квадрата
        end

    elseif game then
        -- Отрисовка непосредственно игры
        love.graphics.draw(tableImage, 0, 0)

        -- Параметры отрисовки карт
        local cardScale = 1 -- Масштаб карт (0.5 = 50%)
        local cardSpacing = 72 -- Расстояние между картами

        -- Отрисовка карт ---------------------------------------------------------------------------------------
        if game.currentPhase ~= "ante" then
            if game.currentPhase ~= "pairPlus" then
                
                -- Отрисовка карт игрока
                love.graphics.print("Your Cards", 281, 330)
                for i, card in ipairs(game.player.hand) do
                    
                    local cardName = card.rank .. "_" .. string.lower(card.suit)
                    local cardImage = cardImages[cardName]
                    
                    if game.currentPhase == "deal" then
                        local cardPos = cardAnimation.playerCards[i]
                        if cardPos and cardPos.isAnimating then
                            love.graphics.draw(cardBack, cardPos.x, cardPos.y, 0, cardScale, cardScale)
                        end
                    elseif game.currentPhase == "showPlayer" then
                        local cardAnim = cardFlipAnimation.cards[i]
                        if cardAnim and cardAnim.isFlipping then
                            -- Анимация переворота
                            local scaleX = math.abs(math.cos(cardAnim.progress * math.pi)) -- Изменение ширины
                            love.graphics.draw(
                                cardAnim.progress < 0.5 and cardBack or cardImage, -- Выбор текстуры
                                217 + (i - 1) * cardSpacing + 32, 228 + 46,
                                0, scaleX, cardScale, 32, 46
                            )
                        else
                            love.graphics.draw(cardImage, 217 + (i - 1) * cardSpacing, 228, 0, cardScale, cardScale)
                        end
                    elseif game.currentPhase == "decideBetBlind" then
                        love.graphics.draw(cardBack, 217 + (i - 1) * cardSpacing, 228, 0, cardScale, cardScale)
                    elseif game.currentPhase == "blindFold" then
                        local cardAnim = cardFlipAnimation.cards[i]
                        if cardAnim and cardAnim.isFlipping then
                            -- Анимация переворота
                            local scaleX = math.abs(math.cos(cardAnim.progress * math.pi)) -- Изменение ширины
                            love.graphics.draw(
                                cardAnim.progress < 0.5 and cardBack or cardImage,
                                217 + (i - 1) * cardSpacing + 32, 228 + 46,
                                0, scaleX, cardScale, 32, 46
                            )
                        else
                            love.graphics.draw(cardImage, 217 + (i - 1) * cardSpacing, 228, 0, cardScale, cardScale)
                        end
                    elseif game.currentPhase == "showDealer" or game.currentPhase == "decideBet" then
                        love.graphics.draw(cardImage, 217 + (i - 1) * cardSpacing, 228, 0, cardScale, cardScale)
                    else
                        print("ERROR: image for" .. cardName .. " not found!")
                    end
                end
    
                -- Отрисовка карт дилера
                love.graphics.print("Dealer Cards", 275, 20)
                for i, card in ipairs(game.dealer.hand) do
        
                    local cardName = card.rank .. "_" .. string.lower(card.suit)
                    local cardImage = cardImages[cardName]
        
                    if game.currentPhase == "deal" then
                        local cardPos = cardAnimation.dealerCards[i]
                        if cardPos and cardPos.isAnimating then
                            love.graphics.draw(cardBack, cardPos.x, cardPos.y, 0, cardScale, cardScale)
                        end
                    elseif game.currentPhase == "showPlayer" or game.currentPhase == "decideBet" or game.currentPhase == "decideBetBlind" then
                        love.graphics.draw(cardBack, 217 + (i - 1) * cardSpacing, 40, 0, cardScale, cardScale)
                    elseif game.currentPhase == "blindFold" then
                        local cardAnim = cardFlipAnimation.cards[i]
                        if cardAnim and cardAnim.isFlipping then
                            -- Анимация переворота
                            local scaleX = math.abs(math.cos(cardAnim.progress * math.pi))
                            love.graphics.draw(
                                cardAnim.progress < 0.5 and cardBack or cardImage,
                                217 + (i - 1) * cardSpacing + 32, 40 + 46,
                                0, scaleX, cardScale, 32, 46
                            )
                        else
                            love.graphics.draw(cardImage, 217 + (i - 1) * cardSpacing, 40, 0, cardScale, cardScale)
                        end
                    elseif game.currentPhase == "showDealer" then
                        local cardAnim = cardFlipAnimation.cards[i]
                        if cardAnim and cardAnim.isFlipping then
                            -- Анимация переворота
                            local scaleX = math.abs(math.cos(cardAnim.progress * math.pi))
                            love.graphics.draw(
                                cardAnim.progress < 0.5 and cardBack or cardImage,
                                217 + (i - 1) * cardSpacing + 32, 40 + 46,
                                0, scaleX, cardScale, 32, 46
                            )
                        else
                            love.graphics.draw(cardImage, 217 + (i - 1) * cardSpacing, 40, 0, cardScale, cardScale)
                        end
                    else
                        print("ERROR: image for" .. cardName .. " not found!")
                    end
                end

            end
        end
        ---------------------------------------------------------------------------------------------------------

        -- Отрисовка текста -------------------------------------------------------------------------------------
        -- Подсказки для игрока
        if game.currentPhase == "ante" then
            if showText then
                love.graphics.print("Use arrow keys to change ante", 205, 160)
                love.graphics.print("Press 'space' to confirm bet", 208, 175)
            end

        elseif game.currentPhase == "pairPlus" then
            if showText then
                love.graphics.print("Use arrow keys to change pair-plus", 185, 160)
                love.graphics.print("Press 'space' to confirm bet", 208, 175)
            end

        elseif game.currentPhase == "decideBetBlind" then
            if showText then
                love.graphics.print("Press 'space' to confirm play (" .. game.player.ante .. " chips)", 155, 160)
                love.graphics.print("Press 's' to see your cards", 215, 175)
                love.graphics.print("Press 'f' to fold", 252, 190)
            end
        elseif game.currentPhase == "decideBet" then
            if showText then
                love.graphics.print("Press 'space' to confirm play (" .. game.player.ante .. " chips)", 155, 160)
                love.graphics.print("Press 'f' to fold", 252, 175)
            end
        elseif game.currentPhase == "showDealer" then
            love.graphics.print("Result: " .. game.result, 247, 160)
            showText = true
            timer = 0
        end

        -- Ставки и счёт
        love.graphics.print("Current chips:" .. game.player.chips .. "", 450, 320)
        love.graphics.print(game.player.pairPlus , 560, 120)
        love.graphics.print(game.player.ante , 560, 174)
        love.graphics.print(game.player.bet, 560, 230)
    else
        love.graphics.print("Game haven't started!", 50, 50)
    end
    ---------------------------------------------------------------------------------------------------------

    -- Вывод для отладки (может и оставить?) -----------------------------------------------
    --local playerValues = game:getSortedValues(game.player.hand)
    --local dealerValues = game:getSortedValues(game.dealer.hand)

    --love.graphics.print("Sorted player hand: " .. table.concat(playerValues, ", "), 0, 100)
    --love.graphics.print("Sorted dealer hand: " .. table.concat(dealerValues, ", "), 0, 120)

    --love.graphics.print("Current phase: " .. game.currentPhase .. "", 50, 0)
    --love.graphics.print("PPP: " .. PairPlusPayout .. "", 50, 0)
    --love.graphics.print("Current timer: " .. game.timer .. "", 50, 20)
    --if cardFlipAnimation.isComplete then
    --    love.graphics.print("Complete", 50, 40)
    --end
    ----------------------------------------------------------------------------------------
    
    Push:finish()
end

-- Обработка нажатий клавиш
function love.keypressed(key)
    if game.state == "menu" then -- Обработка для меню
        if key == "up" then
            menu.selected = math.max(1, menu.selected - 1)
        elseif key == "down" then
            menu.selected = math.min(#menu.items, menu.selected + 1)
        elseif key == "return" then
            selectMenuItem(menu.selected)
        end
    elseif game.state == "options" then
        -- Возврат в меню при нажатии Escape
        if key == "escape" then
            game.state = "menu"
        end

    elseif game.state == "game" then -- Обработка для игры

        if game.currentPhase == "ante" then
            if key == "up" then
                game.player:increaseAnte(1000)
            elseif key == "down" then
                game.player:decreaseAnte(1000)
            elseif key == "space" then
                game.currentPhase = "pairPlus"
                showText = true
                timer = 0
            end

        elseif game.currentPhase == "pairPlus" then
            if key == "up" then
                game.player:increasePairPlus(250)
            elseif key == "down" then
                game.player:decreasePairPlus(250)
            elseif key == "space" then
                game.currentPhase = "deal"
                showText = true
                timer = 0
            end

        elseif game.currentPhase == "decideBetBlind" then
            if key == "s" then
                game.currentPhase = "showPlayer"
                resetCardFlipAnimation(game.currentPhase)

                showText = true
                timer = 0
            elseif key == "f" then
                game.currentPhase = "blindFold"
                resetCardFlipAnimation(game.currentPhase)

                showText = true
                timer = 0

                game.result = game.player.name .. " folded.\n\nLost: " .. (game.player.ante + game.player.pairPlus)
            elseif key == "space" then
                game.player:placeBet(game.player.ante)
                
                game.currentPhase = "blindFold"
                resetCardFlipAnimation(game.currentPhase)

                showText = true
                timer = 0
                
                game:determineWinner()
            end

        elseif game.currentPhase == "decideBet" then
            if key == "f" then
                game.currentPhase = "showDealer"
                resetCardFlipAnimation(game.currentPhase)
                
                showText = true
                timer = 0

                game.result = game.player.name .. " folded.\n\nLost: " .. (game.player.ante + game.player.pairPlus)
            elseif key == "space" then
                game.player:placeBet(game.player.ante)

                game.currentPhase = "showDealer"
                resetCardFlipAnimation(game.currentPhase)
                
                showText = true
                timer = 0

                game.result = game.player.name .. " folded.\n\nLost: " .. (game.player.ante + game.player.pairPlus)
                game:determineWinner()
            end 

        elseif game.currentPhase == "showDealer" then
            if key == "r" then
                cardShuffle:play()
                game:resetGame()
            end
        end
        if key == "escape" then
            game.state = "menu"
        end
    end
    -- Смена режима окна сочетанием клавиш
    if key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
        isFullscreen = not isFullscreen
        love.window.setFullscreen(isFullscreen)
        Push:resize(love.graphics.getWidth(), love.graphics.getHeight())
    end
end

function love.mousemoved(x, y)
    if game.state == "menu" then
        -- Преобразуем координаты мыши в виртуальные координаты
        local virtualX, virtualY = Push:toGame(x, y)
        
        -- Игнориурем вне окна игры
        if not virtualX or not virtualY then
            return
        end
        
        menu.selected = 0

        -- Проверяем, находится ли курсор над пунктом меню
        for i, item in ipairs(menu.items) do
            local itemY = menu.startY + i * 40
            local itemWidth = font:getWidth(item)
            local offsetX = (menu.maxTextWidth - itemWidth) / 2
            if virtualY >= itemY and virtualY <= itemY + 10 and virtualX >= menu.startX + offsetX and virtualX <= menu.startX + offsetX + itemWidth then
                menu.selected = i
            end
        end
    end
end

function love.mousepressed(x, y, button)
    if game.state == "menu" and button == 1 then
        -- Преобразуем координаты мыши в виртуальные координаты
        local virtualX, virtualY = Push:toGame(x, y)
        
        -- Игнориурем вне окна игры
        if not virtualX or not virtualY then
            return
        end

        -- Проверяем, был ли клик по пункту меню
        for i, item in ipairs(menu.items) do
            local itemY = menu.startY + i * 40
            local itemWidth = font:getWidth(item)
            local offsetX = (menu.maxTextWidth - itemWidth) / 2
            if virtualY >= itemY and virtualY <= itemY + 10 and virtualX >= menu.startX + offsetX and virtualX <= menu.startX + offsetX + itemWidth then
                selectMenuItem(i)
                break
            end
        end
    elseif game.state == "options" and button == 1 then
        -- Преобразуем координаты мыши в виртуальные координаты
        local virtualX, virtualY = Push:toGame(x, y)
        
        -- Игнориурем вне окна игры
        if not virtualX or not virtualY then
            return
        end

        -- Координаты и размеры квадрата-переключателя
        local toggleSize = 10
        local toggleX = 150 + font:getWidth("Fullscreen mode") + 10
        local toggleY = 100

        -- Проверяем, был ли клик по квадрату-переключателю
        if virtualX >= toggleX and virtualX <= toggleX + toggleSize and virtualY >= toggleY and virtualY <= toggleY + toggleSize then
            -- Переключаем полноэкранный режим
            isFullscreen = not isFullscreen
            love.window.setFullscreen(isFullscreen)
            Push:resize(love.graphics.getWidth(), love.graphics.getHeight()) -- Обновляем размеры экрана
        end
    end
end

function selectMenuItem(index)
    if index == 1 then
        game.state = "game"
        showText = true
        timer = 0
    elseif index == 2 then
        game.state = "options"
    elseif index == 3 then
        -- Выход
        love.event.quit()
    end
end