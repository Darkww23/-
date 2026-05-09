--[[
	EnemyAI.lua
	Enemy AI system with state machine, pathfinding, and ability usage.
	Supports patrol, chase, attack, flee, and boss phase behaviors.
	Place in: ServerScriptService/EnemyAI
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.SharedModules.Config)

local EnemyAI = {}
EnemyAI.__index = EnemyAI

local activeEnemies = {}
local enemyIdCounter = 0

-- ========== REMOTE EVENTS ==========
local remoteEvents = {}

local function ensureRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	remoteEvents[name] = remote
	return remote
end

ensureRemote("EnemySpawned")
ensureRemote("EnemyDamaged")
ensureRemote("EnemyDied")
ensureRemote("EnemyAbilityUsed")
ensureRemote("BossPhaseChanged")

-- ========== AI STATES ==========
local AIState = {
	Idle = "Idle",
	Patrol = "Patrol",
	Chase = "Chase",
	Attack = "Attack",
	Flee = "Flee",
	Ability = "Ability",
	Dead = "Dead",
}

-- ========== ENEMY CREATION ==========
local function createEnemyModel(enemyType, config, position, floorNumber)
	local model = Instance.new("Model")
	model.Name = enemyType

	-- Scale stats by floor
	local scaling = Config.Enemy.ScalingPerFloor
	local floorMult = 1 + (floorNumber - 1)

	local scaledHealth = config.Health * (1 + scaling.HealthMult * (floorMult - 1))
	local scaledAttack = config.Attack * (1 + scaling.AttackMult * (floorMult - 1))
	local scaledDefense = config.Defense * (1 + scaling.DefenseMult * (floorMult - 1))

	-- Body
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(2 * config.Scale, 4 * config.Scale, 2 * config.Scale)
	body.Position = position + Vector3.new(0, 3 * config.Scale, 0)
	body.Material = Enum.Material.SmoothPlastic
	body.Color = config.Color
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5 * config.Scale, 1.5 * config.Scale, 1.5 * config.Scale)
	head.Position = body.Position + Vector3.new(0, 2.5 * config.Scale, 0)
	head.Material = Enum.Material.SmoothPlastic
	head.Color = config.Color
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head

	-- Eyes (glowing)
	for _, offset in ipairs({-0.3, 0.3}) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.2, 0.2, 0.1) * config.Scale
		eye.Position = head.Position + Vector3.new(offset * config.Scale, 0.2 * config.Scale, -0.7 * config.Scale)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 0, 0)
		eye.Anchored = false
		eye.CanCollide = false
		eye.Parent = model

		local eyeWeld = Instance.new("WeldConstraint")
		eyeWeld.Part0 = head
		eyeWeld.Part1 = eye
		eyeWeld.Parent = eye
	end

	-- Humanoid for pathfinding
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = scaledHealth
	humanoid.Health = scaledHealth
	humanoid.WalkSpeed = config.Speed
	humanoid.Parent = model

	-- Health bar
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(4, 0, 0.5, 0)
	billboard.StudsOffset = Vector3.new(0, 3 * config.Scale, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = billboard

	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = bgFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "EnemyName"
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 0, -1.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = enemyType .. " Lv." .. math.floor(floorNumber * 2)
	nameLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	model.PrimaryPart = body
	model.Parent = workspace

	return model, {
		MaxHealth = scaledHealth,
		CurrentHealth = scaledHealth,
		Attack = scaledAttack,
		Defense = scaledDefense,
		Speed = config.Speed,
		XPReward = math.floor(config.XPReward * (1 + scaling.XPMult * (floorMult - 1))),
	}
end

-- ========== PATHFINDING ==========
local function findPath(startPos, endPos)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
	})

	local success, err = pcall(function()
		path:ComputeAsync(startPos, endPos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- ========== FIND NEAREST PLAYER ==========
local function findNearestPlayer(position, maxRange)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local dist = (hrp.Position - position).Magnitude
				if dist < nearestDist then
					nearest = player
					nearestDist = dist
				end
			end
		end
	end

	return nearest, nearestDist
end

-- ========== ABILITY EXECUTION ==========
local function executeAbility(enemy, abilityName, target)
	local abilityConfig = Config.Abilities[abilityName]
	if not abilityConfig then return false end

	local now = tick()
	local lastUsed = enemy.AbilityCooldowns[abilityName] or 0
	if now - lastUsed < abilityConfig.Cooldown then
		return false
	end

	enemy.AbilityCooldowns[abilityName] = now

	local targetChar = target and target.Character
	local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	local enemyPos = enemy.Model.PrimaryPart.Position

	if abilityConfig.Type == "Melee" or abilityConfig.Type == "Ranged" then
		if targetHRP then
			local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, targetHRP.Position)
			return true, damage, {target}
		end

	elseif abilityConfig.Type == "AoE" then
		local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
		local targets = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - enemyPos).Magnitude <= abilityConfig.Range then
					table.insert(targets, player)
				end
			end
		end
		remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, nil)
		return true, damage, targets

	elseif abilityConfig.Type == "DoT" then
		if targetHRP then
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, targetHRP.Position)
			return true, 0, {target}, {
				Type = "DoT",
				TickDamage = abilityConfig.TickDamage * (1 + enemy.FloorNumber * 0.1),
				Duration = abilityConfig.Duration,
			}
		end

	elseif abilityConfig.Type == "Slow" then
		if targetHRP then
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, targetHRP.Position)
			return true, enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 0), {target}, {
				Type = "Slow",
				SlowMult = abilityConfig.SlowMult,
				Duration = abilityConfig.Duration,
			}
		end

	elseif abilityConfig.Type == "Drain" then
		if targetHRP then
			local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
			local heal = damage * (abilityConfig.HealRatio or 0.5)
			enemy.ScaledStats.CurrentHealth = math.min(
				enemy.ScaledStats.MaxHealth,
				enemy.ScaledStats.CurrentHealth + heal
			)
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, targetHRP.Position)
			return true, damage, {target}
		end

	elseif abilityConfig.Type == "Teleport" then
		if targetHRP then
			local dir = (targetHRP.Position - enemyPos).Unit
			local teleportPos = targetHRP.Position - dir * 3
			enemy.Model:PivotTo(CFrame.new(teleportPos))
			local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, teleportPos)
			return true, damage, {target}
		end

	elseif abilityConfig.Type == "Summon" then
		remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, nil)
		return true, 0, {}, {
			Type = "Summon",
			MinionType = abilityConfig.MinionType,
			Count = abilityConfig.Count,
			SpawnPosition = enemyPos,
		}

	elseif abilityConfig.Type == "Cone" then
		if targetHRP then
			local dir = (targetHRP.Position - enemyPos).Unit
			local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
			local halfAngle = math.rad((abilityConfig.Angle or 60) / 2)
			local targets = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				if char then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp then
						local toPlayer = (hrp.Position - enemyPos)
						if toPlayer.Magnitude <= abilityConfig.Range then
							local angle = math.acos(math.clamp(dir:Dot(toPlayer.Unit), -1, 1))
							if angle <= halfAngle then
								table.insert(targets, player)
							end
						end
					end
				end
			end
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, targetHRP.Position)
			return true, damage, targets
		end

	elseif abilityConfig.Type == "Knockback" then
		local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
		local targets = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - enemyPos).Magnitude <= abilityConfig.Range then
					table.insert(targets, player)
					local knockDir = (hrp.Position - enemyPos).Unit
					local bv = Instance.new("BodyVelocity")
					bv.Velocity = knockDir * (abilityConfig.Force or 50) + Vector3.new(0, 30, 0)
					bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
					bv.Parent = hrp
					task.delay(0.3, function()
						bv:Destroy()
					end)
				end
			end
		end
		remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, nil)
		return true, damage, targets

	elseif abilityConfig.Type == "Channel" then
		if targetHRP then
			enemy.IsChanneling = true
			enemy.ChannelEndTime = now + (abilityConfig.Duration or 3)
			local damage = enemy.ScaledStats.Attack * (abilityConfig.DamageMult or 1)
			remoteEvents.EnemyAbilityUsed:FireAllClients(enemy.Id, abilityName, enemyPos, targetHRP.Position)
			return true, damage, {target}
		end
	end

	return false
