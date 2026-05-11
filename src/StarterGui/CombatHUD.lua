--[[
	CombatHUD.lua
	Client-side HUD: health/mana/stamina bars, XP bar, ability hotbar,
	floating damage numbers, buff indicators, minimap, and boss health bar.
	Place in: StarterGui/CombatHUD (LocalScript inside a ScreenGui)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== WAIT FOR REMOTES ==========
local function waitRemote(name)
	return ReplicatedStorage:WaitForChild(name, 10)
end

local PlayerStatsUpdated = waitRemote("PlayerStatsUpdated")
local PlayerLevelUp = waitRemote("PlayerLevelUp")
local DamageNumber = waitRemote("DamageNumber")
local XPGained = waitRemote("XPGained")
local GoldUpdated = waitRemote("GoldUpdated")
local FloorChanged = waitRemote("FloorChanged")
local EnemyDamaged = waitRemote("EnemyDamaged")
local EnemyDied = waitRemote("EnemyDied")
local EnemyAbilityUsed = waitRemote("EnemyAbilityUsed")
local BossPhaseChanged = waitRemote("BossPhaseChanged")
local StatusEffectApplied = waitRemote("StatusEffectApplied")
local StatusEffectRemoved = waitRemote("StatusEffectRemoved")
local PlayerAttack = waitRemote("PlayerAttack")
local PlayerUseAbility = waitRemote("PlayerUseAbility")
local CombatLog = waitRemote("CombatLog")
local DungeonInfo = waitRemote("DungeonInfo")
local LootPickedUp = waitRemote("LootPickedUp")

-- ========== GUI CREATION ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ===== HELPER FUNCTIONS =====
local function createFrame(parent, name, size, position, color, transparency)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or Color3.fromRGB(30, 30, 40)
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	return frame
end

local function createBar(parent, name, size, position, barColor, bgColor)
	local bg = createFrame(parent, name .. "BG", size, position, bgColor or Color3.fromRGB(20, 20, 25))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.ZIndex = 2
	label.Parent = bg

	return bg, fill, label
end

local function createTextLabel(parent, name, size, position, text, textColor, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
	return label
end

-- ===== MAIN HUD CONTAINER =====
local hudContainer = createFrame(screenGui, "HUDContainer",
	UDim2.new(0, 300, 0, 180),
	UDim2.new(0, 20, 1, -200),
	Color3.fromRGB(15, 15, 20), 0.3
)

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(80, 80, 120)
hudStroke.Thickness = 1
hudStroke.Parent = hudContainer

-- Level & name
local levelLabel = createTextLabel(hudContainer, "LevelLabel",
	UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 5),
	"Level 1 - Adventurer", Color3.fromRGB(255, 215, 0)
)
levelLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Health bar
local healthBG, healthFill, healthLabel = createBar(hudContainer, "Health",
	UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 30),
	Color3.fromRGB(200, 40, 40)
)

-- Mana bar
local manaBG, manaFill, manaLabel = createBar(hudContainer, "Mana",
	UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 58),
	Color3.fromRGB(40, 80, 200)
)

-- Stamina bar
local staminaBG, staminaFill, staminaLabel = createBar(hudContainer, "Stamina",
	UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 82),
	Color3.fromRGB(40, 180, 40)
)

-- XP bar
local xpBG, xpFill, xpLabel = createBar(hudContainer, "XP",
	UDim2.new(1, -20, 0, 10), UDim2.new(0, 10, 0, 102),
	Color3.fromRGB(180, 180, 40), Color3.fromRGB(40, 40, 20)
)

-- Gold display
local goldLabel = createTextLabel(hudContainer, "GoldLabel",
	UDim2.new(0.5, -10, 0, 20), UDim2.new(0, 5, 0, 118),
	"Gold: 0", Color3.fromRGB(255, 215, 0)
)
goldLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Floor display
local floorLabel = createTextLabel(hudContainer, "FloorLabel",
	UDim2.new(0.5, -10, 0, 20), UDim2.new(0.5, 5, 0, 118),
	"Floor: 1", Color3.fromRGB(200, 200, 255)
)
floorLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Stats display
local statsLabel = createTextLabel(hudContainer, "StatsLabel",
	UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 0, 142),
	"ATK: 10 | DEF: 5 | CRIT: 5%", Color3.fromRGB(180, 180, 180)
)
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextScaled = false
statsLabel.TextSize = 11

