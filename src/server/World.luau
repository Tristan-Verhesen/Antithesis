-- Builds the + shaped lobby (round hub + PLAY, SHOP, QUESTS and range-teleport arms) and the lighting,
-- and hands out arenas. Everything is generated from code, so the place needs no manual building.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local Arena = require(script.Parent.Arena)
local Props = require(script.Parent.Props)
local Range = require(script.Parent.Range)

local C = Config.Colors

local World = {}
World.stations = {}
World.teleports = {} -- { center = Vector3, target = CFrame }

local map: Folder
local board: TextLabel

---------------------------------------------------------------- lobby

local L = Config.Lobby
local R = L.HubRadius
local ARMS = {
	{ key = "Pads", dir = Vector3.new(0, 0, 1), width = 60, length = 170, trim = C.Purple, title = "PLAY" },
	{ key = "Shop", dir = Vector3.new(1, 0, 0), width = 40, length = 60, trim = C.Gold, title = "SHOP" },
	{ key = "Quests", dir = Vector3.new(-1, 0, 0), width = 40, length = 60, trim = C.Good, title = "QUESTS" },
	{ key = "Range", dir = Vector3.new(0, 0, -1), width = 30, length = 40, trim = C.Ally, title = "FIRING RANGE" },
}
local WALL_H = 24

local function buildStation(lobby: Model, index: number, mode: string)
	local half = math.ceil(#L.Stations / 2)
	local side = index <= half and -1 or 1 -- left wall first, then right wall
	local row = (index - 1) % half
	local zc = R + 30 + row * 50
	local x = side * 18
	local wallX = side * 29.6
	local inward = Vector3.new(-side, 0, 0)
	local cfg = Config.Modes[mode]
	local station = { mode = mode, size = cfg.teamSize, pads = {}, startsAt = nil }

	Props.block(lobby, Vector3.new(14, 0.1, 32), CFrame.new(x, 0.05, zc), C.MetalLight, "StationPlate")
	Props.sign(lobby, Vector3.new(wallX, 16, zc), inward, Vector2.new(10, 3.5), cfg.label, C.Purple)
	for team, dz in { -7, 7 } do
		local color = team == 1 and C.Ally or C.Enemy
		local center = Vector3.new(x, 0, zc + dz)
		local ring = Props.glowPad(lobby, center, color)
		local label = Props.sign(lobby, Vector3.new(wallX, 9, zc + dz), inward, Vector2.new(9, 5.5), "0/" .. cfg.teamSize, color)
		table.insert(station.pads, { center = center + Vector3.new(0, 0.35, 0), board = label, ring = ring, occupants = {} })
	end
	table.insert(World.stations, station)
end

-- One arm of the + : floor, side walls, end wall, neon trims and a title over the entrance.
-- at(along, lateral, y) converts arm-local coordinates to world space.
local function buildArm(lobby: Model, arm)
	local dir, w = arm.dir, arm.width
	local perp = Vector3.new(dir.Z, 0, -dir.X)
	local function at(along: number, lateral: number, y: number): Vector3
		return dir * along + perp * lateral + Vector3.new(0, y, 0)
	end
	local s0 = math.sqrt((R + 0.5) ^ 2 - (w / 2 + 0.5) ^ 2)
	local e = R + arm.length
	local len = e - s0
	local mid = (s0 + e) / 2
	Props.block(lobby, Vector3.new(w, 1, len + 2), CFrame.lookAt(at(mid - 1, 0, -0.5), at(mid - 1, 0, -0.5) + dir), C.Metal, "Floor")
	for _, sideSign in { -1, 1 } do
		local wallPos = at(mid, sideSign * (w / 2 + 0.5), WALL_H / 2)
		Props.block(lobby, Vector3.new(1, WALL_H, len), CFrame.lookAt(wallPos, wallPos + dir), C.MetalLight)
		for _, y in { 1, 20 } do
			local trimPos = at(mid, sideSign * (w / 2 - 0.1), y)
			Props.neon(lobby, Vector3.new(0.3, 0.4, len), CFrame.lookAt(trimPos, trimPos + dir), arm.trim)
		end
	end
	local endPos = at(e + 0.5, 0, WALL_H / 2)
	Props.block(lobby, Vector3.new(w + 2, WALL_H, 1), CFrame.lookAt(endPos, endPos + dir), C.MetalLight)
	Props.sign(lobby, at(R + 1, 0, 19), -dir, Vector2.new(math.min(w - 6, 30), 4), arm.title, arm.trim)
	return at, e
end

local function buildHub(lobby: Model)
	Props.disc(lobby, Vector3.new(0, -0.5, 0), R * 2 + 2, 1, C.Metal)
	Props.disc(lobby, Vector3.new(0, 0.03, 0), R * 2 - 4, 0.06, C.Purple, Enum.Material.Neon)
	Props.disc(lobby, Vector3.new(0, 0.04, 0), R * 2 - 6, 0.08, C.Metal)

	-- Circular wall from short segments, leaving an opening for each arm.
	local n = 48
	local segment = 2 * math.pi * (R + 0.5) / n + 0.4
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 2 * math.pi
		local p = Vector3.new(math.sin(a), 0, math.cos(a)) * (R + 0.5)
		local open = false
		for _, arm in ARMS do
			local perp = Vector3.new(arm.dir.Z, 0, -arm.dir.X)
			if p:Dot(arm.dir) > 0 and math.abs(p:Dot(perp)) < arm.width / 2 + 1 then
				open = true
			end
		end
		if not open then
			local wallPos = p + Vector3.new(0, WALL_H / 2, 0)
			Props.block(lobby, Vector3.new(segment, WALL_H, 1), CFrame.lookAt(wallPos, Vector3.new(0, WALL_H / 2, 0)), C.MetalLight)
			local trimPos = p * ((R - 0.1) / (R + 0.5)) + Vector3.new(0, 1, 0)
			Props.neon(lobby, Vector3.new(segment, 0.4, 0.3), CFrame.lookAt(trimPos, Vector3.new(0, 1, 0)), C.Purple)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 1)) -- face the pads arm
	spawn.Color = C.Purple
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby
end

