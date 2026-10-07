-- The separate firing range room (first person + weapons): a fully closed sci-fi hall with a lit firing-line
-- booth, a distance-marked lane, detailed training bots and a portal pad back to the lobby.
--
-- Shot safety: between the player area and the bots nothing taller than the 1-stud counters collides or is
-- queryable. Everything decorative goes through Props.decor, so only the floor, walls, ceiling, counters and
-- the bots' hit parts can stop a ray.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

local C = Config.Colors
local L = Config.Lobby
local R = L.HubRadius
local WALL_H = 24
local DISTANCES = { 15, 30, 45, 60, 75 } -- bot distances from the firing line
local OFFSETS = { -10, 8, -4, 10, 0 } -- bot x offsets, one per distance
local MARKS = { 0, 15, 30, 45, 60, 75 } -- wall pilasters / ceiling ribs (firing line + each distance)
local Range = {}

local METAL = Enum.Material.Metal
local PLATE = Enum.Material.DiamondPlate
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

local DEEP = Color3.fromRGB(17, 18, 23) -- recessed panel insets
local LANE = Color3.fromRGB(21, 23, 28)
local BOT = Color3.fromRGB(72, 76, 88) -- bot body (hit parts)
local STEEL = Color3.fromRGB(98, 102, 116) -- bot armor plates
local LAMP = Color3.fromRGB(214, 230, 255) -- cool white ceiling light
local SCREEN = Color3.fromRGB(16, 66, 84) -- dim holo screens
local VISOR = Color3.fromRGB(12, 18, 26)
local PORTAL = Color3.fromRGB(34, 16, 52)
local BOOTH_GLASS = Color3.fromRGB(96, 160, 190)

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis vertical
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis along Z

---------------------------------------------------------------- helpers

-- Visual-only block: never collides, blocks shots or triggers touches.
local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Props.block(parent, size, cf, color, "Decor", material or METAL)
	Props.decor(p)
	return p
end

