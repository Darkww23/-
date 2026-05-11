--[[
	HungerSystem.lua
	Hunger system for the Geometry Cube in "Raise a Geometry Cube".

	Responsibilities:
	  • Gradually drains hunger over time
	  • Updates the hunger bar GUI (shrinks the fill frame)
	  • When hunger is critically low, the cube walks to its FoodBowl to eat
	  • Handles empty bowl — cube arrives, sees no food, walks away hungry

	Expected workspace layout:
	  workspace
	    └─ GeometryZone
	         ├─ GeometryCube        (Model: HumanoidRootPart + Humanoid)
	         │    └─ HumanoidRootPart
	         │         └─ HungerBar (BillboardGui — created by the user)
	         │              └─ Background (Frame)
	         │                   └─ Fill (Frame — we control its Size.X.Scale)
	         └─ FoodBowl           (Model or BasePart)
	              └─ .Name = "FoodBowl"
	              ── Attribute "FoodAmount" (number, 0 = empty)

	Place this Script in ServerScriptService.
]]

-- ========== SERVICES ==========
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
	BOWL_FOOD_PER_USE = 1,

	PATH_RECOMPUTE_INTERVAL = 2.0,
	STUCK_TIMEOUT    = 6.0,

	BAR_COLOR_FULL    = Color3.fromRGB(80, 200, 55),
	BAR_COLOR_MID     = Color3.fromRGB(230, 180, 30),
	BAR_COLOR_LOW     = Color3.fromRGB(210, 40, 40),
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

local bgFrame = nil

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

-- Fix bar clipping: ensure Fill stays inside Background
if bgFrame then
	bgFrame.ClipsDescendants = true
end
if fillFrame then
	fillFrame.AnchorPoint = Vector2.new(0, 0)
	fillFrame.Position     = UDim2.new(0, 0, 0, 0)
	fillFrame.Size         = UDim2.new(1, 0, 1, 0)
end

-- ========== FOOD BOWL ==========
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

local function getBowlPosition(bowl)
	if bowl:IsA("Model") then
		local primary = bowl.PrimaryPart or bowl:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary.Position
		end
	elseif bowl:IsA("BasePart") then
		return bowl.Position
	end
	return nil
end

local function getBowlFoodAmount(bowl)
	local amount = bowl:GetAttribute("FoodAmount")
	if amount == nil then
		return 1
	end
	return amount
end

local function consumeFood(bowl)
	local current = getBowlFoodAmount(bowl)
	if current <= 0 then
		return false
	end
	bowl:SetAttribute("FoodAmount", math.max(0, current - HUNGER.BOWL_FOOD_PER_USE))
	return true
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

-- ========== REMOTE EVENT (server → client bar sync) ==========
local hungerRemote = ReplicatedStorage:FindFirstChild("HungerUpdate")
if not hungerRemote then
	hungerRemote = Instance.new("RemoteEvent")
	hungerRemote.Name = "HungerUpdate"
	hungerRemote.Parent = ReplicatedStorage
end

-- ========== STATE ==========
local currentHunger = HUNGER.START

local HungerState = {
	Normal    = "Normal",
	GoingToBowl = "GoingToBowl",
	Eating    = "Eating",
	BowlEmpty = "BowlEmpty",
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
		-- Only change X scale; Y stays at full height so the bar never escapes vertically
		fillFrame.Size = UDim2.new(ratio, 0, 1, 0)
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
			hungerState = HungerState.GoingToBowl
			stateStart  = now
			lastPathTime = 0
			bowlWaypoints = nil
			bowlWpIndex   = 0
		end
		return
	end

	-- ---- STATE: GOING TO BOWL ----
	if hungerState == HungerState.GoingToBowl then
		local bowl = findBowl()
		if not bowl then
			warn("[HungerSystem] No FoodBowl found in GeometryZone.")
			hungerState = HungerState.Normal
			return
		end

		local bowlPos = getBowlPosition(bowl)
		if not bowlPos then
			hungerState = HungerState.Normal
			return
		end

		local distToBowl = (rootPart.Position * Vector3.new(1, 0, 1)
			- bowlPos * Vector3.new(1, 0, 1)).Magnitude

		-- Reached the bowl
		if distToBowl <= HUNGER.BOWL_REACH_DIST then
			local foodAvailable = getBowlFoodAmount(bowl)
			if foodAvailable <= 0 then
				hungerState = HungerState.BowlEmpty
				stateStart  = now
				return
			end

			local ate = consumeFood(bowl)
			if ate then
				hungerState = HungerState.Eating
				stateStart  = now
				humanoid:MoveTo(rootPart.Position)
			else
				hungerState = HungerState.BowlEmpty
				stateStart  = now
			end
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
		if now - stateStart >= HUNGER.EAT_DURATION then
			currentHunger = math.clamp(currentHunger + HUNGER.EAT_RESTORE, 0, HUNGER.MAX)
			updateHungerBar()
			publishState()
			hungerState = HungerState.Normal
			print("[HungerSystem] Cube finished eating. Hunger:", math.floor(currentHunger))
		end
		return
	end

	-- ---- STATE: BOWL EMPTY ----
	if hungerState == HungerState.BowlEmpty then
		if now - stateStart >= 2.0 then
			hungerState = HungerState.Normal
			print("[HungerSystem] Bowl was empty — cube walks away hungry.")
		end
		return
	end
end

-- ========== CONNECT ==========
RunService.Heartbeat:Connect(onHeartbeat)

cubeModel.AncestryChanged:Connect(function(_, parent)
	if not parent then
		warn("[HungerSystem] GeometryCube removed — hunger system stopped.")
	end
end)

print("[HungerSystem] Hunger system started. Decay:", HUNGER.DECAY_PER_SECOND, "/s")
