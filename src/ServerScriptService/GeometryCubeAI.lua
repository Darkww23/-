--[[
	GeometryCubeAI.lua
	Серверный скрипт для оживления существующей модели GeometryCube.
	Куб патрулирует только внутри зоны GeometryZone, обходит препятствия
	через PathfindingService и автоматически перепрыгивает низкие объекты.

	Требования к сцене:
	- В Workspace должна быть модель "GeometryCube" с Humanoid и HumanoidRootPart
	- В Workspace должна быть часть (Part) или папка "GeometryZone",
	  определяющая границы зоны перемещения

	Размещение: ServerScriptService (обычный Script)
]]

-- ========== СЕРВИСЫ ==========
local PathfindingService = game:GetService("PathfindingService")

-- ========== НАСТРОЙКИ ==========
local SETTINGS = {
	MinWaitTime = 2,            -- минимальное время ожидания между перемещениями (сек)
	MaxWaitTime = 5,            -- максимальное время ожидания между перемещениями (сек)
	MoveTimeout = 20,           -- максимальное время на весь маршрут (сек)
	WaypointTimeout = 4,        -- максимальное время на одну точку маршрута (сек)
	MaxPathAttempts = 5,        -- максимум попыток построить путь за одну итерацию
}

-- Параметры агента для PathfindingService
local PATH_PARAMS = {
	AgentRadius = 2,            -- радиус агента
	AgentHeight = 5,            -- высота агента
	AgentCanJump = true,        -- агент умеет прыгать
	AgentCanClimb = false,      -- агент не умеет лазить
	WaypointSpacing = 4,        -- расстояние между точками пути
}

-- ========== ОЖИДАНИЕ ОБЪЕКТОВ В WORKSPACE ==========
-- Ждём появления модели GeometryCube и зоны GeometryZone

local cube = game.Workspace:WaitForChild("GeometryCube", 30)
if not cube then
	warn("[GeometryCubeAI] Модель 'GeometryCube' не найдена в Workspace. Скрипт остановлен.")
	return
end

local humanoid = cube:WaitForChild("Humanoid", 10)
if not humanoid then
	warn("[GeometryCubeAI] Humanoid не найден внутри GeometryCube. Скрипт остановлен.")
	return
end

local rootPart = cube:WaitForChild("HumanoidRootPart", 10)
if not rootPart then
	warn("[GeometryCubeAI] HumanoidRootPart не найден внутри GeometryCube. Скрипт остановлен.")
	return
end

local zone = game.Workspace:WaitForChild("GeometryZone", 30)
if not zone then
	warn("[GeometryCubeAI] Зона 'GeometryZone' не найдена в Workspace. Скрипт остановлен.")
	return
end

print("[GeometryCubeAI] Все объекты найдены. Запуск AI куба.")

-- ========== ВЫЧИСЛЕНИЕ ГРАНИЦ ЗОНЫ ==========
-- Определяет границы зоны GeometryZone.
-- Если GeometryZone — это Part (прозрачный блок), берём его Size и Position.
-- Если GeometryZone — это Model/Folder, вычисляем BoundingBox по дочерним объектам.

local function getZoneBounds(): (Vector3, Vector3)
	local minBound, maxBound

	if zone:IsA("BasePart") then
		-- Зона — это один Part (прозрачный блок)
		local halfSize = zone.Size / 2
		local center = zone.Position
		minBound = center - halfSize
		maxBound = center + halfSize
	elseif zone:IsA("Model") then
		-- Зона — это Model, используем GetBoundingBox
		local cf, size = zone:GetBoundingBox()
		local center = cf.Position
		local halfSize = size / 2
		minBound = center - halfSize
		maxBound = center + halfSize
	else
		-- Зона — это Folder или другой контейнер, вычисляем вручную
		local parts = {}
		for _, child in ipairs(zone:GetDescendants()) do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end

		if #parts == 0 then
			warn("[GeometryCubeAI] GeometryZone не содержит частей. Используем зону по умолчанию.")
			return Vector3.new(-50, 0, -50), Vector3.new(50, 20, 50)
		end

		-- Вычисляем минимальные и максимальные координаты по всем частям
		minBound = Vector3.new(math.huge, math.huge, math.huge)
		maxBound = Vector3.new(-math.huge, -math.huge, -math.huge)

		for _, part in ipairs(parts) do
			local halfSize = part.Size / 2
			local pos = part.Position
			minBound = Vector3.new(
				math.min(minBound.X, pos.X - halfSize.X),
				math.min(minBound.Y, pos.Y - halfSize.Y),
				math.min(minBound.Z, pos.Z - halfSize.Z)
			)
			maxBound = Vector3.new(
				math.max(maxBound.X, pos.X + halfSize.X),
				math.max(maxBound.Y, pos.Y + halfSize.Y),
				math.max(maxBound.Z, pos.Z + halfSize.Z)
			)
		end
	end

	return minBound, maxBound
end

