--[[
	LootSystem.lua
	Handles loot generation, rarity rolling, stat randomization, and item pickup.
	Place in: ServerScriptService/LootSystem
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.SharedModules.Config)
local ItemDatabase = require(ReplicatedStorage.SharedModules.ItemDatabase)

local LootSystem = {}
LootSystem.__index = LootSystem

local PlayerDataManager

LootSystem.CurrentFloor = 1

local droppedItems = {}
local dropIdCounter = 0

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

ensureRemote("LootDropped")
ensureRemote("LootPickedUp")
ensureRemote("ChestOpened")

-- ========== RARITY ROLLING ==========
local function rollRarity(luckBonus)
	luckBonus = luckBonus or 0
	local rarities = Config.Loot.Rarities
	local totalWeight = 0
	local rarityList = {}

	for name, rarity in pairs(rarities) do
		local weight = rarity.DropWeight
		if name ~= "Common" then
			weight = weight * (1 + luckBonus)
		end
		totalWeight = totalWeight + weight
		table.insert(rarityList, {Name = name, Weight = weight, Cumulative = totalWeight})
	end

	local roll = math.random() * totalWeight
	for _, entry in ipairs(rarityList) do
		if roll <= entry.Cumulative then
			return entry.Name
		end
	end
	return "Common"
end

-- ========== ITEM GENERATION ==========
local function generateItem(floorNumber, forcedRarity, isBossLoot)
	local eligibleItems = ItemDatabase:GetItemsByMaxLevel(floorNumber * 2 + 5)
	if #eligibleItems == 0 then
		eligibleItems = ItemDatabase:GetAllItems()
	end

	-- Filter out consumables for boss loot
	if isBossLoot then
		local filtered = {}
		for _, item in ipairs(eligibleItems) do
			if item.Type ~= "Consumable" then
				table.insert(filtered, item)
			end
		end
		if #filtered > 0 then
			eligibleItems = filtered
		end
	end

	local template = eligibleItems[math.random(1, #eligibleItems)]

	local rarity
	if template.ForceRarity then
		rarity = template.ForceRarity
	elseif forcedRarity then
		rarity = forcedRarity
	else
		local luckBonus = isBossLoot and 0.5 or floorNumber * 0.03
		rarity = rollRarity(luckBonus)
	end

	local rarityConfig = Config.Loot.Rarities[rarity]
	local statMult = rarityConfig and rarityConfig.StatMult or 1.0

	-- Randomize stats
	local itemInstance = {
		Id = template.Id,
		Name = template.Name,
		Rarity = rarity,
		Stats = {},
		UniqueId = tostring(math.random(100000, 999999)) .. "_" .. tick(),
	}

	if template.BaseStats then
		for stat, baseValue in pairs(template.BaseStats) do
			local variance = baseValue * 0.15
			local finalValue = (baseValue + math.random() * variance * 2 - variance) * statMult
			if stat == "CritChance" or stat == "CritMult" then
				itemInstance.Stats[stat] = math.floor(finalValue * 1000) / 1000
			else
				itemInstance.Stats[stat] = math.floor(finalValue)
			end
		end
	end

	if template.Stackable then
		itemInstance.Count = 1
		itemInstance.MaxStack = template.MaxStack
		itemInstance.Stackable = true
	end

	return itemInstance, template
end

-- ========== WORLD DROP ==========
local function createWorldDrop(position, itemInstance, template)
	dropIdCounter = dropIdCounter + 1
	local dropId = dropIdCounter

	local rarity = itemInstance.Rarity or "Common"
	local rarityConfig = Config.Loot.Rarities[rarity]
	local color = rarityConfig and rarityConfig.Color or Color3.fromRGB(180, 180, 180)

	local dropPart = Instance.new("Part")
	dropPart.Name = "LootDrop_" .. dropId
	dropPart.Size = Vector3.new(1.5, 1.5, 1.5)
	dropPart.Position = position + Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))
	dropPart.Material = Enum.Material.Neon
	dropPart.Color = color
	dropPart.Anchored = true
	dropPart.CanCollide = false
	dropPart.Shape = Enum.PartType.Ball
	dropPart.Parent = workspace

	-- Glow effect
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = color
	highlight.Parent = dropPart

	-- Floating animation
	local startY = dropPart.Position.Y
	task.spawn(function()
		local t = 0
		while dropPart and dropPart.Parent do
			t = t + 0.03
			dropPart.Position = Vector3.new(
				dropPart.Position.X,
				startY + math.sin(t * 2) * 0.5,
				dropPart.Position.Z
			)
			dropPart.Orientation = Vector3.new(0, t * 50 % 360, 0)
			task.wait(0.03)
		end
	end)

	-- Pickup prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up: " .. itemInstance.Name .. " [" .. rarity .. "]"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.Parent = dropPart

	local dropData = {
		Id = dropId,
		Part = dropPart,
		Item = itemInstance,
		Template = template,
	}
	droppedItems[dropId] = dropData

	prompt.Triggered:Connect(function(player)
		if not droppedItems[dropId] then return end

		local success = PlayerDataManager:AddToInventory(player, itemInstance)
		if success then
			droppedItems[dropId] = nil
			dropPart:Destroy()
			remoteEvents.LootPickedUp:FireClient(player, itemInstance)
		end
	end)

	remoteEvents.LootDropped:FireAllClients(dropId, itemInstance.Name, rarity, dropPart.Position)

	-- Auto-despawn after 60 seconds
	task.delay(60, function()
		if droppedItems[dropId] then
			droppedItems[dropId] = nil
			if dropPart then
				dropPart:Destroy()
			end
		end
	end)

	return dropData
end

-- ========== PUBLIC API ==========
function LootSystem:RollDrop(position, floorNumber, isBossLoot)
	local dropChance = isBossLoot and 1.0 or Config.Loot.DropChance
	if math.random() > dropChance then return end

	local numDrops = isBossLoot and math.random(2, 4) or 1

	for i = 1, numDrops do
		local forcedRarity = nil
		if isBossLoot and i == 1 then
			-- First boss drop is always Epic or Legendary
			forcedRarity = math.random() < 0.3 and "Legendary" or "Epic"
		end

		local itemInstance, template = generateItem(floorNumber, forcedRarity, isBossLoot)
		createWorldDrop(position, itemInstance, template)
	end

	-- Always drop gold
	local goldAmount = math.floor(
		Config.Loot.GoldDropBase * (1 + floorNumber * 0.3) *
		(isBossLoot and 5 or 1) *
		(1 + math.random() * 0.4 - 0.2)
	)

	-- Gold drop visual
	local goldPart = Instance.new("Part")
	goldPart.Name = "GoldDrop"
	goldPart.Size = Vector3.new(1, 1, 1)
	goldPart.Position = position + Vector3.new(math.random(-2, 2), 1, math.random(-2, 2))
	goldPart.Material = Enum.Material.Neon
	goldPart.Color = Color3.fromRGB(255, 215, 0)
	goldPart.Shape = Enum.PartType.Cylinder
	goldPart.Anchored = true
	goldPart.CanCollide = false
	goldPart.Parent = workspace

	local goldPrompt = Instance.new("ProximityPrompt")
	goldPrompt.ActionText = "Pick up " .. goldAmount .. " Gold"
	goldPrompt.HoldDuration = 0.1
	goldPrompt.MaxActivationDistance = 12
	goldPrompt.Parent = goldPart

	local goldPickedUp = false
	goldPrompt.Triggered:Connect(function(player)
		if goldPickedUp then return end
		goldPickedUp = true
		PlayerDataManager:AddGold(player, goldAmount)
		goldPart:Destroy()
	end)

	task.delay(45, function()
		if not goldPickedUp and goldPart then
			goldPart:Destroy()
		end
	end)
end

function LootSystem:OpenChest(player, chest)
	if not chest then return end

	local opened = chest:FindFirstChild("Opened")
	if opened and opened.Value then return end

	if opened then opened.Value = true end

	local floorVal = chest:FindFirstChild("FloorNumber")
	local floor = floorVal and floorVal.Value or self.CurrentFloor

	-- Generate 1-3 items
	local numItems = math.random(1, 3)
	for i = 1, numItems do
		local itemInstance, template = generateItem(floor, nil, false)
		local success = PlayerDataManager:AddToInventory(player, itemInstance)
		if success then
			remoteEvents.LootPickedUp:FireClient(player, itemInstance)
		end
	end

	-- Gold
	local goldAmount = math.floor(Config.Loot.GoldDropBase * (1 + floor * 0.5) * math.random(2, 5))
	PlayerDataManager:AddGold(player, goldAmount)

	remoteEvents.ChestOpened:FireAllClients(chest.Position)

	-- Visual change
	chest.BrickColor = BrickColor.new("Medium stone grey")
	local hl = chest:FindFirstChild("Highlight")
	if hl then hl:Destroy() end
	local pp = chest:FindFirstChild("ProximityPrompt")
	if pp then pp:Destroy() end
end

function LootSystem:Init(playerDataMgr)
	PlayerDataManager = playerDataMgr

	-- Listen for chest interactions
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") and desc.Parent and desc.Parent.Name == "LootChest" then
			desc.Triggered:Connect(function(player)
				self:OpenChest(player, desc.Parent)
			end)
		end
	end)

	print("[LootSystem] Initialized.")
end

return LootSystem
