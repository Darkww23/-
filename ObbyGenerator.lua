--[[
    ObbyGenerator — Roblox Studio Script
    ======================================
    Генератор обби (obstacle course) с движущимися платформами,
    убийственными блоками, чекпоинтами и эффектами.

    Инструкция:
      1. Откройте Roblox Studio и создайте новый Place.
      2. Вставьте этот скрипт в ServerScriptService (Script).
      3. Нажмите Play — обби сгенерируется автоматически.

    Возможности:
      • Автоматическая генерация уровня с N этапами
      • Статические, движущиеся и вращающиеся платформы
      • Kill-блоки (лава)
      • Чекпоинты со спавном
      • Монетки с подсчётом очков
      • Финишная платформа с победным сообщением
--]]

---------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------
local STAGE_COUNT       = 15       -- Количество этапов
local PLATFORM_WIDTH    = 8        -- Ширина платформы
local PLATFORM_DEPTH    = 8        -- Глубина платформы
local GAP_MIN           = 8        -- Мин. расстояние между платформами
local GAP_MAX           = 14       -- Макс. расстояние между платформами
local HEIGHT_VARIATION  = 6        -- Макс. изменение высоты между этапами
local BASE_HEIGHT       = 20       -- Начальная высота
local KILL_BRICK_CHANCE = 0.3      -- Шанс появления kill-блока рядом
local MOVING_CHANCE     = 0.35     -- Шанс движущейся платформы
local SPINNING_CHANCE   = 0.15     -- Шанс вращающейся платформы
local COIN_CHANCE       = 0.5      -- Шанс появления монетки на платформе

---------------------------------------------------------------------
-- СЕРВИСЫ
---------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

---------------------------------------------------------------------
-- ПАПКИ
---------------------------------------------------------------------
local obbyFolder = Instance.new("Folder")
obbyFolder.Name = "ObbyGenerated"
obbyFolder.Parent = Workspace

local coinsFolder = Instance.new("Folder")
coinsFolder.Name = "Coins"
coinsFolder.Parent = obbyFolder

---------------------------------------------------------------------
-- УТИЛИТЫ
---------------------------------------------------------------------
local rng = Random.new()

local function randomFloat(min, max)
    return min + (max - min) * rng:NextNumber()
end

local function createPart(properties)
    local part = Instance.new("Part")
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(properties) do
        part[k] = v
    end
    part.Parent = obbyFolder
    return part
end

---------------------------------------------------------------------
-- СТАРТОВАЯ ПЛАТФОРМА
---------------------------------------------------------------------
local startPlatform = createPart({
    Name = "StartPlatform",
    Size = Vector3.new(16, 2, 16),
    Position = Vector3.new(0, BASE_HEIGHT, 0),
    BrickColor = BrickColor.new("Bright green"),
    Material = Enum.Material.Grass,
})

-- Спавн-поинт
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(0, BASE_HEIGHT + 1.5, 0)
spawnLocation.Anchored = true
spawnLocation.CanCollide = false
spawnLocation.Transparency = 1
spawnLocation.Parent = obbyFolder

---------------------------------------------------------------------
-- ГЕНЕРАЦИЯ ЭТАПОВ
---------------------------------------------------------------------
local stages = {}
local currentX = 0
local currentY = BASE_HEIGHT
local currentZ = 0

