--[[
	OrbVisual.lua (LocalScript)
	Shows visual orb particles flying from cube to player when clicked.

	Place as LocalScript in StarterGui.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

local orbRemote = ReplicatedStorage:WaitForChild("OrbCollected", 10)
if not orbRemote then return end

local function createOrb(origin)
	local orb = Instance.new("Part")
	orb.Name = "OrbVisual"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.6, 0.6, 0.6)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(255, 215, 0)
	orb.Anchored = true
	orb.CanCollide = false
	orb.CastShadow = false
	orb.Position = origin + Vector3.new(
		math.random(-20, 20) / 10,
		math.random(10, 30) / 10,
		math.random(-20, 20) / 10
	)
	orb.Parent = workspace

	-- Fly upward then fade
	local targetPos = orb.Position + Vector3.new(0, 4, 0)
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(orb, tweenInfo, {
		Position = targetPos,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
	})

	tween:Play()
	tween.Completed:Connect(function()
		orb:Destroy()
	end)
end

orbRemote.OnClientEvent:Connect(function(cubePos, orbCount)
	for i = 1, (orbCount or 3) do
		task.delay((i - 1) * 0.1, function()
			createOrb(cubePos)
		end)
	end
end)