-- ========== ВЫБОР СЛУЧАЙНОЙ ТОЧКИ ВНУТРИ ЗОНЫ ==========
-- Генерирует случайную точку внутри границ GeometryZone.
-- Использует Raycast вниз, чтобы точка оказалась на поверхности пола.
local function getRandomPointInZone(): Vector3?
	local minBound, maxBound = getZoneBounds()
	local rng = Random.new()

	-- Делаем несколько попыток найти валидную точку
	for _ = 1, 15 do
		-- Случайные координаты внутри границ зоны (X и Z — горизонтальные)
		local randomX = rng:NextNumber(minBound.X, maxBound.X)
		local randomZ = rng:NextNumber(minBound.Z, maxBound.Z)

		-- Raycast вниз от верхней границы зоны для нахождения пола
		local rayOrigin = Vector3.new(randomX, maxBound.Y + 10, randomZ)
		local rayDirection = Vector3.new(0, -(maxBound.Y - minBound.Y + 20), 0)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		-- Исключаем саму модель куба из Raycast, чтобы не попасть в себя
		raycastParams.FilterDescendantsInstances = { cube }

		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result then
			-- Проверяем, что найденная точка находится внутри границ зоны по Y
			local hitY = result.Position.Y
			if hitY >= minBound.Y - 1 and hitY <= maxBound.Y + 1 then
				-- Поднимаем точку немного над полом
				return result.Position + Vector3.new(0, 2, 0)
			end
		end
	end

	-- Не удалось найти валидную точку
	return nil
end

-- ========== ДВИЖЕНИЕ К ТОЧКЕ С PATHFINDING ==========
-- Прокладывает путь через PathfindingService и ведёт куба по точкам маршрута.
-- Возвращает true, если куб успешно добрался до цели.
local function moveToPoint(destination: Vector3): boolean
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if not rootPart or not rootPart.Parent then
		return false
	end

	-- Создаём путь с параметрами агента
	local path = PathfindingService:CreatePath(PATH_PARAMS)

	-- Вычисляем путь от текущей позиции до цели (оборачиваем в pcall для безопасности)
	local computeSuccess, computeError = pcall(function()
		path:ComputeAsync(rootPart.Position, destination)
	end)

	if not computeSuccess then
		-- Ошибка при вычислении пути — пропускаем итерацию без спама в консоль
		return false
	end

	-- Проверяем, удалось ли построить путь
	if path.Status ~= Enum.PathStatus.Success then
		-- Путь не найден (точка внутри стены или недоступна) — пропускаем
		return false
	end

	-- Получаем точки маршрута (waypoints)
	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then
		return false
	end

	-- Флаг блокировки пути
	local isPathBlocked = false

	-- Обработчик события блокировки пути — при блокировке прерываем маршрут
	local blockedConnection = path.Blocked:Connect(function(_blockedWaypointIndex: number)
		isPathBlocked = true
	end)

	-- Засекаем время начала перемещения (для проверки общего таймаута)
	local moveStartTime = tick()

	-- Проходим по каждой точке маршрута (начинаем с 2-й, т.к. 1-я — текущая позиция)
	for i = 2, #waypoints do
		local waypoint = waypoints[i]

		-- Проверка общего таймаута на весь маршрут
		if tick() - moveStartTime > SETTINGS.MoveTimeout then
			blockedConnection:Disconnect()
			return false
		end

		-- Проверка блокировки пути
		if isPathBlocked then
			blockedConnection:Disconnect()
			return false
		end

		-- Подписываемся на MoveToFinished ДО вызова MoveTo,
		-- чтобы перехватить ложный MoveToFinished(false) от отмены предыдущего MoveTo
		local waypointReached = false
		local moveFinishedConnection
		moveFinishedConnection = humanoid.MoveToFinished:Connect(function(reached: boolean)
			if reached then
				waypointReached = true
			end
			moveFinishedConnection:Disconnect()
		end)

		-- Если точка маршрута требует прыжка (ступенька, низкий объект)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		-- Двигаем куб к следующей точке маршрута
		humanoid:MoveTo(waypoint.Position)

		-- Ждём завершения движения к точке с проверками таймаутов
		local waypointStartTime = tick()

		while not waypointReached do
			-- Таймаут на одну точку
			if tick() - waypointStartTime > SETTINGS.WaypointTimeout then
				moveFinishedConnection:Disconnect()
				blockedConnection:Disconnect()
				return false
			end

			-- Общий таймаут на маршрут
			if tick() - moveStartTime > SETTINGS.MoveTimeout then
				moveFinishedConnection:Disconnect()
				blockedConnection:Disconnect()
				return false
			end

			-- Блокировка пути
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
-- Бесконечный цикл: выбираем случайную точку в зоне → идём к ней → ждём → повторяем.
local function startPatrol()
	local rng = Random.new()

	while true do
		-- Проверяем, что куб ещё существует и «жив»
		if not cube.Parent or not humanoid or humanoid.Health <= 0 then
			warn("[GeometryCubeAI] Куб уничтожен или мёртв. Останавливаем патрулирование.")
			break
		end

		-- Пытаемся найти доступную точку и построить к ней путь
		local moved = false

		for _ = 1, SETTINGS.MaxPathAttempts do
			local destination = getRandomPointInZone()

			if destination then
				local success = moveToPoint(destination)
				if success then
					moved = true
					break
				end
			end
			-- Точка недоступна или путь не построен — пробуем другую
		end

		if moved then
			-- Успешно дошли — ждём случайное время от 2 до 5 секунд
			local waitTime = rng:NextNumber(SETTINGS.MinWaitTime, SETTINGS.MaxWaitTime)
			task.wait(waitTime)
		else
			-- Не удалось найти доступный путь за все попытки — ждём и пробуем снова
			task.wait(SETTINGS.MinWaitTime)
		end
	end
end

-- ========== ИНИЦИАЛИЗАЦИЯ ==========
-- Небольшая задержка для загрузки мира
task.wait(1)

print("[GeometryCubeAI] Запуск патрулирования GeometryCube внутри GeometryZone...")
startPatrol()
