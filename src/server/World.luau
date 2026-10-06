-- Builds the lobby (with firing range) and 4 arenas from code, so the place needs no manual building.
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
World.arenas = {}

local board: TextLabel

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Block"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function walls(parent: Instance, origin: Vector3, sx: number, sz: number, height: number)
	block(parent, Vector3.new(sx + 2, height, 1), CFrame.new(origin + Vector3.new(0, height / 2, sz / 2 + 0.5)), GRAY)
	block(parent, Vector3.new(sx + 2, height, 1), CFrame.new(origin + Vector3.new(0, height / 2, -sz / 2 - 0.5)), GRAY)
	block(parent, Vector3.new(1, height, sz), CFrame.new(origin + Vector3.new(sx / 2 + 0.5, height / 2, 0)), GRAY)
	block(parent, Vector3.new(1, height, sz), CFrame.new(origin + Vector3.new(-sx / 2 - 0.5, height / 2, 0)), GRAY)
end

local function sign(parent: Instance, cf: CFrame, size: Vector2, text: string, textSize: number): TextLabel
	local part = block(parent, Vector3.new(size.X, size.Y, 0.5), cf, C.Dark, "Sign")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 25
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = C.Light
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	return label
end

local function dummy(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Dummy"
	local function limb(name, size, offset, color)
		local p = block(m, size, CFrame.new(pos + offset), color, name)
		return p
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

local function buildLobby(map: Folder)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	block(lobby, Vector3.new(120, 1, 200), CFrame.new(0, -0.5, 0), C.Light, "Floor")
	block(lobby, Vector3.new(30, 0.05, 150), CFrame.new(0, 0.025, -15), C.Dark, "RangeLane")
	block(lobby, Vector3.new(30, 0.05, 0.6), CFrame.new(0, 0.05, 60), C.Gold, "FiringLine")
	walls(lobby, Vector3.zero, 120, 200, 24)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 80), Vector3.new(0, 0.5, 0))
	spawn.Color = C.Ally
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby

	local x = -59.5
	sign(lobby, CFrame.lookAt(Vector3.new(x, 12, 50), Vector3.new(0, 12, 50)), Vector2.new(40, 10),
		"ANTITHESIS\nEvery loadout has an answer.", 80)
	sign(lobby, CFrame.lookAt(Vector3.new(x, 12, 0), Vector3.new(0, 12, 0)), Vector2.new(40, 12),
		"[M] or the MENU button: queue Duel / Doubles, open the Shop\nWalk up to a player to CHALLENGE them\nShoot the dummies to warm up", 45)
	board = sign(lobby, CFrame.lookAt(Vector3.new(-x, 12, 30), Vector3.new(0, 12, 30)), Vector2.new(30, 20), "WEEKLY WINS\n...", 40)

	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	for i, d in { 20, 40, 70, 110, 150 } do
		dummy(dummies, Vector3.new(({ -10, 8, -4, 10, 0 })[i], 0, 60 - d))
	end
	lobby.Parent = map
end

local function buildArena(map: Folder, index: number, layout)
	local origin = Vector3.new(500 * index, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Arena" .. index
	local sx, sz = layout.size[1], layout.size[2]
	block(model, Vector3.new(sx / 2, 1, sz), CFrame.new(origin + Vector3.new(-sx / 4, -0.5, 0)), C.Light, "Floor")
	block(model, Vector3.new(sx / 2, 1, sz), CFrame.new(origin + Vector3.new(sx / 4, -0.5, 0)), C.Dark, "Floor")
	block(model, Vector3.new(0.4, 0.05, sz), CFrame.new(origin + Vector3.new(0, 0.025, 0)), C.Gold, "CenterLine")
	walls(model, origin, sx, sz, 20)

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
	table.insert(World.arenas, {
		index = index,
		name = layout.name,
		origin = origin,
		radius = math.sqrt((sx / 2) ^ 2 + (sz / 2) ^ 2),
		spawns = {
			{ spawnAt(-s, -4), spawnAt(-s, 4) },
			{ spawnAt(s, -4), spawnAt(s, 4) },
		},
		busy = false,
	})
	model.Parent = map
end

function World.build()
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildLobby(map)
	for i = 1, 4 do
		buildArena(map, i, LAYOUTS[(i - 1) % #LAYOUTS + 1])
	end
end

function World.setBoard(lines: { string })
	board.Text = "WEEKLY WINS\n" .. table.concat(lines, "\n")
end

return World
