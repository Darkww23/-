--[[
	NPCController.lua
	Скрипт для NPC (куба) в Roblox Studio.
	
	Поведение:
	  - NPC патрулирует случайные точки внутри заданной зоны
	  - При клике на NPC он начинает следовать за игроком
	  - Повторный клик возвращает NPC в режим патрулирования
	
	Настройка:
	  1. Создай Part (куб) — это будет NPC
	  2. Внутрь NPC добавь этот Script (серверный скрипт)
	  3. Создай невидимую Part с именем "PatrolZone" — зона патрулирования
	     (можно сделать её прозрачной: Transparency = 1, CanCollide = false)
	  4. Поставь PatrolZone в Workspace
	  
	Структура NPC:
	  NPC (Part)
	    ├── Script (этот скрипт)
	    └── ClickDetector
--]]

-- ============ НАСТРОЙКИ ============
local PATROL_SPEED = 16          -- Скорость патрулирования
local FOLLOW_SPEED = 24          -- Скорость следования за игроком
local PATROL_WAIT_TIME = 2       -- Пауза в точке патрулирования (сек)
local FOLLOW_STOP_DISTANCE = 5   -- Минимальная дистанция до игрока
local PATROL_ZONE_NAME = "PatrolZone" -- Имя Part-зоны патрулирования
local NPC_HEIGHT = 3             -- Высота NPC над землёй
-- ====================================

local npc = script.Parent
local clickDetector = npc:FindFirstChildOfClass("ClickDetector")

-- Создаём ClickDetector если его нет
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.Parent = npc
end

-- Состояния NPC
local STATE_PATROL = "Patrolling"
local STATE_FOLLOW = "Following"
local currentState = STATE_PATROL

-- Текущий игрок, за которым следуем
local targetPlayer = nil

-- Ищем зону патрулирования
local patrolZone = workspace:FindFirstChild(PATROL_ZONE_NAME)
if not patrolZone then
	warn("NPCController: Не найден объект '" .. PATROL_ZONE_NAME .. "' в Workspace!")
	warn("NPCController: Создаю зону патрулирования 50x50 вокруг NPC")
	
	patrolZone = Instance.new("Part")
	patrolZone.Name = PATROL_ZONE_NAME
	patrolZone.Size = Vector3.new(50, 1, 50)
	patrolZone.Position = npc.Position
	patrolZone.Anchored = true
	patrolZone.CanCollide = false
	patrolZone.Transparency = 0.8
	patrolZone.BrickColor = BrickColor.new("Lime green")
	patrolZone.Parent = workspace
end

--- Получить случайную точку внутри зоны патрулирования
local function getRandomPatrolPoint(): Vector3
	local zonePos = patrolZone.Position
	local zoneSize = patrolZone.Size
	
	local x = zonePos.X + math.random() * zoneSize.X - zoneSize.X / 2
	local z = zonePos.Z + math.random() * zoneSize.Z - zoneSize.Z / 2
	local y = zonePos.Y + NPC_HEIGHT
	
	return Vector3.new(x, y, z)
end

--- Плавно двигать NPC к точке
local function moveTowards(targetPos: Vector3, speed: number, dt: number)
	local currentPos = npc.Position
	local direction = (targetPos - currentPos)
	-- Игнорируем вертикальную составляющую для расчёта расстояния
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	local distance = flatDirection.Magnitude
	
	if distance < 0.5 then
		return true -- Достигли цели
	end
	
	local moveDir = flatDirection.Unit
	local step = math.min(speed * dt, distance)
	
	npc.CFrame = CFrame.new(
		currentPos + moveDir * step,
		currentPos + moveDir * step + moveDir
	)
	
	return false
end

--- Получить позицию персонажа игрока
local function getPlayerPosition(): Vector3?
	if not targetPlayer then return nil end
	
	local character = targetPlayer.Character
	if not character then return nil end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	return rootPart.Position
end

--- Расстояние до игрока (горизонтальное)
local function distanceToPlayer(): number
	local playerPos = getPlayerPosition()
	if not playerPos then return math.huge end
	
	local npcPos = npc.Position
	return (Vector3.new(playerPos.X, 0, playerPos.Z) - Vector3.new(npcPos.X, 0, npcPos.Z)).Magnitude
end

-- Обработка клика по NPC
clickDetector.MouseClick:Connect(function(player)
	if currentState == STATE_PATROL then
		currentState = STATE_FOLLOW
		targetPlayer = player
		print("NPC: Следую за " .. player.Name)
	else
		currentState = STATE_PATROL
		targetPlayer = nil
		print("NPC: Патрулирую зону")
	end
end)

-- Убедимся что NPC не двигается физикой
npc.Anchored = true

-- Главный цикл NPC
local currentTarget = getRandomPatrolPoint()
local waitTimer = 0
local isWaiting = false

while true do
	local dt = task.wait()  -- ~1/30 сек, возвращает delta time
	
	if currentState == STATE_PATROL then
		-- === РЕЖИМ ПАТРУЛИРОВАНИЯ ===
		if isWaiting then
			waitTimer += dt
			if waitTimer >= PATROL_WAIT_TIME then
				isWaiting = false
				currentTarget = getRandomPatrolPoint()
			end
		else
			local reached = moveTowards(currentTarget, PATROL_SPEED, dt)
			if reached then
				isWaiting = true
				waitTimer = 0
			end
		end
		
	elseif currentState == STATE_FOLLOW then
		-- === РЕЖИМ СЛЕДОВАНИЯ ===
		local playerPos = getPlayerPosition()
		
		if playerPos then
			local dist = distanceToPlayer()
			if dist > FOLLOW_STOP_DISTANCE then
				moveTowards(playerPos, FOLLOW_SPEED, dt)
			end
		else
			-- Игрок вышел / умер — возвращаемся к патрулированию
			currentState = STATE_PATROL
			targetPlayer = nil
			currentTarget = getRandomPatrolPoint()
			print("NPC: Игрок потерян, возвращаюсь к патрулированию")
		end
	end
end
