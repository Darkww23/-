--[[
	NPCController.lua
	Скрипт для NPC-гуманоида в Roblox Studio.
	
	Поведение:
	  - NPC патрулирует случайные точки внутри заданной зоны
	  - При клике на NPC он начинает следовать за игроком
	  - Повторный клик возвращает NPC в режим патрулирования
	  - NPC использует Humanoid для плавной ходьбы и анимаций
	
	Настройка:
	  1. Создай Model — это будет NPC
	  2. Внутрь модели добавь Part (куб, тело NPC) и назови "HumanoidRootPart"
	  3. Добавь Humanoid внутрь модели
	  4. Внутрь модели добавь этот Script
	  5. Создай Part с именем "PatrolZone" в Workspace — зона патрулирования
	  
	  Или используй автоматическую сборку — скрипт сам создаст
	  модель NPC с Humanoid, если родитель скрипта — обычная Part.
	  
	Структура NPC (Model):
	  NPCModel
	    ├── HumanoidRootPart (Part — тело/куб)
	    ├── Humanoid
	    ├── ClickDetector (внутри HumanoidRootPart)
	    └── Script (этот скрипт)
--]]

-- ============ НАСТРОЙКИ ============
local PATROL_SPEED = 12          -- Скорость патрулирования
local FOLLOW_SPEED = 20          -- Скорость следования за игроком
local PATROL_WAIT_TIME = 2       -- Пауза в точке патрулирования (сек)
local FOLLOW_STOP_DISTANCE = 5   -- Минимальная дистанция до игрока
local PATROL_ZONE_NAME = "PatrolZone" -- Имя Part-зоны патрулирования
local MOVE_TO_TIMEOUT = 8        -- Таймаут MoveTo (сек), чтобы не застревать
-- ====================================

-- ============ СБОРКА NPC ============
-- Если скрипт лежит внутри обычной Part, автоматически
-- превращаем её в полноценную модель с Humanoid.

local parent = script.Parent
local npcModel, humanoid, rootPart

if parent:IsA("Model") then
	npcModel = parent
	humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	rootPart = npcModel:FindFirstChild("HumanoidRootPart")
	
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = npcModel
	end
	if not rootPart then
		warn("NPCController: HumanoidRootPart не найден в модели!")
		return
	end
else
	-- Родитель — обычная Part. Создаём модель вокруг неё.
	local part = parent
	
	npcModel = Instance.new("Model")
	npcModel.Name = "NPC"
	npcModel.Parent = part.Parent
	
	-- Настраиваем Part как HumanoidRootPart
	part.Name = "HumanoidRootPart"
	part.Parent = npcModel
	part.Anchored = false
	
	-- Добавляем Humanoid
	humanoid = Instance.new("Humanoid")
	humanoid.Parent = npcModel

	-- Перемещаем скрипт в модель
	script.Parent = npcModel
	
	npcModel.PrimaryPart = part
	rootPart = part
end

-- Настраиваем Humanoid
humanoid.WalkSpeed = PATROL_SPEED

-- ClickDetector на видимой части NPC
local clickDetector = rootPart:FindFirstChildOfClass("ClickDetector")
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.Parent = rootPart
end

-- ============ СОСТОЯНИЕ ============
local STATE_PATROL = "Patrolling"
local STATE_FOLLOW = "Following"
local currentState = STATE_PATROL
local targetPlayer = nil

-- ============ ЗОНА ПАТРУЛИРОВАНИЯ ============
local patrolZone = workspace:FindFirstChild(PATROL_ZONE_NAME)
if not patrolZone then
	warn("NPCController: Не найден '" .. PATROL_ZONE_NAME .. "' — создаю зону 50x50")
	
	patrolZone = Instance.new("Part")
	patrolZone.Name = PATROL_ZONE_NAME
	patrolZone.Size = Vector3.new(50, 1, 50)
	patrolZone.Position = rootPart.Position
	patrolZone.Anchored = true
	patrolZone.CanCollide = false
	patrolZone.Transparency = 0.8
	patrolZone.BrickColor = BrickColor.new("Lime green")
	patrolZone.Parent = workspace
end

-- ============ ФУНКЦИИ ============

--- Получить случайную точку внутри зоны патрулирования
local function getRandomPatrolPoint(): Vector3
	local zonePos = patrolZone.Position
	local zoneSize = patrolZone.Size
	
	local x = zonePos.X + math.random() * zoneSize.X - zoneSize.X / 2
	local z = zonePos.Z + math.random() * zoneSize.Z - zoneSize.Z / 2
	
	return Vector3.new(x, zonePos.Y + 3, z)
end

--- Получить позицию персонажа игрока
local function getPlayerPosition(): Vector3?
	if not targetPlayer then return nil end
	
	local character = targetPlayer.Character
	if not character then return nil end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	
	return hrp.Position
end

--- Горизонтальное расстояние между NPC и точкой
local function horizontalDistance(target: Vector3): number
	local npcPos = rootPart.Position
	return (Vector3.new(target.X, 0, target.Z) - Vector3.new(npcPos.X, 0, npcPos.Z)).Magnitude
end

--- Плавно двигать NPC к точке через Humanoid:MoveTo()
--- Возвращает true когда NPC достиг цели или истёк таймаут.
local function moveToPoint(target: Vector3): boolean
	humanoid:MoveTo(target)
	
	local reached = humanoid.MoveToFinished:Wait(MOVE_TO_TIMEOUT)
	return reached
end

-- ============ ОБРАБОТКА КЛИКА ============
clickDetector.MouseClick:Connect(function(player)
	if currentState == STATE_PATROL then
		currentState = STATE_FOLLOW
		targetPlayer = player
		humanoid.WalkSpeed = FOLLOW_SPEED
		print("NPC: Следую за " .. player.Name)
	else
		currentState = STATE_PATROL
		targetPlayer = nil
		humanoid.WalkSpeed = PATROL_SPEED
		print("NPC: Патрулирую зону")
	end
end)

-- Если игрок вышел из игры — вернуться к патрулированию
game.Players.PlayerRemoving:Connect(function(player)
	if targetPlayer == player then
		currentState = STATE_PATROL
		targetPlayer = nil
		humanoid.WalkSpeed = PATROL_SPEED
		print("NPC: Игрок вышел, возвращаюсь к патрулированию")
	end
end)

-- ============ ГЛАВНЫЙ ЦИКЛ ============
while true do
	if currentState == STATE_PATROL then
		-- === РЕЖИМ ПАТРУЛИРОВАНИЯ ===
		local target = getRandomPatrolPoint()
		moveToPoint(target)
		
		-- Пауза перед следующей точкой
		if currentState == STATE_PATROL then
			task.wait(PATROL_WAIT_TIME)
		end
		
	elseif currentState == STATE_FOLLOW then
		-- === РЕЖИМ СЛЕДОВАНИЯ ===
		local playerPos = getPlayerPosition()
		
		if playerPos then
			local dist = horizontalDistance(playerPos)
			if dist > FOLLOW_STOP_DISTANCE then
				-- Двигаемся к игроку короткими шагами для плавного преследования
				humanoid:MoveTo(playerPos)
				task.wait(0.2)
			else
				-- Слишком близко — стоим и ждём
				task.wait(0.1)
			end
		else
			-- Игрок потерян — возвращаемся к патрулированию
			currentState = STATE_PATROL
			targetPlayer = nil
			humanoid.WalkSpeed = PATROL_SPEED
			print("NPC: Игрок потерян, возвращаюсь к патрулированию")
		end
	else
		task.wait(0.1)
	end
end
