--[[
	HungerSystem.lua
	Hunger system for the Geometry Cube in "Raise a Geometry Cube".

	Responsibilities:
	  • Gradually drains hunger over time
	  • Updates the hunger bar GUI (shrinks the fill frame)
	  • When hunger is critically low, the cube walks to its FoodBowl to eat
	  • Player fills the bowl using food from their Backpack (ProximityPrompt)
	  • Empty bowl — cube arrives, sees no food, walks away hungry

	Expected workspace layout:
	  workspace
	    └─ GeometryZone
	         ├─ GeometryCube        (Model: HumanoidRootPart + Humanoid)
	         │    └─ HumanoidRootPart
	         │         └─ HungerBar (BillboardGui)
	         │              └─ Background (Frame)
	         │                   └─ Fill (Frame)
	         └─ FoodBowl           (BasePart or Model)
	              -- ProximityPrompt is created automatically by this script
	              -- Player needs a Tool named "CubeFood" (or any name listed
	              -- in FOOD_TOOL_NAMES) in their Backpack to fill the bowl.

	Place this Script in ServerScriptService.
]]

-- ========== SERVICES ==========
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local PathService     = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== CONFIGURATION ==========
local HUNGER = {
	MAX              = 100,
	START            = 100,

	DECAY_PER_SECOND = 0.8,

	CRITICAL_THRESHOLD = 25,
	EAT_RESTORE      = 50,
	EAT_DURATION     = 3.0,

	BOWL_REACH_DIST  = 5,
	BOWL_MAX_PORTIONS = 5,

	PATH_RECOMPUTE_INTERVAL = 2.0,
	STUCK_TIMEOUT    = 6.0,

	BAR_COLOR_FULL    = Color3.fromRGB(80, 200, 55),
	BAR_COLOR_MID     = Color3.fromRGB(230, 180, 30),
	BAR_COLOR_LOW     = Color3.fromRGB(210, 40, 40),
}

-- Tool names in the player's Backpack that count as food for the cube.
-- The player picks up / buys these items, then uses ProximityPrompt on the bowl.
local FOOD_TOOL_NAMES = {
	["CubeFood"]       = true,
	["CubeFoodPremium"] = true,
}

-- How much hunger each food type restores per portion
local FOOD_RESTORE = {
	["CubeFood"]       = 40,
	["CubeFoodPremium"] = 70,
}

-- ========== REFERENCES ==========
local zone = workspace:WaitForChild("GeometryZone", 30)
if not zone then
	warn("[HungerSystem] GeometryZone not found — aborting.")
	return
end

local cubeModel = zone:WaitForChild("GeometryCube", 10)
if not cubeModel then
	warn("[HungerSystem] GeometryCube not found — aborting.")
	return
end

local humanoid = cubeModel:WaitForChild("Humanoid")
local rootPart = cubeModel:WaitForChild("HumanoidRootPart")

-- ========== HUNGER BAR GUI ==========
local hungerBarGui = rootPart:WaitForChild("HungerBar", 10)
local fillFrame = nil
local bgFrame   = nil

if hungerBarGui then
	bgFrame = hungerBarGui:FindFirstChild("Background")
	if bgFrame then
		fillFrame = bgFrame:FindFirstChild("Fill")
	end
	if not fillFrame then
		fillFrame = hungerBarGui:FindFirstChildWhichIsA("Frame", true)
		if fillFrame and fillFrame.Name == "Background" then
			fillFrame = nil
		end
	end
end

if not fillFrame then
	warn("[HungerSystem] HungerBar Fill frame not found — bar won't update visually.")
end

if bgFrame then
	bgFrame.ClipsDescendants = true
end
if fillFrame then
	fillFrame.AnchorPoint = Vector2.new(0, 0)
	fillFrame.Position    = UDim2.new(0, 0, 0, 0)
	fillFrame.Size        = UDim2.new(1, 0, 1, 0)
end

-- ========== FOOD BOWL + PROXIMITY PROMPT ==========
local bowlPortions = 0

local function findBowl()
	local bowl = zone:FindFirstChild("FoodBowl")
	if not bowl then
		for _, child in ipairs(zone:GetDescendants()) do
			if child.Name == "FoodBowl" then
				bowl = child
				break
			end
		end
	end
	return bowl
end

local function getBowlPart(bowl)
	if bowl:IsA("BasePart") then
		return bowl
	end
	if bowl:IsA("Model") then
		return bowl.PrimaryPart or bowl:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function getBowlPosition(bowl)
	local part = getBowlPart(bowl)
	return part and part.Position or nil
end

