--[[
	MinimapSystem.lua
	Client-side minimap: renders dungeon rooms, corridors, player position,
	enemy positions, chest locations, and exit portal on a corner overlay.
	Place in: StarterPlayerScripts/MinimapSystem (LocalScript)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MINIMAP_SIZE = 180
local MINIMAP_SCALE = 0.6
local UPDATE_INTERVAL = 0.2

-- ========== GUI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinimapGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local minimapFrame = Instance.new("Frame")
minimapFrame.Name = "Minimap"
minimapFrame.Size = UDim2.new(0, MINIMAP_SIZE, 0, MINIMAP_SIZE)
minimapFrame.Position = UDim2.new(1, -MINIMAP_SIZE - 15, 0, 15)
minimapFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
minimapFrame.BackgroundTransparency = 0.2
minimapFrame.BorderSizePixel = 0
minimapFrame.ClipsDescendants = true
minimapFrame.Parent = screenGui

local minimapCorner = Instance.new("UICorner")
minimapCorner.CornerRadius = UDim.new(0, 8)
minimapCorner.Parent = minimapFrame

local minimapStroke = Instance.new("UIStroke")
minimapStroke.Color = Color3.fromRGB(80, 80, 120)
minimapStroke.Thickness = 2
minimapStroke.Parent = minimapFrame

-- Minimap content (moves relative to player)
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(2, 0, 2, 0)
content.Position = UDim2.new(-0.5, 0, -0.5, 0)
content.BackgroundTransparency = 1
content.Parent = minimapFrame

-- Player dot (always centered)
local playerDot = Instance.new("Frame")
playerDot.Name = "PlayerDot"
playerDot.Size = UDim2.new(0, 8, 0, 8)
playerDot.Position = UDim2.new(0.5, -4, 0.5, -4)
playerDot.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
playerDot.BorderSizePixel = 0
playerDot.ZIndex = 10
playerDot.Parent = minimapFrame

local playerDotCorner = Instance.new("UICorner")
playerDotCorner.CornerRadius = UDim.new(1, 0)
playerDotCorner.Parent = playerDot

-- Directional arrow
local arrow = Instance.new("TextLabel")
arrow.Name = "Arrow"
arrow.Size = UDim2.new(0, 12, 0, 12)
arrow.Position = UDim2.new(0.5, -6, 0.5, -14)
arrow.BackgroundTransparency = 1
arrow.Text = "^"
arrow.TextColor3 = Color3.fromRGB(50, 200, 50)
arrow.TextSize = 14
arrow.Font = Enum.Font.GothamBold
arrow.ZIndex = 10
arrow.Parent = minimapFrame

-- Floor label
local floorLabel = Instance.new("TextLabel")
floorLabel.Name = "FloorLabel"
floorLabel.Size = UDim2.new(1, 0, 0, 18)
floorLabel.Position = UDim2.new(0, 0, 1, 2)
floorLabel.BackgroundTransparency = 1
floorLabel.Text = "Floor 1"
floorLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
floorLabel.TextSize = 12
floorLabel.Font = Enum.Font.GothamBold
floorLabel.Parent = minimapFrame

-- ========== MINIMAP DOTS ==========
local minimapDots = {}

local function clearDots()
	for _, dot in ipairs(minimapDots) do
		dot:Destroy()
	end
	minimapDots = {}
end

local function createDot(worldX, worldZ, color, size, shape)
	size = size or 4
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, size, 0, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Parent = content

	if shape == "circle" then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = dot
	end

	dot:SetAttribute("WorldX", worldX)
	dot:SetAttribute("WorldZ", worldZ)

	table.insert(minimapDots, dot)
	return dot
end

-- ========== ROOM RENDERING ==========
local roomFrames = {}

local function clearRooms()
	for _, frame in ipairs(roomFrames) do
		frame:Destroy()
	end
	roomFrames = {}
end

local function renderRoom(roomPart)
	local frame = Instance.new("Frame")
	frame.Name = "Room"
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.ZIndex = 2
	frame.Parent = content

	local roomStroke = Instance.new("UIStroke")
	roomStroke.Color = Color3.fromRGB(60, 60, 80)
	roomStroke.Thickness = 1
	roomStroke.Parent = frame

	frame:SetAttribute("WorldX", roomPart.Position.X)
	frame:SetAttribute("WorldZ", roomPart.Position.Z)
	frame:SetAttribute("WorldW", roomPart.Size.X)
	frame:SetAttribute("WorldH", roomPart.Size.Z)

	table.insert(roomFrames, frame)
	return frame
end

-- ========== SCAN DUNGEON ==========
local function scanDungeon()
	clearRooms()
	clearDots()

	-- Find current dungeon
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name:match("^Dungeon_Floor_") then
			-- Render room floors
			local roomsFolder = child:FindFirstChild("Rooms")
			if roomsFolder then
				for _, room in ipairs(roomsFolder:GetChildren()) do
					if room:IsA("Folder") then
						local floor = room:FindFirstChild("Floor")
						if floor then
							renderRoom(floor)
						end
					end
				end
			end

			-- Render corridor floors
			local corridorsFolder = child:FindFirstChild("Corridors")
			if corridorsFolder then
				for _, corridor in ipairs(corridorsFolder:GetChildren()) do
					if corridor:IsA("Folder") then
						for _, part in ipairs(corridor:GetChildren()) do
							if part.Name:match("Floor") then
								renderRoom(part)
							end
						end
					end
				end
			end

			-- Chest dots
			local chestsFolder = child:FindFirstChild("Chests")
			if chestsFolder then
				for _, chest in ipairs(chestsFolder:GetChildren()) do
					if chest.Name == "LootChest" then
						createDot(chest.Position.X, chest.Position.Z, Color3.fromRGB(255, 215, 0), 6, "rect")
					end
				end
			end

			-- Exit portal
			local portal = child:FindFirstChild("ExitPortal")
			if portal then
				createDot(portal.Position.X, portal.Position.Z, Color3.fromRGB(0, 200, 255), 8, "circle")
			end

			-- Boss room
			local bossRoom = child:FindFirstChild("BossRoom")
			if bossRoom then
				local bossSpawn = bossRoom:FindFirstChild("BossSpawnPoint")
				if bossSpawn then
					createDot(bossSpawn.Position.X, bossSpawn.Position.Z, Color3.fromRGB(255, 0, 0), 10, "circle")
				end
			end

			break
		end
	end
end

-- ========== UPDATE LOOP ==========
local lastUpdate = 0

local function updateMinimap()
	local now = tick()
	if now - lastUpdate < UPDATE_INTERVAL then return end
	lastUpdate = now

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local px = hrp.Position.X
	local pz = hrp.Position.Z

	-- Update content position (center on player)
	local centerX = MINIMAP_SIZE / 2
	local centerZ = MINIMAP_SIZE / 2

	-- Update room positions
	for _, frame in ipairs(roomFrames) do
		local wx = frame:GetAttribute("WorldX") or 0
		local wz = frame:GetAttribute("WorldZ") or 0
		local ww = frame:GetAttribute("WorldW") or 10
		local wh = frame:GetAttribute("WorldH") or 10

		local relX = (wx - px) * MINIMAP_SCALE + centerX
		local relZ = (wz - pz) * MINIMAP_SCALE + centerZ

		frame.Position = UDim2.new(0, relX - ww * MINIMAP_SCALE / 2, 0, relZ - wh * MINIMAP_SCALE / 2)
		frame.Size = UDim2.new(0, ww * MINIMAP_SCALE, 0, wh * MINIMAP_SCALE)
	end

	-- Update dots
	for _, dot in ipairs(minimapDots) do
		local wx = dot:GetAttribute("WorldX") or 0
		local wz = dot:GetAttribute("WorldZ") or 0
		local relX = (wx - px) * MINIMAP_SCALE + centerX
		local relZ = (wz - pz) * MINIMAP_SCALE + centerZ
		dot.Position = UDim2.new(0, relX - dot.Size.X.Offset / 2, 0, relZ - dot.Size.Y.Offset / 2)
	end

	-- Update enemy dots (dynamic)
	-- Remove old enemy dots
	for _, child in ipairs(content:GetChildren()) do
		if child.Name == "EnemyDot" then
			child:Destroy()
		end
	end

	-- Add new enemy dots
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:FindFirstChild("Humanoid") then
			local hum = model:FindFirstChild("Humanoid")
			local rootPart = model.PrimaryPart
			if hum and rootPart and hum.Health > 0 and model ~= character then
				local ex = rootPart.Position.X
				local ez = rootPart.Position.Z
				local relX = (ex - px) * MINIMAP_SCALE + centerX
				local relZ = (ez - pz) * MINIMAP_SCALE + centerZ

				if math.abs(relX) < MINIMAP_SIZE and math.abs(relZ) < MINIMAP_SIZE then
					local enemyDot = Instance.new("Frame")
					enemyDot.Name = "EnemyDot"
					enemyDot.Size = UDim2.new(0, 5, 0, 5)
					enemyDot.Position = UDim2.new(0, relX - 2.5, 0, relZ - 2.5)
					enemyDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
					enemyDot.BorderSizePixel = 0
					enemyDot.ZIndex = 6
					enemyDot.Parent = content

					local c = Instance.new("UICorner")
					c.CornerRadius = UDim.new(1, 0)
					c.Parent = enemyDot
				end
			end
		end
	end

	-- Other player dots
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local otherChar = otherPlayer.Character
			if otherChar then
				local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
				if otherHRP then
					local ox = otherHRP.Position.X
					local oz = otherHRP.Position.Z
					local relX = (ox - px) * MINIMAP_SCALE + centerX
					local relZ = (oz - pz) * MINIMAP_SCALE + centerZ

					-- Reuse or create player dot
					local dotName = "PlayerDot_" .. otherPlayer.UserId
					local existing = content:FindFirstChild(dotName)
					if not existing then
						existing = Instance.new("Frame")
						existing.Name = dotName
						existing.Size = UDim2.new(0, 6, 0, 6)
						existing.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
						existing.BorderSizePixel = 0
						existing.ZIndex = 7
						existing.Parent = content

						local c = Instance.new("UICorner")
						c.CornerRadius = UDim.new(1, 0)
						c.Parent = existing
					end
					existing.Position = UDim2.new(0, relX - 3, 0, relZ - 3)
				end
			end
		end
	end

	-- Update directional arrow rotation
	local lookVector = hrp.CFrame.LookVector
	local angle = math.atan2(lookVector.X, lookVector.Z)
	arrow.Rotation = math.deg(-angle)
end

-- ========== EVENT CONNECTIONS ==========
local FloorChanged = ReplicatedStorage:WaitForChild("FloorChanged", 10)
if FloorChanged then
	FloorChanged.OnClientEvent:Connect(function(floor)
		floorLabel.Text = "Floor " .. floor
		task.wait(1)
		scanDungeon()
	end)
end

local DungeonReady = ReplicatedStorage:WaitForChild("DungeonReady", 10)
if DungeonReady then
	DungeonReady.OnClientEvent:Connect(function()
		task.wait(0.5)
		scanDungeon()
	end)
end

RunService.Heartbeat:Connect(updateMinimap)

-- Initial scan
task.wait(3)
scanDungeon()

print("[MinimapSystem] Initialized.")