-- ===== ABILITY HOTBAR =====
local abilityBar = createFrame(screenGui, "AbilityBar",
	UDim2.new(0, 280, 0, 60),
	UDim2.new(0.5, -140, 1, -80),
	Color3.fromRGB(15, 15, 20), 0.4
)

local abilitySlots = {}
local abilityKeys = {"Q", "E", "R", "T"}

for i = 1, 4 do
	local slot = createFrame(abilityBar, "Slot" .. i,
		UDim2.new(0, 55, 0, 50),
		UDim2.new(0, 10 + (i - 1) * 65, 0, 5),
		Color3.fromRGB(40, 40, 55)
	)

	local keyLabel = createTextLabel(slot, "KeyLabel",
		UDim2.new(0, 20, 0, 14), UDim2.new(0, 2, 0, 2),
		abilityKeys[i], Color3.fromRGB(200, 200, 200)
	)
	keyLabel.TextScaled = false
	keyLabel.TextSize = 10

	local nameLabel = createTextLabel(slot, "AbilityName",
		UDim2.new(1, -4, 0, 16), UDim2.new(0, 2, 0.5, -2),
		"---", Color3.fromRGB(255, 255, 255)
	)
	nameLabel.TextScaled = false
	nameLabel.TextSize = 9

	local cdOverlay = createFrame(slot, "CooldownOverlay",
		UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 1, 0),
		Color3.fromRGB(0, 0, 0), 0.6
	)
	cdOverlay.Visible = false

	local cdLabel = createTextLabel(slot, "CooldownLabel",
		UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		"", Color3.fromRGB(255, 100, 100)
	)

	abilitySlots[i] = {
		Frame = slot,
		NameLabel = nameLabel,
		CooldownOverlay = cdOverlay,
		CooldownLabel = cdLabel,
		AbilityName = nil,
		CooldownEnd = 0,
	}
end

-- ===== BOSS HEALTH BAR =====
local bossBarContainer = createFrame(screenGui, "BossBar",
	UDim2.new(0, 500, 0, 45),
	UDim2.new(0.5, -250, 0, 20),
	Color3.fromRGB(15, 10, 10), 0.2
)
bossBarContainer.Visible = false

local bossStroke = Instance.new("UIStroke")
bossStroke.Color = Color3.fromRGB(200, 50, 50)
bossStroke.Thickness = 2
bossStroke.Parent = bossBarContainer

local bossNameLabel = createTextLabel(bossBarContainer, "BossName",
	UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 2),
	"BOSS", Color3.fromRGB(255, 80, 80)
)

local bossBG, bossFill, bossHPLabel = createBar(bossBarContainer, "BossHP",
	UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 22),
	Color3.fromRGB(200, 30, 30)
)

-- ===== COMBAT LOG =====
local logContainer = createFrame(screenGui, "CombatLog",
	UDim2.new(0, 300, 0, 150),
	UDim2.new(1, -320, 1, -170),
	Color3.fromRGB(10, 10, 15), 0.5
)

local logScroll = Instance.new("ScrollingFrame")
logScroll.Name = "LogScroll"
logScroll.Size = UDim2.new(1, -10, 1, -10)
logScroll.Position = UDim2.new(0, 5, 0, 5)
logScroll.BackgroundTransparency = 1
logScroll.ScrollBarThickness = 3
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = logContainer

local logLayout = Instance.new("UIListLayout")
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logScroll

local logCount = 0
local MAX_LOG_ENTRIES = 30