-- Set up ProximityPrompt on the bowl so players can fill it from inventory
local function setupBowlPrompt(bowl)
	local part = getBowlPart(bowl)
	if not part then return end

	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText     = "Food Bowl"
		prompt.ActionText     = "Fill Bowl"
		prompt.HoldDuration   = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight  = false
		prompt.Parent = part
	end

	prompt.Triggered:Connect(function(player)
		if bowlPortions >= HUNGER.BOWL_MAX_PORTIONS then
			-- Bowl is already full
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character
		if not backpack then return end

		-- Search Backpack first, then equipped tools on the character
		local foodTool = nil
		local foodName = nil

		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and FOOD_TOOL_NAMES[item.Name] then
				foodTool = item
				foodName = item.Name
				break
			end
		end

		if not foodTool and character then
			for _, item in ipairs(character:GetChildren()) do
				if item:IsA("Tool") and FOOD_TOOL_NAMES[item.Name] then
					foodTool = item
					foodName = item.Name
					break
				end
			end
		end

		if not foodTool then
			-- Player has no food — notify them
			local noFoodRemote = ReplicatedStorage:FindFirstChild("BowlNotification")
			if noFoodRemote then
				noFoodRemote:FireClient(player, "no_food",
					"You don't have any food! Get CubeFood first.")
			end
			return
		end

		-- Consume one food tool from the player's inventory
		foodTool:Destroy()
		bowlPortions = math.min(bowlPortions + 1, HUNGER.BOWL_MAX_PORTIONS)

		-- Store restore value so the cube gets the right amount
		local restorePerPortion = FOOD_RESTORE[foodName] or HUNGER.EAT_RESTORE
		bowl:SetAttribute("RestorePerPortion", restorePerPortion)

		-- Update prompt text
		prompt.ActionText = "Fill Bowl (" .. bowlPortions .. "/" .. HUNGER.BOWL_MAX_PORTIONS .. ")"

		local feedRemote = ReplicatedStorage:FindFirstChild("BowlNotification")
		if feedRemote then
			feedRemote:FireClient(player, "filled",
				"Bowl filled! (" .. bowlPortions .. "/" .. HUNGER.BOWL_MAX_PORTIONS .. ")")
		end

		print("[HungerSystem] Player", player.Name, "filled the bowl. Portions:", bowlPortions)
	end)
end

local bowl = findBowl()
if bowl then
	setupBowlPrompt(bowl)
else
	warn("[HungerSystem] FoodBowl not found — will retry when cube is hungry.")
end

-- Remote for client notifications
local bowlNotifyRemote = ReplicatedStorage:FindFirstChild("BowlNotification")
if not bowlNotifyRemote then
	bowlNotifyRemote = Instance.new("RemoteEvent")
	bowlNotifyRemote.Name = "BowlNotification"
	bowlNotifyRemote.Parent = ReplicatedStorage
end

