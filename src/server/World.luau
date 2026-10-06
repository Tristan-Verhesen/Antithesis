-- Builds the + shaped lobby (hub + pads, shop, quests and range-teleport arms), the separate firing range,
-- and creates/destroys an arena per match.
-- Everything is generated from code, so the place needs no manual building.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)

local C = Config.Colors
local GRAY = Color3.fromRGB(120, 122, 128)

-- Half-arena layouts (x < 0). Boxes are mirrored across x = 0; boxes with x == 0 are center pieces.
-- {x, z, sizeX, sizeY, sizeZ, baseY?}
local LAYOUTS = {
	{
		name = "Fulcrum",
		size = { 90, 60 },
		spawnX = 40,
		boxes = {
			{ -34, 0, 1, 6, 10 }, -- spawn shield
			{ -22, -22, 4, 3, 4 }, -- long lane
			{ -9, -25, 3, 4, 6 },
			{ -18, -13, 24, 10, 1 }, -- long/mid divider
			{ 0, 0, 16, 3, 10 }, -- central bridge
			{ -14, 4, 4, 4, 4 }, -- mid lane
			{ -26, -5, 3, 5, 3 },
			{ -18, 13, 28, 10, 1 }, -- mid/close divider
			{ -30, 20, 2, 10, 8 }, -- close-quarters lane
			{ -21, 25, 8, 10, 2 },
			{ -12, 18, 2, 10, 8 },
			{ -5, 26, 6, 10, 2 },
			{ 0, 20, 2, 10, 6 },
		},
	},
	{
		name = "Mirrorline",
		size = { 120, 90 },
		spawnX = 55,
		boxes = {
			{ -48, 0, 1, 6, 12 }, -- spawn shield
			{ -40, -20, 2, 12, 2 },
			{ -40, 20, 2, 12, 2 },
			{ -25, 0, 2, 12, 2 },
			{ -12, -30, 2, 12, 2 },
			{ -12, 30, 2, 12, 2 },
			{ -30, -32, 14, 3, 14 }, -- stepped platforms
			{ -33, -35, 6, 6, 6 },
			{ -30, 32, 14, 3, 14 },
			{ -33, 35, 6, 6, 6 },
			{ -20, -15, 1, 8, 14 },
			{ -20, 15, 1, 8, 14 },
			{ -8, -12, 4, 4, 4 },
			{ -8, 12, 4, 4, 4 },
			{ 0, 0, 10, 3, 30 }, -- center platform + pillar
			{ 0, 0, 4, 8, 4 },
			{ 0, -38, 6, 4, 6 },
			{ 0, 38, 6, 4, 6 },
		},
	},
}

local World = {}
World.stations = {}
World.teleports = {} -- { center = Vector3, target = CFrame }

local map: Folder
local board: TextLabel
local usedSlots = {}

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name or "Block"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = block(parent, size, cf, color, "Neon", Enum.Material.Neon)
	p.CastShadow = false
	return p
end

