-- Builds the + shaped lobby (round hub + PLAY, SHOP, QUESTS and range-teleport arms) and the lighting,
-- and hands out arenas. Everything is generated from code, so the place needs no manual building.
-- The lobby is a closed building: every floor has walls and a ceiling, so the sky is never visible.
-- Style: dark metal shell, panelled walls with neon seams, ribbed ceilings with light panels.
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

---------------------------------------------------------------- look

local WALL_H = 24
local UP = Vector3.new(0, 1, 0)
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local PLATE = Enum.Material.DiamondPlate
local FLOOR = Color3.fromRGB(21, 22, 28)
local CEILING = Color3.fromRGB(16, 17, 22)
local WALL = Color3.fromRGB(40, 43, 51)
local PANEL = C.MetalLight
local DARK = Color3.fromRGB(23, 25, 31)
local STEEL = Color3.fromRGB(70, 75, 88)
local LINE = Color3.fromRGB(44, 47, 57)
local LAMP = Color3.fromRGB(214, 222, 255)
local WARM = Color3.fromRGB(255, 228, 190)
local GLASS = Color3.fromRGB(176, 204, 236)

---------------------------------------------------------------- building helpers

-- Structure people touch: walls, floors, ceilings, furniture.
local function solid(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string, material: Enum.Material?): Part
	return Props.block(parent, size, cf, color, name, material)
end

-- Purely visual detail: no collisions, queries or touches. Small details skip shadows.
local function detail(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shadow: boolean?): Part
	local p = Props.block(parent, size, cf, color, "Detail", material)
	p.CastShadow = shadow == true
	Props.decor(p)
	return p
end

