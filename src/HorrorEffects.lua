-- HorrorEffects (StarterPlayerScripts - LocalScript)
-- Flickering lights, ambient sounds, VHS glitch overlay, atmosphere

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Events = ReplicatedStorage:WaitForChild("Events")
local GameStateEvent = Events:WaitForChild("GameState")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local horrorLevel = 0

local vhsGui = Instance.new("ScreenGui")
vhsGui.Name = "VHSGui"
vhsGui.ResetOnSpawn = false
vhsGui.IgnoreGuiInset = true
vhsGui.DisplayOrder = 100
vhsGui.Parent = playerGui

local scanlines = Instance.new("Frame")
scanlines.Size = UDim2.new(1, 0, 1, 0)
scanlines.BackgroundTransparency = 1
scanlines.Name = "Scanlines"
scanlines.Parent = vhsGui

for i = 0, 50 do
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, i / 50, 0)
	line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	line.BackgroundTransparency = 0.92
	line.BorderSizePixel = 0
	line.Parent = scanlines
end

local glitchFrame = Instance.new("Frame")
glitchFrame.Size = UDim2.new(1, 0, 0.02, 0)
glitchFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
glitchFrame.BackgroundTransparency = 0.9
glitchFrame.BorderSizePixel = 0
glitchFrame.Visible = false
glitchFrame.Name = "GlitchBar"
glitchFrame.Parent = vhsGui

local vignetteFrame = Instance.new("Frame")
vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
vignetteFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignetteFrame.BackgroundTransparency = 0.85
vignetteFrame.BorderSizePixel = 0
vignetteFrame.Name = "Vignette"
vignetteFrame.Parent = vhsGui

local roomLight = workspace:WaitForChild("Apartment"):WaitForChild("Room"):FindFirstChild("CeilingLight")

local function flickerLight()
	if not roomLight then return end
	local light = roomLight:FindFirstChildOfClass("PointLight") or roomLight:FindFirstChildOfClass("SpotLight")
	if not light then return end

	local originalBrightness = light.Brightness

	for i = 1, math.random(3, 7) do
		light.Brightness = 0
		light.Enabled = false
		task.wait(math.random() * 0.1 + 0.02)
		light.Brightness = originalBrightness * (0.5 + math.random() * 0.5)
		light.Enabled = true
		task.wait(math.random() * 0.15 + 0.05)
	end

	light.Brightness = originalBrightness
	light.Enabled = true
end

local function triggerGlitch()
	glitchFrame.Visible = true
	for i = 1, math.random(5, 15) do
		glitchFrame.Position = UDim2.new(0, 0, math.random(), 0)
		glitchFrame.Size = UDim2.new(1, 0, 0.005 + math.random() * 0.03, 0)
		glitchFrame.BackgroundTransparency = 0.7 + math.random() * 0.2
		task.wait(0.02)
	end
	glitchFrame.Visible = false
end

local function setHorrorAtmosphere(level)
	horrorLevel = level

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Parent = Lighting
	end

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end

	if level == 0 then
		colorCorrection.Saturation = -0.2
		colorCorrection.Contrast = 0.1
		colorCorrection.TintColor = Color3.fromRGB(230, 220, 200)
		Lighting.Ambient = Color3.fromRGB(30, 25, 20)
		bloom.Intensity = 0.1
		vignetteFrame.BackgroundTransparency = 0.85
	elseif level == 1 then
		colorCorrection.Saturation = -0.5
		colorCorrection.Contrast = 0.2
		colorCorrection.TintColor = Color3.fromRGB(200, 190, 170)
		Lighting.Ambient = Color3.fromRGB(20, 15, 10)
		bloom.Intensity = 0.2
		vignetteFrame.BackgroundTransparency = 0.75
	elseif level == 2 then
		colorCorrection.Saturation = -0.7
		colorCorrection.Contrast = 0.3
		colorCorrection.TintColor = Color3.fromRGB(180, 170, 150)
		Lighting.Ambient = Color3.fromRGB(10, 8, 5)
		bloom.Intensity = 0.3
		vignetteFrame.BackgroundTransparency = 0.6
	elseif level >= 3 then
		colorCorrection.Saturation = -0.9
		colorCorrection.Contrast = 0.4
		colorCorrection.TintColor = Color3.fromRGB(150, 130, 120)
		Lighting.Ambient = Color3.fromRGB(5, 3, 2)
		bloom.Intensity = 0.5
		vignetteFrame.BackgroundTransparency = 0.45
	end
end

GameStateEvent.OnClientEvent:Connect(function(state)
	if state == "Intro" then
		setHorrorAtmosphere(0)
	elseif state == "ComputerOn" then
		setHorrorAtmosphere(1)
		task.spawn(flickerLight)
	elseif state == "FaceDistorted" then
		setHorrorAtmosphere(2)
		task.spawn(flickerLight)
		task.spawn(triggerGlitch)
	elseif state == "LeaveRoom" then
		setHorrorAtmosphere(3)
		task.spawn(flickerLight)
		task.spawn(triggerGlitch)
	elseif state == "BadEnding" then
		setHorrorAtmosphere(3)
		for i = 1, 3 do
			task.spawn(triggerGlitch)
			task.spawn(flickerLight)
			task.wait(0.3)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(math.random(8, 20))
		if horrorLevel >= 1 then
			task.spawn(triggerGlitch)
		end
		if horrorLevel >= 2 then
			task.spawn(flickerLight)
		end
	end
end)
