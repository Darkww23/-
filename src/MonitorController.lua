-- MonitorController (StarterPlayerScripts - LocalScript)
-- Controls the CRT monitor face display and distortion effects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Events = ReplicatedStorage:WaitForChild("Events")
local GameStateEvent = Events:WaitForChild("GameState")

local player = Players.LocalPlayer
local monitor = workspace:WaitForChild("Apartment"):WaitForChild("Room"):WaitForChild("Monitor")
local screenGui = monitor:WaitForChild("Screen"):WaitForChild("SurfaceGui")
local faceImage = screenGui:WaitForChild("FaceImage")
local staticOverlay = screenGui:WaitForChild("StaticOverlay")

local distortionLevel = 0
local isFlickering = false
local screenOn = false

local function setScreenOn(on)
	screenOn = on
	faceImage.Visible = on
	if on then
		staticOverlay.Visible = true
	end
end

local function updateDistortion(level)
	distortionLevel = level

	if level == 0 then
		faceImage.ImageColor3 = Color3.fromRGB(200, 200, 200)
		faceImage.Rotation = 0
		faceImage.Size = UDim2.new(0.8, 0, 0.8, 0)
	elseif level == 1 then
		faceImage.ImageColor3 = Color3.fromRGB(180, 180, 180)
		faceImage.Rotation = 2
		faceImage.Size = UDim2.new(0.85, 0, 0.85, 0)
	elseif level == 2 then
		faceImage.ImageColor3 = Color3.fromRGB(160, 150, 150)
		faceImage.Rotation = -3
		faceImage.Size = UDim2.new(0.9, 0, 0.9, 0)
	elseif level >= 3 then
		faceImage.ImageColor3 = Color3.fromRGB(140, 120, 120)
		faceImage.Rotation = 5
		faceImage.Size = UDim2.new(0.95, 0, 0.95, 0)
	end
end

local function flickerScreen()
	isFlickering = true
	for i = 1, 5 do
		faceImage.Visible = false
		staticOverlay.BackgroundTransparency = 0.3
		task.wait(math.random() * 0.15 + 0.05)
		faceImage.Visible = true
		staticOverlay.BackgroundTransparency = 0.8
		task.wait(math.random() * 0.2 + 0.1)
	end
	isFlickering = false
end

local function startStaticAnimation()
	task.spawn(function()
		while screenOn do
			staticOverlay.BackgroundTransparency = 0.85 + math.random() * 0.1
			task.wait(0.1)
		end
	end)
end

GameStateEvent.OnClientEvent:Connect(function(state, ...)
	if state == "ComputerOn" then
		setScreenOn(true)
		updateDistortion(0)
		startStaticAnimation()

	elseif state == "TryShutdown" then
		flickerScreen()
		task.wait(0.5)
		flickerScreen()

	elseif state == "FaceDistorted" then
		updateDistortion(1)
		task.wait(1)
		updateDistortion(2)
		task.wait(1)
		updateDistortion(3)
		flickerScreen()

	elseif state == "BadEnding" then
		updateDistortion(3)
		setScreenOn(true)
		task.wait(0.5)

		local jumpscare = Instance.new("Frame")
		jumpscare.Size = UDim2.new(1, 0, 1, 0)
		jumpscare.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		jumpscare.Parent = player.PlayerGui:WaitForChild("MainGui")

		task.wait(0.3)

		local scareImage = Instance.new("ImageLabel")
		scareImage.Size = UDim2.new(1, 0, 1, 0)
		scareImage.BackgroundTransparency = 1
		scareImage.Image = "rbxassetid://0" -- placeholder
		scareImage.Parent = jumpscare

		task.wait(2)
		jumpscare:Destroy()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if screenOn and not isFlickering and distortionLevel >= 2 then
		local wobble = math.sin(tick() * 3) * (distortionLevel * 0.5)
		faceImage.Position = UDim2.new(
			0.5 + wobble * 0.01,
			0,
			0.5 + math.cos(tick() * 2.5) * 0.005 * distortionLevel,
			0
		)
	end
end)
