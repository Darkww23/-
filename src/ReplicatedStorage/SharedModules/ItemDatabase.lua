--[[
	ItemDatabase.lua
	Definitions for all items (weapons, armor, consumables, etc.)
	Place in: ReplicatedStorage/SharedModules/ItemDatabase
]]

local ItemDatabase = {}

-- ========== ITEM TEMPLATES ==========
-- Each item has: Name, Type, Slot, Rarity (override), BaseStats, Description, LevelReq

ItemDatabase.Weapons = {
	{
		Id = "sword_iron", Name = "Iron Sword", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 8}, LevelReq = 1,
		Description = "A sturdy iron blade. Reliable in close quarters.",
		MeshId = "rbxassetid://0",
	},
	{
		Id = "sword_flame", Name = "Flamebrand", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 15, CritChance = 0.05}, LevelReq = 8, ForceRarity = "Rare",
		Description = "A sword wreathed in eternal flame. Burns foes on contact.",
		SpecialEffect = "BurnOnHit",
		BurnDamage = 5, BurnDuration = 3,
	},
	{
		Id = "sword_void", Name = "Voidreaver", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 30, CritChance = 0.12, CritMult = 0.3}, LevelReq = 25, ForceRarity = "Legendary",
		Description = "Forged in the abyss. Each strike tears at the fabric of reality.",
		SpecialEffect = "LifeStealOnCrit",
		LifeStealRatio = 0.15,
	},
	{
		Id = "staff_apprentice", Name = "Apprentice Staff", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 5, Mana = 20}, LevelReq = 1,
		Description = "A basic staff imbued with minor arcane energy.",
	},
	{
		Id = "staff_storm", Name = "Stormcaller", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 22, Mana = 50, CritChance = 0.08}, LevelReq = 18, ForceRarity = "Epic",
		Description = "Lightning crackles along its length. Calls upon tempest power.",
		SpecialEffect = "ChainLightning",
		ChainTargets = 3, ChainDamageDecay = 0.7,
	},
	{
		Id = "dagger_shadow", Name = "Shadow Fang", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 12, CritChance = 0.15, Speed = 4}, LevelReq = 10, ForceRarity = "Uncommon",
		Description = "A dagger that bends shadows. Strikes with blinding speed.",
	},
	{
		Id = "bow_hunter", Name = "Hunter's Longbow", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 11, CritChance = 0.08}, LevelReq = 5,
		Description = "A well-crafted longbow. Precise at range.",
		IsRanged = true, Range = 60,
	},
	{
		Id = "bow_phoenix", Name = "Phoenix Bow", Type = "Weapon", Slot = "MainHand",
		BaseStats = {Attack = 28, CritChance = 0.10, CritMult = 0.5}, LevelReq = 30, ForceRarity = "Legendary",
		Description = "Arrows ignite mid-flight. Said to be crafted from a phoenix feather.",
		IsRanged = true, Range = 80,
		SpecialEffect = "ExplosiveArrows",
		ExplosionRadius = 10, ExplosionDamageRatio = 0.4,
	},
}

ItemDatabase.Armor = {
	{
		Id = "armor_leather", Name = "Leather Tunic", Type = "Armor", Slot = "Chest",
		BaseStats = {Defense = 5, Stamina = 10}, LevelReq = 1,
		Description = "Basic leather armor. Offers minimal protection.",
	},
	{
		Id = "armor_chainmail", Name = "Chainmail Hauberk", Type = "Armor", Slot = "Chest",
		BaseStats = {Defense = 12, Health = 20}, LevelReq = 8,
		Description = "Interlocking rings of steel. Decent protection against slashes.",
	},
	{
		Id = "armor_plate", Name = "Dragonscale Plate", Type = "Armor", Slot = "Chest",
		BaseStats = {Defense = 30, Health = 80, Stamina = 20}, LevelReq = 25, ForceRarity = "Legendary",
		Description = "Forged from the scales of an ancient dragon. Nearly impervious.",
		SpecialEffect = "FireResistance",
		FireResist = 0.5,
	},
	{
		Id = "helm_iron", Name = "Iron Helm", Type = "Armor", Slot = "Head",
		BaseStats = {Defense = 3}, LevelReq = 1,
		Description = "A plain iron helmet.",
	},
	{
		Id = "helm_crown", Name = "Crown of the Undying", Type = "Armor", Slot = "Head",
		BaseStats = {Defense = 15, Health = 50, Mana = 30}, LevelReq = 20, ForceRarity = "Epic",
		Description = "A cursed crown that refuses to let its wearer die easily.",
		SpecialEffect = "ReviveOnDeath",
		ReviveHealthRatio = 0.3, ReviveCooldown = 120,
	},
	{
		Id = "boots_leather", Name = "Leather Boots", Type = "Armor", Slot = "Feet",
		BaseStats = {Defense = 2, Speed = 2}, LevelReq = 1,
		Description = "Simple boots for dungeon exploration.",
	},
	{
		Id = "boots_wind", Name = "Windstrider Greaves", Type = "Armor", Slot = "Feet",
		BaseStats = {Defense = 8, Speed = 8, Stamina = 15}, LevelReq = 15, ForceRarity = "Rare",
		Description = "Enchanted with wind magic. The wearer moves like a gale.",
		SpecialEffect = "DoubleJump",
	},
	{
		Id = "shield_wooden", Name = "Wooden Shield", Type = "Armor", Slot = "OffHand",
		BaseStats = {Defense = 7}, LevelReq = 1,
		Description = "A simple wooden shield. Better than nothing.",
		BlockChance = 0.15, BlockReduction = 0.5,
	},
	{
		Id = "shield_aegis", Name = "Aegis of the Ancients", Type = "Armor", Slot = "OffHand",
		BaseStats = {Defense = 25, Health = 40}, LevelReq = 22, ForceRarity = "Epic",
		Description = "An ancient shield that absorbs incoming magic.",
		BlockChance = 0.30, BlockReduction = 0.7,
		SpecialEffect = "MagicReflect",
		ReflectChance = 0.2, ReflectDamageRatio = 0.5,
	},
}

