--[[
	InventoryUI.lua
	Client-side inventory screen with equipment slots, item grid, tooltips,
	drag-and-drop equipping, and item context menus.
	Place in: StarterGui/InventoryUI (LocalScript inside a ScreenGui)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Config"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("ItemDatabase"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== REMOTES ==========
local InventoryUpdated = ReplicatedStorage:WaitForChild("InventoryUpdated", 10)
local EquipItem = ReplicatedStorage:WaitForChild("EquipItem", 10)
local UnequipItem = ReplicatedStorage:WaitForChild("UnequipItem", 10)
local UseConsumable = ReplicatedStorage:WaitForChild("UseConsumable", 10)
local DropItem = ReplicatedStorage:WaitForChild("DropItem", 10)
local PlayerStatsUpdated = ReplicatedStorage:WaitForChild("PlayerStatsUpdated", 10)

-- ========== STATE ==========
local inventoryOpen = false
local currentInventory = {}
local currentEquipment = {}
local selectedSlot = nil

-- ========== GUI CREATION ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

-- ===== HELPER =====
local function createFrame(parent, name, size, position, color, transparency)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or Color3.fromRGB(25, 25, 35)
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	return frame
end

-- ===== MAIN PANEL =====
local mainPanel = createFrame(screenGui, "MainPanel",
	UDim2.new(0, 700, 0, 500),
	UDim2.new(0.5, -350, 0.5, -250),
	Color3.fromRGB(18, 18, 25)
)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(80, 80, 120)
mainStroke.Thickness = 2
mainStroke.Parent = mainPanel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
titleLabel.BorderSizePixel = 0
titleLabel.Text = "INVENTORY"
titleLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainPanel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 6)
titleCorner.Parent = titleLabel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
	inventoryOpen = false
end)

-- ===== EQUIPMENT PANEL =====
local equipPanel = createFrame(mainPanel, "EquipmentPanel",
	UDim2.new(0, 200, 0, 440),
	UDim2.new(0, 10, 0, 45),
	Color3.fromRGB(22, 22, 32)
)

local equipTitle = Instance.new("TextLabel")
equipTitle.Size = UDim2.new(1, 0, 0, 25)
equipTitle.BackgroundTransparency = 1
equipTitle.Text = "Equipment"
equipTitle.TextColor3 = Color3.fromRGB(180, 180, 220)
equipTitle.TextSize = 14
equipTitle.Font = Enum.Font.GothamBold
equipTitle.Parent = equipPanel

local equipSlots = {}
local slotNames = {"Head", "Chest", "MainHand", "OffHand", "Feet", "Ring", "Amulet"}
local slotIcons = {
	Head = "H", Chest = "C", MainHand = "W", OffHand = "S",
	Feet = "B", Ring = "R", Amulet = "A"
}

for i, slotName in ipairs(slotNames) do
	local row = math.floor((i - 1) / 2)
	local col = (i - 1) % 2

	local slot = createFrame(equipPanel, "EquipSlot_" .. slotName,
		UDim2.new(0, 85, 0, 50),
		UDim2.new(0, 10 + col * 95, 0, 30 + row * 58),
		Color3.fromRGB(35, 35, 50)
	)

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = Color3.fromRGB(60, 60, 80)
	slotStroke.Thickness = 1
	slotStroke.Parent = slot

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 20, 0, 20)
	iconLabel.Position = UDim2.new(0, 3, 0, 3)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = slotIcons[slotName] or "?"
	iconLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
	iconLabel.TextSize = 10
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = slot

	local itemLabel = Instance.new("TextLabel")
	itemLabel.Name = "ItemName"
	itemLabel.Size = UDim2.new(1, -6, 0, 14)
	itemLabel.Position = UDim2.new(0, 3, 0, 22)
	itemLabel.BackgroundTransparency = 1
	itemLabel.Text = "Empty"
	itemLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	itemLabel.TextSize = 9
	itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
	itemLabel.Font = Enum.Font.Gotham
	itemLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemLabel.Parent = slot

	local slotLabel = Instance.new("TextLabel")
	slotLabel.Name = "SlotLabel"
	slotLabel.Size = UDim2.new(1, -6, 0, 10)
	slotLabel.Position = UDim2.new(0, 3, 1, -13)
	slotLabel.BackgroundTransparency = 1
	slotLabel.Text = slotName
	slotLabel.TextColor3 = Color3.fromRGB(80, 80, 100)
	slotLabel.TextSize = 8
	slotLabel.Font = Enum.Font.Gotham
	slotLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotLabel.Parent = slot

	-- Unequip on click
	local btn = Instance.new("TextButton")
	btn.Name = "ClickArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = slot

	btn.MouseButton1Click:Connect(function()
		if currentEquipment[slotName] then
			UnequipItem:FireServer(slotName)
		end
	end)

	equipSlots[slotName] = {
		Frame = slot,
		ItemLabel = itemLabel,
		Stroke = slotStroke,
	}
end

-- ===== INVENTORY GRID =====
local invPanel = createFrame(mainPanel, "InventoryGrid",
	UDim2.new(0, 460, 0, 440),
	UDim2.new(0, 225, 0, 45),
	Color3.fromRGB(22, 22, 32)
)

