--[[
	CubeNPC.lua
	Серверный скрипт для управления поведением куба-NPC.
	Куб бесконечно бродит по дому, выбирая случайные точки в радиусе 50 студов,
	обходит препятствия через PathfindingService и автоматически прыгает
	через низкие объекты.

	Размещение: ServerScriptService (обычный Script)
]]

-- ========== СЕРВИСЫ ==========
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

-- ========== НАСТРОЙКИ ==========
local SETTINGS = {
	WanderRadius = 50,          -- радиус выбора случайной точки (в студах)
	WalkSpeed = 10,             -- скорость ходьбы куба
	JumpPower = 50,             -- сила прыжка
	RetryDelay = 2,             -- задержка перед повторным выбором точки (сек)
	MoveTimeout = 15,           -- максимальное время на переход к точке (сек)
	WaypointReachDist = 4,      -- расстояние, при котором точка считается достигнутой
	CubeSize = Vector3.new(4, 4, 4), -- размер куба
	CubeColor = Color3.fromRGB(0, 170, 255), -- цвет куба
	SpawnPosition = Vector3.new(0, 5, 0), -- стартовая позиция куба
}

-- Параметры агента для PathfindingService
local PATH_PARAMS = {
	AgentRadius = 2,            -- радиус агента (половина ширины куба)
	AgentHeight = 4,            -- высота агента
	AgentCanJump = true,        -- агент умеет прыгать
	AgentCanClimb = false,      -- агент не умеет лазить
	WaypointSpacing = 4,        -- расстояние между точками пути
}

-- ========== СОЗДАНИЕ МОДЕЛИ КУБА ==========
-- Создаёт модель куба со структурой Character (Humanoid + HumanoidRootPart + визуальная часть)
local function createCubeModel(): Model
	local model = Instance.new("Model")
	model.Name = "CubeNPC"

	-- Корневая часть (HumanoidRootPart) — невидимая основа для перемещения
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = SETTINGS.CubeSize
	rootPart.Position = SETTINGS.SpawnPosition
	rootPart.Transparency = 1
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Parent = model

	-- Визуальная часть куба (привязана к корневой части через WeldConstraint)
	local cubeVisual = Instance.new("Part")
	cubeVisual.Name = "CubeVisual"
	cubeVisual.Size = SETTINGS.CubeSize
	cubeVisual.Position = SETTINGS.SpawnPosition
	cubeVisual.Material = Enum.Material.SmoothPlastic
	cubeVisual.Color = SETTINGS.CubeColor
	cubeVisual.Anchored = false
	cubeVisual.CanCollide = false
	cubeVisual.Parent = model

	-- Привязка визуальной части к корневой через WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = cubeVisual
	weld.Parent = cubeVisual

	-- Humanoid — необходим для PathfindingService и движения через MoveTo
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = SETTINGS.WalkSpeed
	humanoid.JumpPower = SETTINGS.JumpPower
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model

	-- Имя над головой (BillboardGui)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(4, 0, 0.6, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = rootPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Куб-NPC"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	-- Устанавливаем корневую часть как PrimaryPart модели
	model.PrimaryPart = rootPart
	model.Parent = workspace

	return model
end

-- ========== ВЫБОР СЛУЧАЙНОЙ ТОЧКИ ==========
-- Генерирует случайную точку в радиусе wanderRadius от текущей позиции куба.
-- Использует Raycast вниз, чтобы точка была на поверхности пола.
local function getRandomDestination(currentPosition: Vector3): Vector3?
	local rng = Random.new()

	-- Делаем несколько попыток найти валидную точку на полу
	for _ = 1, 10 do
		-- Случайное смещение в горизонтальной плоскости (X, Z)
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(10, SETTINGS.WanderRadius)
		local offsetX = math.cos(angle) * distance
		local offsetZ = math.sin(angle) * distance

		-- Начальная точка для Raycast: высоко над целевой позицией
		local rayOrigin = Vector3.new(
			currentPosition.X + offsetX,
			currentPosition.Y + 50, -- бросаем луч сверху
			currentPosition.Z + offsetZ
		)

		-- Raycast вниз для определения поверхности пола
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {} -- исключаем ничего, ищем любой пол

		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), raycastParams)

		if result then
			-- Точка найдена на поверхности — поднимаем немного над полом
			return result.Position + Vector3.new(0, 2, 0)
		end
	end

	-- Если ни одна точка не найдена, возвращаем nil
	return nil
end

