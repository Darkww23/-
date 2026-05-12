--[[
	NPCNavigation.lua
	Autonomous navigation script for a Cube NPC inside a house environment.
	Uses PathfindingService for smooth pathfinding, raycasting for obstacle
	avoidance, and stuck detection with automatic recovery.

	Place this Script directly inside the NPC Model.
	The model must contain a Humanoid and a PrimaryPart (HumanoidRootPart).
--]]

-- ========== SERVICES ==========
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

-- ========== MODEL REFERENCES ==========
local npcModel = script.Parent
local humanoid = npcModel:WaitForChild("Humanoid")
local rootPart = npcModel:WaitForChild("HumanoidRootPart")

-- ========== CONFIGURATION ==========
local NAV_CONFIG = {
	-- Pathfinding agent dimensions (tuned for a cube-shaped NPC)
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,

	-- Wandering area: maximum distance from the NPC's spawn point
	WanderRadius = 60,

	-- How close the NPC must get to a waypoint before advancing to the next one
	WaypointReachThreshold = 4,

	-- Maximum time (seconds) to wait at a single waypoint before declaring it unreachable
	WaypointTimeout = 6,

	-- Stuck detection: if the NPC moves less than this distance over the check interval, it's stuck
	StuckDistanceThreshold = 0.5,
	StuckCheckInterval = 2,

	-- Raycast: forward ray length to detect low obstacles
	RaycastDistance = 5,
	-- Maximum obstacle height that can be jumped over
	JumpableWallHeight = 6,

	-- Short pause between picking new destinations
	IdlePauseBetweenPaths = 0.5,

	-- Maximum number of consecutive path failures before forcing a random jump + new attempt
	MaxConsecutiveFailures = 3,
}

-- ========== STATE ==========
local spawnPosition = rootPart.Position
local consecutiveFailures = 0
local isNavigating = false

-- ========== PATHFINDING SETUP ==========
local function createPath()
	return PathfindingService:CreatePath({
		AgentRadius = NAV_CONFIG.AgentRadius,
		AgentHeight = NAV_CONFIG.AgentHeight,
		AgentCanJump = NAV_CONFIG.AgentCanJump,
		AgentCanClimb = NAV_CONFIG.AgentCanClimb,
	})
end

-- ========== UTILITY ==========

--- Pick a random walkable destination within WanderRadius of spawn.
--- Samples a random point on the XZ plane around spawn at ground level.
local function getRandomDestination(): Vector3
	local angle = math.random() * 2 * math.pi
	local dist = math.random() * NAV_CONFIG.WanderRadius
	local offsetX = math.cos(angle) * dist
	local offsetZ = math.sin(angle) * dist

	-- Cast a ray downward to find the floor at the random XZ offset
	local origin = spawnPosition + Vector3.new(offsetX, 50, offsetZ)
	local direction = Vector3.new(0, -100, 0)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { npcModel }

	local result = workspace:Raycast(origin, direction, rayParams)
	if result then
		return result.Position + Vector3.new(0, 3, 0)
	end

	-- Fallback: return a point near spawn at current Y
	return spawnPosition + Vector3.new(offsetX, 0, offsetZ)
end

--- Cast a short ray forward from the NPC to detect low obstacles.
--- Returns true if a jumpable obstacle is detected directly ahead.
local function detectObstacleAhead(): boolean
	if not rootPart or not rootPart.Parent then
		return false
	end

	local origin = rootPart.Position
	local forward = rootPart.CFrame.LookVector
	local direction = forward * NAV_CONFIG.RaycastDistance

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { npcModel }

	-- Ray at lower body height to detect low barriers
	local lowerOrigin = origin - Vector3.new(0, 1, 0)
	local result = workspace:Raycast(lowerOrigin, direction, rayParams)

	if result then
		-- Check if the obstacle is low enough to jump over
		local hitTop = result.Position.Y + (result.Instance.Size.Y / 2)
		local npcFeet = origin.Y - (rootPart.Size.Y / 2)
		local wallHeight = hitTop - npcFeet

		if wallHeight > 0 and wallHeight <= NAV_CONFIG.JumpableWallHeight then
			return true
		end
	end

	return false
end

