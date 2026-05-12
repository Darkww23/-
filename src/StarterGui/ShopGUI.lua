--[[
	ShopGUI.lua (LocalScript)
	Connects to the player's existing shop GUI for "Raise a Geometry Cube".

	Expected GUI structure (created by the player in Studio):
	  PlayerGui
	    └─ CubeShopGui (ScreenGui)
	         ├─ CubeShop (ScrollingFrame — main shop window)
	         │    ├─ PurchaseBasicFood (TextButton — buy CubeFood, 25 Orbs)
	         │    └─ PurchasePremiumFood (TextButton — buy CubeFoodPremium, 100 Orbs)
	         └─ CubeShopCloseButton (TextButton — close shop)

	Place as LocalScript in StarterGui.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopRemote = ReplicatedStorage:WaitForChild("ShopRemote")

-- ========== FIND GUI ELEMENTS ==========
local shopGui    = playerGui:WaitForChild("CubeShopGui", 10)
if not shopGui then warn("[ShopGUI] CubeShopGui not found") return end

local shopFrame  = shopGui:WaitForChild("CubeShop", 10)
local closeBtn   = shopGui:FindFirstChild("CubeShopCloseButton", true)
local buyBasic   = shopFrame and shopFrame:FindFirstChild("PurchaseBasicFood", true)
local buyPremium = shopFrame and shopFrame:FindFirstChild("PurchasePremiumFood", true)
local buyUpgrade = shopFrame and shopFrame:FindFirstChild("PurchaseOrbUpgrade", true)
local buyHungerUpgrade = shopFrame and shopFrame:FindFirstChild("PurchaseHungerUpgrade", true)

-- Start hidden
if shopFrame then shopFrame.Visible = false end

-- ========== OPEN / CLOSE ==========
local function openShop()
	if shopFrame then shopFrame.Visible = true end
end

local function closeShop()
	if shopFrame then shopFrame.Visible = false end
end

if closeBtn then
	closeBtn.MouseButton1Click:Connect(closeShop)
end

-- ========== PURCHASE ==========
local purchaseCooldown = false

local function tryBuy(itemId)
	if purchaseCooldown then return end
	purchaseCooldown = true
	shopRemote:FireServer("buy", itemId)
	task.delay(1, function()
		purchaseCooldown = false
	end)
end

if buyBasic then
	buyBasic.MouseButton1Click:Connect(function()
		tryBuy("CubeFood")
	end)
end

if buyPremium then
	buyPremium.MouseButton1Click:Connect(function()
		tryBuy("CubeFoodPremium")
	end)
end

if buyUpgrade then
	buyUpgrade.MouseButton1Click:Connect(function()
		tryBuy("OrbUpgrade")
	end)
end

if buyHungerUpgrade then
	buyHungerUpgrade.MouseButton1Click:Connect(function()
		tryBuy("HungerUpgrade")
	end)
end

-- ========== SERVER EVENTS ==========
local function flashButton(btn, success)
	if not btn then return end
	local origText = btn.Text
	local origColor = btn.BackgroundColor3
	if success then
		btn.Text = "✓"
		btn.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
	else
		btn.Text = "✗"
		btn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	end
	task.delay(0.8, function()
		btn.Text = origText
		btn.BackgroundColor3 = origColor
	end)
end

local buttonMap = {
	CubeFood = buyBasic,
	CubeFoodPremium = buyPremium,
	OrbUpgrade = buyUpgrade,
	HungerUpgrade = buyHungerUpgrade,
}

shopRemote.OnClientEvent:Connect(function(action, data)
	if action == "open" then
		openShop()
	elseif action == "purchased" then
		local btn = buttonMap[data]
		if (data == "OrbUpgrade" or data == "HungerUpgrade") and btn then
			btn.Text = "✓"
			btn.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
			task.delay(0.8, function()
				btn.Text = "Owned"
				btn.Active = false
			end)
		else
			flashButton(btn, true)
		end
	elseif action == "noFunds" then
		flashButton(buttonMap[data], false)
	elseif action == "alreadyOwned" then
		local btn = buttonMap[data]
		if btn then
			btn.Text = "Owned"
			btn.Active = false
		end
	end
end)
