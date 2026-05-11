--[[
	OrbsSystem.lua
	Currency system for "Raise a Geometry Cube".

	• Creates leaderstats with "Orbs" currency (starts at 0)
	• Player clicks on GeometryCube → Orbs drop out (visual) + currency added
	• ClickDetector on cube with cooldown per player

	Place in ServerScriptService.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- ========== CONFIG ==========
local CFG = {
	ORBS_PER_CLICK  = 1,
	CLICK_COOLDOWN  = 0.5,
	ORB_COUNT       = 3,
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

-- ========== ORB REMOTE (for visual on client) ==========
local orbRemote = ReplicatedStorage:FindFirstChild("OrbCollected")
if not orbRemote then
	orbRemote = Instance.new("RemoteEvent")
	orbRemote.Name = "OrbCollected"
	orbRemote.Parent = ReplicatedStorage
end

-- ========== CLICK HANDLER ==========
local lastClick = {} -- [UserId] = timestamp

local zone = workspace:WaitForChild("GeometryZone", 30)
if not zone then warn("[Orbs] No GeometryZone") return end

local cubeModel = zone:WaitForChild("GeometryCube", 10)
if not cubeModel then warn("[Orbs] No GeometryCube") return end

local rootPart = cubeModel:WaitForChild("HumanoidRootPart")

-- Add ClickDetector to all cube parts
local function setupClickDetector()
	for _, part in ipairs(cubeModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local cd = part:FindFirstChildWhichIsA("ClickDetector")
			if not cd then
				cd = Instance.new("ClickDetector")
				cd.MaxActivationDistance = 15
				cd.Parent = part
			end

			cd.MouseClick:Connect(function(player)
				local now = tick()
				local userId = player.UserId

				if lastClick[userId] and (now - lastClick[userId]) < CFG.CLICK_COOLDOWN then
					return
				end
				lastClick[userId] = now

				-- Add orbs
				local leaderstats = player:FindFirstChild("leaderstats")
				if not leaderstats then return end
				local orbsVal = leaderstats:FindFirstChild("Orbs")
				if not orbsVal then return end

				local amount = getOrbsForPlayer(player)
				orbsVal.Value = orbsVal.Value + amount

				-- Tell client to show orb visual
				orbRemote:FireClient(player, rootPart.Position, CFG.ORB_COUNT)
			end)
		end
	end
end

setupClickDetector()

-- Also set up for parts added later
cubeModel.DescendantAdded:Connect(function(desc)
	if desc:IsA("BasePart") then
		task.defer(function()
			local cd = desc:FindFirstChildWhichIsA("ClickDetector")
			if not cd then
				cd = Instance.new("ClickDetector")
				cd.MaxActivationDistance = 15
				cd.Parent = desc
			end

			cd.MouseClick:Connect(function(player)
				local now = tick()
				local userId = player.UserId

				if lastClick[userId] and (now - lastClick[userId]) < CFG.CLICK_COOLDOWN then
					return
				end
				lastClick[userId] = now

				local leaderstats = player:FindFirstChild("leaderstats")
				if not leaderstats then return end
				local orbsVal = leaderstats:FindFirstChild("Orbs")
				if not orbsVal then return end

				local amount = getOrbsForPlayer(player)
				orbsVal.Value = orbsVal.Value + amount
				orbRemote:FireClient(player, rootPart.Position, CFG.ORB_COUNT)
			end)
		end)
	end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
	lastClick[player.UserId] = nil
end)

print("[Orbs] Orbs system started. Per click:", CFG.ORBS_PER_CLICK)
