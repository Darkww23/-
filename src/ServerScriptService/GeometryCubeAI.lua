--[[
	GeometryCubeAI.lua
	AI controller for the Geometry Cube pet in "Raise a Geometry Cube".
	The cube roams inside the GeometryZone, avoids obstacles via raycasting,
	and jumps over low obstacles when possible.

	Expected workspace layout:
	  workspace
	    └─ GeometryZone          (Folder or Model)
	         ├─ Floor             (BasePart — the walkable floor)
	         ├─ GeometryCube      (Model with HumanoidRootPart + Humanoid)
	         └─ ... obstacles / furniture / walls

	Place this Script in ServerScriptService.
]]

-- ========== SERVICES ==========
local RunService        = game:GetService("RunService")
local PathService       = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== CONFIGURATION ==========
local CFG = {
	WALK_SPEED          = 12,
	JUMP_POWER          = 50,

	-- Zone patrol
	WAYPOINT_PAUSE_MIN  = 1.0,
	WAYPOINT_PAUSE_MAX  = 3.0,
	STUCK_TIMEOUT       = 4.0,

	-- Obstacle detection (raycasts)
	RAY_DISTANCE        = 6,
	RAY_LOW_HEIGHT      = 1.5,
	RAY_HIGH_HEIGHT     = 4.0,
	JUMPABLE_MAX_HEIGHT = 4.5,
	SIDE_RAY_ANGLE      = math.rad(40),

	-- Pathfinding agent
	AGENT_RADIUS        = 2,
	AGENT_HEIGHT        = 4,
}

-- ========== REFERENCES ==========
local zone = workspace:WaitForChild("GeometryZone", 30)
if not zone then
	warn("[GeometryCubeAI] GeometryZone not found in workspace — aborting.")
	return
end

local floor = zone:WaitForChild("Floor", 10)
local cubeModel = zone:WaitForChild("GeometryCube", 10)
if not cubeModel then
	warn("[GeometryCubeAI] GeometryCube model not found in GeometryZone — aborting.")
	return
end

local humanoid = cubeModel:WaitForChild("Humanoid")
local rootPart = cubeModel:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = CFG.WALK_SPEED
humanoid.JumpPower  = CFG.JUMP_POWER

-- ========== ZONE BOUNDS ==========
local function getZoneBounds()
	if floor and floor:IsA("BasePart") then
		local cf   = floor.CFrame
		local size = floor.Size
		return {
			Center = cf.Position,
			HalfX  = size.X / 2,
			HalfZ  = size.Z / 2,
			Y      = cf.Position.Y + size.Y / 2,
		}
	end

	local minVec = Vector3.new(math.huge, math.huge, math.huge)
	local maxVec = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, obj in ipairs(zone:GetDescendants()) do
		if obj:IsA("BasePart") and obj ~= rootPart then
			local pos  = obj.Position
			local half = obj.Size / 2
			minVec = Vector3.new(
				math.min(minVec.X, pos.X - half.X),
				math.min(minVec.Y, pos.Y - half.Y),
				math.min(minVec.Z, pos.Z - half.Z)
			)
			maxVec = Vector3.new(
				math.max(maxVec.X, pos.X + half.X),
				math.max(maxVec.Y, pos.Y + half.Y),
				math.max(maxVec.Z, pos.Z + half.Z)
			)
		end
	end

	local center = (minVec + maxVec) / 2
	local size   = maxVec - minVec
	return {
		Center = center,
		HalfX  = size.X / 2,
		HalfZ  = size.Z / 2,
		Y      = minVec.Y,
	}
end

local bounds = getZoneBounds()

-- ========== HELPERS ==========
local function randomPointInZone()
	local margin = 2
	local x = bounds.Center.X + math.random() * (bounds.HalfX - margin) * 2 - (bounds.HalfX - margin)
	local z = bounds.Center.Z + math.random() * (bounds.HalfZ - margin) * 2 - (bounds.HalfZ - margin)
	return Vector3.new(x, bounds.Y + 3, z)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {cubeModel}

local function castRay(origin, direction)
	return workspace:Raycast(origin, direction, rayParams)
end

-- ========== OBSTACLE DETECTION ==========
local function analyseObstaclesAhead()
	local cf  = rootPart.CFrame
	local fwd = cf.LookVector

	local lowOrigin  = cf.Position + Vector3.new(0, CFG.RAY_LOW_HEIGHT, 0)
	local highOrigin = cf.Position + Vector3.new(0, CFG.RAY_HIGH_HEIGHT, 0)

	local hitLow  = castRay(lowOrigin, fwd * CFG.RAY_DISTANCE)
	local hitHigh = castRay(highOrigin, fwd * CFG.RAY_DISTANCE)

	if not hitLow then
		return "clear"
	end

	if hitLow and not hitHigh then
		local obstacleTop = hitLow.Instance.Position.Y + hitLow.Instance.Size.Y / 2
		local cubeBase    = rootPart.Position.Y - rootPart.Size.Y / 2
		if (obstacleTop - cubeBase) <= CFG.JUMPABLE_MAX_HEIGHT then
			return "jumpable"
		end
	end

	return "blocked"
end