ItemDatabase.Consumables = {
	{
		Id = "potion_health_small", Name = "Small Health Potion", Type = "Consumable",
		Effect = "Heal", Value = 30, Stackable = true, MaxStack = 20,
		Description = "Restores 30 health.",
	},
	{
		Id = "potion_health_large", Name = "Large Health Potion", Type = "Consumable",
		Effect = "Heal", Value = 80, Stackable = true, MaxStack = 10,
		Description = "Restores 80 health.",
	},
	{
		Id = "potion_mana", Name = "Mana Elixir", Type = "Consumable",
		Effect = "RestoreMana", Value = 40, Stackable = true, MaxStack = 15,
		Description = "Restores 40 mana.",
	},
	{
		Id = "potion_strength", Name = "Strength Tonic", Type = "Consumable",
		Effect = "BuffAttack", Value = 0.3, Duration = 30, Stackable = true, MaxStack = 5,
		Description = "Increases attack by 30% for 30 seconds.",
	},
	{
		Id = "potion_speed", Name = "Swiftness Draught", Type = "Consumable",
		Effect = "BuffSpeed", Value = 0.5, Duration = 20, Stackable = true, MaxStack = 5,
		Description = "Increases movement speed by 50% for 20 seconds.",
	},
	{
		Id = "scroll_teleport", Name = "Scroll of Return", Type = "Consumable",
		Effect = "TeleportToSpawn", Stackable = true, MaxStack = 3,
		Description = "Instantly teleports you to the dungeon entrance.",
	},
	{
		Id = "bomb_fire", Name = "Fire Bomb", Type = "Consumable",
		Effect = "AoEDamage", Value = 40, Radius = 15, Stackable = true, MaxStack = 10,
		Description = "Deals 40 fire damage to all enemies in range.",
	},
}

ItemDatabase.Accessories = {
	{
		Id = "ring_health", Name = "Ring of Vitality", Type = "Accessory", Slot = "Ring",
		BaseStats = {Health = 30}, LevelReq = 5,
		Description = "A simple ring that bolsters the wearer's vitality.",
	},
	{
		Id = "ring_crit", Name = "Assassin's Signet", Type = "Accessory", Slot = "Ring",
		BaseStats = {CritChance = 0.10, CritMult = 0.3}, LevelReq = 12, ForceRarity = "Rare",
		Description = "A ring favored by assassins. Sharpens lethal precision.",
	},
	{
		Id = "amulet_mana", Name = "Arcane Pendant", Type = "Accessory", Slot = "Amulet",
		BaseStats = {Mana = 40, Attack = 5}, LevelReq = 7,
		Description = "An amulet that pulses with arcane energy.",
	},
	{
		Id = "amulet_undying", Name = "Amulet of the Undying", Type = "Accessory", Slot = "Amulet",
		BaseStats = {Health = 60, Defense = 10, Mana = 20}, LevelReq = 28, ForceRarity = "Legendary",
		Description = "Grants the wearer a second chance at life once per dungeon floor.",
		SpecialEffect = "AutoRevive",
		ReviveHealthRatio = 0.5,
	},
}

-- ========== UTILITY ==========
function ItemDatabase:GetAllItems()
	local all = {}
	for _, list in pairs({self.Weapons, self.Armor, self.Consumables, self.Accessories}) do
		for _, item in ipairs(list) do
			table.insert(all, item)
		end
	end
	return all
end

function ItemDatabase:GetItemById(id)
	for _, item in ipairs(self:GetAllItems()) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function ItemDatabase:GetItemsByType(itemType)
	local results = {}
	for _, item in ipairs(self:GetAllItems()) do
		if item.Type == itemType then
			table.insert(results, item)
		end
	end
	return results
end

function ItemDatabase:GetItemsByMaxLevel(maxLevel)
	local results = {}
	for _, item in ipairs(self:GetAllItems()) do
		if (item.LevelReq or 1) <= maxLevel then
			table.insert(results, item)
		end
	end
	return results
end

return ItemDatabase