for i = 1, STAGE_COUNT do
    -- Случайное смещение
    local gap = randomFloat(GAP_MIN, GAP_MAX)
    local heightDelta = randomFloat(-HEIGHT_VARIATION / 2, HEIGHT_VARIATION)
    currentX = currentX + gap
    currentY = math.max(BASE_HEIGHT - 5, currentY + heightDelta)
    currentZ = currentZ + randomFloat(-6, 6)

    local platformWidth = PLATFORM_WIDTH + randomFloat(-2, 2)
    local platformDepth = PLATFORM_DEPTH + randomFloat(-2, 2)

    -- Тип платформы
    local isMoving = rng:NextNumber() < MOVING_CHANCE
    local isSpinning = (not isMoving) and (rng:NextNumber() < SPINNING_CHANCE)

    -- Цвет в зависимости от типа
    local color
    if isMoving then
        color = BrickColor.new("Bright yellow")
    elseif isSpinning then
        color = BrickColor.new("Bright orange")
    else
        color = BrickColor.new("Medium stone grey")
    end

    local platform = createPart({
        Name = "Stage_" .. i,
        Size = Vector3.new(platformWidth, 2, platformDepth),
        Position = Vector3.new(currentX, currentY, currentZ),
        BrickColor = color,
        Material = Enum.Material.SmoothPlastic,
    })

    ---------------------------------------------------------------
    -- ДВИЖУЩАЯСЯ ПЛАТФОРМА
    ---------------------------------------------------------------
    if isMoving then
        local startPos = platform.Position
        local endPos = startPos + Vector3.new(0, randomFloat(4, 8), 0)
        local tweenTime = randomFloat(2, 4)

        local tweenUp = TweenService:Create(
            platform,
            TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = endPos }
        )
        tweenUp:Play()
    end

    ---------------------------------------------------------------
    -- ВРАЩАЮЩАЯСЯ ПЛАТФОРМА
    ---------------------------------------------------------------
    if isSpinning then
        local speed = randomFloat(20, 60)
        RunService.Heartbeat:Connect(function(dt)
            if platform and platform.Parent then
                platform.CFrame = platform.CFrame * CFrame.Angles(0, math.rad(speed * dt), 0)
            end
        end)
    end

    ---------------------------------------------------------------
    -- KILL-БЛОК (лава)
    ---------------------------------------------------------------
    if rng:NextNumber() < KILL_BRICK_CHANCE then
        local killSize = Vector3.new(
            platformWidth + randomFloat(2, 6),
            1,
            platformDepth + randomFloat(2, 6)
        )
        local killPart = createPart({
            Name = "KillBrick_" .. i,
            Size = killSize,
            Position = Vector3.new(currentX, currentY - 4, currentZ),
            BrickColor = BrickColor.new("Really red"),
            Material = Enum.Material.Neon,
            Transparency = 0.3,
        })

        killPart.Touched:Connect(function(hit)
            local character = hit.Parent
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0
            end
        end)
    end

    ---------------------------------------------------------------
    -- ЧЕКПОИНТ (каждые 3 этапа)
    ---------------------------------------------------------------
    if i % 3 == 0 then
        local checkpoint = createPart({
            Name = "Checkpoint_" .. i,
            Size = Vector3.new(2, 4, 2),
            Position = Vector3.new(currentX, currentY + 3, currentZ),
            BrickColor = BrickColor.new("Bright blue"),
            Material = Enum.Material.Neon,
            CanCollide = false,
            Transparency = 0.4,
        })

        -- Свечение
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(85, 170, 255)
        light.Brightness = 2
        light.Range = 16
        light.Parent = checkpoint

        checkpoint.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                -- Устанавливаем точку респавна
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                    local stageVal = leaderstats:FindFirstChild("Stage")
                    if stageVal and i > stageVal.Value then
                        stageVal.Value = i
                        -- Визуальный эффект активации
                        checkpoint.BrickColor = BrickColor.new("Lime green")
                        local tween = TweenService:Create(
                            checkpoint,
                            TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                            { Transparency = 0.8 }
                        )
                        tween:Play()
                    end
                end
            end
        end)
    end

    ---------------------------------------------------------------
    -- МОНЕТКА
    ---------------------------------------------------------------
    if rng:NextNumber() < COIN_CHANCE then
        local coin = createPart({
            Name = "Coin_" .. i,
            Size = Vector3.new(2, 2, 0.4),
            Position = Vector3.new(currentX, currentY + 5, currentZ),
            BrickColor = BrickColor.new("Bright yellow"),
            Material = Enum.Material.Neon,
            Shape = Enum.PartType.Cylinder,
            CanCollide = false,
        })
        coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(0, 0, math.rad(90))
        coin.Parent = coinsFolder

        -- Вращение монетки
        local spinSpeed = randomFloat(60, 120)
        RunService.Heartbeat:Connect(function(dt)
            if coin and coin.Parent then
                coin.CFrame = coin.CFrame * CFrame.Angles(math.rad(spinSpeed * dt), 0, 0)
            end
        end)

        -- Сбор монетки
        coin.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                    local coinsVal = leaderstats:FindFirstChild("Coins")
                    if coinsVal then
                        coinsVal.Value = coinsVal.Value + 1
                        coin:Destroy()
                    end
                end
            end
        end)
    end

    stages[i] = {
        platform = platform,
        position = Vector3.new(currentX, currentY, currentZ),
    }
end

---------------------------------------------------------------------
-- ФИНИШНАЯ ПЛАТФОРМА
---------------------------------------------------------------------
currentX = currentX + GAP_MAX
local finishPlatform = createPart({
    Name = "FinishPlatform",
    Size = Vector3.new(20, 2, 20),
    Position = Vector3.new(currentX, currentY, currentZ),
    BrickColor = BrickColor.new("Gold"),
    Material = Enum.Material.Neon,
})

-- Трофей на финише (цилиндр + шар)
local trophy = createPart({
    Name = "Trophy",
    Size = Vector3.new(3, 6, 3),
    Position = Vector3.new(currentX, currentY + 5, currentZ),
    BrickColor = BrickColor.new("Gold"),
    Material = Enum.Material.Neon,
    Shape = Enum.PartType.Cylinder,
})
trophy.CFrame = CFrame.new(trophy.Position) * CFrame.Angles(0, 0, math.rad(90))

local trophyBall = createPart({
    Name = "TrophyBall",
    Size = Vector3.new(4, 4, 4),
    Position = Vector3.new(currentX, currentY + 9, currentZ),
    BrickColor = BrickColor.new("Gold"),
    Material = Enum.Material.Neon,
    Shape = Enum.PartType.Ball,
})

-- Свечение трофея
local trophyLight = Instance.new("PointLight")
trophyLight.Color = Color3.fromRGB(255, 215, 0)
trophyLight.Brightness = 3
trophyLight.Range = 30
trophyLight.Parent = trophyBall

