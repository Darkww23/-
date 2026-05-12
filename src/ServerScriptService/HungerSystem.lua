--[[
	HungerSystem.lua
	Hunger system for the Geometry Cube in "Raise a Geometry Cube".

	• Hunger decays over time; the bar only shrinks (no color/position changes)
	• Player fills the bowl with one click (ProximityPrompt) using food from Backpack
	• Visual effects: uses FoodBowl → FoodBowlEffects ParticleEmitter
	• Empty bowl — cube walks away hungry

	workspace layout:
	  GeometryZone
	    ├─ GeometryCube  (Model: HumanoidRootPart + Humanoid)
	    │    └─ HumanoidRootPart → HungerBar (BillboardGui → Background → Fill)
	    └─ FoodBowl      (BasePart or Model)

	Place in ServerScriptService.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local PathService       = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== CONFIG ==========
local CFG = {
	MAX_HUNGER       = 100,
	DECAY_PER_SEC    = 0.8,
	CRITICAL         = 25,
	EAT_RESTORE      = 100,
	EAT_DURATION     = 3.0,
	BOWL_REACH       = 5,
	PATH_INTERVAL    = 2.0,
	STUCK_TIMEOUT    = 6.0,
}

local FOOD_NAMES = { CubeFood = true, CubeFoodPremium = true }

-- ========== REFS ==========
local zone = workspace:WaitForChild("GeometryZone", 30)
if not zone then warn("[Hunger] No GeometryZone") return end

local cube = zone:WaitForChild("GeometryCube", 10)
if not cube then warn("[Hunger] No GeometryCube") return end

local hum  = cube:WaitForChild("Humanoid")
local root = cube:WaitForChild("HumanoidRootPart")

-- ========== HUNGER BAR ==========
-- We NEVER touch Size, Position, AnchorPoint, or Color of the Fill frame.
-- Instead we use a UIGradient on the Fill: the left portion stays visible,
-- the right portion becomes transparent — the bar visually shrinks in place.
local barGui = root:WaitForChild("HungerBar", 10)
local fill
local bg

if barGui then
	bg = barGui:FindFirstChild("Background")
	if bg then fill = bg:FindFirstChild("Fill") end
end

local gradient
if fill then
	gradient = fill:FindFirstChildWhichIsA("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = fill
	end
end

local function updateBar(hunger)
	if not gradient then return end
	local ratio = math.clamp(hunger / CFG.MAX_HUNGER, 0, 1)

	if ratio <= 0 then
		gradient.Transparency = NumberSequence.new(1)
	elseif ratio >= 1 then
		gradient.Transparency = NumberSequence.new(0)
	else
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(math.min(ratio, 0.998), 0),
			NumberSequenceKeypoint.new(math.min(ratio + 0.001, 0.999), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

-- ========== VISUAL EFFECTS ==========
-- Uses the player's own ParticleEmitter inside FoodBowl → FoodBowlEffects
local function playBowlEffect(bowl)
	local effectsPart = bowl:FindFirstChild("FoodBowlEffects")
	if not effectsPart then return end

	for _, emitter in ipairs(effectsPart:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = true
			task.delay(1.5, function() emitter.Enabled = false end)
		end
	end
end

-- ========== FOOD BOWL VISUAL ==========
local function showBowlVisual(bowl, visible)
	local vis = bowl:FindFirstChild("FoodBowlVisual")
	if not vis then return end

	if vis:IsA("BasePart") then
		vis.Transparency = visible and 0 or 1
	elseif vis:IsA("Model") then
		for _, part in ipairs(vis:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = visible and 0 or 1
			end
		end
	end
end

-- ========== FOOD BOWL ==========
local bowlFull = false

local function findBowl()
	return zone:FindFirstChild("FoodBowl") or nil
end

local function getBowlPart(b)
	if b:IsA("BasePart") then return b end
	if b:IsA("Model") then return b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart") end
	return nil
end

local function getBowlPos(b)
	local p = getBowlPart(b)
	return p and p.Position or nil
end

local function setupPrompt(b)
	local part = getBowlPart(b)
	if not part then return end

	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Food Bowl"
		prompt.ActionText = "Fill Bowl"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end

	prompt.Triggered:Connect(function(player)
		if bowlFull then return end

		local foodTool
		local bp = player:FindFirstChild("Backpack")
		local ch = player.Character

		if bp then
			for _, item in ipairs(bp:GetChildren()) do
				if item:IsA("Tool") and FOOD_NAMES[item.Name] then
					foodTool = item
					break
				end
			end
		end
		if not foodTool and ch then
			for _, item in ipairs(ch:GetChildren()) do
				if item:IsA("Tool") and FOOD_NAMES[item.Name] then
					foodTool = item
					break
				end
			end
		end

		if not foodTool then
			local remote = ReplicatedStorage:FindFirstChild("BowlNotification")
			if remote then
				remote:FireClient(player, "no_food", "No food in inventory!")
			end
			return
		end

		-- Move tool to nil parent first to force unequip, then destroy
		foodTool.Parent = nil
		foodTool:Destroy()
		bowlFull = true
		prompt.Enabled = false

		showBowlVisual(b, true)
		playBowlEffect(b)

		local remote = ReplicatedStorage:FindFirstChild("BowlNotification")
		if remote then
			remote:FireClient(player, "filled", "Bowl filled!")
		end
	end)
end

local b = findBowl()
if b then setupPrompt(b) end

-- Ensure remote exists
if not ReplicatedStorage:FindFirstChild("BowlNotification") then
	local r = Instance.new("RemoteEvent")
	r.Name = "BowlNotification"
	r.Parent = ReplicatedStorage
end

if not ReplicatedStorage:FindFirstChild("HungerUpdate") then
	local r = Instance.new("RemoteEvent")
	r.Name = "HungerUpdate"
	r.Parent = ReplicatedStorage
end

local hungerRemote = ReplicatedStorage.HungerUpdate

-- ========== PATHFINDING ==========
local function computePath(from, to)
	local p = PathService:CreatePath({
		AgentRadius = 2, AgentHeight = 4,
		AgentCanJump = true, AgentCanClimb = false,
	})
	local ok = pcall(function() p:ComputeAsync(from, to) end)
	if ok and p.Status == Enum.PathStatus.Success then return p:GetWaypoints() end
	return nil
end

-- ========== STATE ==========
local hunger = CFG.MAX_HUNGER
local State  = { Normal = 1, GoingToBowl = 2, Eating = 3, BowlEmpty = 4 }
local state  = State.Normal
local stateT = tick()
local wps, wpI, lastPath = nil, 0, 0

-- Shared flag for GeometryCubeAI
local flag = ReplicatedStorage:FindFirstChild("HungerSystemState")
if not flag then
	flag = Instance.new("BoolValue")
	flag.Name = "HungerSystemState"
	flag.Parent = ReplicatedStorage
end

local function publish()
	flag.Value = (state ~= State.Normal)
	flag:SetAttribute("Hunger", hunger)
end

-- ========== HEARTBEAT ==========
local lastT = tick()
local lastRemoteSync = 0

local heartbeatConn = RunService.Heartbeat:Connect(function()
	local now = tick()
	local dt  = now - lastT
	lastT = now

	if state ~= State.Eating then
		-- HungerUpgrade: halve decay if any player owns the upgrade
		local decayRate = CFG.DECAY_PER_SEC
		local hungerUpFolder = ReplicatedStorage:FindFirstChild("HungerUpgradeState")
		if hungerUpFolder and #hungerUpFolder:GetChildren() > 0 then
			decayRate = decayRate * 0.5
		end
		hunger = math.max(0, hunger - decayRate * dt)
		updateBar(hunger)

		-- Sync to clients at most once per second to avoid queue overflow
		if now - lastRemoteSync >= 1.0 then
			lastRemoteSync = now
			hungerRemote:FireAllClients(hunger, CFG.MAX_HUNGER)
		end
	end

	if state == State.Normal then
		if hunger <= CFG.CRITICAL then
			state = State.GoingToBowl
			stateT = now; lastPath = 0; wps = nil; wpI = 0
		end
		publish()
		return
	end

	if state == State.GoingToBowl then
		local bowl = findBowl()
		if not bowl then state = State.Normal publish() return end
		local bPos = getBowlPos(bowl)
		if not bPos then state = State.Normal publish() return end

		local dist = (root.Position * Vector3.new(1,0,1) - bPos * Vector3.new(1,0,1)).Magnitude

		if dist <= CFG.BOWL_REACH then
			if not bowlFull then
				state = State.BowlEmpty; stateT = now
				publish()
				return
			end
			bowlFull = false
			state = State.Eating; stateT = now
			hum:MoveTo(root.Position)
			showBowlVisual(bowl, false)
			playBowlEffect(bowl)

			local part = getBowlPart(bowl)
			if part then
				local pr = part:FindFirstChildWhichIsA("ProximityPrompt")
				if pr then pr.Enabled = true; pr.ActionText = "Fill Bowl" end
			end

			task.delay(CFG.EAT_DURATION, function()
				hunger = math.clamp(hunger + CFG.EAT_RESTORE, 0, CFG.MAX_HUNGER)
				updateBar(hunger)
				state = State.Normal
				publish()
			end)
			publish()
			return
		end

		if now - lastPath > CFG.PATH_INTERVAL then
			lastPath = now; wps = computePath(root.Position, bPos); wpI = 1
		end

		if wps and wpI <= #wps then
			local wp = wps[wpI]
			if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
			hum:MoveTo(wp.Position)
			if (root.Position * Vector3.new(1,0,1) - wp.Position * Vector3.new(1,0,1)).Magnitude < 3 then
				wpI = wpI + 1
			end
		else
			hum:MoveTo(bPos)
		end

		if now - stateT > CFG.STUCK_TIMEOUT then
			stateT = now; lastPath = 0; wps = nil
		end
		publish()
		return
	end

	if state == State.Eating then publish() return end

	if state == State.BowlEmpty then
		if now - stateT >= 2.0 then state = State.Normal end
		publish()
		return
	end

	publish()
end)

local childAddedConn = zone.ChildAdded:Connect(function(child)
	if child.Name == "FoodBowl" then setupPrompt(child) end
end)

cube.AncestryChanged:Connect(function(_, parent)
	if not parent then
		warn("[Hunger] GeometryCube was removed — stopping hunger system.")
		heartbeatConn:Disconnect()
		childAddedConn:Disconnect()
	end
end)

print("[Hunger] Started. Decay:", CFG.DECAY_PER_SEC, "/s")