local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, 0, 0, 25)
invTitle.BackgroundTransparency = 1
invTitle.Text = "Items (0/" .. Config.Loot.MaxInventorySlots .. ")"
invTitle.TextColor3 = Color3.fromRGB(180, 180, 220)
invTitle.TextSize = 14
invTitle.Font = Enum.Font.GothamBold
invTitle.Parent = invPanel

local invScroll = Instance.new("ScrollingFrame")
invScroll.Name = "ItemScroll"
invScroll.Size = UDim2.new(1, -10, 1, -30)
invScroll.Position = UDim2.new(0, 5, 0, 28)
invScroll.BackgroundTransparency = 1
invScroll.ScrollBarThickness = 4
invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.Parent = invPanel

local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.new(0, 70, 0, 70)
invGrid.CellPadding = UDim2.new(0, 5, 0, 5)
invGrid.SortOrder = Enum.SortOrder.LayoutOrder
invGrid.Parent = invScroll

-- ===== TOOLTIP =====
local tooltip = createFrame(screenGui, "Tooltip",
	UDim2.new(0, 220, 0, 160),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(15, 15, 22)
)
tooltip.Visible = false
tooltip.ZIndex = 10

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = Color3.fromRGB(100, 100, 140)
tooltipStroke.Thickness = 1
tooltipStroke.Parent = tooltip

local tooltipName = Instance.new("TextLabel")
tooltipName.Name = "ItemName"
tooltipName.Size = UDim2.new(1, -10, 0, 20)
tooltipName.Position = UDim2.new(0, 5, 0, 5)
tooltipName.BackgroundTransparency = 1
tooltipName.TextColor3 = Color3.fromRGB(255, 255, 255)
tooltipName.TextSize = 13
tooltipName.Font = Enum.Font.GothamBold
tooltipName.TextXAlignment = Enum.TextXAlignment.Left
tooltipName.Parent = tooltip

local tooltipRarity = Instance.new("TextLabel")
tooltipRarity.Name = "Rarity"
tooltipRarity.Size = UDim2.new(1, -10, 0, 14)
tooltipRarity.Position = UDim2.new(0, 5, 0, 25)
tooltipRarity.BackgroundTransparency = 1
tooltipRarity.TextSize = 11
tooltipRarity.Font = Enum.Font.GothamBold
tooltipRarity.TextXAlignment = Enum.TextXAlignment.Left
tooltipRarity.Parent = tooltip

local tooltipStats = Instance.new("TextLabel")
tooltipStats.Name = "Stats"
tooltipStats.Size = UDim2.new(1, -10, 0, 80)
tooltipStats.Position = UDim2.new(0, 5, 0, 42)
tooltipStats.BackgroundTransparency = 1
tooltipStats.TextColor3 = Color3.fromRGB(150, 220, 150)
tooltipStats.TextSize = 11
tooltipStats.Font = Enum.Font.Gotham
tooltipStats.TextXAlignment = Enum.TextXAlignment.Left
tooltipStats.TextYAlignment = Enum.TextYAlignment.Top
tooltipStats.TextWrapped = true
tooltipStats.Parent = tooltip

local tooltipDesc = Instance.new("TextLabel")
tooltipDesc.Name = "Description"
tooltipDesc.Size = UDim2.new(1, -10, 0, 30)
tooltipDesc.Position = UDim2.new(0, 5, 1, -35)
tooltipDesc.BackgroundTransparency = 1
tooltipDesc.TextColor3 = Color3.fromRGB(150, 150, 170)
tooltipDesc.TextSize = 10
tooltipDesc.Font = Enum.Font.Gotham
tooltipDesc.TextXAlignment = Enum.TextXAlignment.Left
tooltipDesc.TextWrapped = true
tooltipDesc.Parent = tooltip

local function showTooltip(itemInstance, position)
	if not itemInstance then
		tooltip.Visible = false
		return
	end

	local template = ItemDatabase:GetItemById(itemInstance.Id)
	if not template then
		tooltip.Visible = false
		return
	end

	local rarityColors = {
		Common = Color3.fromRGB(180, 180, 180),
		Uncommon = Color3.fromRGB(30, 200, 30),
		Rare = Color3.fromRGB(30, 100, 255),
		Epic = Color3.fromRGB(160, 30, 200),
		Legendary = Color3.fromRGB(255, 165, 0),
	}

	tooltipName.Text = itemInstance.Name or template.Name
	tooltipName.TextColor3 = rarityColors[itemInstance.Rarity] or Color3.fromRGB(180, 180, 180)

	tooltipRarity.Text = "[" .. (itemInstance.Rarity or "Common") .. "]"
	tooltipRarity.TextColor3 = rarityColors[itemInstance.Rarity] or Color3.fromRGB(180, 180, 180)
	tooltipStroke.Color = rarityColors[itemInstance.Rarity] or Color3.fromRGB(100, 100, 140)

	local statsText = ""
	if itemInstance.Stats then
		for stat, value in pairs(itemInstance.Stats) do
			if stat == "CritChance" then
				statsText = statsText .. "+" .. string.format("%.1f%%", value * 100) .. " Crit Chance\n"
			elseif stat == "CritMult" then
				statsText = statsText .. "+" .. string.format("%.1f%%", value * 100) .. " Crit Damage\n"
			else
				statsText = statsText .. "+" .. tostring(value) .. " " .. stat .. "\n"
			end
		end
	end
	tooltipStats.Text = statsText

	tooltipDesc.Text = template.Description or ""

	tooltip.Position = UDim2.new(0, position.X + 15, 0, position.Y)
	tooltip.Visible = true
