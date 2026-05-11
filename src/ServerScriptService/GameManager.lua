--[[
	GameManager.lua
	Main orchestrator: initializes all systems, manages dungeon progression,
	player spawning, floor transitions, and the game loop.
	Place in: ServerScriptService/GameManager (Script, not ModuleScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========== LOAD MODULES ==========
local Config = require(ReplicatedStorage.SharedModules.Config)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local DungeonGenerator = require(ServerScriptService.DungeonGenerator)
local EnemyAI = require(ServerScriptService.EnemyAI)
local CombatSystem = require(ServerScriptService.CombatSystem)
local LootSystem = require(ServerScriptService.LootSystem)

-- ========== REMOTE EVENTS ==========
local function ensureRemote(name, className)
	className = className or "RemoteEvent"
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local floorChangedEvent = ensureRemote("FloorChanged")
local dungeonReadyEvent = ensureRemote("DungeonReady")
local gameOverEvent = ensureRemote("GameOver")
local requestNextFloorEvent = ensureRemote("RequestNextFloor")
local dungeonInfoEvent = ensureRemote("DungeonInfo")

-- ========== STATE ==========
local currentFloor = 1
local dungeonData = nil
local gameActive = false
local enemiesAlive = 0
local bossAlive = false

-- ========== ENEMY SPAWNING ==========
local function spawnEnemies(dungeon)
	local spawnsFolder = dungeon.Folder:FindFirstChild("Spawns")
	if not spawnsFolder then return end

	local enemyTypes = {}
	for name, _ in pairs(Config.Enemy.Types) do
		table.insert(enemyTypes, name)
	end

	enemiesAlive = 0

	for _, spawn in ipairs(spawnsFolder:GetChildren()) do
		if spawn.Name == "EnemySpawn" then
			local enemyType = enemyTypes[math.random(1, #enemyTypes)]
			local enemy = EnemyAI:SpawnEnemy(enemyType, spawn.Position, currentFloor, false)
			if enemy then
				CombatSystem:SetupEnemyCallbacks(enemy)

				local originalOnDeath = enemy.OnDeath
				enemy.OnDeath = function()
					if originalOnDeath then originalOnDeath() end
					enemiesAlive = enemiesAlive - 1
					checkFloorComplete()
				end

				enemiesAlive = enemiesAlive + 1
			end
		end
	end

	-- Boss spawning
	if dungeon.HasBoss and dungeon.BossRoom then
		local bossTypes = {}
		for name, _ in pairs(Config.Enemy.Boss) do
			table.insert(bossTypes, name)
		end
		local bossType = bossTypes[math.random(1, #bossTypes)]
		local bossPos = Vector3.new(dungeon.BossRoom.CenterX, 3, dungeon.BossRoom.CenterZ)

		local boss = EnemyAI:SpawnEnemy(bossType, bossPos, currentFloor, true)
		if boss then
			CombatSystem:SetupEnemyCallbacks(boss)
			bossAlive = true

			local originalOnDeath = boss.OnDeath
			boss.OnDeath = function()
				if originalOnDeath then originalOnDeath() end
				bossAlive = false
				enemiesAlive = enemiesAlive - 1

				-- Boss death announcement
				for _, player in ipairs(Players:GetPlayers()) do
					gameOverEvent:FireClient(player, "BossDefeated", bossType, currentFloor)
				end

				checkFloorComplete()
			end

			enemiesAlive = enemiesAlive + 1
		end
	end

	print("[GameManager] Spawned " .. enemiesAlive .. " enemies on floor " .. currentFloor)
end

-- ========== FLOOR MANAGEMENT ==========
function checkFloorComplete()
	if enemiesAlive <= 0 then
		print("[GameManager] Floor " .. currentFloor .. " cleared!")
		for _, player in ipairs(Players:GetPlayers()) do
			local data = PlayerDataManager:GetData(player)
			if data then
				data.DungeonsCleared = data.DungeonsCleared + 1
				if currentFloor > data.MaxFloorReached then
					data.MaxFloorReached = currentFloor
				end
			end
		end

		-- Enable exit portal
		if dungeonData and dungeonData.ExitPortal then
			local portal = dungeonData.ExitPortal
			portal.Transparency = 0
			portal.Material = Enum.Material.Neon

			local portalPrompt = portal:FindFirstChild("ProximityPrompt")
			if not portalPrompt then
				portalPrompt = Instance.new("ProximityPrompt")
				portalPrompt.ActionText = "Enter Next Floor"
				portalPrompt.HoldDuration = 1
				portalPrompt.MaxActivationDistance = 12
				portalPrompt.Parent = portal
			end
			portalPrompt.Enabled = true
		end
	end
end

local function startFloor(floorNumber)
	currentFloor = floorNumber
	LootSystem.CurrentFloor = floorNumber

	-- Cleanup previous floor
	EnemyAI:ClearAll()

	-- Generate new dungeon
	dungeonData = DungeonGenerator:Generate(floorNumber)

	-- Spawn enemies
	spawnEnemies(dungeonData)

	-- Teleport players to spawn
	local spawnPos = Vector3.new(
		dungeonData.SpawnRoom.CenterX,
		3,
		dungeonData.SpawnRoom.CenterZ
	)

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character or player.CharacterAdded:Wait()
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
		if hrp then
			hrp.CFrame = CFrame.new(spawnPos)
		end

		-- Heal player on new floor
		local data = PlayerDataManager:GetData(player)
		if data then
			data.CurrentHealth = data.Stats.MaxHealth
			data.CurrentMana = data.Stats.MaxMana
			data.CurrentStamina = data.Stats.MaxStamina
			PlayerDataManager:SyncToClient(player)
		end

		floorChangedEvent:FireClient(player, floorNumber)
		dungeonInfoEvent:FireClient(player, {
			FloorNumber = floorNumber,
			RoomCount = #dungeonData.Rooms,
			HasBoss = dungeonData.HasBoss,
			EnemyCount = enemiesAlive,
		})
	end

	-- Setup exit portal interaction
	if dungeonData.ExitPortal then
		local existingPrompt = dungeonData.ExitPortal:FindFirstChild("ProximityPrompt")
		if existingPrompt then
			existingPrompt.Enabled = false
		end

		local touched = false
		dungeonData.ExitPortal.Touched:Connect(function(hit)
			if touched then return end
			if enemiesAlive > 0 then return end

			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				touched = true
				startFloor(currentFloor + 1)
			end
		end)
	end

	dungeonReadyEvent:FireAllClients(floorNumber)
	gameActive = true

	print("[GameManager] Floor " .. floorNumber .. " started!")
end

-- ========== PLAYER SPAWNING ==========
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		-- Wait for dungeon to be ready
		task.wait(1)

		if dungeonData and dungeonData.SpawnRoom then
			local spawnPos = Vector3.new(
				dungeonData.SpawnRoom.CenterX,
				3,
				dungeonData.SpawnRoom.CenterZ
			)
			local hrp = character:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				hrp.CFrame = CFrame.new(spawnPos)
			end
		end
	end)
end

-- ========== INITIALIZATION ==========
print("===========================================")
print("  RPG DUNGEON CRAWLER v1.0")
print("  Initializing game systems...")
print("===========================================")

-- Init all systems
PlayerDataManager:Init()
EnemyAI:Init()
LootSystem:Init(PlayerDataManager)
CombatSystem:Init(PlayerDataManager, EnemyAI, LootSystem)

-- Player connections
Players.PlayerAdded:Connect(onPlayerAdded)

-- Next floor request
requestNextFloorEvent.OnServerEvent:Connect(function(player)
	if enemiesAlive <= 0 then
		startFloor(currentFloor + 1)
	end
end)

-- Start first floor
task.wait(2)
startFloor(1)

print("===========================================")
print("  All systems online. Game started!")
print("===========================================")
