--[[
	Config.lua
	Shared configuration for the RPG Dungeon System.
	Place in: ReplicatedStorage/SharedModules/Config
]]

local Config = {}

-- ========== DUNGEON GENERATION ==========
Config.Dungeon = {
	MinRooms        = 8,
	MaxRooms        = 18,
	RoomMinSize     = Vector3.new(20, 12, 20),
	RoomMaxSize     = Vector3.new(50, 16, 50),
	CorridorWidth   = 8,
	WallThickness   = 2,
	FloorMaterial   = Enum.Material.Slate,
	WallMaterial    = Enum.Material.Cobblestone,
	CeilingMaterial = Enum.Material.Slate,
	TorchSpacing    = 15,
	TrapChance      = 0.15,
	SecretRoomChance = 0.10,
	BossRoomMinFloor = 3,
}

-- ========== PLAYER STATS ==========
Config.Player = {
	BaseHealth      = 100,
	BaseMana        = 50,
	BaseStamina     = 80,
	BaseAttack      = 10,
	BaseDefense     = 5,
	BaseCritChance  = 0.05,
	BaseCritMult    = 1.5,
	BaseSpeed       = 16,
	XPPerLevel      = function(level)
		return math.floor(100 * (level ^ 1.5))
	end,
	StatsPerLevel = {
		Health  = 15,
		Mana    = 8,
		Stamina = 5,
		Attack  = 3,
		Defense = 2,
	},
	MaxLevel = 50,
	RespawnTime = 5,
	ManaRegenRate = 2,
	StaminaRegenRate = 5,
}

-- ========== ENEMY CONFIG ==========
Config.Enemy = {
	Types = {
		Skeleton = {
			Health = 60, Attack = 8, Defense = 3, Speed = 12,
			XPReward = 25, DetectRange = 40, AttackRange = 5,
			AttackCooldown = 1.2, Color = Color3.fromRGB(200, 200, 180),
			Scale = 1.0, Abilities = {"SlashCombo"},
		},
		DarkMage = {
			Health = 45, Attack = 14, Defense = 2, Speed = 10,
			XPReward = 35, DetectRange = 50, AttackRange = 30,
			AttackCooldown = 2.0, Color = Color3.fromRGB(80, 20, 120),
			Scale = 1.1, Abilities = {"Fireball", "DarkPulse"},
		},
		Golem = {
			Health = 200, Attack = 20, Defense = 12, Speed = 6,
			XPReward = 60, DetectRange = 30, AttackRange = 8,
			AttackCooldown = 2.5, Color = Color3.fromRGB(100, 100, 100),
			Scale = 1.8, Abilities = {"GroundSlam", "RockThrow"},
		},
		Spider = {
			Health = 35, Attack = 12, Defense = 1, Speed = 20,
			XPReward = 20, DetectRange = 35, AttackRange = 4,
			AttackCooldown = 0.8, Color = Color3.fromRGB(30, 30, 30),
			Scale = 0.7, Abilities = {"PoisonBite", "WebShot"},
		},
		Wraith = {
			Health = 80, Attack = 16, Defense = 0, Speed = 14,
			XPReward = 45, DetectRange = 45, AttackRange = 6,
			AttackCooldown = 1.5, Color = Color3.fromRGB(40, 40, 60),
			Scale = 1.2, Abilities = {"LifeDrain", "PhaseStrike"},
		},
	},
	Boss = {
		DragonLord = {
			Health = 1500, Attack = 35, Defense = 20, Speed = 8,
			XPReward = 500, DetectRange = 80, AttackRange = 15,
			AttackCooldown = 1.8, Color = Color3.fromRGB(180, 30, 30),
			Scale = 3.0,
			Abilities = {"FireBreath", "TailSwipe", "WingGust", "SummonMinions"},
			Phases = {
				{HealthThreshold = 1.0, SpeedMult = 1.0, DamageMult = 1.0},
				{HealthThreshold = 0.6, SpeedMult = 1.3, DamageMult = 1.4},
				{HealthThreshold = 0.3, SpeedMult = 1.6, DamageMult = 1.8},
			},
		},
		LichKing = {
			Health = 1200, Attack = 40, Defense = 10, Speed = 10,
			XPReward = 500, DetectRange = 70, AttackRange = 40,
			AttackCooldown = 1.5, Color = Color3.fromRGB(0, 200, 80),
			Scale = 2.5,
			Abilities = {"NecroBlast", "SummonUndead", "DeathField", "SoulHarvest"},
			Phases = {
				{HealthThreshold = 1.0, SpeedMult = 1.0, DamageMult = 1.0},
				{HealthThreshold = 0.5, SpeedMult = 1.2, DamageMult = 1.5},
				{HealthThreshold = 0.2, SpeedMult = 1.5, DamageMult = 2.0},
			},
		},
	},
	ScalingPerFloor = {
		HealthMult  = 0.25,
		AttackMult  = 0.15,
		DefenseMult = 0.10,
		XPMult      = 0.20,
	},
}