end

-- ===== ITEM SLOT CREATION =====
local function createItemSlot(index, itemInstance)
	local template = ItemDatabase:GetItemById(itemInstance.Id)
	local rarity = itemInstance.Rarity or "Common"

	local rarityColors = {
		Common = Color3.fromRGB(80, 80, 80),
		Uncommon = Color3.fromRGB(20, 80, 20),
		Rare = Color3.fromRGB(20, 50, 120),
		Epic = Color3.fromRGB(70, 20, 100),
		Legendary = Color3.fromRGB(120, 70, 0),
	}

	local slot = createFrame(invScroll, "ItemSlot_" .. index,
		UDim2.new(0, 70, 0, 70),
		UDim2.new(0, 0, 0, 0),
		rarityColors[rarity] or Color3.fromRGB(40, 40, 50)
	)
	slot.LayoutOrder = index

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = (Config.Loot.Rarities[rarity] and Config.Loot.Rarities[rarity].Color) or Color3.fromRGB(60, 60, 70)
	slotStroke.Thickness = 1
	slotStroke.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0, 24)
	nameLabel.Position = UDim2.new(0, 2, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = (template and template.Name) or itemInstance.Name or "Unknown"
	nameLabel.TextColor3 = (Config.Loot.Rarities[rarity] and Config.Loot.Rarities[rarity].Color) or Color3.fromRGB(200, 200, 200)
	nameLabel.TextSize = 9
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextWrapped = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = slot

	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, -4, 0, 12)
	typeLabel.Position = UDim2.new(0, 2, 0, 26)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = (template and template.Type) or ""
	typeLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
	typeLabel.TextSize = 8
	typeLabel.Font = Enum.Font.Gotham
	typeLabel.Parent = slot

	if itemInstance.Count and itemInstance.Count > 1 then
		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0, 20, 0, 14)
		countLabel.Position = UDim2.new(1, -22, 1, -16)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "x" .. itemInstance.Count
		countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		countLabel.TextSize = 10
		countLabel.Font = Enum.Font.GothamBold
		countLabel.Parent = slot
	end

	-- Interaction button
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = slot

	btn.MouseButton1Click:Connect(function()
		if template then
			if template.Type == "Consumable" then
				UseConsumable:FireServer(index)
			elseif template.Slot then
				EquipItem:FireServer(index)
			end
		end
	end)

	btn.MouseEnter:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		showTooltip(itemInstance, mousePos)
		slotStroke.Thickness = 2
	end)

	btn.MouseLeave:Connect(function()
		tooltip.Visible = false
		slotStroke.Thickness = 1
	end)

	return slot
end

-- ===== REFRESH DISPLAY =====
local function refreshInventory()
	-- Clear existing slots
	for _, child in ipairs(invScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	invTitle.Text = "Items (" .. #currentInventory .. "/" .. Config.Loot.MaxInventorySlots .. ")"

	for i, item in ipairs(currentInventory) do
		createItemSlot(i, item)
	end
end

local function refreshEquipment()
	for slotName, slotUI in pairs(equipSlots) do
		local item = currentEquipment[slotName]
		if item then
			local template = ItemDatabase:GetItemById(item.Id)
			local rarity = item.Rarity or "Common"
			local rarityColor = (Config.Loot.Rarities[rarity] and Config.Loot.Rarities[rarity].Color) or Color3.fromRGB(180, 180, 180)

			slotUI.ItemLabel.Text = (template and template.Name) or item.Name or "Unknown"
			slotUI.ItemLabel.TextColor3 = rarityColor
			slotUI.Stroke.Color = rarityColor
		else
			slotUI.ItemLabel.Text = "Empty"
			slotUI.ItemLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
			slotUI.Stroke.Color = Color3.fromRGB(60, 60, 80)
		end
	end
end

-- ===== EVENT HANDLERS =====
if InventoryUpdated then
	InventoryUpdated.OnClientEvent:Connect(function(inventory)
		currentInventory = inventory
		if inventoryOpen then
			refreshInventory()
		end
	end)
end

if PlayerStatsUpdated then
	PlayerStatsUpdated.OnClientEvent:Connect(function(data)
		currentEquipment = data.Equipment or {}
		if inventoryOpen then
			refreshEquipment()
		end
	end)
end

-- ===== TOGGLE WITH TAB =====
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		inventoryOpen = not inventoryOpen
		screenGui.Enabled = inventoryOpen
		if inventoryOpen then
			refreshInventory()
			refreshEquipment()
		end
	end
end)

print("[InventoryUI] Initialized.")
