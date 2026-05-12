-- InteractionSystem (StarterPlayerScripts - LocalScript)
-- Handles proximity-based interaction with objects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Events = ReplicatedStorage:WaitForChild("Events")
local InteractEvent = Events:WaitForChild("Interact")
local GameStateEvent = Events:WaitForChild("GameState")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local INTERACT_DISTANCE = 8

local interactGui = Instance.new("ScreenGui")
interactGui.Name = "InteractGui"
interactGui.ResetOnSpawn = false
interactGui.Parent = playerGui

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(0.3, 0, 0.06, 0)
promptLabel.Position = UDim2.new(0.35, 0, 0.85, 0)
promptLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
promptLabel.BackgroundTransparency = 0.4
promptLabel.Text = ""
promptLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
promptLabel.TextSize = 20
promptLabel.Font = Enum.Font.Gotham
promptLabel.Visible = false
promptLabel.Parent = interactGui

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 6)
promptCorner.Parent = promptLabel

local currentState = "Intro"
local inventory = {}
local nearObject = nil

local interactableObjects = {}

local function setupInteractables()
	local apartment = workspace:WaitForChild("Apartment")

	local monitor = apartment:WaitForChild("Room"):FindFirstChild("Monitor")
	if monitor then
		interactableObjects["Monitor"] = {
			part = monitor:FindFirstChild("Screen") or monitor.PrimaryPart or monitor:FindFirstChildWhichIsA("BasePart"),
			prompt = "[E] Выключить компьютер",
			action = "click",
			states = { "ComputerOn" },
		}
	end

	local door = apartment:WaitForChild("Hallway"):FindFirstChild("Door")
	if door then
		interactableObjects["Door"] = {
			part = door:FindFirstChild("Handle") or door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart"),
			prompt = "[E] Открыть дверь",
			promptWipe = "[E] Протереть дверь раствором",
			action = "open",
			states = { "LeaveRoom", "WipeDoor", "DoorLocked" },
		}
	end

	local cloth = apartment:WaitForChild("Hallway"):FindFirstChild("Cloth")
	if cloth then
		interactableObjects["Cloth"] = {
			part = cloth:FindFirstChildWhichIsA("BasePart") or cloth,
			prompt = "[E] Подобрать тряпку",
			action = "pickup",
			states = { "DoorLocked", "LeaveRoom" },
		}
	end

	local solution = apartment:WaitForChild("Room"):FindFirstChild("Solution")
	if solution then
		interactableObjects["Solution"] = {
			part = solution:FindFirstChildWhichIsA("BasePart") or solution,
			prompt = "[E] Подобрать раствор",
			action = "pickup",
			states = { "DoorLocked", "LeaveRoom" },
		}
	end
end

local function getCharacterPosition()
	local character = player.Character
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	return rootPart.Position
end

local function findNearestInteractable()
	local pos = getCharacterPosition()
	if not pos then return nil, nil end

	local nearest = nil
	local nearestName = nil
	local nearestDist = INTERACT_DISTANCE

	for name, data in pairs(interactableObjects) do
		if data.part and data.part:IsA("BasePart") then
			local dist = (data.part.Position - pos).Magnitude
			if dist < nearestDist then
				local canInteract = false
				for _, state in ipairs(data.states) do
					if state == currentState then
						canInteract = true
						break
					end
				end
				if canInteract then
					nearestDist = dist
					nearest = data
					nearestName = name
				end
			end
		end
	end

	return nearestName, nearest
end

local function interact()
	if not nearObject then return end

	local name, data = nearObject.name, nearObject.data
	local action = data.action

	if name == "Door" and currentState == "DoorLocked" and inventory["Cloth"] and inventory["Solution"] then
		action = "wipe"
	end

	InteractEvent:FireServer(name, action)

	if name == "Cloth" or name == "Solution" then
		inventory[name] = true
		if data.part and data.part.Parent then
			data.part.Parent:Destroy()
		end
		interactableObjects[name] = nil
	end
end

GameStateEvent.OnClientEvent:Connect(function(state, ...)
	if state == "ItemPickup" then
		local itemName = select(1, ...)
		inventory[itemName] = true
	else
		currentState = state
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		interact()
	end
end)

RunService.Heartbeat:Connect(function()
	local name, data = findNearestInteractable()
	if name and data then
		nearObject = { name = name, data = data }
		if name == "Door" and currentState == "DoorLocked" then
			if inventory["Cloth"] and inventory["Solution"] then
				promptLabel.Text = data.promptWipe or data.prompt
			else
				promptLabel.Text = data.prompt
			end
		else
			promptLabel.Text = data.prompt
		end
		promptLabel.Visible = true
	else
		nearObject = nil
		promptLabel.Visible = false
	end
end)

task.defer(setupInteractables)
