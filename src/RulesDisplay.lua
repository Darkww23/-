-- RulesDisplay (StarterPlayerScripts - LocalScript)
-- Shows horror rules as GUI overlays

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = ReplicatedStorage:WaitForChild("Events")
local RulesEvent = Events:WaitForChild("ShowRule")
local GameStateEvent = Events:WaitForChild("GameState")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RulesGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function createRuleDisplay(ruleNumber, ruleText)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local fadeIn = TweenService:Create(container, TweenInfo.new(0.5), {
		BackgroundTransparency = 0.3,
	})

	local ruleNumberLabel = Instance.new("TextLabel")
	ruleNumberLabel.Size = UDim2.new(1, 0, 0.3, 0)
	ruleNumberLabel.Position = UDim2.new(0, 0, 0.15, 0)
	ruleNumberLabel.BackgroundTransparency = 1
	ruleNumberLabel.Text = "ПРАВИЛО " .. tostring(ruleNumber)
	ruleNumberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ruleNumberLabel.TextSize = 72
	ruleNumberLabel.Font = Enum.Font.GothamBold
	ruleNumberLabel.TextTransparency = 1
	ruleNumberLabel.Parent = container

	local ruleTextLabel = Instance.new("TextLabel")
	ruleTextLabel.Size = UDim2.new(0.8, 0, 0.4, 0)
	ruleTextLabel.Position = UDim2.new(0.1, 0, 0.45, 0)
	ruleTextLabel.BackgroundTransparency = 1
	ruleTextLabel.Text = ruleText
	ruleTextLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	ruleTextLabel.TextSize = 28
	ruleTextLabel.Font = Enum.Font.Gotham
	ruleTextLabel.TextTransparency = 1
	ruleTextLabel.TextWrapped = true
	ruleTextLabel.TextYAlignment = Enum.TextYAlignment.Top
	ruleTextLabel.Parent = container

	fadeIn:Play()
	TweenService:Create(ruleNumberLabel, TweenInfo.new(0.8), {
		TextTransparency = 0,
	}):Play()
	task.wait(1)
	TweenService:Create(ruleTextLabel, TweenInfo.new(0.8), {
		TextTransparency = 0,
	}):Play()

	task.wait(3)

	TweenService:Create(container, TweenInfo.new(0.5), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(ruleNumberLabel, TweenInfo.new(0.5), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(ruleTextLabel, TweenInfo.new(0.5), {
		TextTransparency = 1,
	}):Play()

	task.wait(0.6)
	container:Destroy()
end

local function showTitle()
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0
	container.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.3, 0)
	title.Position = UDim2.new(0, 0, 0.25, 0)
	title.BackgroundTransparency = 1
	title.Text = "АНОМАЛИЯ 228"
	title.TextColor3 = Color3.fromRGB(200, 0, 0)
	title.TextSize = 80
	title.Font = Enum.Font.GothamBold
	title.TextTransparency = 1
	title.Parent = container

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0.15, 0)
	subtitle.Position = UDim2.new(0, 0, 0.55, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Соблюдайте правила, чтобы оставаться в безопасности."
	subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	subtitle.TextSize = 24
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextTransparency = 1
	subtitle.Parent = container

	TweenService:Create(title, TweenInfo.new(1.5), {
		TextTransparency = 0,
	}):Play()
	task.wait(1)
	TweenService:Create(subtitle, TweenInfo.new(1), {
		TextTransparency = 0,
	}):Play()
	task.wait(2.5)

	TweenService:Create(container, TweenInfo.new(1), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(title, TweenInfo.new(1), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(subtitle, TweenInfo.new(1), {
		TextTransparency = 1,
	}):Play()

	task.wait(1.2)
	container:Destroy()
end

RulesEvent.OnClientEvent:Connect(function(ruleNumber, ruleText)
	task.spawn(function()
		createRuleDisplay(ruleNumber, ruleText)
	end)
end)

GameStateEvent.OnClientEvent:Connect(function(state)
	if state == "ShowTitle" then
		task.spawn(showTitle)
	end
end)
