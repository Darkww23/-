--[[
	CombatSystem.lua
	Handles all combat logic: player attacks, ability usage, damage calculation,
	critical hits, status effects (DoT, slow, stun), and loot drops on kill.
	Place in: ServerScriptService/CombatSystem
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.SharedModules.Config)
local ItemDatabase = require(ReplicatedStorage.SharedModules.ItemDatabase)

local CombatSystem = {}
CombatSystem.__index = CombatSystem

local PlayerDataManager
local EnemyAI
local LootSystem

local statusEffects = {}

-- ========== REMOTE EVENTS ==========
local remoteEvents = {}

local function ensureRemote(name, className)
	className = className or "RemoteEvent"
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	remoteEvents[name] = remote
	return remote
end

ensureRemote("PlayerAttack")
ensureRemote("PlayerUseAbility")
ensureRemote("DamageNumber")
ensureRemote("StatusEffectApplied")
ensureRemote("StatusEffectRemoved")
ensureRemote("CombatLog")

-- ========== DAMAGE CALCULATION ==========
local function calculateDamage(attackerStats, defenderDefense, baseMult)
	baseMult = baseMult or 1.0
	local rawDamage = attackerStats.Attack * baseMult
	local variance = rawDamage * 0.1
	rawDamage = rawDamage + math.random() * variance * 2 - variance

	local isCrit = math.random() < (attackerStats.CritChance or 0.05)
	if isCrit then
		rawDamage = rawDamage * (1 + (attackerStats.CritMult or 0.5))
	end

	local mitigated = rawDamage * (1 - defenderDefense / (defenderDefense + 100))
	return math.floor(math.max(1, mitigated)), isCrit
end

-- ========== STATUS EFFECTS ==========
local function applyStatusEffect(targetId, targetType, effect)
	if not statusEffects[targetId] then
		statusEffects[targetId] = {}
	end

	local effectData = {
		Type = effect.Type,
		StartTime = tick(),
		Duration = effect.Duration or 5,
		TickDamage = effect.TickDamage or 0,
		SlowMult = effect.SlowMult or 1,
		LastTick = tick(),
		TickInterval = 1,
		TargetType = targetType,
	}

	table.insert(statusEffects[targetId], effectData)

	if targetType == "Player" then
		local player = Players:GetPlayerByUserId(targetId)
		if player then
			remoteEvents.StatusEffectApplied:FireClient(player, effect.Type, effect.Duration)
		end
	end
end

local function processStatusEffects(dt)
	local now = tick()
	for targetId, effects in pairs(statusEffects) do
		for i = #effects, 1, -1 do
			local effect = effects[i]
			local elapsed = now - effect.StartTime

			if elapsed >= effect.Duration then
				-- Remove expired effect
				if effect.TargetType == "Player" then
					local player = Players:GetPlayerByUserId(targetId)
					if player then
						remoteEvents.StatusEffectRemoved:FireClient(player, effect.Type)
						if effect.Type == "Slow" then
							local char = player.Character
							local hum = char and char:FindFirstChild("Humanoid")
							if hum then
								hum.WalkSpeed = Config.Player.BaseSpeed
							end
						end
					end
				end
				table.remove(effects, i)
			else
				-- Process tick effects
				if now - effect.LastTick >= effect.TickInterval then
					effect.LastTick = now

					if effect.Type == "DoT" and effect.TickDamage > 0 then
						if effect.TargetType == "Player" then
							local player = Players:GetPlayerByUserId(targetId)
							if player and PlayerDataManager then
								local dmg = PlayerDataManager:TakeDamage(player, effect.TickDamage, "Poison")
								remoteEvents.DamageNumber:FireAllClients(
									player.Character and player.Character:FindFirstChild("HumanoidRootPart") and
									player.Character.HumanoidRootPart.Position or Vector3.new(0, 0, 0),
									dmg, false, "Poison"
								)
							end
						elseif effect.TargetType == "Enemy" then
							if EnemyAI then
								EnemyAI:DamageEnemy(targetId, effect.TickDamage)
							end
						end
					end

					if effect.Type == "Slow" and effect.TargetType == "Player" then
						local player = Players:GetPlayerByUserId(targetId)
						if player then
							local char = player.Character
							local hum = char and char:FindFirstChild("Humanoid")
							if hum then
								hum.WalkSpeed = Config.Player.BaseSpeed * effect.SlowMult
							end
						end
					end
				end
			end
		end

		if #effects == 0 then
			statusEffects[targetId] = nil
		end
	end
end

-- ========== PLAYER ATTACK HANDLER ==========
local function onPlayerAttack(player)
	local data = PlayerDataManager:GetData(player)
	if not data or data.CurrentHealth <= 0 then return end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local attackRange = 6
	local equipment = data.Equipment
	if equipment.MainHand then
		local template = ItemDatabase:GetItemById(equipment.MainHand.Id)
		if template and template.IsRanged then
			attackRange = template.Range or 60
		end
	end

	-- Find enemies in range
	local bestEnemy = nil
	local bestDist = attackRange

	for id, enemy in pairs(EnemyAI:GetAllEnemies()) do
		if enemy.State ~= "Dead" and enemy.Model and enemy.Model.PrimaryPart then
			local dist = (enemy.Model.PrimaryPart.Position - hrp.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestEnemy = enemy
			end
		end
	end

	if not bestEnemy then return end

	local damage, isCrit = calculateDamage(data.Stats, bestEnemy.ScaledStats.Defense)

	-- Check weapon special effects
	if equipment.MainHand then
		local template = ItemDatabase:GetItemById(equipment.MainHand.Id)
		if template then
			if template.SpecialEffect == "BurnOnHit" then
				applyStatusEffect(bestEnemy.Id, "Enemy", {
					Type = "DoT",
					TickDamage = template.BurnDamage or 5,
					Duration = template.BurnDuration or 3,
				})
			elseif template.SpecialEffect == "LifeStealOnCrit" and isCrit then
				local heal = damage * (template.LifeStealRatio or 0.15)
				PlayerDataManager:Heal(player, heal)
			elseif template.SpecialEffect == "ChainLightning" then
				local chainTargets = {}
				local chainPos = bestEnemy.Model.PrimaryPart.Position
				for cId, cEnemy in pairs(EnemyAI:GetAllEnemies()) do
					if cId ~= bestEnemy.Id and cEnemy.State ~= "Dead" and cEnemy.Model and cEnemy.Model.PrimaryPart then
						if (cEnemy.Model.PrimaryPart.Position - chainPos).Magnitude <= 20 then
							table.insert(chainTargets, cEnemy)
							if #chainTargets >= (template.ChainTargets or 3) then break end
						end
					end
				end
				local chainDmg = damage
				for _, chainEnemy in ipairs(chainTargets) do
					chainDmg = chainDmg * (template.ChainDamageDecay or 0.7)
					EnemyAI:DamageEnemy(chainEnemy.Id, chainDmg)
					remoteEvents.DamageNumber:FireAllClients(
						chainEnemy.Model.PrimaryPart.Position,
						math.floor(chainDmg), false, "Lightning"
					)
				end
			end
		end
	end

	local actualDmg = EnemyAI:DamageEnemy(bestEnemy.Id, damage)
	remoteEvents.DamageNumber:FireAllClients(
		bestEnemy.Model and bestEnemy.Model.PrimaryPart and bestEnemy.Model.PrimaryPart.Position or hrp.Position,
		actualDmg, isCrit, "Physical"
	)

	remoteEvents.CombatLog:FireClient(player,
		"You dealt " .. actualDmg .. (isCrit and " CRITICAL" or "") .. " damage to " .. bestEnemy.EnemyType
	)
end

-- ========== ABILITY USAGE HANDLER ==========
local function onPlayerUseAbility(player, abilityIndex)
	local data = PlayerDataManager:GetData(player)
	if not data or data.CurrentHealth <= 0 then return end

	local abilityName = data.EquippedAbilities[abilityIndex]
	if not abilityName then return end

	local abilityConfig = Config.Abilities[abilityName]
	if not abilityConfig then return end

	-- Check cooldown
	local now = tick()
	local lastUsed = data.AbilityCooldowns[abilityName] or 0
	if now - lastUsed < abilityConfig.Cooldown then return end

	-- Check mana
	if abilityConfig.ManaCost and not PlayerDataManager:UseMana(player, abilityConfig.ManaCost) then
		return
	end

	data.AbilityCooldowns[abilityName] = now

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if abilityConfig.Type == "Self" then
		if abilityConfig.HealMult then
			local healAmount = data.Stats.MaxHealth * abilityConfig.HealMult
			PlayerDataManager:Heal(player, healAmount)
			remoteEvents.DamageNumber:FireAllClients(hrp.Position, math.floor(healAmount), false, "Heal")
		end

	elseif abilityConfig.Type == "Shield" then
		local shieldAmount = data.Stats.MaxHealth * (abilityConfig.ShieldMult or 0.3)
		PlayerDataManager:ApplyBuff(player, {
			Type = "Shield",
			Value = shieldAmount,
			Remaining = shieldAmount,
			Duration = abilityConfig.Duration,
		})
		remoteEvents.DamageNumber:FireAllClients(hrp.Position, math.floor(shieldAmount), false, "Shield")

	elseif abilityConfig.Type == "Melee" or abilityConfig.Type == "Dash" then
		local range = abilityConfig.Range or 8

		if abilityConfig.Type == "Dash" then
			local lookDir = hrp.CFrame.LookVector
			local dashTarget = hrp.Position + lookDir * range
			hrp.CFrame = CFrame.new(dashTarget, dashTarget + lookDir)
		end

		for id, enemy in pairs(EnemyAI:GetAllEnemies()) do
			if enemy.State ~= "Dead" and enemy.Model and enemy.Model.PrimaryPart then
				local dist = (enemy.Model.PrimaryPart.Position - hrp.Position).Magnitude
				if dist <= range then
					local dmg, isCrit = calculateDamage(data.Stats, enemy.ScaledStats.Defense, abilityConfig.DamageMult)
					local actualDmg = EnemyAI:DamageEnemy(id, dmg)
					remoteEvents.DamageNumber:FireAllClients(
						enemy.Model.PrimaryPart.Position, actualDmg, isCrit, "Physical"
					)
				end
			end
		end

	elseif abilityConfig.Type == "Ranged" then
		local bestEnemy, bestDist = nil, abilityConfig.Range or 50
		for id, enemy in pairs(EnemyAI:GetAllEnemies()) do
			if enemy.State ~= "Dead" and enemy.Model and enemy.Model.PrimaryPart then
				local dist = (enemy.Model.PrimaryPart.Position - hrp.Position).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestEnemy = enemy
				end
			end
		end
		if bestEnemy then
			local dmg, isCrit = calculateDamage(data.Stats, bestEnemy.ScaledStats.Defense, abilityConfig.DamageMult)
			local actualDmg = EnemyAI:DamageEnemy(bestEnemy.Id, dmg)
			remoteEvents.DamageNumber:FireAllClients(
				bestEnemy.Model.PrimaryPart.Position, actualDmg, isCrit, "Magic"
			)
		end

	elseif abilityConfig.Type == "AoE" then
		local range = abilityConfig.Range or 15
		for id, enemy in pairs(EnemyAI:GetAllEnemies()) do
			if enemy.State ~= "Dead" and enemy.Model and enemy.Model.PrimaryPart then
				local dist = (enemy.Model.PrimaryPart.Position - hrp.Position).Magnitude
				if dist <= range then
					local dmg, isCrit = calculateDamage(data.Stats, enemy.ScaledStats.Defense, abilityConfig.DamageMult)
					local actualDmg = EnemyAI:DamageEnemy(id, dmg)
					remoteEvents.DamageNumber:FireAllClients(
						enemy.Model.PrimaryPart.Position, actualDmg, isCrit, "Magic"
					)
				end
			end
		end

	elseif abilityConfig.Type == "Teleport" then
		local range = abilityConfig.Range or 30
		local lookDir = hrp.CFrame.LookVector
		local teleportTarget = hrp.Position + lookDir * range
		hrp.CFrame = CFrame.new(teleportTarget, teleportTarget + lookDir)

		for id, enemy in pairs(EnemyAI:GetAllEnemies()) do
			if enemy.State ~= "Dead" and enemy.Model and enemy.Model.PrimaryPart then
				local dist = (enemy.Model.PrimaryPart.Position - teleportTarget).Magnitude
				if dist <= 8 then
					local dmg, isCrit = calculateDamage(data.Stats, enemy.ScaledStats.Defense, abilityConfig.DamageMult)
					EnemyAI:DamageEnemy(id, dmg)
					remoteEvents.DamageNumber:FireAllClients(
						enemy.Model.PrimaryPart.Position, dmg, isCrit, "Shadow"
					)
				end
			end
		end
	end

	remoteEvents.CombatLog:FireClient(player, "Used ability: " .. abilityName)
end

-- ========== ENEMY ATTACK CALLBACKS ==========
local function setupEnemyCallbacks(enemy)
	enemy.OnBasicAttack = function(targetPlayer, damage)
		if not PlayerDataManager then return end
		local actualDmg = PlayerDataManager:TakeDamage(targetPlayer, damage, "Physical")
		local targetHRP = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if targetHRP then
			remoteEvents.DamageNumber:FireAllClients(targetHRP.Position, actualDmg, false, "EnemyPhysical")
		end
	end

	enemy.OnAbilityHit = function(abilityName, damage, targets, effect)
		if not PlayerDataManager then return end
		for _, target in ipairs(targets) do
			if typeof(target) == "Instance" and target:IsA("Player") then
				local actualDmg = PlayerDataManager:TakeDamage(target, damage, "Magic")
				local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					remoteEvents.DamageNumber:FireAllClients(targetHRP.Position, actualDmg, false, "EnemyMagic")
				end

				if effect then
					if effect.Type == "DoT" or effect.Type == "Slow" then
						applyStatusEffect(target.UserId, "Player", effect)
					end
				end
			end
		end

		if effect and effect.Type == "Summon" then
			local spawnPos = effect.SpawnPosition
			for i = 1, effect.Count do
				local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
				EnemyAI:SpawnEnemy(effect.MinionType, spawnPos + offset, enemy.FloorNumber, false)
			end
		end
	end

	enemy.OnDeath = function()
		local xpReward = enemy.ScaledStats.XPReward
		local goldReward = math.floor(
			Config.Loot.GoldDropBase * (1 + enemy.FloorNumber * 0.2) *
			(1 + math.random() * Config.Loot.GoldDropVariance * 2 - Config.Loot.GoldDropVariance)
		)

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and enemy.Model and enemy.Model.PrimaryPart then
					local dist = (hrp.Position - enemy.Model.PrimaryPart.Position).Magnitude
					if dist <= 80 then
						PlayerDataManager:AddXP(player, xpReward)
						PlayerDataManager:AddGold(player, goldReward)
						local pdata = PlayerDataManager:GetData(player)
						if pdata then
							pdata.TotalKills = pdata.TotalKills + 1
						end
					end
				end
			end
		end

		if LootSystem and enemy.Model and enemy.Model.PrimaryPart then
			LootSystem:RollDrop(enemy.Model.PrimaryPart.Position, enemy.FloorNumber, enemy.IsBoss)
		end
	end
end

-- ========== TRAP SYSTEM ==========
local function processTrap(trap, player)
	local config = trap:FindFirstChild("TrapConfig")
	if not config then return end

	local lastTrigger = config:FindFirstChild("LastTrigger")
	local cooldown = config:FindFirstChild("Cooldown")
	local damage = config:FindFirstChild("Damage")
	local trapType = config:FindFirstChild("TrapType")

	if not lastTrigger or not cooldown or not damage then return end

	local now = tick()
	if now - lastTrigger.Value < cooldown.Value then return end
	lastTrigger.Value = now

	local dmg = PlayerDataManager:TakeDamage(player, damage.Value, "Trap")
	remoteEvents.CombatLog:FireClient(player, "Triggered " .. (trapType and trapType.Value or "trap") .. " for " .. dmg .. " damage!")

	if trapType and trapType.Value == "FireTrap" then
		applyStatusEffect(player.UserId, "Player", {
			Type = "DoT",
			TickDamage = 5,
			Duration = 3,
		})
	elseif trapType and trapType.Value == "PoisonGas" then
		applyStatusEffect(player.UserId, "Player", {
			Type = "DoT",
			TickDamage = 3,
			Duration = 6,
		})
	end
end

-- ========== INITIALIZATION ==========
function CombatSystem:Init(playerDataMgr, enemyAI, lootSys)
	PlayerDataManager = playerDataMgr
	EnemyAI = enemyAI
	LootSystem = lootSys

	remoteEvents.PlayerAttack.OnServerEvent:Connect(onPlayerAttack)
	remoteEvents.PlayerUseAbility.OnServerEvent:Connect(onPlayerUseAbility)

	-- Status effect tick
	RunService.Heartbeat:Connect(function(dt)
		processStatusEffects(dt)
	end)

	-- Trap detection
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end

			local dungeonFolder = workspace:FindFirstChild("Dungeon_Floor_" .. (LootSystem and LootSystem.CurrentFloor or 1))
			if not dungeonFolder then continue end

			local trapsFolder = dungeonFolder:FindFirstChild("Traps")
			if not trapsFolder then continue end

			for _, trap in ipairs(trapsFolder:GetChildren()) do
				if trap.Name:match("^Trap_") then
					local dist = (trap.Position - hrp.Position).Magnitude
					local config = trap:FindFirstChild("TrapConfig")
					local triggerRadius = config and config:FindFirstChild("TriggerRadius")
					local radius = triggerRadius and triggerRadius.Value or 4
					if dist <= radius then
						processTrap(trap, player)
					end
				end
			end
		end
	end)

	print("[CombatSystem] Initialized.")
end

function CombatSystem:SetupEnemyCallbacks(enemy)
	setupEnemyCallbacks(enemy)
end

return CombatSystem