local function addLogEntry(text, color)
	logCount = logCount + 1
	local entry = Instance.new("TextLabel")
	entry.Name = "Log_" .. logCount
	entry.Size = UDim2.new(1, 0, 0, 14)
	entry.BackgroundTransparency = 1
	entry.Text = text
	entry.TextColor3 = color or Color3.fromRGB(200, 200, 200)
	entry.TextScaled = false
	entry.TextSize = 11
	entry.Font = Enum.Font.Gotham
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.LayoutOrder = logCount
	entry.Parent = logScroll

	-- Remove old entries
	local children = logScroll:GetChildren()
	local labels = {}
	for _, child in ipairs(children) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > MAX_LOG_ENTRIES then
		labels[1]:Destroy()
	end

	logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
end

-- ===== BUFF INDICATORS =====
local buffContainer = createFrame(screenGui, "BuffContainer",
	UDim2.new(0, 200, 0, 30),
	UDim2.new(0, 20, 1, -220),
	Color3.fromRGB(0, 0, 0), 1
)

local buffLayout = Instance.new("UIListLayout")
buffLayout.FillDirection = Enum.FillDirection.Horizontal
buffLayout.Padding = UDim.new(0, 4)
buffLayout.Parent = buffContainer

local activeBuffs = {}

-- ===== NOTIFICATION POPUP =====
local function showNotification(text, color, duration)
	duration = duration or 3

	local notif = createFrame(screenGui, "Notification",
		UDim2.new(0, 400, 0, 40),
		UDim2.new(0.5, -200, 0.3, 0),
		Color3.fromRGB(20, 20, 30), 0.2
	)

	local notifStroke = Instance.new("UIStroke")
	notifStroke.Color = color or Color3.fromRGB(255, 215, 0)
	notifStroke.Thickness = 1
	notifStroke.Parent = notif

	local notifLabel = createTextLabel(notif, "Text",
		UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		text, color or Color3.fromRGB(255, 215, 0)
	)

	-- Animate
	notif.Position = UDim2.new(0.5, -200, 0.3, -30)
	TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -200, 0.3, 0)
	}):Play()

	task.delay(duration, function()
		TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, -200, 0.3, -50),
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.5)
		notif:Destroy()
	end)
end