local function glow(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Props.neon(parent, size, cf, color)
	p.Name = "Glow"
	Props.decor(p)
	return p
end

-- Decorative vertical-axis cylinder (floor rings, ceiling coffers).
local function round(parent: Instance, center: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material?): Part
	local p = Props.disc(parent, center, diameter, height, color, material)
	p.Name = "Detail"
	p.CastShadow = false
	Props.decor(p)
	return p
end

-- Walkable round floor layer from y = 0 up to `top`.
local function floorDisc(parent: Instance, top: number, diameter: number, color: Color3, material: Enum.Material?): Part
	local p = Props.disc(parent, Vector3.new(0, top / 2, 0), diameter, top, color, material)
	p.Name = "Floor"
	p.CastShadow = false
	return p
end

local function ball(parent: Instance, center: Vector3, diameter: number, color: Color3): Part
	local p = glow(parent, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Bevel piece. A wedge is solid below the slope that rises from its front (look direction) to its back.
local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = "Bevel"
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CastShadow = false
	Props.decor(w)
	w.Parent = parent
	return w
end

-- Ceiling light: a neon panel with a real downward SurfaceLight. Only a few key lights cast shadows.
local function lamp(parent: Instance, cf: CFrame, size: Vector3, color: Color3, brightness: number, range: number, shadows: boolean): Part
	local p = Props.lightPanel(parent, cf, size, color, brightness, range)
	Props.decor(p)
	local light = p:FindFirstChildOfClass("SurfaceLight")
	if light then
		light.Shadows = shadows
	end
	return p
end

-- Signs float a little off walls; they never need to collide.
local function quiet(label: TextLabel): TextLabel
	local part = label:FindFirstAncestorWhichIsA("BasePart")
	if part then
		Props.decor(part)
	end
	return label
end

-- Bezel around a Props.sign placed at `pos` looking along `facing`; the bars stand 0.1 proud of its face.
local function frameSign(parent: Instance, pos: Vector3, facing: Vector3, size: Vector2, color: Color3, lit: boolean)
	local base = CFrame.lookAt(pos, pos + facing)
	local t = 0.35
	local hx, hy = (size.X + t) / 2, (size.Y + t) / 2
	local bars = {
		{ Vector3.new(size.X + 2 * t, t, 0.5), CFrame.new(0, hy, -0.05) },
		{ Vector3.new(size.X + 2 * t, t, 0.5), CFrame.new(0, -hy, -0.05) },
		{ Vector3.new(t, size.Y, 0.5), CFrame.new(hx, 0, -0.05) },
		{ Vector3.new(t, size.Y, 0.5), CFrame.new(-hx, 0, -0.05) },
	}
	for _, bar in bars do
		if lit then
			glow(parent, bar[1], base * bar[2], color)
		else
			detail(parent, bar[1], base * bar[2], color, METAL)
		end
	end
end

-- Horizontal neon hoop from straight segments; returns one segment (to hang a light on).
local function hoop(parent: Instance, center: Vector3, radius: number, n: number, thickness: number, color: Color3): Part
	local first: Part? = nil
	local len = 2 * radius * math.sin(math.pi / n) + thickness * 0.5
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local p = center + Vector3.new(math.sin(a), 0, math.cos(a)) * radius * math.cos(math.pi / n)
		local seg = glow(parent, Vector3.new(len, thickness, thickness), CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), color)
		first = first or seg
	end
	return first :: Part
end

-- Floor arrow: two neon bars meeting at `tip`, pointing along `dir`.
local function chevron(parent: Instance, tip: Vector3, dir: Vector3, size: number, color: Color3)
	local side = Vector3.new(dir.Z, 0, -dir.X)
	for _, s in { -1, 1 } do
		local tail = tip - dir * size + side * size * s
		glow(parent, Vector3.new(0.35, 0.04, (tip - tail).Magnitude + 0.35), CFrame.lookAt((tip + tail) / 2, tip), color)
	end
end

-- Uncovered stretches of [0, len] between sorted, non-overlapping gaps.
local function freeRuns(len: number, gaps: { { number } }?): { { number } }
	local runs = {}
	local t = 0
	for _, g in gaps or {} do
		if g[1] > t then
			table.insert(runs, { t, math.min(g[1], len) })
		end
		t = math.max(t, g[2])
	end
	if len > t then
		table.insert(runs, { t, len })
	end
	return runs
end

-- Dresses the inner face of a straight wall from `a` to `b` (floor-level points on the face):
-- kick plate with a bevel and a neon line, panel bays with lit slots, and a bevelled top band with a neon line.
-- `gaps` (distances from `a`) are left without panels for boards and station bays.
local function dressWall(parent: Instance, a: Vector3, b: Vector3, inward: Vector3, trim: Color3, gaps: { { number } }?)
	local span = b - a
	local len = span.Magnitude
	local along = span.Unit
	local function place(t: number, depth: number, y: number, up: Vector3?): CFrame
		local p = a + along * t + inward * depth + Vector3.new(0, y, 0)
		return CFrame.lookAt(p, p + inward, up or UP)
	end
	local mid = len / 2
	solid(parent, Vector3.new(len, 2.2, 0.5), place(mid, 0.25, 1.1), C.Metal, "Wall", METAL)
	wedge(parent, Vector3.new(len, 0.5, 0.5), place(mid, 0.25, 2.45), C.Metal, METAL)
	glow(parent, Vector3.new(len, 0.2, 0.2), place(mid, 0.1, 2.85), trim)
	solid(parent, Vector3.new(len, 5.4, 0.45), place(mid, 0.225, WALL_H - 2.7), C.Metal, "Wall", METAL)
	wedge(parent, Vector3.new(len, 0.45, 0.45), place(mid, 0.225, 18.375, -UP), C.Metal, METAL)
	glow(parent, Vector3.new(len, 0.2, 0.2), place(mid, 0.1, 17.95), trim)
	for _, run in freeRuns(len, gaps) do
		local runLen = run[2] - run[1]
		if runLen >= 3 then
			local n = math.max(1, math.round(runLen / 10))
			local bay = runLen / n
			for i = 1, n do
				local t = run[1] + (i - 0.5) * bay
				detail(parent, Vector3.new(bay - 0.5, 14.4, 0.22), place(t, 0.11, 10.4), PANEL, METAL)
				if n > 1 and i % 2 == 1 then
					glow(parent, Vector3.new(math.min(3, bay * 0.4), 0.15, 0.08), place(t, 0.26, 16.4), trim)
				end
			end
		end
	end
end

-- Square column against a wall: plinth, shaft, capital, a neon collar under it and a neon strip on the `facing` side.
local function column(parent: Instance, pos: Vector3, facing: Vector3, trim: Color3)
	local base = CFrame.lookAt(pos, pos + facing)
	solid(parent, Vector3.new(3.2, 1.2, 3.2), base * CFrame.new(0, 0.6, 0), C.Metal, "Column", METAL)
	solid(parent, Vector3.new(2.2, WALL_H - 2.4, 2.2), base * CFrame.new(0, WALL_H / 2, 0), WALL, "Column", METAL)
	detail(parent, Vector3.new(3.2, 1.2, 3.2), base * CFrame.new(0, WALL_H - 0.6, 0), C.Metal, METAL, true)
	glow(parent, Vector3.new(2.5, 0.3, 2.5), base * CFrame.new(0, WALL_H - 1.35, 0), trim)
	glow(parent, Vector3.new(0.4, WALL_H - 6, 0.2), base * CFrame.new(0, WALL_H / 2, -1.15), trim)
end

---------------------------------------------------------------- lobby

local L = Config.Lobby
local R = L.HubRadius
-- board = width kept free of wall panels on the end wall; lamps = ceiling slots (studs past R) with a real light
-- (the other slots get the same neon panel without a light). Light budget for this file: 30 lights, 4 with shadows.
local ARMS = {
	{ key = "Pads", dir = Vector3.new(0, 0, 1), width = 60, length = 170, trim = C.Purple, title = "PLAY", board = 34, lamps = { 10, 60, 110, 160 } },
	{ key = "Shop", dir = Vector3.new(1, 0, 0), width = 40, length = 60, trim = C.Gold, title = "SHOP", board = 34, lamps = { 20, 40 } },
	{ key = "Quests", dir = Vector3.new(-1, 0, 0), width = 40, length = 60, trim = C.Good, title = "QUESTS", board = 34, lamps = { 20, 40 } },
	{ key = "Range", dir = Vector3.new(0, 0, -1), width = 30, length = 40, trim = C.Ally, title = "FIRING RANGE", board = 26, lamps = { 10, 30 } },
}

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
	-- Point on this station's wall (inner face at |x| = 30): local X runs along the wall.
	local function onWall(along: number, depth: number, y: number, up: Vector3?): CFrame
		local p = Vector3.new(side * (30 - depth), y, along)
		return CFrame.lookAt(p, p + inward, up or UP)
	end

	-- Platform with lit edges and a gold split line between the two team pads.
	solid(lobby, Vector3.new(16, 0.1, 32), CFrame.new(x, 0, zc), Color3.fromRGB(34, 36, 44), "StationPlate", PLATE)
	for _, s in { -1, 1 } do
		glow(lobby, Vector3.new(0.2, 0.04, 32), CFrame.new(x + s * 7.9, 0.06, zc), C.Purple)
	end
	glow(lobby, Vector3.new(11, 0.04, 0.25), CFrame.new(x, 0.06, zc), C.Gold)

	-- Station bay on the wall: dark backdrop, pilasters with neon strips and a braced header framing the title.
	detail(lobby, Vector3.new(30, 14.6, 0.2), onWall(zc, 0.1, 10.4), DARK, METAL)
	detail(lobby, Vector3.new(33.2, 1.6, 1.2), onWall(zc, 0.6, 20.2), C.Metal, METAL, true)
	glow(lobby, Vector3.new(26, 0.15, 0.3), onWall(zc, 1, 19.3), C.Purple)
	for _, s in { -1, 1 } do
		solid(lobby, Vector3.new(1.6, 19.4, 1.2), onWall(zc + s * 15.6, 0.6, 9.7), C.Metal, "Pilaster", METAL)
		glow(lobby, Vector3.new(0.3, 16, 0.15), onWall(zc + s * 15.6, 1.275, 10.5), C.Purple)
		local brace = Vector3.new(side * 29.4, 18.6, zc + s * 14)
		wedge(lobby, Vector3.new(1.2, 1.6, 1.6), CFrame.lookAt(brace, brace - Vector3.new(0, 0, s), -UP), C.Metal, METAL)
	end
	local titlePos = Vector3.new(wallX, 16, zc) -- framed by the bay's header and pilasters
	quiet(Props.sign(lobby, titlePos, inward, Vector2.new(10, 3.5), cfg.label, C.Purple))
	lamp(lobby, CFrame.new(x, WALL_H - 0.1, zc), Vector3.new(9, 0.2, 7), LAMP, 1.6, 30, row == 0)

	for team, dz in { -7, 7 } do
		local color = team == 1 and C.Ally or C.Enemy
		local center = Vector3.new(x, 0, zc + dz)
		round(lobby, center + Vector3.new(0, 0.02, 0), 13.4, 0.14, color, NEON) -- outer halo, top 0.09
		round(lobby, center + Vector3.new(0, 0.04, 0), 12.6, 0.18, C.Metal, METAL) -- collar, top 0.13
		local ring = Props.glowPad(lobby, center, color)
		local boardPos = Vector3.new(wallX, 9, zc + dz)
		local label = quiet(Props.sign(lobby, boardPos, inward, Vector2.new(9, 5.5), "0/" .. cfg.teamSize, color))
		frameSign(lobby, boardPos, inward, Vector2.new(9, 5.5), color, true)
		table.insert(station.pads, { center = center + Vector3.new(0, 0.35, 0), board = label, ring = ring, occupants = {} })
	end
	table.insert(World.stations, station)
end

-- One arm of the + : floor, walls, ceiling, entrance portal and dressing.
-- at(along, lateral, y) converts arm-local coordinates to world space; place() gives a CFrame there whose
-- local X runs across the arm, Y up and -Z along the arm (away from the hub).
local function buildArm(lobby: Model, arm)
	local dir, w = arm.dir, arm.width
	local half = w / 2
	local perp = Vector3.new(dir.Z, 0, -dir.X)
	local function at(along: number, lateral: number, y: number): Vector3
		return dir * along + perp * lateral + Vector3.new(0, y, 0)
	end
	local function place(along: number, lateral: number, y: number): CFrame
		local p = at(along, lateral, y)
		return CFrame.lookAt(p, p + dir)
	end
	local s0 = math.sqrt((R + 0.5) ^ 2 - (half + 0.5) ^ 2)
	local sIn = math.sqrt(R ^ 2 - half ^ 2) -- side walls start where their inner face meets the hub circle
	local e = R + arm.length

	-- Shell: floor under the walls, side walls, end wall and a ceiling slab from the hub ceiling's edge (R + 1)
	-- to the end wall's outer face, as wide as the outer faces of the side walls -> no gaps to the outside.
	local f0, f1 = s0 - 2, e + 1
	solid(lobby, Vector3.new(w + 2, 1, f1 - f0), place((f0 + f1) / 2, 0, -0.5), FLOOR, "Floor")
	for _, side in { -1, 1 } do
		solid(lobby, Vector3.new(1, WALL_H, e - sIn), place((sIn + e) / 2, side * (half + 0.5), WALL_H / 2), WALL, "Wall")
	end
	solid(lobby, Vector3.new(w + 2, WALL_H, 1), place(e + 0.5, 0, WALL_H / 2), WALL, "Wall")
	local c0, c1 = R + 1, e + 1
	solid(lobby, Vector3.new(w + 2, 1, c1 - c0), place((c0 + c1) / 2, 0, WALL_H + 0.5), CEILING, "Ceiling")

	-- Wall dressing. The pads arm keeps its station bays free; end walls keep the board area free.
	local sideGaps = nil
	if arm.key == "Pads" then
		sideGaps = {}
		for row = 0, math.ceil(#L.Stations / 2) - 1 do
			local zc = R + 30 + row * 50
			table.insert(sideGaps, { zc - 16.6 - sIn, zc + 16.6 - sIn })
		end
	end
	for _, side in { -1, 1 } do
		dressWall(lobby, at(sIn, side * half, 0), at(e, side * half, 0), -perp * side, arm.trim, sideGaps)
	end
	dressWall(lobby, at(e, -half, 0), at(e, half, 0), -dir, arm.trim, { { half - arm.board / 2, half + arm.board / 2 } })

	-- Entrance portal: header beam carrying the title, lit lower edges on both sides.
	detail(lobby, Vector3.new(w, 7.4, 1.2), place(R + 1.8, 0, WALL_H - 3.7), C.Metal, METAL, true)
	glow(lobby, Vector3.new(w, 0.25, 0.25), place(R + 1.075, 0, 16.75), arm.trim)
	glow(lobby, Vector3.new(w, 0.25, 0.25), place(R + 2.525, 0, 16.75), arm.trim)
	quiet(Props.sign(lobby, at(R + 1, 0, 19), -dir, Vector2.new(math.min(w - 6, 30), 4), arm.title, arm.trim))

	-- Ceiling: cross ribs every 10 studs (every other one lit), two lit service channels, light panels between ribs.
	local k = 0
	for along = R + 5, e - 2, 10 do
		detail(lobby, Vector3.new(w, 1, 1.2), place(along, 0, WALL_H - 0.5), C.Metal, METAL)
		if k % 2 == 0 then
			glow(lobby, Vector3.new(w - 1, 0.1, 0.3), place(along, 0, WALL_H - 1.05), arm.trim)
		end
		detail(lobby, Vector3.new(w - 3.4, 0.03, 0.15), place(along, 0, 0.015), LINE) -- matching floor seam
		k += 1
	end
	local runLen = e - c0 - 1.4
	for _, side in { -1, 1 } do
		detail(lobby, Vector3.new(1.2, 0.6, runLen), place(c0 + 1.4 + runLen / 2, side * (half - 4), WALL_H - 0.3), DARK, METAL)
		glow(lobby, Vector3.new(0.2, 0.08, runLen), place(c0 + 1.4 + runLen / 2, side * (half - 4), WALL_H - 0.64), arm.trim)
		glow(lobby, Vector3.new(0.25, 0.04, e - R - 1.5), place((R + 1 + e - 0.5) / 2, side * (half - 1.4), 0.02), arm.trim)
		-- long floor seams complete the tile grid with the cross seams under the ribs
		local seam = arm.key == "Pads" and 8 or half / 2
		detail(lobby, Vector3.new(0.15, 0.03, e - R - 2), place((R + e) / 2, side * seam, 0.015), LINE)
	end
	local slot = Vector3.new(w == 40 and 8 or 6, 0.2, 4)
	for along = R + 10, e - 5, 10 do
		if table.find(arm.lamps, along - R) then
			lamp(lobby, place(along, 0, WALL_H - 0.1), slot, LAMP, 1.4, 30, false)
		else
			glow(lobby, slot, place(along, 0, WALL_H - 0.1), LAMP)
		end
	end
	return at, place, perp, e
end

local function buildHub(lobby: Model)
	-- Floor: base disc and stepped walkable rings, neon circles, and guide lines in each arm's color.
	local base = Props.disc(lobby, Vector3.new(0, -0.5, 0), R * 2 + 2, 1, FLOOR)
	base.Name = "Floor"
	round(lobby, Vector3.new(0, 0.02, 0), R * 2 - 4, 0.04, C.Purple, NEON)
	floorDisc(lobby, 0.08, R * 2 - 6, DARK, METAL)
	round(lobby, Vector3.new(0, 0.07, 0), 36, 0.1, C.Purple, NEON)
	floorDisc(lobby, 0.16, 35, Color3.fromRGB(30, 32, 40), PLATE)
	round(lobby, Vector3.new(0, 0.17, 0), 22, 0.04, C.Ally, NEON)
	floorDisc(lobby, 0.24, 21.2, DARK, METAL)
	round(lobby, Vector3.new(0, 0.26, 0), 13.4, 0.04, C.Purple, NEON)
	floorDisc(lobby, 0.32, 12.6, C.Metal, METAL)
	for _, arm in ARMS do
		local p = arm.dir * ((18.2 + R) / 2) + Vector3.new(0, 0.09, 0)
		glow(lobby, Vector3.new(0.35, 0.04, R - 18.2), CFrame.lookAt(p, p + arm.dir), arm.trim)
	end
	for i = 0, 3 do
		local a = (i + 0.5) * math.pi / 2
		local d = Vector3.new(math.sin(a), 0, math.cos(a))
		local p = d * 25.4 + Vector3.new(0, 0.09, 0)
		detail(lobby, Vector3.new(0.3, 0.04, 14.4), CFrame.lookAt(p, p + d), STEEL)
	end

	-- Hub wall: arcs of segments between the arm openings (an opening spans where the arm's inner wall face
	-- meets the hub circle). Adjacent arms whose openings overlap meet in a corner of their own side walls.
	local openings = {}
	for _, arm in ARMS do
		local mid = math.atan2(arm.dir.X, arm.dir.Z)
		local halfAngle = math.asin(arm.width / 2 / R)
		table.insert(openings, { arm = arm, from = mid - halfAngle, to = mid + halfAngle })
	end
	table.sort(openings, function(a, b)
		return a.from < b.from
	end)
	local rm = R + 0.5
	for i, o in openings do
		local nextOpening = openings[i % #openings + 1]
		local from, to = o.to, nextOpening.from + (i == #openings and 2 * math.pi or 0)
		if to - from > 0.002 then
			local n = math.max(1, math.ceil((to - from) * rm / 4.5))
			local step = (to - from) / n
			local chord = 2 * rm * math.sin(step / 2)
			for j = 0, n - 1 do
				local a = from + (j + 0.5) * step
				local radial = Vector3.new(math.sin(a), 0, math.cos(a))
				local tangent = Vector3.new(math.cos(a), 0, -math.sin(a))
				local pos = radial * rm + Vector3.new(0, WALL_H / 2, 0)
				solid(lobby, Vector3.new(chord + 0.4, WALL_H, 1), CFrame.lookAt(pos, Vector3.new(0, WALL_H / 2, 0)), WALL, "Wall")
				local inner = radial * R
				dressWall(lobby, inner - tangent * chord / 2, inner + tangent * chord / 2, -radial, C.Purple)
			end
			for _, a in { from, (from + to) / 2, to } do
				local radial = Vector3.new(math.sin(a), 0, math.cos(a))
				column(lobby, radial * (R - 1.1), -radial, C.Purple)
			end
		else
			-- Inner corner where the two arms' side walls cross.
			local da, db = o.arm.dir, nextOpening.arm.dir
			local corner = db * (o.arm.width / 2) + da * (nextOpening.arm.width / 2)
			column(lobby, corner - (da + db) * 1.1, -(da + db).Unit, C.Purple)
		end
	end

	-- Ceiling: one square slab over the whole hub (arm ceilings start at its edge), with a stepped round coffer,
	-- spokes and a ring of light panels.
	solid(lobby, Vector3.new(2 * (R + 1), 1, 2 * (R + 1)), CFrame.new(0, WALL_H + 0.5, 0), CEILING, "Ceiling")
	round(lobby, Vector3.new(0, WALL_H - 0.3, 0), 58, 0.6, DARK, METAL)
	round(lobby, Vector3.new(0, WALL_H - 0.45, 0), 59, 0.2, C.Purple, NEON)
	round(lobby, Vector3.new(0, WALL_H - 1, 0), 34, 0.8, Color3.fromRGB(30, 32, 40), METAL)
	round(lobby, Vector3.new(0, WALL_H - 1.25, 0), 35, 0.2, C.Ally, NEON)
	round(lobby, Vector3.new(0, WALL_H - 1.75, 0), 16, 0.7, C.Metal, METAL)
	round(lobby, Vector3.new(0, WALL_H - 1.95, 0), 16.8, 0.2, C.Purple, NEON)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local d = Vector3.new(math.sin(a), 0, math.cos(a))
		local p = d * 23.2 + Vector3.new(0, WALL_H - 0.85, 0)
		detail(lobby, Vector3.new(0.8, 0.5, 11.2), CFrame.lookAt(p, p + d), STEEL, METAL)
		glow(lobby, Vector3.new(0.2, 0.06, 11), CFrame.lookAt(p, p + d) * CFrame.new(0, -0.28, 0), i % 2 == 0 and C.Ally or C.Purple)
		local la = (i + 0.5) * math.pi / 4
		local ld = Vector3.new(math.sin(la), 0, math.cos(la))
		local lp = ld * 23 + Vector3.new(0, WALL_H - 0.7, 0)
		if i % 2 == 0 then -- every other panel carries a real light; two opposite ones cast shadows
			lamp(lobby, CFrame.lookAt(lp, lp + ld), Vector3.new(5, 0.2, 2.4), LAMP, 1.6, 34, i == 0 or i == 4)
		else
			glow(lobby, Vector3.new(5, 0.2, 2.4), CFrame.lookAt(lp, lp + ld), LAMP)
		end
	end

	-- Centerpiece: a hanging ANTITHESIS screen box with neon hoops, lighting the spawn from below.
	for _, s in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
		detail(lobby, Vector3.new(0.15, 3.5, 0.15), CFrame.new(s * 4 + Vector3.new(0, 20.15, 0)), STEEL, METAL)
		glow(lobby, Vector3.new(0.6, 3.6, 0.6), CFrame.new(s * 6 + Vector3.new(0, 16, 0)), C.Ally)
	end
	detail(lobby, Vector3.new(12.6, 0.6, 12.6), CFrame.new(0, 18.1, 0), C.Metal, METAL, true)
	glow(lobby, Vector3.new(13, 0.16, 13), CFrame.new(0, 17.9, 0), C.Purple)
	detail(lobby, Vector3.new(12.6, 0.6, 12.6), CFrame.new(0, 13.9, 0), C.Metal, METAL, true)
	glow(lobby, Vector3.new(13, 0.16, 13), CFrame.new(0, 14.1, 0), C.Purple)
	for i, facing in { Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0) } do
		quiet(Props.sign(lobby, facing * 6 + Vector3.new(0, 16, 0), facing, Vector2.new(12, 3.4), "ANTITHESIS", i % 2 == 1 and C.Purple or C.Ally))
	end
	lamp(lobby, CFrame.new(0, 13.5, 0), Vector3.new(8, 0.2, 8), Color3.fromRGB(200, 236, 255), 1.2, 18, false)
	hoop(lobby, Vector3.new(0, 16, 0), 10, 14, 0.3, C.Ally)
	Props.pointLight(hoop(lobby, Vector3.new(0, 12.2, 0), 7.5, 10, 0.3, C.Purple), C.Purple, 28, 0.9)

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

local function buildPadsArm(lobby: Model, at, place, e: number)
	-- Center walkway with lit edges and arrows toward the far board.
	solid(lobby, Vector3.new(12, 0.05, 170), CFrame.new(0, 0.025, R + 85), Color3.fromRGB(12, 12, 16), "Walkway")
	glow(lobby, Vector3.new(0.4, 0.08, 170), CFrame.new(-6, 0.04, R + 85), C.Purple)
	glow(lobby, Vector3.new(0.4, 0.08, 170), CFrame.new(6, 0.04, R + 85), C.Gold)
	for along = R + 10, R + 130, 40 do
		chevron(lobby, Vector3.new(0, 0.07, along + 1), Vector3.new(0, 0, 1), 1.8, C.Purple)
	end
	for i, mode in L.Stations do
		buildStation(lobby, i, mode)
	end

	-- WEEKLY WINS leaderboard on the end wall: backing, neon frame and lit pylons.
	local boardPos = at(R + 170 - 0.4, 0, 12)
	board = quiet(Props.sign(lobby, boardPos, Vector3.new(0, 0, -1), Vector2.new(24, 16), "WEEKLY WINS", C.Light))
	detail(lobby, Vector3.new(26.4, 18.4, 0.2), place(e - 0.1, 0, 12), DARK, METAL)
	frameSign(lobby, boardPos, Vector3.new(0, 0, -1), Vector2.new(24, 16), C.Purple, true)
	for _, side in { -1, 1 } do
		detail(lobby, Vector3.new(2.4, 18, 0.8), place(e - 0.4, side * 15.4, 11), C.Metal, METAL, true)
		glow(lobby, Vector3.new(0.3, 16, 0.15), place(e - 0.875, side * 15.4, 11), C.Gold)
	end

	local helpPos = Vector3.new(-29.6, 10, R + 6)
	local helpSize = Vector2.new(14, 9)
	quiet(Props.sign(lobby, helpPos, Vector3.new(1, 0, 0), helpSize,
		"STAND ON A PAD TO QUEUE\nFirst to 5 rounds wins\nHold E near a player to challenge", C.Light))
	frameSign(lobby, helpPos, Vector3.new(1, 0, 0), helpSize, C.MetalLight, false)
	glow(lobby, Vector3.new(0.15, 0.2, 12), CFrame.new(-29.5, 4.9, R + 6), C.Purple)
end

-- Glass display case with a palette-skinned Paragon inside, lit from its lid.
local function displayCase(lobby: Model, base: Vector3, facing: Vector3, name: string)
	local function up(y: number): CFrame
		return CFrame.new(base + Vector3.new(0, y, 0))
	end
	round(lobby, base + Vector3.new(0, 0.02, 0), 8.4, 0.04, C.Gold, NEON)
	round(lobby, base + Vector3.new(0, 0.035, 0), 7.8, 0.07, C.Metal, METAL)
	solid(lobby, Vector3.new(6, 0.6, 6), up(0.3), C.Metal, "Pedestal", METAL)
	solid(lobby, Vector3.new(5, 2.4, 5), up(1.8), WALL, "Pedestal", METAL)
	glow(lobby, Vector3.new(5.3, 0.2, 5.3), up(3.1), C.Gold)
	solid(lobby, Vector3.new(5.6, 0.3, 5.6), up(3.35), C.Metal, "Pedestal", METAL)
	local glass = solid(lobby, Vector3.new(4.8, 3.8, 4.8), up(5.4), GLASS, "DisplayGlass", Enum.Material.Glass)
	glass.Transparency = 0.6
	glass.CastShadow = false
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
		detail(lobby, Vector3.new(0.35, 3.8, 0.35), up(5.4) + corner * 2.4, STEEL, METAL)
	end
	solid(lobby, Vector3.new(5.6, 0.45, 5.6), up(7.525), C.Metal, "Pedestal", METAL)
	glow(lobby, Vector3.new(5.8, 0.12, 5.8), up(7.4), C.Gold)
	Props.pointLight(glow(lobby, Vector3.new(3, 0.1, 3), up(7.24), WARM), WARM, 9, 1.6)
	detail(lobby, Vector3.new(0.25, 1, 0.25), up(4), STEEL, METAL)
	detail(lobby, Vector3.new(1.4, 0.15, 0.6), up(4.55), STEEL, METAL)

	local model = WeaponModels.build("Paragon", name)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	-- The model's grip is its origin; shift it so the whole gun sits centered in the glass.
	model:PivotTo(up(5.3) * CFrame.new(0.8, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(-15)))
	model.Parent = lobby

	local pal = Config.Palettes[name]
	local price = pal.price == 0 and "FREE" or pal.price and (pal.price .. " COINS") or "ROBUX"
	quiet(Props.sign(lobby, base + Vector3.new(0, 1.8, 0) + facing * 2.7, facing, Vector2.new(4.2, 2), string.upper(name) .. "\n" .. price, C.Gold))
end

-- Lit floor runner down the middle of an arm, from the hub edge (R) to `len` studs past it.
local function runner(lobby: Model, place, width: number, len: number, trim: Color3)
	solid(lobby, Vector3.new(width, 0.05, len), place(R + len / 2, 0, 0.025), Color3.fromRGB(14, 14, 18), "Walkway")
	for _, side in { -1, 1 } do
		glow(lobby, Vector3.new(0.3, 0.08, len), place(R + len / 2, side * width / 2, 0.04), trim)
	end
end

local function buildShopArm(lobby: Model, at, place, e: number)
	runner(lobby, place, 10, 56, C.Gold)
	local stands = { { 14, -13 }, { 28, -13 }, { 42, -13 }, { 21, 13 }, { 35, 13 } }
	for i, name in Config.PaletteOrder do
		local spot = stands[i]
		if not spot then
			break
		end
		local base = at(R + spot[1], spot[2], 0)
		displayCase(lobby, base, Vector3.new(0, 0, -math.sign(base.Z)), name) -- face the walkway
	end

	-- Counter under the shop sign.
	solid(lobby, Vector3.new(14, 3.2, 2.4), place(e - 2.4, 0, 1.6), WALL, "Counter", METAL)
	detail(lobby, Vector3.new(14.6, 0.3, 3), place(e - 2.4, 0, 3.35), C.Metal, METAL, true)
	glow(lobby, Vector3.new(14, 0.25, 0.1), place(e - 3.65, 0, 2.6), C.Gold)

	local signPos = at(R + 60 - 0.4, 0, 12)
	quiet(Props.sign(lobby, signPos, Vector3.new(-1, 0, 0), Vector2.new(28, 9), "COSMETICS SHOP\nWalk in to browse", C.Gold))
	detail(lobby, Vector3.new(30.4, 11.4, 0.2), place(e - 0.1, 0, 12), DARK, METAL)
	frameSign(lobby, signPos, Vector3.new(-1, 0, 0), Vector2.new(28, 9), C.Gold, true)
end

local function buildQuestsArm(lobby: Model, at, place, e: number)
	runner(lobby, place, 10, 56, C.Good)
	local signPos = at(R + 60 - 0.4, 0, 12)
	quiet(Props.sign(lobby, signPos, Vector3.new(1, 0, 0), Vector2.new(28, 12), "DAILY QUESTS\n3 new quests every day\nWalk in to see yours", C.Good))
	detail(lobby, Vector3.new(30.4, 14.4, 0.2), place(e - 0.1, 0, 12), DARK, METAL)
	frameSign(lobby, signPos, Vector3.new(1, 0, 0), Vector2.new(28, 12), C.Good, true)

	-- Lit pillars: plinth, shaft, capital, two neon collars and a neon strip facing the aisle.
	for _, lateral in { -14, 14 } do
		for along = 12, 48, 18 do
			local p = at(R + along, lateral, 0)
			local aisle = (at(R + along, 0, 0) - p).Unit
			solid(lobby, Vector3.new(3, 1, 3), CFrame.new(p + Vector3.new(0, 0.5, 0)), C.Metal, "Pillar", METAL)
			solid(lobby, Vector3.new(2, WALL_H, 2), CFrame.new(p + Vector3.new(0, WALL_H / 2, 0)), WALL, "Pillar", METAL)
			detail(lobby, Vector3.new(3, 1, 3), CFrame.new(p + Vector3.new(0, WALL_H - 0.5, 0)), C.Metal, METAL, true)
			local collar = glow(lobby, Vector3.new(2.3, 0.4, 2.3), CFrame.new(p + Vector3.new(0, 6, 0)), C.Good)
			glow(lobby, Vector3.new(2.3, 0.4, 2.3), CFrame.new(p + Vector3.new(0, 18, 0)), C.Good)
			local strip = p + aisle * 1.08 + Vector3.new(0, 12, 0)
			glow(lobby, Vector3.new(0.4, 11, 0.15), CFrame.lookAt(strip, strip + aisle), C.Good)
			if along == 30 then
				Props.pointLight(collar, C.Good, 14, 1.2)
			end
		end
	end

	-- Quest terminal: console with a sloped screen facing the hub.
	local toHub = at(0, 0, 0) - at(1, 0, 0)
	local t = R + 50
	solid(lobby, Vector3.new(7, 0.4, 3.4), place(t, 0, 0.2), C.Metal, "Terminal", METAL)
	solid(lobby, Vector3.new(6, 2.8, 2.4), place(t, 0, 1.8), WALL, "Terminal", METAL)
	local top = at(t, 0, 3.7)
	wedge(lobby, Vector3.new(6, 1, 2.4), CFrame.lookAt(top, top + toHub), C.Metal, METAL)
	local slope = math.atan2(1, 2.4)
	local normal = UP * math.cos(slope) + toHub * math.sin(slope)
	quiet(Props.sign(lobby, top + normal * 0.21, normal, Vector2.new(5.4, 2.2), "QUEST\nTERMINAL", C.Good))
	glow(lobby, Vector3.new(6.2, 0.2, 2.6), place(t, 0, 3.1), C.Good)
end

local function buildRangeArm(lobby: Model, at, place, perp: Vector3)
	runner(lobby, place, 8, 21, C.Ally)
	for along = R + 6, R + 18, 6 do
		chevron(lobby, at(along + 1, 0, 0.07), at(1, 0, 0) - at(0, 0, 0), 1.6, C.Ally)
	end

	-- Teleport pad with a halo, a neon arch over it and a hovering ring.
	local padCenter = at(R + 28, 0, 0)
	round(lobby, padCenter + Vector3.new(0, 0.02, 0), 13.4, 0.14, C.Ally, NEON)
	round(lobby, padCenter + Vector3.new(0, 0.04, 0), 12.6, 0.18, C.Metal, METAL)
	local ring = Props.glowPad(lobby, padCenter, C.Ally)
	Props.pointLight(ring, C.Ally, 16, 2)
	local archC = at(R + 28, 0, 6.5)
	local r, n = 7.5, 10
	local seg = 2 * r * math.sin(math.pi / n / 2)
	for i = 0, n - 1 do
		local th = (i + 0.5) / n * math.pi
		local radial = perp * math.cos(th) + UP * math.sin(th)
		local tangent = UP * math.cos(th) - perp * math.sin(th)
		detail(lobby, Vector3.new(seg + 0.15, 1, 1.2), CFrame.fromMatrix(archC + radial * r, tangent, radial), C.Metal, METAL, true)
		glow(lobby, Vector3.new(seg * 0.92 + 0.1, 0.2, 0.5), CFrame.fromMatrix(archC + radial * (r - 0.6), tangent, radial), C.Ally)
	end
	for _, side in { -1, 1 } do
		detail(lobby, Vector3.new(1, 6.5, 1.2), place(R + 28, side * r, 3.25), C.Metal, METAL, true)
		glow(lobby, Vector3.new(0.2, 6.5, 0.5), place(R + 28, side * (r - 0.6), 3.25), C.Ally)
		detail(lobby, Vector3.new(2, 0.5, 2.4), place(R + 28, side * r, 0.25), STEEL, METAL)
	end
	ball(lobby, archC + UP * (r + 0.9), 1.2, C.Ally)
	hoop(lobby, padCenter + Vector3.new(0, 9, 0), 4, 8, 0.25, C.Ally)

	local signPos = at(R + 40 - 0.4, 0, 10)
	quiet(Props.sign(lobby, signPos, Vector3.new(0, 0, 1), Vector2.new(20, 7), "FIRING RANGE\nStep on the pad to teleport", C.Ally))
	detail(lobby, Vector3.new(22.4, 9.4, 0.2), place(R + 40 - 0.1, 0, 10), DARK, METAL)
	frameSign(lobby, signPos, Vector3.new(0, 0, 1), Vector2.new(20, 7), C.Ally, true)

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
		local at, place, perp, e = buildArm(lobby, arm)
		if arm.key == "Pads" then
			buildPadsArm(lobby, at, place, e)
		elseif arm.key == "Shop" then
			buildShopArm(lobby, at, place, e)
		elseif arm.key == "Quests" then
			buildQuestsArm(lobby, at, place, e)
		else
			buildRangeArm(lobby, at, place, perp)
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
