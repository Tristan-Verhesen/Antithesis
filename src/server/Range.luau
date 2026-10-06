-- The separate firing range room (first person + weapons) with target dummies and a pad back to the lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

local C = Config.Colors
local L = Config.Lobby
local R = L.HubRadius
local WALL_H = 24
local Range = {}

local function dummy(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Dummy"
	local function limb(name, size, offset, color)
		return Props.block(m, size, CFrame.new(pos + offset), color, name)
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), C.Dark)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, 1)) -- faces the firing line
	root.Transparency = 1
	root.CanQuery = false
	root.CanCollide = false
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), C.Enemy)
	limb("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), C.Light)
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), C.Dark)
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), C.Dark)
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), C.Dark)
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), C.Dark)
	local hum = Instance.new("Humanoid")
	hum.RequiresNeck = false -- anchored, unjointed limbs; otherwise the Humanoid dies on spawn
	hum.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Dummy", true)
	m.Parent = parent
end

-- The firing range is a separate room 200 studs past the lobby; a pad inside teleports back.
function Range.build(lobby: Model, teleports)
	local c, size = L.Range.center, L.Range.size
	local front, back = c.Z + size.Z / 2, c.Z - size.Z / 2
	Props.block(lobby, Vector3.new(size.X, 1, size.Z), CFrame.new(c.X, -0.5, c.Z), C.MetalLight, "RangeFloor")
	Props.walls(lobby, Vector3.new(c.X, 0, c.Z), size.X, size.Z, WALL_H, C.MetalLight)
	Props.block(lobby, Vector3.new(30, 0.05, size.Z), CFrame.new(c.X, 0.025, c.Z), C.Metal, "RangeLane")
	local line = front - 12
	Props.neon(lobby, Vector3.new(30, 0.06, 0.5), CFrame.new(c.X, 0.03, line), C.Gold)

	local backPad = Vector3.new(c.X + 22, 0, front - 6)
	Props.glowPad(lobby, backPad, C.Purple)
	Props.sign(lobby, Vector3.new(c.X + 22, 9, front - 0.4), Vector3.new(0, 0, -1), Vector2.new(12, 4), "BACK TO LOBBY", C.Purple)
	local lobbyArrive = Vector3.new(0, 3, -(R + 8))
	table.insert(teleports, {
		center = backPad + Vector3.new(0, 0.35, 0),
		target = CFrame.lookAt(lobbyArrive, Vector3.new(0, 3, 0)),
	})

	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	for i, d in { 15, 30, 45, 60, 75 } do
		dummy(dummies, Vector3.new(c.X + ({ -10, 8, -4, 10, 0 })[i], 0, line - d))
	end
	assert(back < line - 75, "range too short for dummies")
end


return Range