-- ========== PATHFINDING ==========
local function computePath(startPos, targetPos)
	local path = PathService:CreatePath({
		AgentRadius   = 2,
		AgentHeight   = 4,
		AgentCanJump  = true,
		AgentCanClimb = false,
	})

	local ok = pcall(function()
		path:ComputeAsync(startPos, targetPos)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- ========== REMOTE EVENT (server → client hunger bar sync) ==========
local hungerRemote = ReplicatedStorage:FindFirstChild("HungerUpdate")
if not hungerRemote then
	hungerRemote = Instance.new("RemoteEvent")
	hungerRemote.Name = "HungerUpdate"
	hungerRemote.Parent = ReplicatedStorage
end

-- ========== STATE ==========
local currentHunger = HUNGER.START

local HungerState = {
	Normal      = "Normal",
	GoingToBowl = "GoingToBowl",
	Eating      = "Eating",
	BowlEmpty   = "BowlEmpty",
}

local hungerState     = HungerState.Normal
local stateStart      = tick()
local bowlWaypoints   = nil
local bowlWpIndex     = 0
local lastPathTime    = 0

-- ========== SHARED STATE (for GeometryCubeAI integration) ==========
local hungerFlag = ReplicatedStorage:FindFirstChild("HungerSystemState")
if not hungerFlag then
	hungerFlag = Instance.new("BoolValue")
	hungerFlag.Name = "HungerSystemState"
	hungerFlag.Parent = ReplicatedStorage
end

local function publishState()
	hungerFlag.Value = (hungerState ~= HungerState.Normal)
	hungerFlag:SetAttribute("Hunger", currentHunger)
	hungerFlag:SetAttribute("MaxHunger", HUNGER.MAX)
end

-- ========== GUI UPDATE ==========
local function updateHungerBar()
	local ratio = math.clamp(currentHunger / HUNGER.MAX, 0, 1)

	if fillFrame then
		fillFrame.Size     = UDim2.new(ratio, 0, 1, 0)
		fillFrame.Position = UDim2.new(0, 0, 0, 0)

		if ratio > 0.5 then
			fillFrame.BackgroundColor3 = HUNGER.BAR_COLOR_FULL
		elseif ratio > 0.25 then
			fillFrame.BackgroundColor3 = HUNGER.BAR_COLOR_MID
		else
			fillFrame.BackgroundColor3 = HUNGER.BAR_COLOR_LOW
		end
	end

	hungerRemote:FireAllClients(currentHunger, HUNGER.MAX)
end

-- ========== MAIN LOOP ==========
local lastTick = tick()

local function onHeartbeat()
	local now = tick()
	local dt  = now - lastTick
	lastTick  = now

	-- Decay hunger
	if hungerState ~= HungerState.Eating then
		currentHunger = math.max(0, currentHunger - HUNGER.DECAY_PER_SECOND * dt)
		updateHungerBar()
		publishState()
	end

	-- ---- STATE: NORMAL ----
	if hungerState == HungerState.Normal then
		if currentHunger <= HUNGER.CRITICAL_THRESHOLD then
			hungerState   = HungerState.GoingToBowl
			stateStart    = now
			lastPathTime  = 0
			bowlWaypoints = nil
			bowlWpIndex   = 0
		end
		return
	end

	-- ---- STATE: GOING TO BOWL ----
	if hungerState == HungerState.GoingToBowl then
		local currentBowl = findBowl()
		if not currentBowl then
			warn("[HungerSystem] No FoodBowl found in GeometryZone.")
			hungerState = HungerState.Normal
			return
		end

		local bowlPos = getBowlPosition(currentBowl)
		if not bowlPos then
			hungerState = HungerState.Normal
			return
		end

		local distToBowl = (rootPart.Position * Vector3.new(1, 0, 1)
			- bowlPos * Vector3.new(1, 0, 1)).Magnitude

		-- Reached the bowl
		if distToBowl <= HUNGER.BOWL_REACH_DIST then
			if bowlPortions <= 0 then
				hungerState = HungerState.BowlEmpty
				stateStart  = now
				return
			end

			-- Eat one portion
			bowlPortions = bowlPortions - 1
			local restoreAmount = currentBowl:GetAttribute("RestorePerPortion")
				or HUNGER.EAT_RESTORE
			hungerState = HungerState.Eating
			stateStart  = now
			humanoid:MoveTo(rootPart.Position)

			-- Update prompt text
			local part = getBowlPart(currentBowl)
			if part then
				local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
				if prompt then
					prompt.ActionText = "Fill Bowl ("
						.. bowlPortions .. "/" .. HUNGER.BOWL_MAX_PORTIONS .. ")"
				end
			end

			-- Schedule restore after eating
			task.delay(HUNGER.EAT_DURATION, function()
				currentHunger = math.clamp(currentHunger + restoreAmount, 0, HUNGER.MAX)
				updateHungerBar()
				publishState()
				hungerState = HungerState.Normal
				print("[HungerSystem] Cube finished eating. Hunger:",
					math.floor(currentHunger), "| Bowl portions left:", bowlPortions)
			end)
			return
		end

		-- Pathfind to bowl
		if now - lastPathTime > HUNGER.PATH_RECOMPUTE_INTERVAL then
			lastPathTime  = now
			bowlWaypoints = computePath(rootPart.Position, bowlPos)
			bowlWpIndex   = 1
		end

		if bowlWaypoints and bowlWpIndex <= #bowlWaypoints then
			local wp = bowlWaypoints[bowlWpIndex]
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(wp.Position)

			local wpDist = (rootPart.Position * Vector3.new(1, 0, 1)
				- wp.Position * Vector3.new(1, 0, 1)).Magnitude
			if wpDist < 3 then
				bowlWpIndex = bowlWpIndex + 1
			end
		else
			humanoid:MoveTo(bowlPos)
		end

		-- Stuck detection — recompute path
		if now - stateStart > HUNGER.STUCK_TIMEOUT then
			stateStart    = now
			lastPathTime  = 0
			bowlWaypoints = nil
		end
		return
	end

	-- ---- STATE: EATING ----
	if hungerState == HungerState.Eating then
		-- Restore is handled by task.delay above; just wait
		return
	end

	-- ---- STATE: BOWL EMPTY ----
	if hungerState == HungerState.BowlEmpty then
		if now - stateStart >= 2.0 then
			hungerState = HungerState.Normal
			print("[HungerSystem] Bowl was empty — cube walks away hungry. "
				.. "Player needs to fill it with food from inventory!")
		end
		return
	end
end

-- ========== CONNECT ==========
RunService.Heartbeat:Connect(onHeartbeat)

-- Watch for FoodBowl being added later
zone.ChildAdded:Connect(function(child)
	if child.Name == "FoodBowl" then
		setupBowlPrompt(child)
	end
end)

cubeModel.AncestryChanged:Connect(function(_, parent)
	if not parent then
		warn("[HungerSystem] GeometryCube removed — hunger system stopped.")
	end
end)

print("[HungerSystem] Hunger system started. Decay:", HUNGER.DECAY_PER_SECOND, "/s")
print("[HungerSystem] Player must place food (CubeFood / CubeFoodPremium) in bowl via ProximityPrompt.")
