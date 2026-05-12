-- GameManager (ServerScriptService)
-- Main game state controller for Anomaly 228

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Events = ReplicatedStorage:WaitForChild("Events")
local GameStateEvent = Events:WaitForChild("GameState")
local InteractEvent = Events:WaitForChild("Interact")
local RulesEvent = Events:WaitForChild("ShowRule")

local GAME_STATES = {
	INTRO = "Intro",
	RULES = "Rules",
	COMPUTER_ON = "ComputerOn",
	TRY_SHUTDOWN = "TryShutdown",
	FACE_DISTORTED = "FaceDistorted",
	LEAVE_ROOM = "LeaveRoom",
	DOOR_LOCKED = "DoorLocked",
	WIPE_DOOR = "WipeDoor",
	DOOR_OPEN = "DoorOpen",
	GOOD_ENDING = "GoodEnding",
	BAD_ENDING = "BadEnding",
}

local playerStates = {}

local rules = {
	{
		id = 1,
		text = "ПРАВИЛО 1:\nСохраняйте спокойствие.\nНе задерживайте взгляд на экране.",
	},
	{
		id = 2,
		text = "ПРАВИЛО 2:\nПопытайтесь выключить компьютер.\nЕсли устройство не реагирует —\nне паникуйте.",
	},
	{
		id = 3,
		text = "ПРАВИЛО 3:\nЕсли изображение не исчезло,\nа ваше лицо стало искажённым —\nкак можно быстрее покиньте комнату.",
	},
	{
		id = 4,
		text = "ПРАВИЛО 4:\nПопытайтесь выйти из квартиры.\nЕсли дверь не открывается —\nсмажьте её раствором.\nПодождите несколько минут.",
	},
	{
		id = 5,
		text = "ПРАВИЛО 5:\nОткрыв дверь, вы должны увидеть\nваш подъезд. Если вместо подъезда\nвы видите вашу комнату\nс включённым компьютером —\nНЕ ОБОРАЧИВАЙТЕСЬ.",
	},
}

local function setPlayerState(player, state)
	playerStates[player.UserId] = state
	GameStateEvent:FireClient(player, state)
end

local function getPlayerState(player)
	return playerStates[player.UserId] or GAME_STATES.INTRO
end

local function showRules(player)
	setPlayerState(player, GAME_STATES.RULES)
	for i, rule in ipairs(rules) do
		task.wait(4)
		RulesEvent:FireClient(player, rule.id, rule.text)
	end
	task.wait(3)
	setPlayerState(player, GAME_STATES.COMPUTER_ON)
end

local function startGame(player)
	setPlayerState(player, GAME_STATES.INTRO)
	task.wait(2)

	GameStateEvent:FireClient(player, "ShowTitle")
	task.wait(3)

	task.spawn(function()
		showRules(player)
	end)
end

local function handleInteraction(player, objectName, action)
	local state = getPlayerState(player)

	if objectName == "Monitor" and action == "click" then
		if state == GAME_STATES.COMPUTER_ON then
			setPlayerState(player, GAME_STATES.TRY_SHUTDOWN)
			task.wait(2)
			setPlayerState(player, GAME_STATES.FACE_DISTORTED)
			task.wait(3)
			setPlayerState(player, GAME_STATES.LEAVE_ROOM)
		end

	elseif objectName == "Door" and action == "open" then
		if state == GAME_STATES.LEAVE_ROOM then
			setPlayerState(player, GAME_STATES.DOOR_LOCKED)
		elseif state == GAME_STATES.WIPE_DOOR then
			local random = math.random(1, 100)
			if random <= 60 then
				setPlayerState(player, GAME_STATES.GOOD_ENDING)
			else
				setPlayerState(player, GAME_STATES.BAD_ENDING)
			end
		end

	elseif objectName == "Door" and action == "wipe" then
		if state == GAME_STATES.DOOR_LOCKED then
			setPlayerState(player, GAME_STATES.WIPE_DOOR)
			task.wait(5)
			GameStateEvent:FireClient(player, "DoorReady")
		end

	elseif objectName == "Cloth" and action == "pickup" then
		GameStateEvent:FireClient(player, "ItemPickup", "Cloth")

	elseif objectName == "Solution" and action == "pickup" then
		GameStateEvent:FireClient(player, "ItemPickup", "Solution")
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		startGame(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
end)

InteractEvent.OnServerEvent:Connect(handleInteraction)