local function glow(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Props.neon(parent, size, cf, color)
	Props.decor(p)
	return p
end

-- Decor cylinder; its axis is the CFrame's X axis (use UP / ALONG_Z to turn it).
local function cylinder(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = deco(parent, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	if material == NEON then
		p.CastShadow = false
	end
	return p
end

local function ball(parent: Instance, diameter: number, pos: Vector3, color: Color3): Part
	local p = glow(parent, Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Decor wedge whose slope faces the horizontal `dir`; `flip` hangs it upside down (a bracket under a beam).
local function wedge(parent: Instance, size: Vector3, center: Vector3, dir: Vector3, color: Color3, flip: boolean?, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = "Decor"
	w.Anchored = true
	w.Size = size
	w.CFrame = CFrame.lookAt(center, center + dir) * (if flip then CFrame.Angles(0, 0, math.pi) else CFrame.identity)
	w.Color = color
	w.Material = material or METAL
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	Props.decor(w)
	w.Parent = parent
	return w
end

-- Decor sign (Props.sign makes a solid one).
local function sign(parent: Instance, pos: Vector3, facing: Vector3, size: Vector2, text: string, color: Color3?): TextLabel
	local label = Props.sign(parent, pos, facing, size, text, color)
	local gui = label.Parent
	local part = gui and gui.Parent
	if part and part:IsA("BasePart") then
		Props.decor(part)
	end
	return label
end

-- Ceiling light panel (decor) with a chosen shadow setting.
local function panel(parent: Instance, cf: CFrame, size: Vector3, brightness: number, range: number, shadows: boolean): Part
	local p = Props.lightPanel(parent, cf, size, LAMP, brightness, range)
	Props.decor(p)
	local light = p:FindFirstChildOfClass("SurfaceLight")
	if light then
		light.Shadows = shadows
	end
	return p
end

local function washLight(part: BasePart, face: Enum.NormalId, color: Color3, range: number, brightness: number)
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Angle = 110
	light.Shadows = false
	light.Parent = part
end

---------------------------------------------------------------- training bot

-- Hitbox contract (Combat): anchored R6-sized parts with the exact names, sizes and offsets below,
-- a Humanoid that Combat damages/refills, PrimaryPart facing +Z. Every extra part is decor (CanQuery = false)
-- and sits at most ~0.15 studs proud of the hit parts, so what you see is what you hit.
local function dummy(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Dummy"
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(pos + Vector3.new(x, y, z))
	end
	local function limb(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		return Props.block(m, size, CFrame.new(pos + offset), color, name, METAL)
	end
	local root = Props.block(m, Vector3.new(2, 2, 1), CFrame.new(pos + Vector3.new(0, 3, 0)), C.Dark, "HumanoidRootPart")
	root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, 1)) -- faces the firing line
	root.Transparency = 1
	root.CanQuery = false
	root.CanCollide = false
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), BOT)
	limb("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), BOT)
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), C.MetalLight)
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), C.MetalLight)
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), C.MetalLight)
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), C.MetalLight)

	-- Stand: base plate with a glow ring, and a support post clamped to the back unit.
	cylinder(m, 0.25, 3.6, at(0, 0.125, 0) * UP, C.Metal)
	cylinder(m, 0.08, 4, at(0, 0.04, 0) * UP, C.Enemy, NEON)
	deco(m, Vector3.new(0.4, 2.35, 0.4), at(0, 1.425, -0.95), C.Metal)
	deco(m, Vector3.new(0.6, 0.45, 0.4), at(0, 2.35, -0.75), STEEL)

	-- Torso armor: chest plate + reactor core, abdomen plate, waist band, back power unit with spine light.
	deco(m, Vector3.new(1.7, 1.05, 0.08), at(0, 3.4, 0.54), STEEL)
	cylinder(m, 0.06, 0.55, at(0, 3.4, 0.61) * ALONG_Z, C.Enemy, NEON)
	deco(m, Vector3.new(1.2, 0.5, 0.06), at(0, 2.55, 0.53), C.Metal)
	glow(m, Vector3.new(2.04, 0.12, 1.04), at(0, 2.12, 0), C.Enemy)
	deco(m, Vector3.new(1.4, 1.3, 0.12), at(0, 3.15, -0.56), STEEL)
	glow(m, Vector3.new(0.14, 0.9, 0.03), at(0, 3.2, -0.635), C.Enemy)

	-- Head: glass visor with glowing eyes, jaw grille, crest, ear pods and an antenna.
	deco(m, Vector3.new(1.8, 0.5, 0.06), at(0, 4.6, 0.53), VISOR, GLASS)
	glow(m, Vector3.new(0.34, 0.14, 0.05), at(-0.42, 4.6, 0.585), C.Enemy)
	glow(m, Vector3.new(0.34, 0.14, 0.05), at(0.42, 4.6, 0.585), C.Enemy)
	deco(m, Vector3.new(0.9, 0.18, 0.05), at(0, 4.2, 0.525), C.Metal)
	deco(m, Vector3.new(0.36, 0.12, 1.04), at(0, 5.06, 0), STEEL)
	cylinder(m, 0.9, 0.08, at(0.7, 5.45, -0.25) * UP, C.Metal)
	ball(m, 0.22, pos + Vector3.new(0.7, 5.95, -0.25), C.Enemy)

	for _, s in { -1, 1 } do
		cylinder(m, 0.12, 0.62, at(s * 1.06, 4.5, 0), STEEL) -- ear pod
		-- arms: shoulder pad, forearm guard, wrist light
		deco(m, Vector3.new(1.2, 0.55, 1.2), at(s * 1.55, 3.76, 0), STEEL)
		deco(m, Vector3.new(1.1, 0.7, 1.1), at(s * 1.5, 2.6, 0), STEEL)
		glow(m, Vector3.new(1.06, 0.1, 1.06), at(s * 1.5, 2.12, 0), C.Enemy)
		-- legs: thigh plate, knee guard, boot
		deco(m, Vector3.new(0.7, 0.5, 0.06), at(s * 0.5, 1.65, 0.53), C.Metal)
		deco(m, Vector3.new(0.84, 0.4, 0.1), at(s * 0.5, 1.15, 0.55), STEEL)
		deco(m, Vector3.new(1.06, 0.4, 1.2), at(s * 0.53, 0.45, 0.05), C.Metal)
	end

	local hum = Instance.new("Humanoid")
	hum.RequiresNeck = false -- anchored, unjointed limbs; otherwise the Humanoid dies on spawn
	hum.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Dummy", true)
	m.Parent = parent
end

---------------------------------------------------------------- room