--- Force the NPC to jump (used for obstacle avoidance and stuck recovery).
local function forceJump()
	if humanoid and humanoid.Health > 0 then
		humanoid.Jump = true
	end
end

-- ========== CORE NAVIGATION ==========

--- Follow computed waypoints sequentially with timeout, stuck detection,
--- and obstacle-avoidance raycasting at each step.
--- Returns true if the NPC reached the final waypoint, false otherwise.
local function followPath(waypoints: { PathWaypoint }): boolean
	for i, waypoint in ipairs(waypoints) do
		if not rootPart or not rootPart.Parent then
			return false
		end

		-- Handle jump waypoints
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			forceJump()
		end

		-- Move toward waypoint
		humanoid:MoveTo(waypoint.Position)

		-- Wait for the NPC to reach the waypoint or timeout
		local startTime = tick()
		local lastPosition = rootPart.Position
		local lastStuckCheck = tick()

		while true do
			if not rootPart or not rootPart.Parent then
				return false
			end

			local currentPos = rootPart.Position
			local distToWaypoint = (currentPos - waypoint.Position).Magnitude

			-- Reached waypoint
			if distToWaypoint <= NAV_CONFIG.WaypointReachThreshold then
				break
			end

			-- Waypoint timeout
			if tick() - startTime > NAV_CONFIG.WaypointTimeout then
				return false
			end

			-- Stuck detection: check every StuckCheckInterval seconds
			if tick() - lastStuckCheck >= NAV_CONFIG.StuckCheckInterval then
				local movedDistance = (currentPos - lastPosition).Magnitude
				if movedDistance < NAV_CONFIG.StuckDistanceThreshold then
					-- NPC is stuck — try jumping first
					forceJump()
					task.wait(0.3)

					-- Re-check after jump
					local afterJumpPos = rootPart.Position
					local jumpMovement = (afterJumpPos - lastPosition).Magnitude
					if jumpMovement < NAV_CONFIG.StuckDistanceThreshold then
						-- Still stuck after jump — abort this path
						return false
					end
				end

				lastPosition = currentPos
				lastStuckCheck = tick()
			end

			-- Raycast safety net: detect low obstacles ahead and jump
			if detectObstacleAhead() then
				forceJump()
			end

			RunService.Heartbeat:Wait()
		end
	end

	return true
end

--- Main navigation loop: endlessly picks random destinations, computes paths,
--- and follows them. Handles failures gracefully with automatic retries.
local function navigationLoop()
	isNavigating = true

	while rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 do
		-- Pick a random destination
		local destination = getRandomDestination()

		-- Compute path
		local path = createPath()
		local success, errorMessage = pcall(function()
			path:ComputeAsync(rootPart.Position, destination)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()

			-- Skip the first waypoint (it's the current position)
			local trimmedWaypoints = {}
			for i = 2, #waypoints do
				table.insert(trimmedWaypoints, waypoints[i])
			end

			if #trimmedWaypoints > 0 then
				-- Listen for path blockage mid-traversal
				local blocked = false
				local blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
					blocked = true
				end)

				local reached = followPath(trimmedWaypoints)
				blockedConnection:Disconnect()

				if reached then
					consecutiveFailures = 0
				else
					consecutiveFailures += 1
				end

				if blocked then
					-- Path was blocked mid-traversal — immediately recalculate
					consecutiveFailures += 1
				end
			end
		else
			-- Path computation failed
			consecutiveFailures += 1
		end

		-- If too many consecutive failures, force a jump to try to unstick
		if consecutiveFailures >= NAV_CONFIG.MaxConsecutiveFailures then
			forceJump()
			task.wait(0.5)

			-- Attempt a short random walk to reposition
			local nudge = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			humanoid:MoveTo(rootPart.Position + nudge)
			task.wait(1)

			consecutiveFailures = 0
		end

		-- Brief idle pause before next destination
		task.wait(NAV_CONFIG.IdlePauseBetweenPaths)
	end

	isNavigating = false
end

-- ========== RESPAWN / HEALTH HANDLING ==========
humanoid.Died:Connect(function()
	isNavigating = false
end)

-- ========== START NAVIGATION ==========
task.defer(navigationLoop)