local function buildPadsArm(lobby: Model, at)
	Props.block(lobby, Vector3.new(12, 0.05, 170), CFrame.new(0, 0.025, R + 85), Color3.fromRGB(12, 12, 16), "Walkway")
	Props.neon(lobby, Vector3.new(0.4, 0.06, 170), CFrame.new(-6, 0.03, R + 85), C.Purple)
	Props.neon(lobby, Vector3.new(0.4, 0.06, 170), CFrame.new(6, 0.03, R + 85), C.Gold)
	for i, mode in L.Stations do
		buildStation(lobby, i, mode)
	end
	board = Props.sign(lobby, at(R + 170 - 0.4, 0, 12), Vector3.new(0, 0, -1), Vector2.new(24, 16), "WEEKLY WINS", C.Light)
	Props.sign(lobby, Vector3.new(-29.6, 10, R + 6), Vector3.new(1, 0, 0), Vector2.new(14, 9),
		"STAND ON A PAD TO QUEUE\nFirst to 5 rounds wins\nHold E near a player to challenge", C.Light)
end

local function buildShopArm(lobby: Model, at)
	local stands = { { 14, -13 }, { 28, -13 }, { 42, -13 }, { 21, 13 }, { 35, 13 } }
	for i, name in Config.PaletteOrder do
		local spot = stands[i]
		if not spot then
			break
		end
		local base = at(R + spot[1], spot[2], 0)
		Props.block(lobby, Vector3.new(4, 3, 4), CFrame.new(base + Vector3.new(0, 1.5, 0)), C.MetalLight, "Pedestal")
		Props.neon(lobby, Vector3.new(4.2, 0.2, 4.2), CFrame.new(base + Vector3.new(0, 3.05, 0)), C.Gold)
		local model = WeaponModels.build("Paragon", name)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		model:PivotTo(CFrame.new(base + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, math.rad(90), math.rad(-15)))
		model.Parent = lobby
		local pal = Config.Palettes[name]
		local price = pal.price == 0 and "FREE" or pal.price and (pal.price .. " COINS") or "ROBUX"
		local facing = Vector3.new(0, 0, -math.sign(base.Z)) -- toward the walkway
		Props.sign(lobby, base + Vector3.new(0, 1.5, 0) + facing * 2.05, facing, Vector2.new(3.8, 2.4), string.upper(name) .. "\n" .. price, C.Gold)
	end
	Props.sign(lobby, at(R + 60 - 0.4, 0, 12), Vector3.new(-1, 0, 0), Vector2.new(28, 9), "COSMETICS SHOP\nWalk in to browse", C.Gold)