-- Floor, four walls and a ceiling at WALL_H: fully closed, no sky anywhere.
local function buildShell(parent: Instance, c: Vector3, size: Vector3)
	Props.block(parent, Vector3.new(size.X + 2, 1, size.Z + 2), CFrame.new(c.X, -0.5, c.Z), C.Metal, "RangeFloor", PLATE)
	Props.block(parent, Vector3.new(size.X + 2, 1, size.Z + 2), CFrame.new(c.X, WALL_H + 0.5, c.Z), C.Metal, "RangeCeiling", METAL)
	for _, s in { -1, 1 } do
		Props.block(parent, Vector3.new(size.X + 2, WALL_H, 1), CFrame.new(c.X, WALL_H / 2, c.Z + s * (size.Z / 2 + 0.5)), C.Metal, "RangeWall", METAL)
		Props.block(parent, Vector3.new(1, WALL_H, size.Z), CFrame.new(c.X + s * (size.X / 2 + 0.5), WALL_H / 2, c.Z), C.Metal, "RangeWall", METAL)
	end
end

-- Flat floor graphics: player-area plating, the lane, its edges, the gold firing line and distance lines.
local function buildFloor(parent: Instance, c: Vector3, size: Vector3, front: number, back: number, line: number)
	deco(parent, Vector3.new(size.X, 0.04, front - line), CFrame.new(c.X, 0.02, (front + line) / 2), C.MetalLight, PLATE)
	local laneLen, laneZ = line - back, (line + back) / 2
	local lane = deco(parent, Vector3.new(30, 0.05, laneLen), CFrame.new(c.X, 0.025, laneZ), LANE, Enum.Material.SmoothPlastic)
	lane.Name = "RangeLane"
	for _, s in { -1, 1 } do
		glow(parent, Vector3.new(0.22, 0.07, laneLen), CFrame.new(c.X + s * 15, 0.035, laneZ), C.Ally)
	end
	glow(parent, Vector3.new(size.X, 0.08, 0.5), CFrame.new(c.X, 0.04, line), C.Gold)
	for _, d in DISTANCES do
		glow(parent, Vector3.new(30, 0.07, 0.22), CFrame.new(c.X, 0.035, line - d), C.Ally)
	end
end

-- Firing-line booth: four low counters (with gaps to walk downrange), a lit canopy, glass side screens
-- and a hanging FIRING LINE header. Only the 1-stud counter bases are solid.
local function buildBooth(parent: Instance, c: Vector3, front: number, line: number)
	local cz = line + 1.3
	for i, x in { -12, -4, 4, 12 } do
		local px = c.X + x
		Props.block(parent, Vector3.new(5, 1, 1.4), CFrame.new(px, 0.5, cz), C.MetalLight, "Counter", METAL)
		deco(parent, Vector3.new(5.3, 0.14, 1.7), CFrame.new(px, 1.07, cz - 0.1), C.Metal)
		glow(parent, Vector3.new(5.3, 0.08, 0.08), CFrame.new(px, 1.0, cz - 0.99), C.Gold)
		sign(parent, Vector3.new(px, 0.55, cz + 0.9), Vector3.new(0, 0, 1), Vector2.new(2.4, 0.6), "LANE " .. i, C.Ally)
		-- tilted holo screen facing the shooter
		deco(parent, Vector3.new(0.18, 0.5, 0.18), CFrame.new(px + 1.6, 1.39, cz), C.Metal)
		local screen = CFrame.new(px + 1.6, 1.95, cz) * CFrame.Angles(math.rad(-20), 0, 0)
		deco(parent, Vector3.new(1.5, 0.95, 0.08), screen, C.Metal)
		glow(parent, Vector3.new(1.3, 0.75, 0.04), screen * CFrame.new(0, 0, 0.06), SCREEN)
	end

	-- Canopy over the shooting stalls with two shadow-casting key lights.
	local edge = line - 1
	local mid = (front + edge) / 2
	deco(parent, Vector3.new(32, 0.8, front - edge), CFrame.new(c.X, 12.4, mid), C.Metal)
	deco(parent, Vector3.new(32.4, 1.6, 0.5), CFrame.new(c.X, 12.2, edge - 0.25), C.MetalLight)
	glow(parent, Vector3.new(32.4, 0.14, 0.12), CFrame.new(c.X, 11.33, edge - 0.25), C.Gold)
	glow(parent, Vector3.new(32.4, 0.12, 0.12), CFrame.new(c.X, 13.06, edge - 0.25), C.Ally)
	for _, s in { -1, 1 } do
		local x = c.X + s * 8
		deco(parent, Vector3.new(10, 0.1, 3.2), CFrame.new(x, 11.95, mid), DEEP)
		panel(parent, CFrame.new(x, 11.86, mid), Vector3.new(9, 0.08, 2.4), 1.6, 16, true)

		-- glass side screen + corner post
		local gx = c.X + s * 15.6
		deco(parent, Vector3.new(0.5, 0.8, 5), CFrame.new(gx, 0.4, line + 1.5), C.MetalLight)
		local pane = deco(parent, Vector3.new(0.2, 11.2, 4.6), CFrame.new(gx, 6.4, line + 1.7), BOOTH_GLASS, GLASS)
		pane.Transparency = 0.7
		deco(parent, Vector3.new(0.5, 12, 0.5), CFrame.new(gx, 6, line - 0.75), C.MetalLight)
		glow(parent, Vector3.new(0.12, 11, 0.12), CFrame.new(gx - s * 0.31, 6, line - 0.75), C.Ally)
	end
	for _, x in { -4.5, 4.5 } do
		deco(parent, Vector3.new(0.12, 2.9, 0.12), CFrame.new(c.X + x, 10.55, line - 0.9), C.MetalLight)
	end
	sign(parent, Vector3.new(c.X, 8.6, line - 0.9), Vector3.new(0, 0, 1), Vector2.new(11, 1.3), "FIRING LINE", C.Gold)
