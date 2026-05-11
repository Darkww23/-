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

-- ========== PURCHASE HANDLER ==========
shopRemote.OnServerEvent:Connect(function(player, action, itemId)
	if action ~= "buy" then return end

	local item = SHOP_ITEMS[itemId]
	if not item then return end

	if item.price > 0 then
		-- TODO: deduct currency when currency system exists
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = createFoodTool(itemId)
	tool.Parent = backpack

	shopRemote:FireClient(player, "purchased", itemId)
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
