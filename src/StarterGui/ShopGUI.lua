--[[
	ShopGUI.lua (LocalScript)
	Client-side shop interface for "Raise a Geometry Cube".

	• Listens for "open" event from server to show shop GUI
	• Displays available items with Buy buttons
	• Sends purchase request to server

	Place in StarterGui.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopRemote = ReplicatedStorage:WaitForChild("ShopRemote")
local shopData   = ReplicatedStorage:WaitForChild("ShopData")

-- ========== CREATE GUI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main frame
local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0, 350, 0, 400)
frame.Position = UDim2.new(0.5, -175, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🛒 Shop"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 24
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = frame

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Items container
local itemsFrame = Instance.new("ScrollingFrame")
itemsFrame.Name = "Items"
itemsFrame.Size = UDim2.new(1, -20, 1, -60)
itemsFrame.Position = UDim2.new(0, 10, 0, 55)
itemsFrame.BackgroundTransparency = 1
itemsFrame.ScrollBarThickness = 4
itemsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
itemsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemsFrame.Parent = frame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = itemsFrame

-- ========== BUILD ITEM CARDS ==========
local function buildShopItems()
	-- Clear existing
	for _, child in ipairs(itemsFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local items = shopData:InvokeServer()
	if not items then return end

	for _, item in ipairs(items) do
		local card = Instance.new("Frame")
		card.Name = item.id
		card.Size = UDim2.new(1, 0, 0, 80)
		card.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		card.Parent = itemsFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 0, 30)
		nameLabel.Position = UDim2.new(0, 12, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 16
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.6, 0, 0, 20)
		descLabel.Position = UDim2.new(0, 12, 0, 40)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = item.desc
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.TextSize = 12
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = card

		local priceText = item.price == 0 and "Free" or tostring(item.price)

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(0, 90, 0, 40)
		buyBtn.Position = UDim2.new(1, -100, 0.5, -20)
		buyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
		buyBtn.Text = priceText
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.TextSize = 16
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.Parent = card

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			shopRemote:FireServer("buy", item.id)
		end)
	end
end

-- ========== EVENTS ==========
shopRemote.OnClientEvent:Connect(function(action, data)
	if action == "open" then
		buildShopItems()
		frame.Visible = true
	elseif action == "purchased" then
		-- Brief flash on the buy button to confirm purchase
		local card = itemsFrame:FindFirstChild(data)
		if card then
			local btn = card:FindFirstChild("BuyBtn")
			if btn then
				btn.BackgroundColor3 = Color3.fromRGB(100, 255, 120)
				btn.Text = "✓"
				task.delay(0.8, function()
					btn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
					btn.Text = "Free"
				end)
			end
		end
	end
end)