-- ========== ДВИЖЕНИЕ К ТОЧКЕ С PATHFINDING ==========
-- Прокладывает путь через PathfindingService и ведёт куба по точкам маршрута.
-- Возвращает true, если куб успешно добрался до цели.
local function moveToDestination(model: Model, destination: Vector3): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model.PrimaryPart

	if not humanoid or not rootPart then
		return false
	end

	-- Создаём путь с параметрами агента
	local path = PathfindingService:CreatePath(PATH_PARAMS)

	-- Вычисляем путь от текущей позиции до цели
	local success, errorMessage = pcall(function()
		path:ComputeAsync(rootPart.Position, destination)
	end)

	if not success then
		warn("[CubeNPC] Ошибка вычисления пути: " .. tostring(errorMessage))
		return false
	end

	-- Проверяем, удалось ли построить путь
	if path.Status ~= Enum.PathStatus.Success then
		warn("[CubeNPC] Путь не найден (статус: " .. tostring(path.Status) .. "). Выбираем новую точку.")
		return false
	end

	-- Получаем точки маршрута (waypoints)
	local waypoints = path:GetWaypoints()

	if #waypoints == 0 then
		return false
	end

	-- Флаг блокировки пути — устанавливается обработчиком события path.Blocked
	local isPathBlocked = false

	-- Обработчик события блокировки пути
	-- Если путь заблокирован на точке впереди, прерываем движение и перестраиваем
	local blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex: number)
		warn("[CubeNPC] Путь заблокирован на точке #" .. blockedWaypointIndex .. ". Перестраиваем маршрут.")
		isPathBlocked = true
	end)

	-- Засекаем время начала перемещения (для проверки таймаута)
	local moveStartTime = tick()

	-- Проходим по каждой точке маршрута
	for i = 2, #waypoints do -- начинаем с 2-й точки (1-я — текущая позиция)
		local waypoint = waypoints[i]

		-- Проверка таймаута: если время перемещения превысило лимит, прерываем
		if tick() - moveStartTime > SETTINGS.MoveTimeout then
			warn("[CubeNPC] Превышен таймаут перемещения (" .. SETTINGS.MoveTimeout .. " сек). Прерываем маршрут.")
			blockedConnection:Disconnect()
			return false
		end

		-- Проверка блокировки пути
		if isPathBlocked then
			blockedConnection:Disconnect()
			return false
		end

		-- Ожидаем, пока куб достигнет точки или истечёт время ожидания (3 сек на точку)
		local waypointReached = false
		local waypointStartTime = tick()
		local maxWaypointTime = 3 -- максимум 3 секунды на одну точку

		-- Подписываемся на событие MoveToFinished ДО вызова MoveTo,
		-- чтобы перехватить ложный MoveToFinished(false) от отмены предыдущего MoveTo.
		-- НЕ отключаемся при reached == false, чтобы обработчик остался для реального сигнала.
		local moveFinishedConnection
		moveFinishedConnection = humanoid.MoveToFinished:Connect(function(reached: boolean)
			if reached then
				waypointReached = true
				moveFinishedConnection:Disconnect()
			end
		end)

		-- Если точка маршрута требует прыжка (например, ступенька или низкий объект)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		-- Двигаем куб к следующей точке маршрута
		humanoid:MoveTo(waypoint.Position)

		-- Ждём завершения движения к точке с проверкой таймаута
		while not waypointReached do
			-- Таймаут на одну точку — прерываем весь маршрут
			if tick() - waypointStartTime > maxWaypointTime then
				warn("[CubeNPC] Таймаут на точке маршрута #" .. i .. ". Прерываем маршрут.")
				moveFinishedConnection:Disconnect()
				blockedConnection:Disconnect()
				return false
			end

			-- Общий таймаут — прерываем весь маршрут
			if tick() - moveStartTime > SETTINGS.MoveTimeout then
				moveFinishedConnection:Disconnect()
				blockedConnection:Disconnect()
				return false
			end

			-- Блокировка пути — прерываем весь маршрут
			if isPathBlocked then
				moveFinishedConnection:Disconnect()
				blockedConnection:Disconnect()
				return false
			end

			task.wait(0.1)
		end
	end

	-- Отключаем обработчик блокировки
	blockedConnection:Disconnect()

	return true
end

-- ========== ГЛАВНЫЙ ЦИКЛ ПОВЕДЕНИЯ ==========
-- Бесконечный цикл: выбираем случайную точку → идём к ней → повторяем.
local function startBehaviorLoop(model: Model)
	local rootPart = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if not rootPart or not humanoid then
		warn("[CubeNPC] Невозможно запустить цикл: отсутствует PrimaryPart или Humanoid.")
		return
	end

	-- Бесконечный цикл патрулирования
	while true do
		-- Проверяем, что куб ещё «жив» (модель существует в workspace)
		if not model.Parent or humanoid.Health <= 0 then
			warn("[CubeNPC] Куб уничтожен или мёртв. Останавливаем цикл.")
			break
		end

		-- Выбираем случайную точку назначения
		local destination = getRandomDestination(rootPart.Position)

		if destination then
			-- Пытаемся дойти до точки
			local reached = moveToDestination(model, destination)

			if reached then
				-- Успешно добрались — небольшая пауза перед следующим перемещением
				task.wait(1)
			else
				-- Не удалось дойти — ждём и выбираем новую точку
				warn("[CubeNPC] Не удалось добраться до точки. Ожидание " .. SETTINGS.RetryDelay .. " сек.")
				task.wait(SETTINGS.RetryDelay)
			end
		else
			-- Не удалось найти валидную точку — ждём и пробуем снова
			warn("[CubeNPC] Не найдена валидная точка назначения. Ожидание " .. SETTINGS.RetryDelay .. " сек.")
			task.wait(SETTINGS.RetryDelay)
		end
	end
end

-- ========== ИНИЦИАЛИЗАЦИЯ ==========
-- Создаём куба и запускаем его поведение

-- Небольшая задержка, чтобы мир успел загрузиться
task.wait(2)

print("[CubeNPC] Инициализация куба-NPC...")

-- Создаём модель куба
local cubeModel = createCubeModel()
print("[CubeNPC] Куб создан на позиции: " .. tostring(SETTINGS.SpawnPosition))

-- Запускаем бесконечный цикл поведения
startBehaviorLoop(cubeModel)
