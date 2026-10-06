-- Builds the lobby hall (pad stations + firing range room) and creates/destroys an arena per match.
-- Everything is generated from code, so the place needs no manual building.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

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
	hum.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Dummy", true)
	m.Parent = parent
end

---------------------------------------------------------------- lobby

local function buildStation(lobby: Model, index: number, mode: string)
	local half = math.ceil(#Config.Lobby.Stations / 2)
	local side = index <= half and -1 or 1 -- left wall first, then right wall
	local row = (index - 1) % half
	local zc = 50 - row * 50
	local x = side * 26
	local wallX = side * 39.6
	local inward = Vector3.new(-side, 0, 0)
	local cfg = Config.Modes[mode]
	local station = { mode = mode, size = cfg.teamSize, pads = {}, startsAt = nil }

	block(lobby, Vector3.new(14, 0.1, 32), CFrame.new(x, 0.05, zc), C.MetalLight, "StationPlate")
	sign(lobby, Vector3.new(wallX, 16, zc), inward, Vector2.new(10, 3.5), cfg.label, C.Purple)
	for team, dz in { -7, 7 } do
		local color = team == 1 and C.Ally or C.Enemy
		local center = Vector3.new(x, 0, zc + dz)
		local ring = disc(lobby, center + Vector3.new(0, 0.11, 0), 10, 0.12, color, Enum.Material.Neon)
		disc(lobby, center + Vector3.new(0, 0.2, 0), 8.6, 0.3, C.Metal)
		disc(lobby, center + Vector3.new(0, 0.21, 0), 3, 0.32, color, Enum.Material.Neon)
		local label = sign(lobby, Vector3.new(wallX, 9, zc + dz), inward, Vector2.new(9, 5.5), "0/" .. cfg.teamSize, color)
		table.insert(station.pads, { center = center + Vector3.new(0, 0.35, 0), board = label, ring = ring, color = color, occupants = {} })
	end
	table.insert(World.stations, station)
end

local function buildHall(lobby: Model)
	block(lobby, Vector3.new(80, 1, 200), CFrame.new(0, -0.5, 0), C.Metal, "Floor")
	block(lobby, Vector3.new(16, 0.05, 200), CFrame.new(0, 0.025, 0), Color3.fromRGB(12, 12, 16), "Walkway")
	neon(lobby, Vector3.new(0.4, 0.06, 200), CFrame.new(-8, 0.03, 0), C.Purple)
	neon(lobby, Vector3.new(0.4, 0.06, 200), CFrame.new(8, 0.03, 0), C.Gold)
	for z = -80, 80, 20 do -- chevrons pointing toward the range door
		neon(lobby, Vector3.new(0.5, 0.07, 4), CFrame.new(-1.3, 0.035, z) * CFrame.Angles(0, math.rad(-35), 0), C.Light)
		neon(lobby, Vector3.new(0.5, 0.07, 4), CFrame.new(1.3, 0.035, z) * CFrame.Angles(0, math.rad(35), 0), C.Light)
	end

	-- Walls with neon trims; the back wall has a door to the firing range.
	block(lobby, Vector3.new(1, 30, 200), CFrame.new(-40.5, 15, 0), C.MetalLight)
	block(lobby, Vector3.new(1, 30, 200), CFrame.new(40.5, 15, 0), C.MetalLight)
	block(lobby, Vector3.new(82, 30, 1), CFrame.new(0, 15, 100.5), C.MetalLight)
	block(lobby, Vector3.new(30, 30, 1), CFrame.new(-25, 15, -100.5), C.MetalLight)
	block(lobby, Vector3.new(30, 30, 1), CFrame.new(25, 15, -100.5), C.MetalLight)
	block(lobby, Vector3.new(20, 18, 1), CFrame.new(0, 21, -100.5), C.MetalLight)
	for _, sx in { -1, 1 } do
		neon(lobby, Vector3.new(0.3, 0.4, 200), CFrame.new(sx * 39.9, 1, 0), C.Gold)
		neon(lobby, Vector3.new(0.3, 0.4, 200), CFrame.new(sx * 39.9, 24, 0), C.Purple)
	end
	neon(lobby, Vector3.new(20, 0.4, 0.3), CFrame.new(0, 12, -99.9), C.Purple)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 88), Vector3.new(0, 0.5, 0))
	spawn.Color = C.Purple
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby

	local forward = Vector3.new(0, 0, 1)
	sign(lobby, Vector3.new(0, 23, -99.8), forward, Vector2.new(36, 7), "ANTITHESIS", C.Light)
	sign(lobby, Vector3.new(0, 14, -99.8), forward, Vector2.new(16, 2.5), "FIRING RANGE", C.Gold)
	board = sign(lobby, Vector3.new(-39.6, 12, 80), Vector3.new(1, 0, 0), Vector2.new(24, 16), "WEEKLY WINS", C.Light)
	sign(lobby, Vector3.new(39.6, 12, 80), Vector3.new(-1, 0, 0), Vector2.new(24, 14),
		"STAND ON A PAD TO QUEUE\nFirst to 5 rounds wins\n[M] Loadout   •   Shop on the left\nHold E near a player to challenge", C.Light)

	for i, mode in Config.Lobby.Stations do
		buildStation(lobby, i, mode)
	end
end

local function buildRange(lobby: Model)
	local c, s = Config.Lobby.RangeCenter, Config.Lobby.RangeSize
	local front, back = c.Z + s.Z / 2, c.Z - s.Z / 2
	block(lobby, Vector3.new(s.X, 1, s.Z), CFrame.new(c.X, -0.5, c.Z), C.MetalLight, "RangeFloor")
	block(lobby, Vector3.new(1, 24, s.Z), CFrame.new(c.X - s.X / 2 - 0.5, 12, c.Z), C.MetalLight)
	block(lobby, Vector3.new(1, 24, s.Z), CFrame.new(c.X + s.X / 2 + 0.5, 12, c.Z), C.MetalLight)
	block(lobby, Vector3.new(s.X + 2, 24, 1), CFrame.new(c.X, 12, back - 0.5), C.MetalLight)
	block(lobby, Vector3.new(30, 0.05, s.Z), CFrame.new(c.X, 0.025, c.Z), C.Metal, "RangeLane")
	local line = front - 8
	neon(lobby, Vector3.new(30, 0.06, 0.5), CFrame.new(c.X, 0.03, line), C.Gold)

	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	for i, d in { 15, 30, 45, 60, 75 } do
		dummy(dummies, Vector3.new(({ -10, 8, -4, 10, 0 })[i], 0, line - d))
	end
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
	buildHall(lobby)
	buildRange(lobby)
	lobby.Parent = map
end

function World.setBoard(lines: { string })
	board.Text = "WEEKLY WINS\n" .. table.concat(lines, "\n")
end

return World
