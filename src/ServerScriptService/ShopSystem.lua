--[[
	ShopSystem.lua
	Shop system for "Raise a Geometry Cube".

	• ProximityPrompt on ShopPart opens the shop GUI for the player
	• Player can buy CubeFood (free) — Tool is added to Backpack
	• Easily extendable: add items to SHOP_ITEMS table

	Expected workspace layout:
	  workspace
	    └─ ShopPart (BasePart with ProximityPrompt auto-created)

	Place in ServerScriptService.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ========== SHOP ITEMS ==========
local SHOP_ITEMS = {
	{
		id    = "CubeFood",
		name  = "Cube Food",
		price = 0,
		desc  = "Basic food for your cube. Restores hunger.",
	},
}

-- ========== REMOTE EVENTS ==========
local shopRemote = ReplicatedStorage:FindFirstChild("ShopRemote")
if not shopRemote then
	shopRemote = Instance.new("RemoteEvent")
	shopRemote.Name = "ShopRemote"
	shopRemote.Parent = ReplicatedStorage
end

local shopDataRemote = ReplicatedStorage:FindFirstChild("ShopData")
if not shopDataRemote then
	shopDataRemote = Instance.new("RemoteFunction")
	shopDataRemote.Name = "ShopData"
	shopDataRemote.Parent = ReplicatedStorage
end

-- ========== TOOL CREATION ==========
local function createFoodTool(itemId)
	local tool = Instance.new("Tool")
	tool.Name = itemId
	tool.CanBeDropped = false
	tool.RequiresHandle = false
	return tool
end

-- ========== SHOP DATA REQUEST ==========
shopDataRemote.OnServerInvoke = function(player)
	return SHOP_ITEMS
end

-- ========== PURCHASE HANDLER ==========
shopRemote.OnServerEvent:Connect(function(player, action, itemId)
	if action ~= "buy" then return end

	local item
	for _, shopItem in ipairs(SHOP_ITEMS) do
		if shopItem.id == itemId then
			item = shopItem
			break
		end
	end

	if not item then return end

	-- Check price (for now all free, but ready for currency)
	if item.price > 0 then
		-- TODO: deduct currency from player when currency system exists
		return
	end

	-- Give tool to player
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = createFoodTool(item.id)
	tool.Parent = backpack

	shopRemote:FireClient(player, "purchased", item.id)
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

-- Find ShopPart in workspace
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
