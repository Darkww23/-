-- DoorController (StarterPlayerScripts - LocalScript)
-- Handles door interaction, wiping, and endings

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = ReplicatedStorage:WaitForChild("Events")
local GameStateEvent = Events:WaitForChild("GameState")
local InteractEvent = Events:WaitForChild("Interact")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local apartment = workspace:WaitForChild("Apartment")
local door = apartment:WaitForChild("Hallway"):WaitForChild("Door")
local doorHinge = door:WaitForChild("Hinge")

local inventory = {}
local currentState = "Intro"
local doorOpen = false

local function addToInventory(itemName)
	inventory[itemName] = true
end

local function hasItem(itemName)
	return inventory[itemName] == true
end

local function showMessage(text, duration)
	local gui = playerGui:FindFirstChild("MainGui")
	if not gui then return end

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(0.6, 0, 0.1, 0)
	msg.Position = UDim2.new(0.2, 0, 0.75, 0)
	msg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	msg.BackgroundTransparency = 0.4
	msg.Text = text
	msg.TextColor3 = Color3.fromRGB(255, 255, 255)
	msg.TextSize = 22
	msg.Font = Enum.Font.Gotham
	msg.TextWrapped = true
	msg.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = msg

	TweenService:Create(msg, TweenInfo.new(0.3), {
		TextTransparency = 0,
	}):Play()

	task.wait(duration or 3)

	TweenService:Create(msg, TweenInfo.new(0.5), {
		TextTransparency = 1,
		BackgroundTransparency = 1,
	}):Play()
	task.wait(0.6)
	msg:Destroy()
end

local function animateDoorOpen()
	if doorOpen then return end
	doorOpen = true

	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local currentCF = doorHinge.CFrame
	local openCF = currentCF * CFrame.Angles(0, math.rad(-90), 0)

	local tween = TweenService:Create(doorHinge, tweenInfo, {
		CFrame = openCF,
	})
	tween:Play()
	tween.Completed:Wait()
end

local function showGoodEnding()
	animateDoorOpen()
	task.wait(1)

	local endScreen = Instance.new("Frame")
	endScreen.Size = UDim2.new(1, 0, 1, 0)
	endScreen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	endScreen.BackgroundTransparency = 1
	endScreen.Parent = playerGui:WaitForChild("MainGui")

	TweenService:Create(endScreen, TweenInfo.new(2), {
		BackgroundTransparency = 0,
	}):Play()

	task.wait(2)

	local endText = Instance.new("TextLabel")
	endText.Size = UDim2.new(0.8, 0, 0.3, 0)
	endText.Position = UDim2.new(0.1, 0, 0.35, 0)
	endText.BackgroundTransparency = 1
	endText.Text = "Вы выбрались.\nАномалия осталась позади."
	endText.TextColor3 = Color3.fromRGB(0, 0, 0)
	endText.TextSize = 36
	endText.Font = Enum.Font.GothamBold
	endText.TextWrapped = true
	endText.Parent = endScreen

	task.wait(4)

	local credits = Instance.new("TextLabel")
	credits.Size = UDim2.new(0.6, 0, 0.15, 0)
	credits.Position = UDim2.new(0.2, 0, 0.65, 0)
	credits.BackgroundTransparency = 1
	credits.Text = "АНОМАЛИЯ 228\nСпасибо за игру."
	credits.TextColor3 = Color3.fromRGB(80, 80, 80)
	credits.TextSize = 24
	credits.Font = Enum.Font.Gotham
	credits.TextWrapped = true
	credits.Parent = endScreen
end

local function showBadEnding()
	animateDoorOpen()
	task.wait(1.5)
	showMessage("Вы видите... вашу комнату. Компьютер всё ещё включён.", 3)
	task.wait(2)
	showMessage("НЕ ОБОРАЧИВАЙТЕСЬ.", 2)

	task.wait(1)

	local blackScreen = Instance.new("Frame")
	blackScreen.Size = UDim2.new(1, 0, 1, 0)
	blackScreen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackScreen.BackgroundTransparency = 1
	blackScreen.Parent = playerGui:WaitForChild("MainGui")

	TweenService:Create(blackScreen, TweenInfo.new(0.1), {
		BackgroundTransparency = 0,
	}):Play()

	task.wait(0.5)

	local scareText = Instance.new("TextLabel")
	scareText.Size = UDim2.new(1, 0, 1, 0)
	scareText.BackgroundTransparency = 1
	scareText.Text = "ОНО ПОЗАДИ ВАС"
	scareText.TextColor3 = Color3.fromRGB(200, 0, 0)
	scareText.TextSize = 64
	scareText.Font = Enum.Font.GothamBold
	scareText.Parent = blackScreen

	task.wait(3)

	local endText = Instance.new("TextLabel")
	endText.Size = UDim2.new(0.8, 0, 0.2, 0)
	endText.Position = UDim2.new(0.1, 0, 0.65, 0)
	endText.BackgroundTransparency = 1
	endText.Text = "Вы не смогли сбежать.\nАномалия поглотила вас."
	endText.TextColor3 = Color3.fromRGB(150, 0, 0)
	endText.TextSize = 28
	endText.Font = Enum.Font.Gotham
	endText.TextWrapped = true
	endText.Parent = blackScreen
end

GameStateEvent.OnClientEvent:Connect(function(state, ...)
	currentState = state

	if state == "DoorLocked" then
		showMessage("Дверь заперта... Нужно найти раствор и тряпку.", 3)
	elseif state == "DoorReady" then
		showMessage("Дверь готова. Попробуйте открыть.", 3)
	elseif state == "GoodEnding" then
		task.spawn(showGoodEnding)
	elseif state == "BadEnding" then
		task.spawn(showBadEnding)
	elseif state == "ItemPickup" then
		local itemName = select(1, ...)
		addToInventory(itemName)
		if itemName == "Cloth" then
			showMessage("Вы подобрали тряпку.", 2)
		elseif itemName == "Solution" then
			showMessage("Вы подобрали раствор.", 2)
		end
	end
end)
