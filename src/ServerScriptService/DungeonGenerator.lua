--[[
	DungeonGenerator.lua
	Procedural dungeon generation using BSP (Binary Space Partition) algorithm.
	Creates rooms, corridors, traps, decorations, spawn points, loot chests, and a boss room.
	Place in: ServerScriptService/DungeonGenerator
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.SharedModules.Config)

local DungeonGenerator = {}
DungeonGenerator.__index = DungeonGenerator

local dungeonFolder = nil

-- ========== BSP NODE ==========
local BSPNode = {}
BSPNode.__index = BSPNode

function BSPNode.new(x, z, w, h)
	return setmetatable({
		X = x, Z = z, W = w, H = h,
		Left = nil, Right = nil,
		Room = nil,
	}, BSPNode)
end

function BSPNode:Split(minSize)
	if self.Left or self.Right then return false end

	local splitH = math.random() > 0.5
	if self.W > self.H and self.W / self.H >= 1.25 then
		splitH = false
	elseif self.H > self.W and self.H / self.W >= 1.25 then
		splitH = true
	end

	local maxSize = (splitH and self.H or self.W) - minSize
	if maxSize < minSize then return false end

	local split = math.random(minSize, maxSize)

	if splitH then
		self.Left = BSPNode.new(self.X, self.Z, self.W, split)
		self.Right = BSPNode.new(self.X, self.Z + split, self.W, self.H - split)
	else
		self.Left = BSPNode.new(self.X, self.Z, split, self.H)
		self.Right = BSPNode.new(self.X + split, self.Z, self.W - split, self.H)
	end

	return true
end

function BSPNode:GetLeaves()
	if not self.Left and not self.Right then
		return {self}
	end
	local leaves = {}
	if self.Left then
		for _, leaf in ipairs(self.Left:GetLeaves()) do
			table.insert(leaves, leaf)
		end
	end
	if self.Right then
		for _, leaf in ipairs(self.Right:GetLeaves()) do
			table.insert(leaves, leaf)
		end
	end
	return leaves
end

-- ========== ROOM CREATION ==========
local function createPart(parent, size, position, material, color, name, anchored, transparency)
	local part = Instance.new("Part")
	part.Name = name or "DungeonPart"
	part.Size = size
	part.Position = position
	part.Material = material or Enum.Material.SmoothPlastic
	part.BrickColor = BrickColor.new(color or "Medium stone grey")
	part.Anchored = anchored ~= false
	part.CanCollide = true
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function createRoom(node, floorY, roomsFolder)
	local padding = 4
	local roomW = math.random(
		math.max(10, node.W - padding * 2 - 10),
		math.max(10, node.W - padding * 2)
	)
	local roomH = math.random(
		math.max(10, node.H - padding * 2 - 10),
		math.max(10, node.H - padding * 2)
	)

	local roomX = node.X + math.random(padding, math.max(padding, node.W - roomW - padding))
	local roomZ = node.Z + math.random(padding, math.max(padding, node.H - roomH - padding))

	local ceilingHeight = math.random(12, 16)

	local roomData = {
		X = roomX, Z = roomZ, W = roomW, H = roomH,
		CenterX = roomX + roomW / 2,
		CenterZ = roomZ + roomH / 2,
		CeilingHeight = ceilingHeight,
	}
	node.Room = roomData

	local roomFolder = Instance.new("Folder")
	roomFolder.Name = "Room_" .. roomX .. "_" .. roomZ
	roomFolder.Parent = roomsFolder

	-- Floor
	createPart(roomFolder,
		Vector3.new(roomW, Config.Dungeon.WallThickness, roomH),
		Vector3.new(roomData.CenterX, floorY, roomData.CenterZ),
		Config.Dungeon.FloorMaterial, "Dark stone grey", "Floor"
	)

	-- Ceiling
	createPart(roomFolder,
		Vector3.new(roomW, Config.Dungeon.WallThickness, roomH),
		Vector3.new(roomData.CenterX, floorY + ceilingHeight, roomData.CenterZ),
		Config.Dungeon.CeilingMaterial, "Really black", "Ceiling"
	)

	-- Walls (4 walls with doorway gaps that corridors will connect through)
	local wallH = ceilingHeight
	local wallT = Config.Dungeon.WallThickness

	-- North wall
	createPart(roomFolder,
		Vector3.new(roomW, wallH, wallT),
		Vector3.new(roomData.CenterX, floorY + wallH / 2, roomZ),
		Config.Dungeon.WallMaterial, "Dark stone grey", "WallNorth"
	)
	-- South wall
	createPart(roomFolder,
		Vector3.new(roomW, wallH, wallT),
		Vector3.new(roomData.CenterX, floorY + wallH / 2, roomZ + roomH),
		Config.Dungeon.WallMaterial, "Dark stone grey", "WallSouth"
	)
	-- West wall
	createPart(roomFolder,
		Vector3.new(wallT, wallH, roomH),
		Vector3.new(roomX, floorY + wallH / 2, roomData.CenterZ),
		Config.Dungeon.WallMaterial, "Dark stone grey", "WallWest"
	)
	-- East wall
	createPart(roomFolder,
		Vector3.new(wallT, wallH, roomH),
		Vector3.new(roomX + roomW, floorY + wallH / 2, roomData.CenterZ),
		Config.Dungeon.WallMaterial, "Dark stone grey", "WallEast"
	)

	return roomData
end

-- ========== CORRIDOR CREATION ==========
local function createCorridor(room1, room2, floorY, corridorsFolder)
	local w = Config.Dungeon.CorridorWidth
	local h = 10
	local wallT = Config.Dungeon.WallThickness

	local cx1 = room1.CenterX
	local cz1 = room1.CenterZ
	local cx2 = room2.CenterX
	local cz2 = room2.CenterZ

	local corrFolder = Instance.new("Folder")
	corrFolder.Name = "Corridor_" .. math.floor(cx1) .. "_" .. math.floor(cz1)
	corrFolder.Parent = corridorsFolder

	-- L-shaped corridor: go horizontal first, then vertical
	local midX = cx2
	local midZ = cz1

	-- Horizontal segment
	local hLen = math.abs(cx2 - cx1)
	if hLen > 0 then
		local hCenterX = (cx1 + cx2) / 2
		createPart(corrFolder,
			Vector3.new(hLen + w, wallT, w),
			Vector3.new(hCenterX, floorY, midZ),
			Config.Dungeon.FloorMaterial, "Dark stone grey", "CorridorFloorH"
		)
		createPart(corrFolder,
			Vector3.new(hLen + w, wallT, w),
			Vector3.new(hCenterX, floorY + h, midZ),
			Config.Dungeon.CeilingMaterial, "Really black", "CorridorCeilH"
		)
	end

	-- Vertical segment
	local vLen = math.abs(cz2 - cz1)
	if vLen > 0 then
		local vCenterZ = (cz1 + cz2) / 2
		createPart(corrFolder,
			Vector3.new(w, wallT, vLen + w),
			Vector3.new(midX, floorY, vCenterZ),
			Config.Dungeon.FloorMaterial, "Dark stone grey", "CorridorFloorV"
		)
		createPart(corrFolder,
			Vector3.new(w, wallT, vLen + w),
			Vector3.new(midX, floorY + h, vCenterZ),
			Config.Dungeon.CeilingMaterial, "Really black", "CorridorCeilV"
		)
	end
end

-- ========== DECORATIONS ==========
local function addTorch(parent, position)
	local torch = Instance.new("Part")
	torch.Name = "Torch"
	torch.Size = Vector3.new(0.5, 2, 0.5)
	torch.Position = position
	torch.Material = Enum.Material.Wood
	torch.BrickColor = BrickColor.new("Brown")
	torch.Anchored = true
	torch.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Brightness = 1.5
	light.Range = 20
	light.Parent = torch

	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 5
	fire.Color = Color3.fromRGB(255, 100, 0)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 50)
	fire.Parent = torch

	return torch
