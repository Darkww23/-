--[[
	PlayerDataManager.lua
	Manages player data: stats, leveling, inventory, save/load via DataStoreService.
	Place in: ServerScriptService/PlayerDataManager
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.SharedModules.Config)

local PlayerDataManager = {}
PlayerDataManager.__index = PlayerDataManager

local DATA_STORE_NAME = "RPGDungeonData_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_RETRIES = 3

local playerDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local activeSessions = {}

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

ensureRemote("PlayerStatsUpdated")
ensureRemote("PlayerLevelUp")
ensureRemote("InventoryUpdated")
ensureRemote("GoldUpdated")
ensureRemote("XPGained")
ensureRemote("PlayerDied")
ensureRemote("UseConsumable")
ensureRemote("EquipItem")
ensureRemote("UnequipItem")
ensureRemote("DropItem")

-- ========== DEFAULT DATA ==========
local function createDefaultData()
	return {
		Level = 1,
		XP = 0,
		Gold = 0,
		DungeonsCleared = 0,
		MaxFloorReached = 0,
		TotalKills = 0,
		TotalDeaths = 0,
		PlayTime = 0,

		Stats = {
			MaxHealth  = Config.Player.BaseHealth,
			MaxMana    = Config.Player.BaseMana,
			MaxStamina = Config.Player.BaseStamina,
			Attack     = Config.Player.BaseAttack,
			Defense    = Config.Player.BaseDefense,
			CritChance = Config.Player.BaseCritChance,
			CritMult   = Config.Player.BaseCritMult,
			Speed      = Config.Player.BaseSpeed,
		},

		CurrentHealth  = Config.Player.BaseHealth,
		CurrentMana    = Config.Player.BaseMana,
		CurrentStamina = Config.Player.BaseStamina,

		Inventory = {},
		Equipment = {
			MainHand = nil,
			OffHand  = nil,
			Head     = nil,
			Chest    = nil,
			Feet     = nil,
			Ring     = nil,
			Amulet   = nil,
		},

		UnlockedAbilities = {"PowerStrike"},
		EquippedAbilities = {"PowerStrike", nil, nil, nil},
		AbilityCooldowns  = {},

		Buffs = {},
		StatusEffects = {},

		Settings = {
			ShowDamageNumbers = true,
			ShowMinimap = true,
			MusicVolume = 0.5,
			SFXVolume = 0.7,
		},
	}
end

-- ========== DATA PERSISTENCE ==========
local function saveData(player, data)
	local key = "Player_" .. player.UserId
	local success, err
	for i = 1, MAX_RETRIES do
		success, err = pcall(function()
			playerDataStore:SetAsync(key, data)
		end)
		if success then break end
		if i < MAX_RETRIES then
			task.wait(1)
		end
	end
	if not success then
		warn("[PlayerDataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
	return success
end

local function loadData(player)
	local key = "Player_" .. player.UserId
	local success, data
	for i = 1, MAX_RETRIES do
		success, data = pcall(function()
			return playerDataStore:GetAsync(key)
		end)
		if success then break end
		if i < MAX_RETRIES then
			task.wait(1)
		end
	end
	if success and data then
		return data
	end
	if not success then
		warn("[PlayerDataManager] Failed to load data for " .. player.Name .. ": " .. tostring(data))
	end
	return nil
end

-- ========== STAT CALCULATIONS ==========
local function recalculateStats(data)
	local level = data.Level
	local spl = Config.Player.StatsPerLevel

	local base = {
		MaxHealth  = Config.Player.BaseHealth + (level - 1) * spl.Health,
		MaxMana    = Config.Player.BaseMana + (level - 1) * spl.Mana,
		MaxStamina = Config.Player.BaseStamina + (level - 1) * spl.Stamina,
		Attack     = Config.Player.BaseAttack + (level - 1) * spl.Attack,
		Defense    = Config.Player.BaseDefense + (level - 1) * spl.Defense,
		CritChance = Config.Player.BaseCritChance,
		CritMult   = Config.Player.BaseCritMult,
		Speed      = Config.Player.BaseSpeed,
	}

	local ItemDB = require(ReplicatedStorage.SharedModules.ItemDatabase)
	for _, itemData in pairs(data.Equipment) do
		if itemData then
			local template = ItemDB:GetItemById(itemData.Id)
			if template and template.BaseStats then
				for stat, value in pairs(template.BaseStats) do
					if base[stat] then
						base[stat] = base[stat] + value
					elseif stat == "Health" then
						base.MaxHealth = base.MaxHealth + value
					elseif stat == "Mana" then
						base.MaxMana = base.MaxMana + value
					elseif stat == "Stamina" then
						base.MaxStamina = base.MaxStamina + value
					end
				end
			end
		end
	end

	data.Stats = base
	data.CurrentHealth = math.min(data.CurrentHealth, base.MaxHealth)
	data.CurrentMana = math.min(data.CurrentMana, base.MaxMana)
	data.CurrentStamina = math.min(data.CurrentStamina, base.MaxStamina)
end

-- ========== LEVELING ==========
local function checkLevelUp(player, data)
	local leveled = false
	while data.Level < Config.Player.MaxLevel do
		local xpNeeded = Config.Player.XPPerLevel(data.Level)
		if data.XP >= xpNeeded then
			data.XP = data.XP - xpNeeded
			data.Level = data.Level + 1
			leveled = true

			recalculateStats(data)
			data.CurrentHealth = data.Stats.MaxHealth
			data.CurrentMana = data.Stats.MaxMana
			data.CurrentStamina = data.Stats.MaxStamina

			local newAbilities = {
				[3]  = "Fireball",
				[6]  = "HealingSurge",
				[10] = "Whirlwind",
				[15] = "DashStrike",
				[20] = "IceBarrier",
				[28] = "ThunderClap",
				[35] = "ShadowStep",
			}
			if newAbilities[data.Level] then
				table.insert(data.UnlockedAbilities, newAbilities[data.Level])
			end

			remoteEvents.PlayerLevelUp:FireClient(player, data.Level, data.Stats)
		else
			break
		end
	end
	return leveled
end

-- ========== PUBLIC API ==========
function PlayerDataManager:GetData(player)
	return activeSessions[player.UserId]
end

function PlayerDataManager:AddXP(player, amount)
	local data = activeSessions[player.UserId]
	if not data then return end

	data.XP = data.XP + amount
	remoteEvents.XPGained:FireClient(player, amount, data.XP)

	if checkLevelUp(player, data) then
		recalculateStats(data)
	end

	self:SyncToClient(player)
end

function PlayerDataManager:AddGold(player, amount)
	local data = activeSessions[player.UserId]
	if not data then return end

	data.Gold = data.Gold + amount
	remoteEvents.GoldUpdated:FireClient(player, data.Gold, amount)
end

function PlayerDataManager:TakeDamage(player, rawDamage, damageType)
	local data = activeSessions[player.UserId]
	if not data then return 0 end

	local defense = data.Stats.Defense
	local effectiveDamage = math.max(1, rawDamage - defense * 0.5)

	for _, buff in ipairs(data.Buffs) do
		if buff.Type == "Shield" and buff.Remaining > 0 then
			local absorbed = math.min(buff.Remaining, effectiveDamage)
			buff.Remaining = buff.Remaining - absorbed
			effectiveDamage = effectiveDamage - absorbed
		end
	end

	data.CurrentHealth = math.max(0, data.CurrentHealth - effectiveDamage)

	if data.CurrentHealth <= 0 then
		data.TotalDeaths = data.TotalDeaths + 1
		remoteEvents.PlayerDied:FireClient(player)
		task.delay(Config.Player.RespawnTime, function()
			if activeSessions[player.UserId] then
				data.CurrentHealth = data.Stats.MaxHealth * 0.5
				self:SyncToClient(player)
			end
		end)
	end

	self:SyncToClient(player)
	return effectiveDamage
end

function PlayerDataManager:Heal(player, amount)
	local data = activeSessions[player.UserId]
	if not data then return end

	data.CurrentHealth = math.min(data.Stats.MaxHealth, data.CurrentHealth + amount)
	self:SyncToClient(player)
end

function PlayerDataManager:UseMana(player, amount)
	local data = activeSessions[player.UserId]
	if not data then return false end

	if data.CurrentMana < amount then return false end
	data.CurrentMana = data.CurrentMana - amount
	self:SyncToClient(player)
	return true
end

function PlayerDataManager:AddToInventory(player, itemInstance)
	local data = activeSessions[player.UserId]
	if not data then return false end

	if #data.Inventory >= Config.Loot.MaxInventorySlots then
		return false
	end

	table.insert(data.Inventory, itemInstance)
	remoteEvents.InventoryUpdated:FireClient(player, data.Inventory)
	return true
end

function PlayerDataManager:RemoveFromInventory(player, index)
	local data = activeSessions[player.UserId]
	if not data then return nil end

	if index < 1 or index > #data.Inventory then return nil end
	local removed = table.remove(data.Inventory, index)
	remoteEvents.InventoryUpdated:FireClient(player, data.Inventory)
	return removed
end

function PlayerDataManager:EquipItem(player, inventoryIndex)
	local data = activeSessions[player.UserId]
	if not data then return false end

	local item = data.Inventory[inventoryIndex]
	if not item then return false end

	local ItemDB = require(ReplicatedStorage.SharedModules.ItemDatabase)
	local template = ItemDB:GetItemById(item.Id)
	if not template or not template.Slot then return false end

	if template.LevelReq and data.Level < template.LevelReq then
		return false
	end

	local slot = template.Slot
	local currentEquipped = data.Equipment[slot]

	table.remove(data.Inventory, inventoryIndex)
	data.Equipment[slot] = item

	if currentEquipped then
		table.insert(data.Inventory, currentEquipped)
	end

	recalculateStats(data)
	self:SyncToClient(player)
	remoteEvents.InventoryUpdated:FireClient(player, data.Inventory)
	return true
end

function PlayerDataManager:UnequipItem(player, slot)
	local data = activeSessions[player.UserId]
	if not data then return false end

	local item = data.Equipment[slot]
	if not item then return false end

	if #data.Inventory >= Config.Loot.MaxInventorySlots then
		return false
	end

	data.Equipment[slot] = nil
	table.insert(data.Inventory, item)

	recalculateStats(data)
	self:SyncToClient(player)
	remoteEvents.InventoryUpdated:FireClient(player, data.Inventory)
	return true
end

function PlayerDataManager:ApplyBuff(player, buffData)
	local data = activeSessions[player.UserId]
	if not data then return end

	table.insert(data.Buffs, {
		Type = buffData.Type,
		Value = buffData.Value,
		Duration = buffData.Duration,
		Remaining = buffData.Remaining or buffData.Value,
		StartTime = tick(),
	})
	self:SyncToClient(player)
end

function PlayerDataManager:SyncToClient(player)
	local data = activeSessions[player.UserId]
	if not data then return end

	remoteEvents.PlayerStatsUpdated:FireClient(player, {
		Level = data.Level,
		XP = data.XP,
		XPToNext = Config.Player.XPPerLevel(data.Level),
		Gold = data.Gold,
		Stats = data.Stats,
		CurrentHealth = data.CurrentHealth,
		CurrentMana = data.CurrentMana,
		CurrentStamina = data.CurrentStamina,
		Equipment = data.Equipment,
		Buffs = data.Buffs,
		DungeonsCleared = data.DungeonsCleared,
		MaxFloorReached = data.MaxFloorReached,
	})
end

-- ========== REGENERATION LOOP ==========
local function startRegenLoop()
	RunService.Heartbeat:Connect(function(dt)
		for userId, data in pairs(activeSessions) do
			if data.CurrentHealth > 0 then
				data.CurrentMana = math.min(
					data.Stats.MaxMana,
					data.CurrentMana + Config.Player.ManaRegenRate * dt
				)
				data.CurrentStamina = math.min(
					data.Stats.MaxStamina,
					data.CurrentStamina + Config.Player.StaminaRegenRate * dt
				)
			end

			local now = tick()
			for i = #data.Buffs, 1, -1 do
				local buff = data.Buffs[i]
				if buff.Duration and (now - buff.StartTime) >= buff.Duration then
					table.remove(data.Buffs, i)
				end
			end

			data.PlayTime = data.PlayTime + dt
		end
	end)
end

-- ========== AUTOSAVE ==========
local function startAutosave()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for userId, data in pairs(activeSessions) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				saveData(player, data)
			end
		end
	end
end

-- ========== INITIALIZATION ==========
function PlayerDataManager:Init()
	Players.PlayerAdded:Connect(function(player)
		local data = loadData(player)
		if not data then
			data = createDefaultData()
		end
		recalculateStats(data)
		activeSessions[player.UserId] = data
		self:SyncToClient(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local data = activeSessions[player.UserId]
		if data then
			saveData(player, data)
			activeSessions[player.UserId] = nil
		end
	end)

	remoteEvents.UseConsumable.OnServerEvent:Connect(function(player, inventoryIndex)
		local data = activeSessions[player.UserId]
		if not data then return end

		local item = data.Inventory[inventoryIndex]
		if not item then return end

		local ItemDB = require(ReplicatedStorage.SharedModules.ItemDatabase)
		local template = ItemDB:GetItemById(item.Id)
		if not template or template.Type ~= "Consumable" then return end

		if template.Effect == "Heal" then
			self:Heal(player, template.Value)
		elseif template.Effect == "RestoreMana" then
			data.CurrentMana = math.min(data.Stats.MaxMana, data.CurrentMana + template.Value)
		elseif template.Effect == "BuffAttack" then
			self:ApplyBuff(player, {Type = "AttackMult", Value = template.Value, Duration = template.Duration})
		elseif template.Effect == "BuffSpeed" then
			self:ApplyBuff(player, {Type = "SpeedMult", Value = template.Value, Duration = template.Duration})
		end

		if item.Count and item.Count > 1 then
			item.Count = item.Count - 1
		else
			table.remove(data.Inventory, inventoryIndex)
		end

		remoteEvents.InventoryUpdated:FireClient(player, data.Inventory)
		self:SyncToClient(player)
	end)

	remoteEvents.EquipItem.OnServerEvent:Connect(function(player, index)
		self:EquipItem(player, index)
	end)

	remoteEvents.UnequipItem.OnServerEvent:Connect(function(player, slot)
		self:UnequipItem(player, slot)
	end)

	startRegenLoop()
	task.spawn(startAutosave)

	print("[PlayerDataManager] Initialized.")
end

return PlayerDataManager
