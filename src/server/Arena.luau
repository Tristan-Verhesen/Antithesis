-- Battle arenas: one is built for every match at (1000 + 500 * slot, 0, 0) and destroyed afterwards.
-- An arena is a closed hall: floor, panelled walls and a ribbed ceiling 20 studs up, so the sky is never visible.
-- Look: the "Contrast" light and dark halves inside a dark sci-fi shell. The x < 0 end (team 1) carries cyan
-- accents, the x > 0 end (team 2) orange ones, and gold marks the center line.
--
-- Shot safety: the layout boxes are the exact collision volumes (movement, bullets and line of sight). Every
-- detail on them is decor (Props.decor) that lies within 0.1 stud of the box surface, so it never changes what
-- blocks a shot. Apart from the boxes only the floor, walls, ceiling, kick plates, corner columns and gate
-- pilasters (all against the walls) collide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

local C = Config.Colors
local GRAY = Color3.fromRGB(120, 122, 128)

-- Half-arena layouts (x < 0). Boxes are mirrored across x = 0; boxes with x == 0 are center pieces.
-- {x, z, sizeX, sizeY, sizeZ, baseY?}. styles[i] is the decor look of boxes[i]: "crate", "wall", "shield", "pillar"
-- or "platform" (purely visual; the boxes themselves are the collision volumes).
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
		-- decor look of each box above, in the same order
		styles = { "shield", "crate", "crate", "wall", "platform", "crate", "crate", "wall", "wall", "wall", "wall", "wall", "wall" },
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
		-- decor look of each box above, in the same order
		styles = {
			"shield", "pillar", "pillar", "pillar", "pillar", "pillar", "platform", "crate", "platform",
			"crate", "wall", "wall", "crate", "crate", "platform", "pillar", "crate", "crate",
		},
	},
}

---------------------------------------------------------------- look

local HEIGHT = 20 -- walls are 20 tall; the ceiling's underside is at this height
local UP = Vector3.new(0, 1, 0)
local METAL = Enum.Material.Metal
local PLATE = Enum.Material.DiamondPlate
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

local WALL = Color3.fromRGB(40, 43, 51)
local CEILING = Color3.fromRGB(16, 17, 22)
local COFFER = Color3.fromRGB(28, 30, 37)
local BEAM = Color3.fromRGB(50, 53, 62)
local DARK = Color3.fromRGB(23, 25, 31)
local PIPE = Color3.fromRGB(66, 70, 82)
local LAMP = Color3.fromRGB(236, 240, 255)
local OUT = 0.08 -- how far trims stand proud of a cover box (decor stays within 0.1 of its surface)

-- Per-side looks. Side 1 is x < 0 (light floor, dark cover, cyan); side 2 is x > 0 (dark floor, light cover, orange).
-- Ceiling lights are tinted a little cooler over the light half and a little warmer over the dark half.
local SIDES = {
	{
		dir = -1,
		floor = C.Light,
		grid = Color3.fromRGB(198, 199, 204),
		wallPanel = Color3.fromRGB(112, 118, 132),
		lamp = Color3.fromRGB(226, 240, 255),
		accent = C.Ally,
		box = C.Dark,
		trim = C.Metal,
		panel = C.MetalLight,
		top = Color3.fromRGB(60, 63, 72),
	},
	{
		dir = 1,
		floor = C.Dark,
		grid = Color3.fromRGB(64, 67, 76),
		wallPanel = Color3.fromRGB(54, 57, 66),
		lamp = Color3.fromRGB(255, 240, 226),
		accent = C.Enemy,
		box = C.Light,
		trim = Color3.fromRGB(146, 150, 158),
		panel = Color3.fromRGB(214, 213, 210),
		top = Color3.fromRGB(196, 197, 200),
	},
}
local CENTER = {
	accent = C.Gold,
	box = GRAY,
	trim = C.Metal,
	panel = Color3.fromRGB(104, 107, 116),
	top = Color3.fromRGB(88, 91, 100),
}

---------------------------------------------------------------- building helpers

-- Structure: floor, walls, ceiling and cover boxes.
local function solid(m: Instance, size: Vector3, cf: CFrame, color: Color3, name: string, material: Enum.Material?): Part
	return Props.block(m, size, cf, color, name, material)
end