-- ===== FLOATING DAMAGE NUMBERS =====
local function showDamageNumber(worldPosition, amount, isCrit, damageType)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local screenPos, onScreen = camera:WorldToScreenPoint(worldPosition)
	if not onScreen then return end

	local color = Color3.fromRGB(255, 255, 255)
	local size = 18

	if damageType == "Heal" then
		color = Config.Visual.HealColor
	elseif damageType == "Shield" then
		color = Config.Visual.ShieldColor
	elseif damageType == "Poison" or damageType == "DoT" then
		color = Color3.fromRGB(100, 200, 50)
	elseif damageType == "Lightning" then
		color = Color3.fromRGB(100, 150, 255)
	elseif damageType == "Shadow" then
		color = Color3.fromRGB(150, 50, 200)
	elseif damageType == "EnemyPhysical" or damageType == "EnemyMagic" then
		color = Color3.fromRGB(255, 100, 100)
	end

	if isCrit then
		color = Config.Visual.CritColor
		size = 26
	end

	local dmgLabel = Instance.new("TextLabel")
	dmgLabel.Name = "DmgNum"
	dmgLabel.Size = UDim2.new(0, 100, 0, 30)
	dmgLabel.Position = UDim2.new(0, screenPos.X - 50 + math.random(-20, 20), 0, screenPos.Y - 15)
	dmgLabel.BackgroundTransparency = 1
	dmgLabel.Text = (isCrit and "CRIT! " or "") .. tostring(math.floor(amount))
	dmgLabel.TextColor3 = color
	dmgLabel.TextSize = size
	dmgLabel.Font = Enum.Font.GothamBold
	dmgLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	dmgLabel.TextStrokeTransparency = 0.3
	dmgLabel.Parent = screenGui

	-- Animate upward and fade
	local startPos = dmgLabel.Position
	TweenService:Create(dmgLabel, TweenInfo.new(Config.Visual.DamageNumberDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = startPos + UDim2.new(0, 0, 0, -60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(Config.Visual.DamageNumberDuration, function()
		dmgLabel:Destroy()
	end)
end

-- ===== INPUT HANDLING =====
local keybinds = {
	[Enum.KeyCode.Q] = 1,
	[Enum.KeyCode.E] = 2,
	[Enum.KeyCode.R] = 3,
	[Enum.KeyCode.T] = 4,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		PlayerAttack:FireServer()
	end

	if input.KeyCode and keybinds[input.KeyCode] then
		local slot = keybinds[input.KeyCode]
		if abilitySlots[slot].AbilityName and tick() >= abilitySlots[slot].CooldownEnd then
			PlayerUseAbility:FireServer(slot)
		end
	end
end)

-- ===== STAT UPDATE HANDLER =====
local currentStats = {}

local function updateHUD(data)
	currentStats = data

	levelLabel.Text = "Level " .. data.Level .. " - Adventurer"

	-- Health
	local healthPct = data.CurrentHealth / data.Stats.MaxHealth
	TweenService:Create(healthFill, TweenInfo.new(0.3), {
		Size = UDim2.new(math.clamp(healthPct, 0, 1), 0, 1, 0)
	}):Play()
	healthLabel.Text = math.floor(data.CurrentHealth) .. " / " .. data.Stats.MaxHealth

	-- Mana
	local manaPct = data.CurrentMana / data.Stats.MaxMana
	TweenService:Create(manaFill, TweenInfo.new(0.3), {
		Size = UDim2.new(math.clamp(manaPct, 0, 1), 0, 1, 0)
	}):Play()
	manaLabel.Text = math.floor(data.CurrentMana) .. " / " .. data.Stats.MaxMana

	-- Stamina
	local staminaPct = data.CurrentStamina / data.Stats.MaxStamina
	TweenService:Create(staminaFill, TweenInfo.new(0.3), {
		Size = UDim2.new(math.clamp(staminaPct, 0, 1), 0, 1, 0)
	}):Play()
	staminaLabel.Text = math.floor(data.CurrentStamina) .. " / " .. data.Stats.MaxStamina

	-- XP
	local xpPct = data.XP / data.XPToNext
	TweenService:Create(xpFill, TweenInfo.new(0.3), {
		Size = UDim2.new(math.clamp(xpPct, 0, 1), 0, 1, 0)
	}):Play()
	xpLabel.Text = data.XP .. " / " .. data.XPToNext .. " XP"

	-- Gold
	goldLabel.Text = "Gold: " .. data.Gold

	-- Stats
	statsLabel.Text = string.format(
		"ATK: %d | DEF: %d | CRIT: %.0f%% | SPD: %d",
		data.Stats.Attack, data.Stats.Defense,
		data.Stats.CritChance * 100, data.Stats.Speed
	)
end

-- ===== EVENT CONNECTIONS =====
if PlayerStatsUpdated then
	PlayerStatsUpdated.OnClientEvent:Connect(updateHUD)
end

if PlayerLevelUp then
	PlayerLevelUp.OnClientEvent:Connect(function(newLevel, newStats)
		showNotification(
			"LEVEL UP! You are now Level " .. newLevel .. "!",
			Color3.fromRGB(255, 215, 0), 4
		)
		addLogEntry("Leveled up to " .. newLevel .. "!", Color3.fromRGB(255, 215, 0))
	end)
end

if DamageNumber then
	DamageNumber.OnClientEvent:Connect(showDamageNumber)
end

if XPGained then
	XPGained.OnClientEvent:Connect(function(amount)
		addLogEntry("+" .. amount .. " XP", Config.Visual.XPColor)
	end)
end

if GoldUpdated then
	GoldUpdated.OnClientEvent:Connect(function(total, gained)
		goldLabel.Text = "Gold: " .. total
		if gained > 0 then
			addLogEntry("+" .. gained .. " Gold", Color3.fromRGB(255, 215, 0))
		end
	end)
end

if FloorChanged then
	FloorChanged.OnClientEvent:Connect(function(floor)
		floorLabel.Text = "Floor: " .. floor
		showNotification("Entering Floor " .. floor, Color3.fromRGB(100, 200, 255), 3)
		addLogEntry("=== Floor " .. floor .. " ===", Color3.fromRGB(100, 200, 255))
	end)
end

if CombatLog then
	CombatLog.OnClientEvent:Connect(function(text)
		addLogEntry(text)
	end)
end

if BossPhaseChanged then
	BossPhaseChanged.OnClientEvent:Connect(function(enemyId, phase, totalPhases)
		showNotification(
			"BOSS PHASE " .. phase .. "/" .. totalPhases .. " - Enraged!",
			Color3.fromRGB(255, 50, 50), 4
		)
		addLogEntry("Boss entered phase " .. phase .. "!", Color3.fromRGB(255, 50, 50))
	end)
end

if StatusEffectApplied then
	StatusEffectApplied.OnClientEvent:Connect(function(effectType, duration)
		local buffFrame = createFrame(buffContainer, effectType,
			UDim2.new(0, 26, 0, 26), UDim2.new(0, 0, 0, 0),
			Color3.fromRGB(60, 60, 80)
		)
		local buffLabel = createTextLabel(buffFrame, "Icon",
			UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
			effectType:sub(1, 2):upper(), Color3.fromRGB(255, 150, 150)
		)
		activeBuffs[effectType] = buffFrame

		addLogEntry("Status: " .. effectType .. " (" .. duration .. "s)", Color3.fromRGB(255, 150, 150))
	end)
end

if StatusEffectRemoved then
	StatusEffectRemoved.OnClientEvent:Connect(function(effectType)
		if activeBuffs[effectType] then
			activeBuffs[effectType]:Destroy()
			activeBuffs[effectType] = nil
		end
	end)
end

if LootPickedUp then
	LootPickedUp.OnClientEvent:Connect(function(itemInstance)
		local rarityColors = {
			Common = Color3.fromRGB(180, 180, 180),
			Uncommon = Color3.fromRGB(30, 200, 30),
			Rare = Color3.fromRGB(30, 100, 255),
			Epic = Color3.fromRGB(160, 30, 200),
			Legendary = Color3.fromRGB(255, 165, 0),
		}
		local color = rarityColors[itemInstance.Rarity] or Color3.fromRGB(180, 180, 180)
		showNotification(
			"Obtained: " .. itemInstance.Name .. " [" .. (itemInstance.Rarity or "Common") .. "]",
			color, 3
		)
		addLogEntry("Picked up: " .. itemInstance.Name, color)
	end)
end

if DungeonInfo then
	DungeonInfo.OnClientEvent:Connect(function(info)
		addLogEntry(string.format(
			"Floor %d: %d rooms, %d enemies%s",
			info.FloorNumber, info.RoomCount, info.EnemyCount,
			info.HasBoss and " [BOSS]" or ""
		), Color3.fromRGB(150, 200, 255))
	end)
end

-- ===== ABILITY COOLDOWN DISPLAY =====
RunService.Heartbeat:Connect(function()
	local now = tick()
	for i, slot in ipairs(abilitySlots) do
		if slot.CooldownEnd > now then
			local remaining = slot.CooldownEnd - now
			slot.CooldownLabel.Text = string.format("%.1f", remaining)
			slot.CooldownOverlay.Visible = true
		else
			slot.CooldownLabel.Text = ""
			slot.CooldownOverlay.Visible = false
		end
	end
end)

-- ===== ATTACK INDICATOR =====
local crosshair = Instance.new("TextLabel")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.Position = UDim2.new(0.5, -10, 0.5, -10)
crosshair.BackgroundTransparency = 1
crosshair.Text = "+"
crosshair.TextColor3 = Color3.fromRGB(255, 255, 255)
crosshair.TextSize = 20
crosshair.Font = Enum.Font.GothamBold
crosshair.TextStrokeTransparency = 0.5
crosshair.Parent = screenGui

print("[CombatHUD] Initialized.")