end

-- ========== BOSS PHASE MANAGEMENT ==========
local function updateBossPhase(enemy)
	if not enemy.IsBoss or not enemy.PhaseConfig then return end

	local healthPercent = enemy.ScaledStats.CurrentHealth / enemy.ScaledStats.MaxHealth
	local phases = enemy.PhaseConfig

	for i = #phases, 1, -1 do
		if healthPercent <= phases[i].HealthThreshold and enemy.CurrentPhase < i then
			enemy.CurrentPhase = i
			enemy.ScaledStats.Speed = enemy.BaseSpeed * phases[i].SpeedMult
			enemy.DamageMult = phases[i].DamageMult

			if enemy.Model and enemy.Model.PrimaryPart then
				local humanoid = enemy.Model:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = enemy.ScaledStats.Speed
				end
			end

			remoteEvents.BossPhaseChanged:FireAllClients(enemy.Id, i, #phases)
			break
		end
	end
end

-- ========== AI UPDATE LOOP ==========
local function updateEnemy(enemy, dt)
	if enemy.State == AIState.Dead then return end

	local model = enemy.Model
	if not model or not model.PrimaryPart then
		enemy.State = AIState.Dead
		return
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		enemy.State = AIState.Dead
		return
	end

	local pos = model.PrimaryPart.Position
	local enemyConfig = enemy.Config

	-- Channeling check
	if enemy.IsChanneling then
		if tick() >= enemy.ChannelEndTime then
			enemy.IsChanneling = false
		else
			return
		end
	end

	-- Find nearest player
	local nearestPlayer, dist = findNearestPlayer(pos, enemyConfig.DetectRange)

	-- State transitions
	if enemy.State == AIState.Idle or enemy.State == AIState.Patrol then
		if nearestPlayer and dist <= enemyConfig.DetectRange then
			enemy.State = AIState.Chase
			enemy.Target = nearestPlayer
		elseif enemy.State == AIState.Idle then
			-- Random patrol
			enemy.PatrolTimer = (enemy.PatrolTimer or 0) - dt
			if enemy.PatrolTimer <= 0 then
				enemy.PatrolTimer = math.random(3, 8)
				local patrolTarget = enemy.SpawnPosition + Vector3.new(
					math.random(-15, 15), 0, math.random(-15, 15)
				)
				humanoid:MoveTo(patrolTarget)
				enemy.State = AIState.Patrol
			end
		elseif enemy.State == AIState.Patrol then
			if humanoid.MoveDirection.Magnitude < 0.1 then
				enemy.State = AIState.Idle
			end
		end

	elseif enemy.State == AIState.Chase then
		if not nearestPlayer then
			enemy.State = AIState.Idle
			enemy.Target = nil
			return
		end

		local targetChar = nearestPlayer.Character
		local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

		if not targetHRP then
			enemy.State = AIState.Idle
			enemy.Target = nil
			return
		end

		-- Flee if low health (non-boss, non-golem)
		local healthPercent = enemy.ScaledStats.CurrentHealth / enemy.ScaledStats.MaxHealth
		if healthPercent < 0.2 and not enemy.IsBoss and enemy.EnemyType ~= "Golem" then
			enemy.State = AIState.Flee
			return
		end

		if dist <= enemyConfig.AttackRange then
			enemy.State = AIState.Attack
		else
			-- Use pathfinding
			local waypoints = findPath(pos, targetHRP.Position)
			if waypoints then
				for _, wp in ipairs(waypoints) do
					humanoid:MoveTo(wp.Position)
					local reached = humanoid.MoveToFinished:Wait()
					if not reached then break end

					-- Recheck distance
					local newDist = (model.PrimaryPart.Position - targetHRP.Position).Magnitude
					if newDist <= enemyConfig.AttackRange then
						enemy.State = AIState.Attack
						break
					end
				end
			else
				-- Direct movement fallback
				humanoid:MoveTo(targetHRP.Position)
			end
		end

	elseif enemy.State == AIState.Attack then
		if not nearestPlayer then
			enemy.State = AIState.Idle
			return
		end

		if dist > enemyConfig.AttackRange * 1.5 then
			enemy.State = AIState.Chase
			return
		end

		-- Check ability cooldowns and use abilities
		local usedAbility = false
		if enemyConfig.Abilities then
			for _, abilityName in ipairs(enemyConfig.Abilities) do
				local success, damage, targets, effect = executeAbility(enemy, abilityName, nearestPlayer)
				if success then
					usedAbility = true
					-- Damage will be handled by CombatSystem
					if enemy.OnAbilityHit then
						enemy.OnAbilityHit(abilityName, damage, targets, effect)
					end
					break
				end
			end
		end

		-- Basic attack if no ability used
		if not usedAbility then
			local now = tick()
			if now - (enemy.LastAttackTime or 0) >= enemyConfig.AttackCooldown then
				enemy.LastAttackTime = now
				local damage = enemy.ScaledStats.Attack * (enemy.DamageMult or 1)
				if enemy.OnBasicAttack then
					enemy.OnBasicAttack(nearestPlayer, damage)
				end
			end
		end

	elseif enemy.State == AIState.Flee then
		if not nearestPlayer then
			enemy.State = AIState.Idle
			return
		end

		local targetChar = nearestPlayer.Character
		local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		if targetHRP then
			local fleeDir = (pos - targetHRP.Position).Unit
			local fleeTarget = pos + fleeDir * 30
			humanoid:MoveTo(fleeTarget)
		end

		-- Return to chase after fleeing if health recovered a bit
		local healthPercent = enemy.ScaledStats.CurrentHealth / enemy.ScaledStats.MaxHealth
		if healthPercent > 0.35 then
			enemy.State = AIState.Chase
		end
	end

	-- Boss phase check
	if enemy.IsBoss then
		updateBossPhase(enemy)
	end

	-- Update health bar
	local healthBar = model:FindFirstChild("Head")
	if healthBar then
		local bb = healthBar:FindFirstChild("HealthBar")
		if bb then
			local fill = bb:FindFirstChild("Frame") and bb.Frame:FindFirstChild("Fill")
			if fill then
				local pct = enemy.ScaledStats.CurrentHealth / enemy.ScaledStats.MaxHealth
				fill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
				if pct > 0.5 then
					fill.BackgroundColor3 = Color3.fromRGB(30, 200, 30)
				elseif pct > 0.25 then
					fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
				else
					fill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
				end
			end
		end
	end
end

-- ========== PUBLIC API ==========
function EnemyAI:SpawnEnemy(enemyType, position, floorNumber, isBoss)
	local configSource = isBoss and Config.Enemy.Boss or Config.Enemy.Types
	local config = configSource[enemyType]
	if not config then
		warn("[EnemyAI] Unknown enemy type: " .. tostring(enemyType))
		return nil
	end

	enemyIdCounter = enemyIdCounter + 1
	local id = enemyIdCounter

	local model, scaledStats = createEnemyModel(enemyType, config, position, floorNumber)

	local enemy = {
		Id = id,
		EnemyType = enemyType,
		Config = config,
		Model = model,
		ScaledStats = scaledStats,
		State = AIState.Idle,
		Target = nil,
		SpawnPosition = position,
		FloorNumber = floorNumber,
		IsBoss = isBoss or false,
		CurrentPhase = 1,
		PhaseConfig = config.Phases,
		BaseSpeed = config.Speed,
		DamageMult = 1,
		AbilityCooldowns = {},
		LastAttackTime = 0,
		PatrolTimer = math.random(2, 5),
		IsChanneling = false,
		ChannelEndTime = 0,

		OnBasicAttack = nil,
		OnAbilityHit = nil,
		OnDeath = nil,
	}

	activeEnemies[id] = enemy
	remoteEvents.EnemySpawned:FireAllClients(id, enemyType, position, isBoss)

	return enemy
end

function EnemyAI:DamageEnemy(enemyId, damage)
	local enemy = activeEnemies[enemyId]
	if not enemy or enemy.State == AIState.Dead then return 0 end

	local defense = enemy.ScaledStats.Defense
	local effectiveDamage = math.max(1, damage - defense * 0.4)
	enemy.ScaledStats.CurrentHealth = enemy.ScaledStats.CurrentHealth - effectiveDamage

	local humanoid = enemy.Model and enemy.Model:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = math.max(0, enemy.ScaledStats.CurrentHealth)
	end

	remoteEvents.EnemyDamaged:FireAllClients(enemy.Id, effectiveDamage, enemy.ScaledStats.CurrentHealth)

	-- Hit flash
	if enemy.Model and enemy.Model.PrimaryPart then
		local original = enemy.Model.PrimaryPart.Color
		enemy.Model.PrimaryPart.Color = Color3.fromRGB(255, 255, 255)
		task.delay(Config.Visual.HitFlashDuration, function()
			if enemy.Model and enemy.Model.PrimaryPart then
				enemy.Model.PrimaryPart.Color = original
			end
		end)
	end

	if enemy.ScaledStats.CurrentHealth <= 0 then
		self:KillEnemy(enemyId)
	end

	return effectiveDamage
end

function EnemyAI:KillEnemy(enemyId)
	local enemy = activeEnemies[enemyId]
	if not enemy then return end

	enemy.State = AIState.Dead

	remoteEvents.EnemyDied:FireAllClients(enemyId, enemy.ScaledStats.XPReward)

	if enemy.OnDeath then
		enemy.OnDeath()
	end

	-- Death effect
	if enemy.Model then
		for _, part in ipairs(enemy.Model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end

		-- Dissolve effect
		task.spawn(function()
			for i = 0, 10 do
				task.wait(0.1)
				for _, part in ipairs(enemy.Model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Transparency = i / 10
					end
				end
			end
			enemy.Model:Destroy()
		end)
	end

	activeEnemies[enemyId] = nil
end

function EnemyAI:GetEnemy(enemyId)
	return activeEnemies[enemyId]
end

function EnemyAI:GetAllEnemies()
	return activeEnemies
end

function EnemyAI:ClearAll()
	for id, enemy in pairs(activeEnemies) do
		if enemy.Model then
			enemy.Model:Destroy()
		end
	end
	activeEnemies = {}
end

function EnemyAI:Init()
	RunService.Heartbeat:Connect(function(dt)
		for _, enemy in pairs(activeEnemies) do
			updateEnemy(enemy, dt)
		end
	end)
	print("[EnemyAI] Initialized.")
end

return EnemyAI