-- ========== ABILITIES ==========
Config.Abilities = {
	-- Player abilities
	PowerStrike   = {ManaCost = 10, Cooldown = 3,  DamageMult = 2.0, Type = "Melee",  Range = 6},
	Whirlwind     = {ManaCost = 20, Cooldown = 8,  DamageMult = 1.5, Type = "AoE",    Range = 12},
	Fireball      = {ManaCost = 15, Cooldown = 4,  DamageMult = 1.8, Type = "Ranged",  Range = 50},
	HealingSurge  = {ManaCost = 25, Cooldown = 12, HealMult = 0.3,   Type = "Self"},
	DashStrike    = {ManaCost = 12, Cooldown = 5,  DamageMult = 1.6, Type = "Dash",    Range = 20},
	IceBarrier    = {ManaCost = 30, Cooldown = 20, ShieldMult = 0.4, Type = "Shield",  Duration = 8},
	ThunderClap   = {ManaCost = 35, Cooldown = 15, DamageMult = 2.5, Type = "AoE",     Range = 18},
	ShadowStep    = {ManaCost = 8,  Cooldown = 6,  DamageMult = 1.3, Type = "Teleport", Range = 30},

	-- Enemy abilities
	SlashCombo    = {Cooldown = 3,  DamageMult = 1.4, Type = "Melee",  Range = 6},
	DarkPulse     = {Cooldown = 5,  DamageMult = 1.6, Type = "AoE",    Range = 15},
	GroundSlam    = {Cooldown = 6,  DamageMult = 2.0, Type = "AoE",    Range = 12},
	RockThrow     = {Cooldown = 4,  DamageMult = 1.5, Type = "Ranged", Range = 40},
	PoisonBite    = {Cooldown = 2,  DamageMult = 0.8, Type = "DoT",    Range = 4, Duration = 5, TickDamage = 3},
	WebShot       = {Cooldown = 7,  DamageMult = 0.3, Type = "Slow",   Range = 25, Duration = 3, SlowMult = 0.4},
	LifeDrain     = {Cooldown = 5,  DamageMult = 1.2, Type = "Drain",  Range = 8, HealRatio = 0.5},
	PhaseStrike   = {Cooldown = 4,  DamageMult = 1.8, Type = "Teleport", Range = 20},
	FireBreath    = {Cooldown = 8,  DamageMult = 2.5, Type = "Cone",   Range = 25, Angle = 60},
	TailSwipe     = {Cooldown = 4,  DamageMult = 1.8, Type = "AoE",    Range = 15},
	WingGust      = {Cooldown = 10, DamageMult = 0.5, Type = "Knockback", Range = 20, Force = 80},
	SummonMinions = {Cooldown = 20, Type = "Summon", Count = 3, MinionType = "Skeleton"},
	NecroBlast    = {Cooldown = 3,  DamageMult = 2.0, Type = "Ranged", Range = 45},
	SummonUndead  = {Cooldown = 15, Type = "Summon", Count = 5, MinionType = "Skeleton"},
	DeathField    = {Cooldown = 12, DamageMult = 1.5, Type = "AoE",    Range = 25, Duration = 4, TickDamage = 8},
	SoulHarvest   = {Cooldown = 25, DamageMult = 3.0, Type = "Channel", Range = 30, Duration = 3},
}

-- ========== LOOT ==========
Config.Loot = {
	Rarities = {
		Common    = {Color = Color3.fromRGB(180, 180, 180), DropWeight = 50, StatMult = 1.0},
		Uncommon  = {Color = Color3.fromRGB(30, 200, 30),   DropWeight = 30, StatMult = 1.3},
		Rare      = {Color = Color3.fromRGB(30, 100, 255),  DropWeight = 14, StatMult = 1.7},
		Epic      = {Color = Color3.fromRGB(160, 30, 200),  DropWeight = 5,  StatMult = 2.2},
		Legendary = {Color = Color3.fromRGB(255, 165, 0),   DropWeight = 1,  StatMult = 3.0},
	},
	GoldDropBase = 10,
	GoldDropVariance = 0.3,
	DropChance = 0.4,
	MaxInventorySlots = 30,
}

-- ========== TRAPS ==========
Config.Traps = {
	SpikeTrap    = {Damage = 20, Cooldown = 3, TriggerRadius = 4},
	FireTrap     = {Damage = 15, Cooldown = 2, TriggerRadius = 5, Duration = 3, TickDamage = 5},
	PoisonGas    = {Damage = 5,  Cooldown = 1, TriggerRadius = 8, Duration = 6, TickDamage = 3},
	ArrowTrap    = {Damage = 25, Cooldown = 4, TriggerRadius = 3},
	BoulderTrap  = {Damage = 50, Cooldown = 15, TriggerRadius = 6},
}

-- ========== VISUAL & AUDIO ==========
Config.Visual = {
	DamageNumberDuration = 1.5,
	DamageNumberRiseSpeed = 3,
	CritColor    = Color3.fromRGB(255, 50, 50),
	HealColor    = Color3.fromRGB(50, 255, 50),
	ShieldColor  = Color3.fromRGB(50, 150, 255),
	XPColor      = Color3.fromRGB(255, 255, 50),
	LevelUpParticleCount = 50,
	HitFlashDuration = 0.15,
}

return Config