end

local function decorateRoom(roomData, floorY, decorFolder)
	local spacing = Config.Dungeon.TorchSpacing
	-- Place torches along walls
	for x = roomData.X + spacing / 2, roomData.X + roomData.W, spacing do
		addTorch(decorFolder, Vector3.new(x, floorY + 4, roomData.Z + 1.5))
		addTorch(decorFolder, Vector3.new(x, floorY + 4, roomData.Z + roomData.H - 1.5))
	end
end

-- ========== TRAPS ==========
local function placeTrap(position, trapType, floorY, trapsFolder)
	local trapConfig = Config.Traps[trapType]
	if not trapConfig then return end

	local trap = Instance.new("Part")
	trap.Name = "Trap_" .. trapType
	trap.Size = Vector3.new(trapConfig.TriggerRadius * 2, 0.5, trapConfig.TriggerRadius * 2)
	trap.Position = Vector3.new(position.X, floorY + 0.3, position.Z)
	trap.Material = Enum.Material.SmoothPlastic
	trap.BrickColor = BrickColor.new("Dark stone grey")
	trap.Anchored = true
	trap.CanCollide = false
	trap.Transparency = 0.8
	trap.Parent = trapsFolder

	local config = Instance.new("Configuration")
	config.Name = "TrapConfig"
	config.Parent = trap

	local dmgVal = Instance.new("NumberValue")
	dmgVal.Name = "Damage"
	dmgVal.Value = trapConfig.Damage
	dmgVal.Parent = config

	local cdVal = Instance.new("NumberValue")
	cdVal.Name = "Cooldown"
	cdVal.Value = trapConfig.Cooldown
	cdVal.Parent = config

	local typeVal = Instance.new("StringValue")
	typeVal.Name = "TrapType"
	typeVal.Value = trapType
	typeVal.Parent = config

	local lastTrigger = Instance.new("NumberValue")
	lastTrigger.Name = "LastTrigger"
	lastTrigger.Value = 0
	lastTrigger.Parent = config

	return trap