-- Flat vertical-axis cylinder (pads, rings).
local function disc(parent: Instance, center: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material?): Part
	local p = block(parent, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, "Disc", material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function walls(parent: Instance, origin: Vector3, sx: number, sz: number, height: number, color: Color3)
	block(parent, Vector3.new(sx + 2, height, 1), CFrame.new(origin + Vector3.new(0, height / 2, sz / 2 + 0.5)), color)
	block(parent, Vector3.new(sx + 2, height, 1), CFrame.new(origin + Vector3.new(0, height / 2, -sz / 2 - 0.5)), color)
	block(parent, Vector3.new(1, height, sz), CFrame.new(origin + Vector3.new(sx / 2 + 0.5, height / 2, 0)), color)
	block(parent, Vector3.new(1, height, sz), CFrame.new(origin + Vector3.new(-sx / 2 - 0.5, height / 2, 0)), color)
end

-- A flat sign whose front face looks along `facing`.
local function sign(parent: Instance, pos: Vector3, facing: Vector3, size: Vector2, text: string, color: Color3?): TextLabel
	local part = block(parent, Vector3.new(size.X, size.Y, 0.4), CFrame.lookAt(pos, pos + facing), C.Metal, "Sign")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or C.Light
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return label
end

local function dummy(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Dummy"
	local function limb(name, size, offset, color)
		return block(m, size, CFrame.new(pos + offset), color, name)
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

local function glowPad(parent: Instance, center: Vector3, color: Color3): Part
	local ring = disc(parent, center + Vector3.new(0, 0.11, 0), 10, 0.12, color, Enum.Material.Neon)
	disc(parent, center + Vector3.new(0, 0.2, 0), 8.6, 0.3, C.Metal)
	disc(parent, center + Vector3.new(0, 0.21, 0), 3, 0.32, color, Enum.Material.Neon)
	return ring
end

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

	block(lobby, Vector3.new(14, 0.1, 32), CFrame.new(x, 0.05, zc), C.MetalLight, "StationPlate")
	sign(lobby, Vector3.new(wallX, 16, zc), inward, Vector2.new(10, 3.5), cfg.label, C.Purple)
	for team, dz in { -7, 7 } do
		local color = team == 1 and C.Ally or C.Enemy
		local center = Vector3.new(x, 0, zc + dz)
		local ring = glowPad(lobby, center, color)
		local label = sign(lobby, Vector3.new(wallX, 9, zc + dz), inward, Vector2.new(9, 5.5), "0/" .. cfg.teamSize, color)
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
	block(lobby, Vector3.new(w, 1, len + 2), CFrame.lookAt(at(mid - 1, 0, -0.5), at(mid - 1, 0, -0.5) + dir), C.Metal, "Floor")
	for _, sideSign in { -1, 1 } do
		local wallPos = at(mid, sideSign * (w / 2 + 0.5), WALL_H / 2)
		block(lobby, Vector3.new(1, WALL_H, len), CFrame.lookAt(wallPos, wallPos + dir), C.MetalLight)
		for _, y in { 1, 20 } do
			local trimPos = at(mid, sideSign * (w / 2 - 0.1), y)
			neon(lobby, Vector3.new(0.3, 0.4, len), CFrame.lookAt(trimPos, trimPos + dir), arm.trim)
		end
	end
	local endPos = at(e + 0.5, 0, WALL_H / 2)
	block(lobby, Vector3.new(w + 2, WALL_H, 1), CFrame.lookAt(endPos, endPos + dir), C.MetalLight)
	sign(lobby, at(R + 1, 0, 19), -dir, Vector2.new(math.min(w - 6, 30), 4), arm.title, arm.trim)
	return at, e
end

local function buildHub(lobby: Model)
	disc(lobby, Vector3.new(0, -0.5, 0), R * 2 + 2, 1, C.Metal)
	disc(lobby, Vector3.new(0, 0.03, 0), R * 2 - 4, 0.06, C.Purple, Enum.Material.Neon)
	disc(lobby, Vector3.new(0, 0.04, 0), R * 2 - 6, 0.08, C.Metal)

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
			block(lobby, Vector3.new(segment, WALL_H, 1), CFrame.lookAt(wallPos, Vector3.new(0, WALL_H / 2, 0)), C.MetalLight)
			local trimPos = p * ((R - 0.1) / (R + 0.5)) + Vector3.new(0, 1, 0)
			neon(lobby, Vector3.new(segment, 0.4, 0.3), CFrame.lookAt(trimPos, Vector3.new(0, 1, 0)), C.Purple)
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
	block(lobby, Vector3.new(12, 0.05, 170), CFrame.new(0, 0.025, R + 85), Color3.fromRGB(12, 12, 16), "Walkway")
	neon(lobby, Vector3.new(0.4, 0.06, 170), CFrame.new(-6, 0.03, R + 85), C.Purple)
	neon(lobby, Vector3.new(0.4, 0.06, 170), CFrame.new(6, 0.03, R + 85), C.Gold)
	for i, mode in L.Stations do
		buildStation(lobby, i, mode)
	end
	board = sign(lobby, at(R + 170 - 0.4, 0, 12), Vector3.new(0, 0, -1), Vector2.new(24, 16), "WEEKLY WINS", C.Light)
	sign(lobby, Vector3.new(-29.6, 10, R + 6), Vector3.new(1, 0, 0), Vector2.new(14, 9),
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
		block(lobby, Vector3.new(4, 3, 4), CFrame.new(base + Vector3.new(0, 1.5, 0)), C.MetalLight, "Pedestal")
		neon(lobby, Vector3.new(4.2, 0.2, 4.2), CFrame.new(base + Vector3.new(0, 3.05, 0)), C.Gold)
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
		sign(lobby, base + Vector3.new(0, 1.5, 0) + facing * 2.05, facing, Vector2.new(3.8, 2.4), string.upper(name) .. "\n" .. price, C.Gold)
	end
	sign(lobby, at(R + 60 - 0.4, 0, 12), Vector3.new(-1, 0, 0), Vector2.new(28, 9), "COSMETICS SHOP\nWalk in to browse", C.Gold)
end

local function buildQuestsArm(lobby: Model, at)
	sign(lobby, at(R + 60 - 0.4, 0, 12), Vector3.new(1, 0, 0), Vector2.new(28, 12), "DAILY QUESTS\n3 new quests every day\nWalk in to see yours", C.Good)
	for _, lateral in { -14, 14 } do
		for along = 12, 48, 18 do
			local p = at(R + along, lateral, 0)
			block(lobby, Vector3.new(2, WALL_H, 2), CFrame.new(p + Vector3.new(0, WALL_H / 2, 0)), C.MetalLight, "Pillar")
			neon(lobby, Vector3.new(2.2, 0.4, 2.2), CFrame.new(p + Vector3.new(0, 6, 0)), C.Good)
		end
	end
end

local function buildRangeArm(lobby: Model, at)
	local padCenter = at(R + 28, 0, 0)
	glowPad(lobby, padCenter, C.Ally)
	sign(lobby, at(R + 40 - 0.4, 0, 10), Vector3.new(0, 0, 1), Vector2.new(20, 7), "FIRING RANGE\nStep on the pad to teleport", C.Ally)
	local c = L.Range.center
	local arrive = Vector3.new(c.X, 3, c.Z + L.Range.size.Z / 2 - 6)
	table.insert(World.teleports, {
		center = padCenter + Vector3.new(0, 0.35, 0),
		target = CFrame.lookAt(arrive, arrive + Vector3.new(0, 0, -1)),
	})
end

-- The firing range is a separate room 200 studs past the lobby; a pad inside teleports back.
local function buildRange(lobby: Model)
	local c, size = L.Range.center, L.Range.size
	local front, back = c.Z + size.Z / 2, c.Z - size.Z / 2
	block(lobby, Vector3.new(size.X, 1, size.Z), CFrame.new(c.X, -0.5, c.Z), C.MetalLight, "RangeFloor")
	walls(lobby, Vector3.new(c.X, 0, c.Z), size.X, size.Z, WALL_H, C.MetalLight)
	block(lobby, Vector3.new(30, 0.05, size.Z), CFrame.new(c.X, 0.025, c.Z), C.Metal, "RangeLane")
	local line = front - 12
	neon(lobby, Vector3.new(30, 0.06, 0.5), CFrame.new(c.X, 0.03, line), C.Gold)

	local backPad = Vector3.new(c.X + 22, 0, front - 6)
	glowPad(lobby, backPad, C.Purple)
	sign(lobby, Vector3.new(c.X + 22, 9, front - 0.4), Vector3.new(0, 0, -1), Vector2.new(12, 4), "BACK TO LOBBY", C.Purple)
	local lobbyArrive = Vector3.new(0, 3, -(R + 8))
	table.insert(World.teleports, {
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
	buildRange(lobby)
end

---------------------------------------------------------------- arenas

function World.createArena(): { [string]: any }
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local layout = LAYOUTS[math.random(#LAYOUTS)]
	local origin = Vector3.new(1000 + 500 * slot, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Arena" .. slot
	local sx, sz = layout.size[1], layout.size[2]
	block(model, Vector3.new(sx / 2, 1, sz), CFrame.new(origin + Vector3.new(-sx / 4, -0.5, 0)), C.Light, "Floor")
	block(model, Vector3.new(sx / 2, 1, sz), CFrame.new(origin + Vector3.new(sx / 4, -0.5, 0)), C.Dark, "Floor")
	block(model, Vector3.new(0.4, 0.05, sz), CFrame.new(origin + Vector3.new(0, 0.025, 0)), C.Gold, "CenterLine")
	walls(model, origin, sx, sz, 20, GRAY)

	for _, b in layout.boxes do
		local size = Vector3.new(b[3], b[4], b[5])
		local y = (b[6] or 0) + b[4] / 2
		if b[1] == 0 then
			block(model, size, CFrame.new(origin + Vector3.new(0, y, b[2])), GRAY)
		else
			block(model, size, CFrame.new(origin + Vector3.new(b[1], y, b[2])), C.Dark)
			block(model, size, CFrame.new(origin + Vector3.new(-b[1], y, b[2])), C.Light)
		end
	end

	local function spawnAt(x: number, z: number): CFrame
		local pos = origin + Vector3.new(x, 3, z)
		return CFrame.lookAt(pos, pos + Vector3.new(-math.sign(x), 0, 0))
	end
	local s = layout.spawnX
	model.Parent = map
	return {
		slot = slot,
		model = model,
		name = layout.name,
		origin = origin,
		radius = math.sqrt((sx / 2) ^ 2 + (sz / 2) ^ 2),
		spawns = {
			{ spawnAt(-s, -4), spawnAt(-s, 4) },
			{ spawnAt(s, -4), spawnAt(s, 4) },
		},
	}
end

function World.destroyArena(arena)
	arena.model:Destroy()
	usedSlots[arena.slot] = nil
end

---------------------------------------------------------------- setup

function World.build()
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 14
	Lighting.Brightness = 1.5
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 125)
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 0.95
	bloom.Parent = Lighting

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