-- Вращение трофея
RunService.Heartbeat:Connect(function(dt)
    if trophyBall and trophyBall.Parent then
        trophyBall.CFrame = trophyBall.CFrame * CFrame.Angles(0, math.rad(45 * dt), 0)
    end
end)

-- Триггер финиша
finishPlatform.Touched:Connect(function(hit)
    local character = hit.Parent
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local stageVal = leaderstats:FindFirstChild("Stage")
            if stageVal then
                stageVal.Value = STAGE_COUNT + 1
            end
        end

        -- Победное сообщение
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if playerGui and not playerGui:FindFirstChild("WinScreen") then
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "WinScreen"
            screenGui.Parent = playerGui

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0.5, 0, 0.3, 0)
            frame.Position = UDim2.new(0.25, 0, 0.35, 0)
            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            frame.BackgroundTransparency = 0.2
            frame.BorderSizePixel = 0
            frame.Parent = screenGui

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 16)
            corner.Parent = frame

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0.6, 0)
            label.Position = UDim2.new(0, 0, 0.1, 0)
            label.BackgroundTransparency = 1
            label.Text = "🏆 ПОБЕДА! 🏆"
            label.TextColor3 = Color3.fromRGB(255, 215, 0)
            label.TextScaled = true
            label.Font = Enum.Font.GothamBold
            label.Parent = frame

            local subLabel = Instance.new("TextLabel")
            subLabel.Size = UDim2.new(1, 0, 0.3, 0)
            subLabel.Position = UDim2.new(0, 0, 0.65, 0)
            subLabel.BackgroundTransparency = 1
            subLabel.Text = "Ты прошёл все этапы!"
            subLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            subLabel.TextScaled = true
            subLabel.Font = Enum.Font.Gotham
            subLabel.Parent = frame

            -- Исчезновение через 5 секунд
            task.delay(5, function()
                if screenGui and screenGui.Parent then
                    local fadeTween = TweenService:Create(
                        frame,
                        TweenInfo.new(1, Enum.EasingStyle.Quad),
                        { BackgroundTransparency = 1 }
                    )
                    fadeTween:Play()
                    fadeTween.Completed:Wait()
                    screenGui:Destroy()
                end
            end)
        end
    end
end)

---------------------------------------------------------------------
-- ПОЛ-УБИЙЦА (внизу)
---------------------------------------------------------------------
local killFloor = createPart({
    Name = "KillFloor",
    Size = Vector3.new(currentX + 50, 1, 200),
    Position = Vector3.new(currentX / 2, BASE_HEIGHT - 30, 0),
    BrickColor = BrickColor.new("Really red"),
    Material = Enum.Material.Neon,
    Transparency = 0.5,
})

killFloor.Touched:Connect(function(hit)
    local character = hit.Parent
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
    end
end)

---------------------------------------------------------------------
-- LEADERSTATS (очки и этап)
---------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local stageVal = Instance.new("IntValue")
    stageVal.Name = "Stage"
    stageVal.Value = 0
    stageVal.Parent = leaderstats

    local coinsVal = Instance.new("IntValue")
    coinsVal.Name = "Coins"
    coinsVal.Value = 0
    coinsVal.Parent = leaderstats

    -- Респавн на чекпоинте
    player.CharacterAdded:Connect(function(character)
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
        if humanoidRootPart and stageVal.Value > 0 then
            local stageIndex = math.min(stageVal.Value, #stages)
            local stageData = stages[stageIndex]
            if stageData then
                task.wait(0.1)
                humanoidRootPart.CFrame = CFrame.new(
                    stageData.position + Vector3.new(0, 5, 0)
                )
            end
        end
    end)
end)

---------------------------------------------------------------------
-- ДЕКОРАЦИИ: парящие кристаллы вдоль трассы
---------------------------------------------------------------------
for i = 1, 8 do
    local crystal = createPart({
        Name = "Crystal_" .. i,
        Size = Vector3.new(2, 4, 2),
        Position = Vector3.new(
            randomFloat(0, currentX),
            BASE_HEIGHT + randomFloat(10, 25),
            randomFloat(-20, 20)
        ),
        BrickColor = BrickColor.new("Toothpaste"),
        Material = Enum.Material.Neon,
        Transparency = 0.3,
        CanCollide = false,
    })

    local crystalLight = Instance.new("PointLight")
    crystalLight.Color = Color3.fromRGB(0, 255, 255)
    crystalLight.Brightness = 1.5
    crystalLight.Range = 20
    crystalLight.Parent = crystal

    -- Парящая анимация
    local startPos = crystal.Position
    TweenService:Create(
        crystal,
        TweenInfo.new(
            randomFloat(3, 6),
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,
            true
        ),
        { Position = startPos + Vector3.new(0, randomFloat(3, 6), 0) }
    ):Play()
end

---------------------------------------------------------------------
print("[ObbyGenerator] Обби успешно сгенерировано!")
print("[ObbyGenerator] Этапов: " .. STAGE_COUNT)
print("[ObbyGenerator] Скрипт размещён в ServerScriptService.")