end

-- ========== LOOT CHESTS ==========
local function placeChest(position, floorY, chestsFolder, floorNumber)
	local chest = Instance.new("Part")
	chest.Name = "LootChest"
	chest.Size = Vector3.new(3, 2, 2)
	chest.Position = Vector3.new(position.X, floorY + 1.5, position.Z)
	chest.Material = Enum.Material.Wood
	chest.BrickColor = BrickColor.new("Bright yellow")
	chest.Anchored = true
	chest.Parent = chestsFolder

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
	highlight.Parent = chest

	local floorVal = Instance.new("IntValue")
	floorVal.Name = "FloorNumber"
	floorVal.Value = floorNumber
	floorVal.Parent = chest

	local opened = Instance.new("BoolValue")
	opened.Name = "Opened"
	opened.Value = false
	opened.Parent = chest

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Chest"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.Parent = chest

	return chest
end

-- ========== SPAWN MARKERS ==========
local function placeSpawnMarker(position, floorY, parent, markerName)
	local marker = Instance.new("Part")
	marker.Name = markerName or "SpawnMarker"
	marker.Size = Vector3.new(4, 0.2, 4)
	marker.Position = Vector3.new(position.X, floorY + 0.2, position.Z)
	marker.Material = Enum.Material.Neon
	marker.BrickColor = BrickColor.new("Lime green")
	marker.Anchored = true
	marker.CanCollide = false
	marker.Transparency = 0.5
	marker.Parent = parent
	return marker
end

-- ========== BOSS ROOM ==========
local function createBossRoom(position, floorY, parent)
	local bossRoomSize = 60
	local ceilingH = 20

	local bossFolder = Instance.new("Folder")
	bossFolder.Name = "BossRoom"
	bossFolder.Parent = parent

	-- Floor
	createPart(bossFolder,
		Vector3.new(bossRoomSize, Config.Dungeon.WallThickness, bossRoomSize),
		Vector3.new(position.X, floorY, position.Z),
		Enum.Material.Marble, "Really red", "BossFloor"
	)

	-- Ceiling
	createPart(bossFolder,
		Vector3.new(bossRoomSize, Config.Dungeon.WallThickness, bossRoomSize),
		Vector3.new(position.X, floorY + ceilingH, position.Z),
		Enum.Material.Marble, "Really black", "BossCeiling"
	)

	-- Walls
	local wallT = Config.Dungeon.WallThickness
	for _, wallInfo in ipairs({
		{Vector3.new(bossRoomSize, ceilingH, wallT), Vector3.new(position.X, floorY + ceilingH / 2, position.Z - bossRoomSize / 2)},
		{Vector3.new(bossRoomSize, ceilingH, wallT), Vector3.new(position.X, floorY + ceilingH / 2, position.Z + bossRoomSize / 2)},
		{Vector3.new(wallT, ceilingH, bossRoomSize), Vector3.new(position.X - bossRoomSize / 2, floorY + ceilingH / 2, position.Z)},
		{Vector3.new(wallT, ceilingH, bossRoomSize), Vector3.new(position.X + bossRoomSize / 2, floorY + ceilingH / 2, position.Z)},
	}) do
		createPart(bossFolder, wallInfo[1], wallInfo[2],
			Enum.Material.Marble, "Maroon", "BossWall"
		)
	end

	-- Ominous torches
	for i = 0, 3 do
		local angle = math.rad(i * 90 + 45)
		local dist = bossRoomSize / 2 - 5
		local tx = position.X + math.cos(angle) * dist
		local tz = position.Z + math.sin(angle) * dist
		local torch = addTorch(bossFolder, Vector3.new(tx, floorY + 5, tz))
		local fire = torch:FindFirstChildOfClass("Fire")
		if fire then
			fire.Color = Color3.fromRGB(100, 0, 200)
			fire.SecondaryColor = Color3.fromRGB(50, 0, 100)
		end
		local light = torch:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = Color3.fromRGB(150, 50, 255)
		end
	end

	-- Boss spawn marker
	local bossSpawn = Instance.new("Part")
	bossSpawn.Name = "BossSpawnPoint"
	bossSpawn.Size = Vector3.new(6, 0.3, 6)
	bossSpawn.Position = Vector3.new(position.X, floorY + 0.3, position.Z)
	bossSpawn.Material = Enum.Material.Neon
	bossSpawn.BrickColor = BrickColor.new("Really red")
	bossSpawn.Anchored = true
	bossSpawn.CanCollide = false
	bossSpawn.Transparency = 0.3
	bossSpawn.Parent = bossFolder

	return bossFolder, {
		CenterX = position.X,
		CenterZ = position.Z,
		Size = bossRoomSize,
	}