end

-- Wall behind the players: plating, neon bands, inset panels and an info board.
local function buildFrontWall(parent: Instance, c: Vector3, size: Vector3, front: number)
	deco(parent, Vector3.new(size.X, 1, 0.5), CFrame.new(c.X, 0.5, front - 0.25), C.MetalLight, PLATE)
	glow(parent, Vector3.new(size.X, 0.14, 0.12), CFrame.new(c.X, 1, front - 0.5), C.Ally)
	glow(parent, Vector3.new(size.X, 0.14, 0.1), CFrame.new(c.X, 18, front - 0.05), C.Ally)
	for _, x in { -10, 0, 10 } do
		deco(parent, Vector3.new(9, 9, 0.2), CFrame.new(c.X + x, 6.2, front - 0.1), C.MetalLight)
		deco(parent, Vector3.new(7.8, 7.8, 0.12), CFrame.new(c.X + x, 6.2, front - 0.26), DEEP)
		glow(parent, Vector3.new(7, 0.14, 0.06), CFrame.new(c.X + x, 8.6, front - 0.35), C.Ally)
	end
	sign(parent, Vector3.new(c.X - 23, 7, front - 0.4), Vector3.new(0, 0, -1), Vector2.new(11, 3.2), "TRAINING BOTS\nThey reset when destroyed", C.Ally)
	glow(parent, Vector3.new(11.5, 3.7, 0.1), CFrame.new(c.X - 23, 7, front - 0.15), C.Ally)
end

-- Return pad: glow pad, bezel, emitter nodes, a shimmering beam and a portal arch with the sign.
local function buildReturnPad(parent: Instance, backPad: Vector3, front: number)
	local ring = Props.glowPad(parent, backPad, C.Purple)
	Props.pointLight(ring, C.Purple, 16, 1.2)
	cylinder(parent, 0.1, 11.2, CFrame.new(backPad + Vector3.new(0, 0.05, 0)) * UP, C.MetalLight)
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local p = backPad + Vector3.new(math.cos(a) * 6.3, 0, math.sin(a) * 6.3)
		cylinder(parent, 0.6, 0.9, CFrame.new(p + Vector3.new(0, 0.3, 0)) * UP, C.MetalLight)
		cylinder(parent, 0.12, 0.6, CFrame.new(p + Vector3.new(0, 0.66, 0)) * UP, C.Purple, NEON)
	end
	local beam = cylinder(parent, 9, 8.2, CFrame.new(backPad + Vector3.new(0, 4.6, 0)) * UP, C.Purple, Enum.Material.ForceField)
	beam.CastShadow = false

	local ax = backPad.X
	for _, s in { -1, 1 } do
		deco(parent, Vector3.new(1.2, 11.6, 1.2), CFrame.new(ax + s * 6.8, 5.8, front - 0.6), C.MetalLight)
		glow(parent, Vector3.new(0.18, 10.2, 0.18), CFrame.new(ax + s * 6.1, 5.2, front - 0.3), C.Purple)
	end
	deco(parent, Vector3.new(14.8, 1.2, 1.4), CFrame.new(ax, 11, front - 0.7), C.MetalLight)
	glow(parent, Vector3.new(14.8, 0.14, 0.1), CFrame.new(ax, 10.5, front - 1.45), C.Purple)
	glow(parent, Vector3.new(12.4, 0.18, 0.18), CFrame.new(ax, 10.2, front - 0.3), C.Purple)
	deco(parent, Vector3.new(12.4, 10.4, 0.12), CFrame.new(ax, 5.2, front - 0.06), PORTAL)
	sign(parent, Vector3.new(ax, 7.6, front - 0.4), Vector3.new(0, 0, -1), Vector2.new(12, 4), "BACK TO LOBBY", C.Purple)
