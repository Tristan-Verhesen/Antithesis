-- Server entry point: builds the world, wires remotes, sets up players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local World = require(script.World)
local Data = require(script.Data)
local Combat = require(script.Combat)
local Match = require(script.Match)
local Lobby = require(script.Lobby)

World.build()
Combat.start()
Data.start(World)
Match.start()
Lobby.start()

local handlers = {
	Hello = Data.push,
	Fire = Combat.fire,
	Reload = Combat.reload,
	Melee = Combat.melee,
	Throw = Combat.throw,
	Equip = Combat.equip,
	Pick = Match.pick,
	ChallengeReply = Match.challengeReply,
	Rematch = Match.rematch,
	Unlock = Data.unlock,
	ClaimQuest = Data.claimQuest,
	Palette = Data.setPalette,
	Fov = Data.setFov,
}

Net.Event.OnServerEvent:Connect(function(player, action, ...)
	local handler = type(action) == "string" and handlers[action]
	if handler then
		handler(player, ...)
	end
end)

local function noQuery(d: Instance)
	if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") then
		d.CanQuery = false -- hats never block or absorb bullets
	end
end

local function onCharacter(player: Player, char: Model)
	Combat.clear(player)
	if player:GetAttribute("MatchId") == 0 then
		Combat.reset(player)
	end
	for _, d in char:GetDescendants() do
		noQuery(d)
	end
	char.DescendantAdded:Connect(noQuery)

	local root = char:WaitForChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Challenge"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = player:GetAttribute("MatchId") == 0
	prompt.Parent = root
	prompt.Triggered:Connect(function(who)
		if who ~= player then
			Match.challenge(who, player)
		end
	end)

	char:WaitForChild("Humanoid").Died:Connect(function()
		if player:GetAttribute("MatchId") == 0 then
			task.delay(2, function()
				if player.Parent and player:GetAttribute("MatchId") == 0 then
					player:LoadCharacter()
				end
			end)
		end
	end)
end

local function onPlayer(player: Player)
	player:SetAttribute("MatchId", 0)
	player:SetAttribute("Team", 0)
	local p = Data.load(player)
	if not player.Parent then
		return
	end
	for _, slot in Config.Slots do
		local id = p.loadout[slot]
		local w = Config.Weapons[id]
		player:SetAttribute(slot, (w and w.slot == slot and p.unlocked[id]) and id or Config.Starter[slot])
	end
	player:SetAttribute("Palette", p.palettes[p.palette] and p.palette or "Default")
	player.DevEnableMouseLock = false -- Shift is Dash, not shift-lock (camera mode is set by the client)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	player:LoadCharacter()
	Data.push(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	Match.onLeave(player)
	Data.release(player)
end)
