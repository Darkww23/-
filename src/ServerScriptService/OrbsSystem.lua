--[[
	OrbsSystem.lua
	Currency system for "Raise a Geometry Cube".

	• Creates leaderstats with "Orbs" currency (starts at 0)
	• Player clicks on GeometryCube → physical Orb model drops out
	• Player touches the dropped Orb → currency added + Orb destroyed
	• Orb model is cloned from ReplicatedStorage.Orb

	Place in ServerScriptService.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== CONFIG ==========
local CFG = {
	ORBS_PER_CLICK  = 1,
	CLICK_COOLDOWN  = 0.5,
	ORB_SPAWN_COUNT = 3,
	ORB_LAUNCH_FORCE = 30,
	ORB_UP_FORCE     = 50,
}

local function getOrbsForPlayer(player)
	local upgradeFolder = ReplicatedStorage:FindFirstChild("OrbUpgradeState")
	if upgradeFolder and upgradeFolder:FindFirstChild(tostring(player.UserId)) then
		return CFG.ORBS_PER_CLICK * 2
	end
	return CFG.ORBS_PER_CLICK
end

-- ========== LEADERSTATS ==========
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local orbs = Instance.new("IntValue")
	orbs.Name = "Orbs"
	orbs.Value = 0
	orbs.Parent = leaderstats
end)

-- ========== ORB TEMPLATE ==========
local orbTemplate = ReplicatedStorage:WaitForChild("Orb", 30)
if not orbTemplate then
	warn("[Orbs] Orb model not found in ReplicatedStorage — aborting.")
	return
end

-- ========== SPAWN ORB ==========
local function spawnOrb(origin, orbValue)
	local orb = orbTemplate:Clone()

	local primaryPart
	if orb:IsA("Model") then
		primaryPart = orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart")
	elseif orb:IsA("BasePart") then
		primaryPart = orb
	end
	if not primaryPart then
		orb:Destroy()
		return
	end

	-- Position near the cube with random offset
	local offset = Vector3.new(
		math.random(-20, 20) / 10,
		2,
		math.random(-20, 20) / 10
	)
	if orb:IsA("Model") then
		orb:PivotTo(CFrame.new(origin + offset))
	else
		orb.Position = origin + offset
	end

	-- Store the orb value
	orb:SetAttribute("OrbValue", orbValue)

	-- Ensure physics
	primaryPart.Anchored = false
	primaryPart.CanCollide = true

	orb.Parent = workspace

	-- Launch upward with random spread
	local horizontal = Vector3.new(
		math.random(-10, 10) / 10,
		0,
		math.random(-10, 10) / 10
	)
	local launchDir = (horizontal.Magnitude > 0 and horizontal.Unit * CFG.ORB_LAUNCH_FORCE or Vector3.zero)
		+ Vector3.new(0, CFG.ORB_UP_FORCE, 0)
	primaryPart:ApplyImpulse(launchDir * primaryPart.AssemblyMass)

	-- Touch detection for collection
	local collected = false
	local touchConn
	touchConn = primaryPart.Touched:Connect(function(hit)
		if collected then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			character = hit.Parent and hit.Parent.Parent
			player = Players:GetPlayerFromCharacter(character)
		end
		if not player then return end

		collected = true
		touchConn:Disconnect()

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local orbsVal = leaderstats:FindFirstChild("Orbs")
			if orbsVal then
				orbsVal.Value = orbsVal.Value + orb:GetAttribute("OrbValue")
			end
		end

		orb:Destroy()
	end)
end

-- ========== CLICK HANDLER ==========
local lastClick = {} -- [UserId] = timestamp

local zone = workspace:WaitForChild("GeometryZone", 30)
if not zone then warn("[Orbs] No GeometryZone") return end

local cubeModel = zone:WaitForChild("GeometryCube", 10)
if not cubeModel then warn("[Orbs] No GeometryCube") return end

local rootPart = cubeModel:WaitForChild("HumanoidRootPart")

local function onCubeClicked(player)
	local now = tick()
	local userId = player.UserId

	if lastClick[userId] and (now - lastClick[userId]) < CFG.CLICK_COOLDOWN then
		return
	end
	lastClick[userId] = now

	local orbValue = getOrbsForPlayer(player)

	for i = 1, CFG.ORB_SPAWN_COUNT do
		task.delay((i - 1) * 0.1, function()
			spawnOrb(rootPart.Position, orbValue)
		end)
	end
end

-- Add ClickDetector to all cube parts
local function setupClickDetector(part)
	if not part:IsA("BasePart") then return end

	local cd = part:FindFirstChildWhichIsA("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 15
		cd.Parent = part
	end

	cd.MouseClick:Connect(onCubeClicked)
end

for _, part in ipairs(cubeModel:GetDescendants()) do
	setupClickDetector(part)
end

cubeModel.DescendantAdded:Connect(function(desc)
	task.defer(function()
		setupClickDetector(desc)
	end)
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
	lastClick[player.UserId] = nil
end)

print("[Orbs] Orbs system started (physical drop). Per click:", CFG.ORBS_PER_CLICK)
