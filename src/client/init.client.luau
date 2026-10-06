-- Client entry point: builds the UI and routes server messages.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Config = require(ReplicatedStorage.Shared.Config)
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
	Results = Menus.results,
	Pad = function(status)
		State.pad = status
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

-- Third person in the lobby, first person in matches and the firing range (Rivals-style).
local firstPerson: boolean? = nil
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	State.inRange = root ~= nil and player:GetAttribute("MatchId") == 0 and Config.inRange(root.Position)
	local fp = player:GetAttribute("MatchId") ~= 0 or State.inRange
	if fp ~= firstPerson then
		firstPerson = fp
		player.CameraMode = fp and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
		-- Order matters: Roblox clamps Min down to the current Max, so never write Min above Max.
		if fp then
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 0.5
		else
			player.CameraMaxZoomDistance = Config.Lobby.MaxZoom
			player.CameraMinZoomDistance = Config.Lobby.MinZoom
		end
	end
end)

Net.Event:FireServer("Hello")