end

-- Side walls: pilasters at every distance mark, inset panels between them, neon bands, distance boards.
local function buildSideWalls(parent: Instance, c: Vector3, size: Vector3, front: number, back: number, line: number)
	local bays = { { front, line } }
	for i = 1, #MARKS - 1 do
		table.insert(bays, { line - MARKS[i], line - MARKS[i + 1] })
	end
	table.insert(bays, { line - MARKS[#MARKS], back })
	for _, s in { -1, 1 } do
		local wx = c.X + s * size.X / 2 -- inner face
		local function out(depth: number): number -- x `depth` studs out from the wall
			return wx - s * depth
		end
		deco(parent, Vector3.new(0.5, 1, size.Z), CFrame.new(out(0.25), 0.5, c.Z), C.MetalLight, PLATE)
		local low = glow(parent, Vector3.new(0.12, 0.14, size.Z), CFrame.new(out(0.5), 1, c.Z), C.Ally) -- skirting edge
		washLight(low, if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left, C.Ally, 12, 0.6)
		glow(parent, Vector3.new(0.1, 0.14, size.Z), CFrame.new(out(0.05), 14.2, c.Z), C.Ally)
		glow(parent, Vector3.new(0.1, 0.14, size.Z), CFrame.new(out(0.05), 22.4, c.Z), C.Purple)
		for _, d in MARKS do
			local z = line - d
			deco(parent, Vector3.new(0.8, WALL_H, 1.6), CFrame.new(out(0.4), WALL_H / 2, z), C.MetalLight)
			glow(parent, Vector3.new(0.1, 20, 0.25), CFrame.new(out(0.85), 11.5, z), C.Ally)
			wedge(parent, Vector3.new(1.6, 1.5, 0.8), Vector3.new(out(1.2), 22.05, z), Vector3.new(-s, 0, 0), C.MetalLight, true)
		end
		for _, bay in bays do
			local len = bay[1] - bay[2] - 2.6
			local mid = (bay[1] + bay[2]) / 2
			if len > 2 then
				deco(parent, Vector3.new(0.2, 11, len), CFrame.new(out(0.1), 7.7, mid), C.MetalLight)
				deco(parent, Vector3.new(0.12, 9.6, len - 1.2), CFrame.new(out(0.26), 7.7, mid), DEEP)
				glow(parent, Vector3.new(0.08, 0.16, len - 2), CFrame.new(out(0.36), 11, mid), C.Ally)
			end
		end
		-- Distance boards hang off each pilaster, angled 45 degrees toward the firing line.
		local facing = Vector3.new(-s, 0, 1).Unit
		for _, d in DISTANCES do
			local center = Vector3.new(out(0.95 + 1.556), 8, line - d - 1.856)
			sign(parent, center, facing, Vector2.new(4.4, 2.6), tostring(d), C.Light)
			glow(parent, Vector3.new(4.8, 3, 0.1), CFrame.lookAt(center - facing * 0.25, center), C.Ally)
		end
	end
end

-- Ceiling: ribs above the pilasters, lane-edge beams, light panels over the lane and the side aisles.
local function buildCeiling(parent: Instance, c: Vector3, size: Vector3, front: number, line: number)
	local y = WALL_H
	for _, d in MARKS do
		deco(parent, Vector3.new(size.X, 1.2, 1.6), CFrame.new(c.X, y - 0.6, line - d), C.MetalLight)
	end
	for _, s in { -1, 1 } do
		deco(parent, Vector3.new(1, 0.8, size.Z), CFrame.new(c.X + s * 15, y - 0.4, c.Z), C.MetalLight)
		glow(parent, Vector3.new(0.25, 0.1, size.Z), CFrame.new(c.X + s * 15, y - 0.85, c.Z), C.Ally)
		deco(parent, Vector3.new(9, 0.4, 3.8), CFrame.new(c.X + s * 23, y - 0.2, front - 6), DEEP)
		panel(parent, CFrame.new(c.X + s * 23, y - 0.5, front - 6), Vector3.new(8, 0.15, 3), 1.2, 28, false)
	end
	for i, d in DISTANCES do
		local z = line - d + 7.5 -- just in front of each bot, so its face is lit
		deco(parent, Vector3.new(13, 0.4, 3.4), CFrame.new(c.X, y - 0.2, z), DEEP)
		panel(parent, CFrame.new(c.X, y - 0.5, z), Vector3.new(12, 0.15, 2.6), 2, 30, i == 2 or i == 4)
	end
end

-- Backstop: sloped berm, a big glowing target emblem, flanking panels and the room title.
local function buildBackWall(parent: Instance, c: Vector3, size: Vector3, back: number)
	wedge(parent, Vector3.new(size.X, 2.4, 3), Vector3.new(c.X, 1.2, back + 1.5), Vector3.new(0, 0, 1), C.Metal, false, PLATE)
	glow(parent, Vector3.new(size.X, 0.12, 0.12), CFrame.new(c.X, 2.46, back + 0.08), C.Enemy)
	glow(parent, Vector3.new(size.X, 0.14, 0.1), CFrame.new(c.X, 22.6, back + 0.05), C.Purple)

	local emblem = Vector3.new(c.X, 12, back)
	local rings = { -- stacked discs, each 0.1 further out: back plate, rings, bullseye
		{ d = 13, color = C.MetalLight, material = METAL },
		{ d = 12, color = C.Enemy, material = NEON },
		{ d = 10.4, color = DEEP, material = METAL },
		{ d = 7, color = C.Enemy, material = NEON },
		{ d = 5.4, color = DEEP, material = METAL },
	}
	for i, r in rings do
		cylinder(parent, 0.1, r.d, CFrame.new(emblem + Vector3.new(0, 0, 0.1 * i - 0.05)) * ALONG_Z, r.color, r.material)
	end
	local core = cylinder(parent, 0.1, 2.2, CFrame.new(emblem + Vector3.new(0, 0, 0.1 * #rings + 0.05)) * ALONG_Z, C.Gold, NEON)
	Props.pointLight(core, C.Enemy, 20, 0.8)

	for _, s in { -1, 1 } do
		local px = c.X + s * 18
		deco(parent, Vector3.new(21, 13, 0.2), CFrame.new(px, 10.3, back + 0.1), C.MetalLight)
		deco(parent, Vector3.new(19.6, 11.6, 0.12), CFrame.new(px, 10.3, back + 0.26), DEEP)
		glow(parent, Vector3.new(18.6, 0.14, 0.06), CFrame.new(px, 7.4, back + 0.35), C.Ally)
		glow(parent, Vector3.new(18.6, 0.14, 0.06), CFrame.new(px, 13.2, back + 0.35), C.Ally)
		glow(parent, Vector3.new(0.18, 14, 0.1), CFrame.new(c.X + s * 7.1, 10.5, back + 0.05), C.Enemy)
	end
	sign(parent, Vector3.new(c.X, 20.4, back + 0.3), Vector3.new(0, 0, 1), Vector2.new(22, 3.2), "FIRING RANGE", C.Ally)
end

-- The firing range is a separate room 200 studs past the lobby; a pad inside teleports back.
-- Lights: 13 (booth 2 + lane 5 + aisles 2 + wall wash 2 + pad + emblem), 4 with shadows.
function Range.build(lobby: Model, teleports)
	local c, size = L.Range.center, L.Range.size
	local front, back = c.Z + size.Z / 2, c.Z - size.Z / 2
	local line = front - 12
	assert(back < line - 75, "range too short for dummies")

	buildShell(lobby, c, size)
	buildFloor(lobby, c, size, front, back, line)
	buildBooth(lobby, c, front, line)
	buildFrontWall(lobby, c, size, front)
	buildSideWalls(lobby, c, size, front, back, line)
	buildCeiling(lobby, c, size, front, line)
	buildBackWall(lobby, c, size, back)

	-- Arrival from the lobby is (0, 3, front - 6) facing -Z: that spot stays clear, the pad is off to the side.
	local backPad = Vector3.new(c.X + 22, 0, front - 6)
	buildReturnPad(lobby, backPad, front)
	local lobbyArrive = Vector3.new(0, 3, -(R + 8))
	table.insert(teleports, {
		center = backPad + Vector3.new(0, 0.35, 0),
		target = CFrame.lookAt(lobbyArrive, Vector3.new(0, 3, 0)),
	})

	-- Not inside Map: Map is the line-of-sight blocker set.
	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	for i, d in DISTANCES do
		dummy(dummies, Vector3.new(c.X + OFFSETS[i], 0, line - d))
	end
end

return Range