end

local function buildQuestsArm(lobby: Model, at)
	Props.sign(lobby, at(R + 60 - 0.4, 0, 12), Vector3.new(1, 0, 0), Vector2.new(28, 12), "DAILY QUESTS\n3 new quests every day\nWalk in to see yours", C.Good)
	for _, lateral in { -14, 14 } do
		for along = 12, 48, 18 do
			local p = at(R + along, lateral, 0)
			Props.block(lobby, Vector3.new(2, WALL_H, 2), CFrame.new(p + Vector3.new(0, WALL_H / 2, 0)), C.MetalLight, "Pillar")
			Props.neon(lobby, Vector3.new(2.2, 0.4, 2.2), CFrame.new(p + Vector3.new(0, 6, 0)), C.Good)
		end
	end
end

local function buildRangeArm(lobby: Model, at)
	local padCenter = at(R + 28, 0, 0)
	Props.glowPad(lobby, padCenter, C.Ally)
	Props.sign(lobby, at(R + 40 - 0.4, 0, 10), Vector3.new(0, 0, 1), Vector2.new(20, 7), "FIRING RANGE\nStep on the pad to teleport", C.Ally)
	local c = L.Range.center
	local arrive = Vector3.new(c.X, 3, c.Z + L.Range.size.Z / 2 - 6)
	table.insert(World.teleports, {
		center = padCenter + Vector3.new(0, 0.35, 0),
		target = CFrame.lookAt(arrive, arrive + Vector3.new(0, 0, -1)),
	})
end

local function buildLobby(lobby: Model)
	buildHub(lobby)
	for _, arm in ARMS do
		local at = buildArm(lobby, arm)
		if arm.key == "Pads" then
			buildPadsArm(lobby, at)
		elseif arm.key == "Shop" then
			buildShopArm(lobby, at)
		elseif arm.key == "Quests" then
			buildQuestsArm(lobby, at)
		else
			buildRangeArm(lobby, at)
		end
	end
	Range.build(lobby, World.teleports)
end

---------------------------------------------------------------- arenas

function World.createArena()
	return Arena.create(map)
end

World.destroyArena = Arena.destroy

---------------------------------------------------------------- setup

function World.build()
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	-- Everything is indoors: no sun, dark ambient, light comes from neon and ceiling panels.
	-- (Lighting.Technology = Future is set in default.project.json; scripts can't change it.)
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(38, 40, 54)
	Lighting.OutdoorAmbient = Color3.fromRGB(38, 40, 54)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0.25
	Lighting.GlobalShadows = true
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 0.92
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.12
	grade.Saturation = 0.08
	grade.TintColor = Color3.fromRGB(236, 238, 255)
	grade.Parent = Lighting

	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	buildLobby(lobby)
	lobby.Parent = map
end

function World.setBoard(lines: { string })
	board.Text = "WEEKLY WINS\n" .. table.concat(lines, "\n")
end

return World