local function findClearDirection()
	local cf  = rootPart.CFrame
	local pos = cf.Position + Vector3.new(0, CFG.RAY_LOW_HEIGHT, 0)

	local leftDir  = (cf * CFrame.Angles(0, CFG.SIDE_RAY_ANGLE, 0)).LookVector
	local rightDir = (cf * CFrame.Angles(0, -CFG.SIDE_RAY_ANGLE, 0)).LookVector

	local hitLeft  = castRay(pos, leftDir  * CFG.RAY_DISTANCE)
	local hitRight = castRay(pos, rightDir * CFG.RAY_DISTANCE)

	if not hitLeft and not hitRight then
		return if math.random() > 0.5 then leftDir else rightDir
	elseif not hitLeft then
		return leftDir
	elseif not hitRight then
		return rightDir
	end

	return -(cf.LookVector)
end

-- ========== PATHFINDING ==========
local function computePath(targetPos)
	local path = PathService:CreatePath({
		AgentRadius   = CFG.AGENT_RADIUS,
		AgentHeight   = CFG.AGENT_HEIGHT,
		AgentCanJump  = true,
		AgentCanClimb = false,
	})

	local ok, err = pcall(function()
		path:ComputeAsync(rootPart.Position, targetPos)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- ========== STATE MACHINE ==========
local State = {
	Idle       = "Idle",
	Walking    = "Walking",
	Jumping    = "Jumping",
	Avoiding   = "Avoiding",
	Pathfinding = "Pathfinding",
}

local currentState  = State.Idle
local stateStart    = tick()

local function switchState(newState)
	currentState = newState
	stateStart   = tick()
end

-- ========== MAIN BEHAVIOUR LOOP ==========
local currentWaypoints = nil
local waypointIndex    = 0
local targetPosition   = nil
local pauseUntil       = 0

local function pickNewDestination()
	targetPosition  = randomPointInZone()
	currentWaypoints = computePath(targetPosition)
	waypointIndex   = 1

	if currentWaypoints and #currentWaypoints > 0 then
		switchState(State.Pathfinding)
	else
		humanoid:MoveTo(targetPosition)
		switchState(State.Walking)
	end
end

-- ========== HUNGER INTEGRATION ==========
local function isHungry()
	local hungerState = ReplicatedStorage:FindFirstChild("HungerSystemState")
	if hungerState and hungerState:IsA("BoolValue") then
		return hungerState.Value
	end
	return false
end

local function onStep()
	if tick() < pauseUntil then
		return
	end

	-- Pause roaming while hungry (HungerSystem takes over movement)
	if isHungry() then
		return
	end

	-- Safety: if cube falls out of zone, teleport back
	if rootPart.Position.Y < bounds.Y - 20 then
		rootPart.CFrame = CFrame.new(bounds.Center + Vector3.new(0, 5, 0))
		switchState(State.Idle)
		return
	end

	-- ---- STATE: IDLE ----
	if currentState == State.Idle then
		local pause = CFG.WAYPOINT_PAUSE_MIN
			+ math.random() * (CFG.WAYPOINT_PAUSE_MAX - CFG.WAYPOINT_PAUSE_MIN)
		pauseUntil = tick() + pause
		pickNewDestination()
		return
	end

	-- ---- STATE: PATHFINDING ----
	if currentState == State.Pathfinding then
		if not currentWaypoints or waypointIndex > #currentWaypoints then
			switchState(State.Idle)
			return
		end

		local wp = currentWaypoints[waypointIndex]

		if wp.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		humanoid:MoveTo(wp.Position)

		local dist = (rootPart.Position * Vector3.new(1, 0, 1)
			- wp.Position * Vector3.new(1, 0, 1)).Magnitude
		if dist < 3 then
			waypointIndex = waypointIndex + 1
		end

		-- Stuck detection
		if tick() - stateStart > CFG.STUCK_TIMEOUT then
			pickNewDestination()
		end

		-- Real-time obstacle check on top of pathfinding
		local obstacle = analyseObstaclesAhead()
		if obstacle == "jumpable" then
			humanoid.Jump = true
		elseif obstacle == "blocked" then
			switchState(State.Avoiding)
		end
		return
	end

	-- ---- STATE: WALKING (fallback straight-line) ----
	if currentState == State.Walking then
		local obstacle = analyseObstaclesAhead()
		if obstacle == "jumpable" then
			humanoid.Jump = true
			switchState(State.Jumping)
		elseif obstacle == "blocked" then
			switchState(State.Avoiding)
		end

		if targetPosition then
			local dist = (rootPart.Position * Vector3.new(1, 0, 1)
				- targetPosition * Vector3.new(1, 0, 1)).Magnitude
			if dist < 3 then
				switchState(State.Idle)
			end
		end

		if tick() - stateStart > CFG.STUCK_TIMEOUT then
			switchState(State.Idle)
		end
		return
	end

	-- ---- STATE: JUMPING ----
	if currentState == State.Jumping then
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			switchState(State.Walking)
			if targetPosition then
				humanoid:MoveTo(targetPosition)
			end
		end
		if tick() - stateStart > 2 then
			switchState(State.Idle)
		end
		return
	end

	-- ---- STATE: AVOIDING ----
	if currentState == State.Avoiding then
		local clearDir = findClearDirection()
		local avoidTarget = rootPart.Position + clearDir * 8
		humanoid:MoveTo(avoidTarget)
		switchState(State.Walking)
		targetPosition = avoidTarget
		return
	end
end

-- ========== CONNECT HEARTBEAT ==========
RunService.Heartbeat:Connect(onStep)

-- Handle the cube being destroyed
cubeModel.AncestryChanged:Connect(function(_, parent)
	if not parent then
		warn("[GeometryCubeAI] GeometryCube was removed — stopping AI.")
	end
end)

print("[GeometryCubeAI] Geometry Cube AI started. Zone:", zone.Name)
