--[[
	ShopGUI.lua (LocalScript)
	Connects to the player's existing shop GUI for "Raise a Geometry Cube".

	Expected GUI structure (created by the player in Studio):
	  PlayerGui
	    └─ CubeShopGui (ScreenGui)
	         ├─ CubeShop (ScrollingFrame — main shop window)
	         │    └─ PurchaseBasicFood (TextButton — buy CubeFood)
	         └─ CubeShopCloseButton (TextButton — close shop)

	This script:
	  • Opens CubeShopGui when server sends "open" event
	  • Closes on CubeShopCloseButton click
	  • Sends purchase request to server on PurchaseBasicFood click
	  • Shows purchase confirmation feedback

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

if buyBasic then
	buyBasic.MouseButton1Click:Connect(function()
		if purchaseCooldown then return end
		purchaseCooldown = true

		shopRemote:FireServer("buy", "CubeFood")

		task.delay(1, function()
			purchaseCooldown = false
		end)
	end)
end

-- ========== SERVER EVENTS ==========
shopRemote.OnClientEvent:Connect(function(action, data)
	if action == "open" then
		openShop()
	elseif action == "purchased" then
		-- Brief visual feedback on the buy button
		if data == "CubeFood" and buyBasic then
			local origText = buyBasic.Text
			local origColor = buyBasic.BackgroundColor3
			buyBasic.Text = "✓"
			buyBasic.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
			task.delay(0.8, function()
				buyBasic.Text = origText
				buyBasic.BackgroundColor3 = origColor
			end)
		end
	end
end)
