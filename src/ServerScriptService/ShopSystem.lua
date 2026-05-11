--[[
	ShopSystem.lua
	Shop system for "Raise a Geometry Cube".

	• ProximityPrompt on ShopPart opens the player's CubeShopGui
	• Player clicks PurchaseBasicFood → server gives CubeFood Tool
	• Easily extendable: add items to SHOP_ITEMS table

	Expected workspace layout:
	  workspace
	    └─ ShopPart (BasePart — ProximityPrompt auto-created)

	Place in ServerScriptService.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== SHOP ITEMS ==========
local SHOP_ITEMS = {
	CubeFood = { price = 0 },
}

-- ========== REMOTE EVENT ==========
local shopRemote = ReplicatedStorage:FindFirstChild("ShopRemote")
if not shopRemote then
	shopRemote = Instance.new("RemoteEvent")
	shopRemote.Name = "ShopRemote"
	shopRemote.Parent = ReplicatedStorage
end

-- ========== TOOL CREATION ==========
local function createFoodTool(itemId)
	local tool = Instance.new("Tool")
	tool.Name = itemId
	tool.CanBeDropped = false
	tool.RequiresHandle = false
	return tool
end

-- ========== RATE LIMITING ==========
local COOLDOWN = 1.0
local MAX_FOOD_IN_BACKPACK = 5
local lastPurchase = {} -- [UserId] = timestamp

-- ========== PURCHASE HANDLER ==========
shopRemote.OnServerEvent:Connect(function(player, action, itemId)
	if action ~= "buy" then return end

	local item = SHOP_ITEMS[itemId]
	if not item then return end

	-- Server-side cooldown
	local now = tick()
	local userId = player.UserId
	if lastPurchase[userId] and (now - lastPurchase[userId]) < COOLDOWN then
		return
	end
	lastPurchase[userId] = now

	if item.price > 0 then
		-- TODO: deduct currency when currency system exists
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	-- Cap max food items (backpack + equipped)
	local count = 0
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") and SHOP_ITEMS[child.Name] then
			count = count + 1
		end
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and SHOP_ITEMS[child.Name] then
				count = count + 1
			end
		end
	end
	if count >= MAX_FOOD_IN_BACKPACK then return end

	local tool = createFoodTool(itemId)
	tool.Parent = backpack

	shopRemote:FireClient(player, "purchased", itemId)
end)

-- Clean up cooldown data when player leaves
game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastPurchase[player.UserId] = nil
end)

-- ========== PROXIMITY PROMPT ON SHOP PART ==========
local function setupShopPrompt(shopPart)
	local prompt = shopPart:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Shop"
		prompt.ActionText = "Open Shop"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = shopPart
	end

	prompt.Triggered:Connect(function(player)
		shopRemote:FireClient(player, "open")
	end)
end

local shopPart = workspace:FindFirstChild("ShopPart")
if shopPart then
	setupShopPrompt(shopPart)
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ShopPart" then
			setupShopPrompt(child)
		end
	end)
end

print("[Shop] Shop system started.")