end

-- ========== MAIN GENERATION ==========
function DungeonGenerator:Generate(floorNumber)
	if dungeonFolder then
		dungeonFolder:Destroy()
	end

	dungeonFolder = Instance.new("Folder")
	dungeonFolder.Name = "Dungeon_Floor_" .. floorNumber
	dungeonFolder.Parent = workspace

	local roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = dungeonFolder

	local corridorsFolder = Instance.new("Folder")
	corridorsFolder.Name = "Corridors"
	corridorsFolder.Parent = dungeonFolder

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decorations"
	decorFolder.Parent = dungeonFolder

	local trapsFolder = Instance.new("Folder")
	trapsFolder.Name = "Traps"
	trapsFolder.Parent = dungeonFolder

	local chestsFolder = Instance.new("Folder")
	chestsFolder.Name = "Chests"
	chestsFolder.Parent = dungeonFolder

	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "Spawns"
	spawnsFolder.Parent = dungeonFolder

	local floorY = 0

	-- Set dark atmosphere
	Lighting.Ambient = Color3.fromRGB(20, 15, 25)
	Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 15)
	Lighting.Brightness = 0
	Lighting.FogEnd = 150
	Lighting.FogColor = Color3.fromRGB(10, 5, 15)

	-- BSP dungeon layout
	local mapSize = 200 + floorNumber * 20
	local root = BSPNode.new(0, 0, mapSize, mapSize)

	-- Recursive split
	local minLeafSize = 25
	local nodes = {root}
	local didSplit = true
	while didSplit do
		didSplit = false
		local newNodes = {}
		for _, node in ipairs(nodes) do
			if not node.Left and not node.Right then
				if node.W > minLeafSize * 2 or node.H > minLeafSize * 2 then
					if node:Split(minLeafSize) then
						table.insert(newNodes, node.Left)
						table.insert(newNodes, node.Right)
						didSplit = true
					end
				end
			end
		end
		for _, n in ipairs(newNodes) do
			table.insert(nodes, n)
		end
	end

	-- Create rooms in leaves
	local leaves = root:GetLeaves()
	local rooms = {}
	local numRooms = math.min(#leaves, math.random(Config.Dungeon.MinRooms, Config.Dungeon.MaxRooms))

	-- Shuffle and pick rooms
	for i = #leaves, 2, -1 do
		local j = math.random(1, i)
		leaves[i], leaves[j] = leaves[j], leaves[i]
	end

	for i = 1, numRooms do
		local roomData = createRoom(leaves[i], floorY, roomsFolder)
		table.insert(rooms, roomData)
		decorateRoom(roomData, floorY, decorFolder)
	end

	-- Connect rooms with corridors
	for i = 1, #rooms - 1 do
		createCorridor(rooms[i], rooms[i + 1], floorY, corridorsFolder)
	end

	-- Add extra corridors for loops (30% chance per pair)
	for i = 1, #rooms do
		for j = i + 2, #rooms do
			if math.random() < 0.15 then
				createCorridor(rooms[i], rooms[j], floorY, corridorsFolder)
			end
		end
	end

	-- Place traps
	local trapTypes = {"SpikeTrap", "FireTrap", "PoisonGas", "ArrowTrap", "BoulderTrap"}
	for _, room in ipairs(rooms) do
		if math.random() < Config.Dungeon.TrapChance then
			local trapX = room.X + math.random(3, math.max(3, room.W - 3))
			local trapZ = room.Z + math.random(3, math.max(3, room.H - 3))
			local trapType = trapTypes[math.random(1, #trapTypes)]
			placeTrap(Vector3.new(trapX, 0, trapZ), trapType, floorY, trapsFolder)
		end
	end

	-- Place loot chests (1-3 per floor)
	local chestCount = math.random(1, 3)
	local chestRooms = {}
	for i = 1, chestCount do
		local idx = math.random(2, #rooms)
		if not chestRooms[idx] then
			chestRooms[idx] = true
			local room = rooms[idx]
			placeChest(
				Vector3.new(room.CenterX + math.random(-3, 3), 0, room.CenterZ + math.random(-3, 3)),
				floorY, chestsFolder, floorNumber
			)
		end
	end

	-- Player spawn in first room
	local spawnRoom = rooms[1]
	placeSpawnMarker(
		Vector3.new(spawnRoom.CenterX, 0, spawnRoom.CenterZ),
		floorY, spawnsFolder, "PlayerSpawn"
	)

	-- Enemy spawn markers in other rooms
	for i = 2, #rooms do
		local room = rooms[i]
		local enemyCount = math.random(1, 3) + math.floor(floorNumber / 3)
		for e = 1, enemyCount do
			local ex = room.X + math.random(3, math.max(3, room.W - 3))
			local ez = room.Z + math.random(3, math.max(3, room.H - 3))
			placeSpawnMarker(
				Vector3.new(ex, 0, ez),
				floorY, spawnsFolder, "EnemySpawn"
			)
		end
	end

	-- Boss room on eligible floors
	local hasBoss = floorNumber >= Config.Dungeon.BossRoomMinFloor and floorNumber % 3 == 0
	local bossRoomData = nil
	if hasBoss then
		local lastRoom = rooms[#rooms]
		local bossPos = Vector3.new(
			lastRoom.CenterX + lastRoom.W + 50,
			0,
			lastRoom.CenterZ
		)
		local bossFolder, bossData = createBossRoom(bossPos, floorY, dungeonFolder)
		bossRoomData = bossData

		-- Connect boss room to last room
		createCorridor(
			lastRoom,
			{CenterX = bossPos.X, CenterZ = bossPos.Z},
			floorY, corridorsFolder
		)
	end

	-- Exit portal in last room (or after boss)
	local exitRoom = rooms[#rooms]
	local exitPortal = Instance.new("Part")
	exitPortal.Name = "ExitPortal"
	exitPortal.Shape = Enum.PartType.Cylinder
	exitPortal.Size = Vector3.new(1, 8, 8)
	exitPortal.CFrame = CFrame.new(exitRoom.CenterX, floorY + 5, exitRoom.CenterZ)
		* CFrame.Angles(0, 0, math.rad(90))
	exitPortal.Material = Enum.Material.Neon
	exitPortal.BrickColor = BrickColor.new("Toothpaste")
	exitPortal.Anchored = true
	exitPortal.CanCollide = false
	exitPortal.Transparency = 0.3
	exitPortal.Parent = dungeonFolder

	local portalParticles = Instance.new("ParticleEmitter")
	portalParticles.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
	portalParticles.Size = NumberSequence.new(0.5, 0)
	portalParticles.Lifetime = NumberRange.new(0.5, 1.5)
	portalParticles.Rate = 50
	portalParticles.Speed = NumberRange.new(2, 5)
	portalParticles.Parent = exitPortal

	local result = {
		Folder = dungeonFolder,
		Rooms = rooms,
		SpawnRoom = spawnRoom,
		HasBoss = hasBoss,
		BossRoom = bossRoomData,
		FloorNumber = floorNumber,
		ExitPortal = exitPortal,
	}

	print("[DungeonGenerator] Generated floor " .. floorNumber .. " with " .. #rooms .. " rooms" ..
		(hasBoss and " (BOSS FLOOR)" or ""))

	return result
end

function DungeonGenerator:Cleanup()
	if dungeonFolder then
		dungeonFolder:Destroy()
		dungeonFolder = nil
	end
end

return DungeonGenerator
