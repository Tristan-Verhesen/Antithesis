-- Client entry point: builds the UI and routes server messages.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.State)
local UI = require(script.UI)
local Hud = require(script.Hud)
local Menus = require(script.Menus)
local Movement = require(script.Movement)
local Weapons = require(script.Weapons)

local player = Players.LocalPlayer
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

local gui = UI.new("ScreenGui", {
	Name = "Antithesis",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
Hud.init(gui)
Menus.init(gui)
Movement.init()
Weapons.init()

local function setPhase(ph)
	State.phase = ph
	Hud.phase(ph)
	Menus.phase(ph)
end

local handlers = {
	Profile = function(p)
		State.profile = p
		Menus.refresh()
	end,
	Phase = setPhase,
	Reveal = Menus.reveal,
	Results = Menus.results,
	Queue = function(mode)
		State.queue = mode
		State.queuedAt = os.clock()
		Menus.refresh()
	end,
	Hit = Hud.hit,
	Damaged = Hud.damaged,
	Feed = Hud.feed,
	Banner = Hud.banner,
	Flash = Hud.flash,
	Notify = Menus.toast,
	Challenged = Menus.challenged,
}

Net.Event.OnClientEvent:Connect(function(action, ...)
	local handler = handlers[action]
	if handler then
		handler(...)
	end
end)
Net.FX.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Tracer" then
		Hud.tracer(a, b)
	end
end)

-- Hide my own challenge prompt; only other players should see it.
local function hideOwnPrompt(char: Model)
	local prompt = char:WaitForChild("HumanoidRootPart"):WaitForChild("ProximityPrompt", 10)
	if prompt then
		prompt.Enabled = false
	end
end
player.CharacterAdded:Connect(hideOwnPrompt)
if player.Character then
	task.spawn(hideOwnPrompt, player.Character)
end

player:GetAttributeChangedSignal("MatchId"):Connect(function()
	if player:GetAttribute("MatchId") == 0 then
		setPhase(nil)
	end
end)

Net.Event:FireServer("Hello")