-- Purely visual detail: no collisions, queries, touches or shadows.
local function detail(m: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Props.block(m, size, cf, color, "Detail", material)
	p.CastShadow = false
	Props.decor(p)
	return p
end

local function glow(m: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Props.neon(m, size, cf, color)
	p.Name = "Glow"
	Props.decor(p)
	return p
end

-- Bevel piece. A wedge is solid below the slope that rises from its front (look direction) to its back.
local function wedge(m: Instance, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = "Bevel"
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = METAL
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CastShadow = false
	Props.decor(w)
	w.Parent = m
	return w
end

-- Decor cylinder lying along the CFrame's X axis.
local function pipe(m: Instance, length: number, diameter: number, cf: CFrame, color: Color3): Part
	local p = detail(m, Vector3.new(length, diameter, diameter), cf, color, METAL)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Decor vertical-axis disc (spawn pads).
local function round(m: Instance, center: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material?): Part
	local p = Props.disc(m, center, diameter, height, color, material)
	p.Name = "Detail"
	p.CastShadow = false
	Props.decor(p)
	return p
end

-- Ceiling light: a neon panel with a real downward SurfaceLight. Only the central panels cast shadows.
local function lamp(m: Instance, cf: CFrame, size: Vector3, color: Color3, shadows: boolean): Part
	local p = Props.lightPanel(m, cf, size, color, 2.2, 46)
	Props.decor(p)
	local light = p:FindFirstChildOfClass("SurfaceLight")
	if light and light:IsA("SurfaceLight") then
		light.Angle = 150
		light.Shadows = shadows
	end
	return p
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

---------------------------------------------------------------- walls

-- Dresses the inner face of a wall from `a` to `b` (arena-relative points on the face at floor level):
-- a kick plate with a bevel and a neon line, panel bays split by ribs with neon strips, a bevelled top band
-- with a neon line and a light strip along the ceiling edge. `gaps` (distances from `a`) stay bare.
local function dressWall(m: Model, O: CFrame, a: Vector3, b: Vector3, inward: Vector3, side, gaps: { { number } }?)
	local span = b - a
	local len = span.Magnitude
	local along = span.Unit
	local function place(t: number, depth: number, y: number, up: Vector3?): CFrame
		local p = a + along * t + inward * depth + Vector3.new(0, y, 0)
		return O * CFrame.lookAt(p, p + inward, up or UP)
	end
	local mid = len / 2
	solid(m, Vector3.new(len, 1.6, 0.5), place(mid, 0.25, 0.8), C.Metal, "Wall", METAL)
	wedge(m, Vector3.new(len, 0.4, 0.5), place(mid, 0.25, 1.8), C.Metal)
	glow(m, Vector3.new(len, 0.14, 0.12), place(mid, 0.06, 2.3), side.accent)
	detail(m, Vector3.new(len, 3.8, 0.45), place(mid, 0.225, HEIGHT - 1.9), C.Metal, METAL)
	wedge(m, Vector3.new(len, 0.45, 0.45), place(mid, 0.225, HEIGHT - 4.025, -UP), C.Metal)
	glow(m, Vector3.new(len, 0.16, 0.12), place(mid, 0.06, HEIGHT - 4.55), side.accent)
	glow(m, Vector3.new(len, 0.12, 0.3), place(mid, 0.75, HEIGHT - 0.08), side.lamp)
	for _, run in freeRuns(len, gaps) do
		local runLen = run[2] - run[1]
		if runLen >= 3 then
			local n = math.max(1, math.round(runLen / 10))
			local bay = runLen / n
			for i = 1, n do
				local t = run[1] + (i - 0.5) * bay
				detail(m, Vector3.new(bay - 0.7, 12.6, 0.2), place(t, 0.1, 8.9), side.wallPanel, METAL)
				if i < n then
					local rib = run[1] + i * bay
					detail(m, Vector3.new(0.6, 12.6, 0.4), place(rib, 0.2, 8.9), C.Metal, METAL)
					glow(m, Vector3.new(0.14, 9, 0.08), place(rib, 0.44, 8.9), side.accent)
				end
			end
		end
	end
end

-- Arena name over the center line of a side wall (inner face at z = zFace), framed by gold and both team colors.
local function nameplate(m: Model, O: CFrame, zFace: number, inward: Vector3, name: string)
	local function at(x: number, depth: number, y: number): CFrame
		local p = Vector3.new(x, y, zFace) + inward * depth
		return O * CFrame.lookAt(p, p + inward)
	end
	detail(m, Vector3.new(11.4, 12.6, 0.2), at(0, 0.1, 8.9), DARK, METAL)
	glow(m, Vector3.new(0.3, 8, 0.12), at(0, 0.26, 6.6), C.Gold)
	for _, side in SIDES do
		local x = side.dir * 6
		detail(m, Vector3.new(0.8, 12.6, 0.5), at(x, 0.25, 8.9), C.Metal, METAL)
		glow(m, Vector3.new(0.16, 10, 0.1), at(x, 0.55, 8.9), side.accent)
	end
	glow(m, Vector3.new(9.6, 3, 0.2), at(0, 0.3, 12.6), C.Gold)
	local label = Props.sign(m, at(0, 0.45, 12.6).Position, inward, Vector2.new(9, 2.4), string.upper(name), C.Gold)
	local board = label:FindFirstAncestorWhichIsA("BasePart")
	if board and board:IsA("BasePart") then
		Props.decor(board)
		board.CastShadow = false
	end
end

-- Spawn gate in the middle of an end wall (inner face at x = xFace): glass window over neon bars, a lit sill
-- (the spawn marker's light), solid pilasters and a header whose light bar fills the arena toward the far end.
local function spawnGate(m: Model, O: CFrame, xFace: number, side)
	local inward = Vector3.new(-side.dir, 0, 0)
	local function at(z: number, depth: number, y: number): CFrame
		local p = Vector3.new(xFace, y, z) + inward * depth
		return O * CFrame.lookAt(p, p + inward)
	end
	detail(m, Vector3.new(17, 12.6, 0.2), at(0, 0.1, 8.9), DARK, METAL)
	for i = -1, 1 do
		glow(m, Vector3.new(10, 0.3, 0.1), at(0, 0.25, 7.5 + i * 2.2), side.accent)
	end
	local glass = detail(m, Vector3.new(12, 8, 0.2), at(0, 0.5, 7.5), side.accent:Lerp(DARK, 0.65), GLASS)
	glass.Transparency = 0.45
	local sill = glow(m, Vector3.new(12.6, 0.3, 0.5), at(0, 0.35, 3.3), side.accent)
	Props.pointLight(sill, side.accent, 16, 1.4)
	for _, s in { -1, 1 } do
		solid(m, Vector3.new(1.4, 14.6, 1), at(s * 8.5, 0.5, 7.3), C.Metal, "Wall", METAL)
		glow(m, Vector3.new(0.25, 11, 0.1), at(s * 8.5, 1.05, 7.8), side.accent)
	end
	detail(m, Vector3.new(18.4, 1.2, 1), at(0, 0.5, 15.2), C.Metal, METAL)
	local bar = glow(m, Vector3.new(12, 0.3, 0.12), at(0, 1.06, 15.2), side.lamp)
	local fill = Instance.new("SurfaceLight")
	fill.Face = Enum.NormalId.Front
	fill.Color = side.lamp
	fill.Brightness = 0.9
	fill.Range = 60
	fill.Angle = 120
	fill.Shadows = false
	fill.Parent = bar
end

-- Outer shell (floor halves are built with the floor): four walls from under the floor up to the ceiling and a
-- ceiling slab that overlaps their tops, so there is no gap to the outside anywhere. Then all wall dressing.
local function buildShell(m: Model, O: CFrame, sx: number, sz: number, name: string)
	for _, s in { -1, 1 } do
		solid(m, Vector3.new(sx + 2, HEIGHT + 1, 1), O * CFrame.new(0, HEIGHT / 2 - 0.5, s * (sz / 2 + 0.5)), WALL, "Wall", METAL)
		solid(m, Vector3.new(1, HEIGHT + 1, sz), O * CFrame.new(s * (sx / 2 + 0.5), HEIGHT / 2 - 0.5, 0), WALL, "Wall", METAL)
	end
	solid(m, Vector3.new(sx + 2, 1, sz + 2), O * CFrame.new(0, HEIGHT + 0.5, 0), CEILING, "Ceiling", METAL)

	for _, side in SIDES do
		local d = side.dir
		-- Side walls, one dressed run per half; the 12 studs around the center line hold the nameplate.
		for _, zs in { -1, 1 } do
			local face = zs * sz / 2
			dressWall(m, O, Vector3.new(0, 0, face), Vector3.new(d * sx / 2, 0, face), Vector3.new(0, 0, -zs), side, { { 0, 6 } })
		end
		-- End wall behind this side's spawn, with the spawn gate in the middle.
		local xFace = d * sx / 2
		dressWall(m, O, Vector3.new(xFace, 0, -sz / 2), Vector3.new(xFace, 0, sz / 2), Vector3.new(-d, 0, 0), side, { { sz / 2 - 9, sz / 2 + 9 } })
		spawnGate(m, O, xFace, side)
		-- Corner columns with a neon strip on their inner edge.
		for _, zs in { -1, 1 } do
			solid(m, Vector3.new(1.6, HEIGHT, 1.6), O * CFrame.new(d * (sx / 2 - 0.8), HEIGHT / 2, zs * (sz / 2 - 0.8)), C.Metal, "Wall", METAL)
			glow(m, Vector3.new(0.3, HEIGHT - 6, 0.3), O * CFrame.new(d * (sx / 2 - 1.6), HEIGHT / 2, zs * (sz / 2 - 1.6)), side.accent)
		end
	end
	for _, zs in { -1, 1 } do
		nameplate(m, O, zs * sz / 2, Vector3.new(0, 0, -zs), name)
		-- Service pipes along the top of the long walls.
		for k, depth in { 1.3, 2.1 } do
			pipe(m, sx, 0.6, O * CFrame.new(0, HEIGHT - 0.5 - k * 0.15, zs * (sz / 2 - depth)), PIPE)
		end
	end
end

---------------------------------------------------------------- floor and ceiling

-- Floor halves (top at y = 0) with flush tile seams, a plated edge trim with a neon line, and the gold center
-- line in a metal channel. Every floor detail tops out at or below y = 0.04, under the collapse ring.
local function buildFloor(m: Model, O: CFrame, sx: number, sz: number)
	for _, side in SIDES do
		local d = side.dir
		solid(m, Vector3.new(sx / 2, 1, sz), O * CFrame.new(d * sx / 4, -0.5, 0), side.floor, "Floor")
		for i = 1, math.floor((sx / 2 - 1) / 10) do
			detail(m, Vector3.new(0.12, 0.02, sz), O * CFrame.new(d * i * 10, 0.01, 0), side.grid)
		end
		local nz = math.floor((sz / 2 - 1) / 10)
		for i = -nz, nz do
			detail(m, Vector3.new(sx / 2, 0.02, 0.12), O * CFrame.new(d * sx / 4, 0.01, i * 10), side.grid)
		end
		detail(m, Vector3.new(1.6, 0.03, sz), O * CFrame.new(d * (sx / 2 - 0.8), 0.015, 0), C.Metal, PLATE)
		glow(m, Vector3.new(0.15, 0.04, sz - 3.2), O * CFrame.new(d * (sx / 2 - 1.675), 0.02, 0), side.accent)
		local runLen = sx / 2 - 1.6
		local neonLen = runLen - 0.7
		for _, zs in { -1, 1 } do
			detail(m, Vector3.new(runLen, 0.03, 1.6), O * CFrame.new(d * runLen / 2, 0.015, zs * (sz / 2 - 0.8)), C.Metal, PLATE)
			glow(m, Vector3.new(neonLen, 0.04, 0.15), O * CFrame.new(d * (0.7 + neonLen / 2), 0.02, zs * (sz / 2 - 1.675)), side.accent)
		end
	end
	detail(m, Vector3.new(1.4, 0.026, sz), O * CFrame.new(0, 0.013, 0), C.Metal, PLATE)
	local line = glow(m, Vector3.new(0.4, 0.04, sz), O * CFrame.new(0, 0.02, 0), C.Gold)
	line.Name = "CenterLine"
end

-- Ceiling: a 4-column grid of coffers, each with a housed light panel, split by beams with neon undersides
-- (gold over the center line) on wall brackets. The panels nearest the center cast shadows (at most 4).
local function buildCeiling(m: Model, O: CFrame, sx: number, sz: number)
	local nc, nr = 4, math.max(1, math.round(sz / 30))
	local cw, cd = sx / nc, sz / nr
	for i = 1, nc - 1 do
		local x = -sx / 2 + i * cw
		detail(m, Vector3.new(1.6, 1.4, sz), O * CFrame.new(x, HEIGHT - 0.7, 0), BEAM, METAL)
		glow(m, Vector3.new(0.3, 0.08, sz - 2), O * CFrame.new(x, HEIGHT - 1.44, 0), if i * 2 == nc then C.Gold else LAMP)
		for _, s in { -1, 1 } do
			local p = Vector3.new(x, HEIGHT - 2, s * (sz / 2 - 1.05))
			wedge(m, Vector3.new(1.6, 1.2, 1.2), O * CFrame.lookAt(p, p - Vector3.new(0, 0, s), -UP), BEAM)
		end
	end
	for j = 1, nr - 1 do
		local z = -sz / 2 + j * cd
		detail(m, Vector3.new(sx, 1, 1.4), O * CFrame.new(0, HEIGHT - 0.5, z), BEAM, METAL)
		glow(m, Vector3.new(sx - 2, 0.08, 0.3), O * CFrame.new(0, HEIGHT - 1.04, z), LAMP)
		for _, s in { -1, 1 } do
			local p = Vector3.new(s * (sx / 2 - 0.95), HEIGHT - 1.5, z)
			wedge(m, Vector3.new(1.4, 1, 1), O * CFrame.lookAt(p, p - Vector3.new(s, 0, 0), -UP), BEAM)
		end
	end
	local w, d = cw * 0.28, cd * 0.45
	for i = 1, nc do
		for j = 1, nr do
			local x = -sx / 2 + (i - 0.5) * cw
			local z = -sz / 2 + (j - 0.5) * cd
			local side = if x < 0 then SIDES[1] else SIDES[2]
			detail(m, Vector3.new(cw - 3, 0.12, cd - 3), O * CFrame.new(x, HEIGHT - 0.06, z), COFFER, METAL)
			detail(m, Vector3.new(w + 0.8, 0.5, d + 0.8), O * CFrame.new(x, HEIGHT - 0.25, z), C.Metal, METAL)
			lamp(m, O * CFrame.new(x, HEIGHT - 0.6, z), Vector3.new(w, 0.2, d), side.lamp, math.abs(x) < cw and math.abs(z) < cd)
		end
	end
end

-- Lit spawn marker on the floor around one team's two spawn points (x, 0, +-4): a plated zone with a neon frame,
-- two glowing pads and a chevron toward the center. The light is the gate sill on the wall behind it.
local function spawnMarker(m: Model, O: CFrame, x: number, side)
	detail(m, Vector3.new(6, 0.03, 15), O * CFrame.new(x, 0.015, 0), C.Metal, PLATE)
	for _, s in { -1, 1 } do
		glow(m, Vector3.new(0.2, 0.04, 15.4), O * CFrame.new(x + s * 3.1, 0.02, 0), side.accent)
		glow(m, Vector3.new(6.4, 0.04, 0.2), O * CFrame.new(x, 0.02, s * 7.6), side.accent)
		local c = O.Position + Vector3.new(x, 0, s * 4)
		round(m, c + Vector3.new(0, 0.02, 0), 3.4, 0.04, side.accent, NEON)
		round(m, c + Vector3.new(0, 0.0225, 0), 2.6, 0.045, C.Metal, METAL)
		round(m, c + Vector3.new(0, 0.025, 0), 0.8, 0.05, side.accent, NEON)
	end
	local dir = Vector3.new(-side.dir, 0, 0)
	local tip = Vector3.new(x, 0.02, 0) + dir * 1.2
	for _, s in { -1, 1 } do
		local tail = tip - dir * 1.2 + Vector3.new(0, 0, s * 1.2)
		glow(m, Vector3.new(0.3, 0.04, (tip - tail).Magnitude + 0.3), O * CFrame.lookAt((tip + tail) / 2, tip), side.accent)
	end
end

---------------------------------------------------------------- cover

-- Decor for one cover box (center cf, size). Every piece lies on the box, at most OUT (0.08) proud of its surface.
-- Heights below are measured from the bottom of the box.
local function dressBox(m: Model, cf: CFrame, size: Vector3, style: string, look)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local h = size.Y
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y - hy, z)
	end
	local function make(s: Vector3, c: CFrame, color: Color3, material: Enum.Material?): Part
		if material == NEON then
			return glow(m, s, c, color)
		end
		return detail(m, s, c, color, material)
	end
	-- Sleeve around all four sides from y0 to y1, `out` proud of them (a lid when it reaches past the top).
	local function sleeve(y0: number, y1: number, out: number, color: Color3, material: Enum.Material?): Part
		return make(Vector3.new(size.X + 2 * out, y1 - y0, size.Z + 2 * out), at(0, (y0 + y1) / 2, 0), color, material)
	end
	-- Strip through the box: along X at z = offset (shows on both X faces) or along Z at x = offset (both Z faces).
	local function strip(alongX: boolean, offset: number, w: number, y0: number, y1: number, out: number, color: Color3, material: Enum.Material?): Part
		if alongX then
			return make(Vector3.new(size.X + 2 * out, y1 - y0, w), at(0, (y0 + y1) / 2, offset), color, material)
		end
		return make(Vector3.new(w, y1 - y0, size.Z + 2 * out), at(offset, (y0 + y1) / 2, 0), color, material)
	end
	local function topPlate(inset: number)
		detail(m, Vector3.new(size.X - inset, 0.04, size.Z - inset), at(0, h + 0.06, 0), look.top, PLATE)
	end

	if style == "crate" then
		-- Skirt, lid, corner posts, a neon band under the lid, cross seams on every face and a plated top.
		sleeve(0, 0.6, OUT, look.trim, METAL)
		sleeve(h - 0.36, h + 0.04, OUT, look.trim, METAL)
		topPlate(0.8)
		for _, px in { -1, 1 } do
			for _, pz in { -1, 1 } do
				local c = at(px * (hx - 0.225 + OUT), (0.6 + h - 0.36) / 2, pz * (hz - 0.225 + OUT))
				detail(m, Vector3.new(0.45, h - 0.96, 0.45), c, look.trim, METAL)
			end
		end
		sleeve(h - 0.75, h - 0.59, 0.06, look.accent, NEON)
		strip(true, 0, 0.14, 0.6, h - 0.36, 0.04, look.trim, METAL)
		strip(false, 0, 0.14, 0.6, h - 0.36, 0.04, look.trim, METAL)
	elseif style == "pillar" then
		-- Base, middle and cap collars, two neon rings and neon fins up the middle of every face.
		local mid = h / 2
		sleeve(0, 0.9, OUT, look.trim, METAL)
		sleeve(mid - 0.25, mid + 0.25, OUT, look.trim, METAL)
		sleeve(h - 0.7, h + 0.04, OUT, look.trim, METAL)
		sleeve(1.1, 1.28, 0.06, look.accent, NEON)
		sleeve(h - 1.08, h - 0.9, 0.06, look.accent, NEON)
		-- The fins run behind the middle collar, which stands further out and hides them there.
		strip(true, 0, 0.22, 1.28, h - 1.08, 0.05, look.accent, NEON)
		strip(false, 0, 0.22, 1.28, h - 1.08, 0.05, look.accent, NEON)
		if math.min(size.X, size.Z) >= 3 then
			topPlate(0.8)
		end
	elseif style == "platform" then
		-- Skirt, lid with a plated deck, a neon rail, panels on every face and a hazard patch on both X faces.
		sleeve(0, 0.5, OUT, look.trim, METAL)
		sleeve(h - 0.36, h + 0.04, OUT, look.trim, METAL)
		topPlate(1.2)
		sleeve(1.1, 1.26, 0.07, look.accent, NEON)
		for _, alongX in { true, false } do
			local inner = (if alongX then size.Z else size.X) - 1
			local n = math.max(1, math.round(inner / 4))
			local bay = inner / n
			for i = 1, n do
				strip(alongX, -inner / 2 + (i - 0.5) * bay, bay - 0.3, 0.62, h - 0.48, 0.03, look.panel, METAL)
			end
		end
		if h >= 2.5 and size.Z >= 6 then
			-- Diagonal stripes on a dark backing; their tips tuck into the skirt (below) and the neon rail (above).
			strip(true, 0, 5.2, 0.5, 1.1, 0.045, C.Metal, METAL)
			for k = 1, 6 do
				local c = at(0, 0.8, (k - 3.5) * 0.8) * CFrame.Angles(math.rad(45), 0, 0)
				detail(m, Vector3.new(size.X + 0.12, 0.85, 0.3), c, C.Gold)
			end
		end
	else
		-- "wall" / "shield": kick base, cap, end posts, panels on both faces and a neon line under the cap.
		-- The shield also carries a neon diamond emblem in its team color.
		local alongX = size.X >= size.Z
		local length = if alongX then size.X else size.Z
		local thick = if alongX then size.Z else size.X
		local function piece(lenA: number, y0: number, y1: number, out: number, a: number, color: Color3, material: Enum.Material?): Part
			if alongX then
				return make(Vector3.new(lenA, y1 - y0, thick + 2 * out), at(a, (y0 + y1) / 2, 0), color, material)
			end
			return make(Vector3.new(thick + 2 * out, y1 - y0, lenA), at(0, (y0 + y1) / 2, a), color, material)
		end
		sleeve(0, 0.8, OUT, look.trim, METAL)
		sleeve(h - 0.5, h + 0.06, OUT, look.trim, METAL)
		for _, s in { -1, 1 } do
			piece(0.5, 0.8, h - 0.5, OUT, s * (length / 2 - 0.25 + OUT), look.trim, METAL)
		end
		local inner = length - 2 * (0.5 - OUT) - 0.3
		local n = math.max(1, math.round(inner / 4.5))
		local bay = inner / n
		for i = 1, n do
			piece(bay - 0.3, 1.05, h - 0.75, 0.035, -inner / 2 + (i - 0.5) * bay, look.panel, METAL)
		end
		piece(length - 1.2, h - 1.18, h - 1.02, 0.06, 0, look.accent, NEON)
		if style == "shield" then
			local y = (1.05 + h - 1.18) / 2
			local turn = if alongX then CFrame.Angles(0, 0, math.rad(45)) else CFrame.Angles(math.rad(45), 0, 0)
			local function diamond(edge: number, out: number, color: Color3, material: Enum.Material)
				local s = if alongX then Vector3.new(edge, edge, thick + 2 * out) else Vector3.new(thick + 2 * out, edge, edge)
				make(s, at(0, y, 0) * turn, color, material)
			end
			diamond(1.8, 0.06, look.accent, NEON)
			diamond(1.1, 0.07, look.trim, METAL)
		end
	end
end

-- One layout box: the exact collision volume (blocks movement, shots and line of sight) plus its decor.
local function cover(m: Model, cf: CFrame, size: Vector3, style: string, look)
	solid(m, size, cf, look.box, "Cover")
	dressBox(m, cf, size, style, look)
end

---------------------------------------------------------------- arenas

local Arena = {}
local usedSlots = {}

function Arena.create(map: Instance): { [string]: any }
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local layout = LAYOUTS[math.random(#LAYOUTS)]
	local origin = Vector3.new(1000 + 500 * slot, 0, 0)
	local O = CFrame.new(origin)
	local model = Instance.new("Model")
	model.Name = "Arena" .. slot
	local sx, sz = layout.size[1], layout.size[2]
	local s = layout.spawnX

	buildShell(model, O, sx, sz, layout.name)
	buildFloor(model, O, sx, sz)
	buildCeiling(model, O, sx, sz)
	for _, side in SIDES do
		spawnMarker(model, O, side.dir * s, side)
	end
	for i, b in layout.boxes do
		local size = Vector3.new(b[3], b[4], b[5])
		local y = (b[6] or 0) + b[4] / 2
		local style = layout.styles[i] or "crate"
		if b[1] == 0 then
			cover(model, O * CFrame.new(0, y, b[2]), size, style, CENTER)
		else
			cover(model, O * CFrame.new(b[1], y, b[2]), size, style, SIDES[1])
			cover(model, O * CFrame.new(-b[1], y, b[2]), size, style, SIDES[2])
		end
	end

	local function spawnAt(x: number, z: number): CFrame
		local pos = origin + Vector3.new(x, 3, z)
		return CFrame.lookAt(pos, pos + Vector3.new(-math.sign(x), 0, 0))
	end
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

function Arena.destroy(arena)
	arena.model:Destroy()
	usedSlots[arena.slot] = nil
end

return Arena
