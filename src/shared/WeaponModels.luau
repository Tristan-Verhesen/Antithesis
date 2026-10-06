-- Builds detailed sci-fi weapon models from primitive parts, so no assets are needed.
-- Model space: grip at the origin, barrel toward -Z, up is +Y. The first-person viewmodel sits at
-- camera * (0, -0.55, -1.6) when aiming, so every sight is built around the line y = 0.55, x = 0.
-- Each weapon is a list of part specs (see the constructors below) turned into parts by build().
local Config = require(script.Parent.Config)

local rad = math.rad

-- Fixed finishes for detail parts. "body" and "accent" come from the player's palette so skins work.
local GUNMETAL = Color3.fromRGB(58, 61, 70)
local DARK = Color3.fromRGB(19, 20, 24)
local GRIP = Color3.fromRGB(32, 33, 38)
local STEEL = Color3.fromRGB(196, 202, 210)
local LENS_TINT = Color3.fromRGB(8, 14, 30)

type Spec = { wedge: boolean, shape: Enum.PartType, size: Vector3, cf: CFrame, role: string }
type WeaponSpec = { muzzle: Vector3, parts: { Spec } }
type Look = { color: Color3, material: Enum.Material, transparency: number?, reflectance: number? }

-- A Cylinder's axis is the part's X axis; these turn it onto Z (barrels) or Y (upright discs).
local TO_Z = CFrame.Angles(0, rad(90), 0)
local TO_Y = CFrame.Angles(0, 0, rad(90))

local function place(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

-- Part spec constructors. Positions are part centers; rx/ry/rz are optional rotations in degrees.
-- Roles: body, accent (palette) | glow (always Neon) | metal, dark, grip, steel | lens, pane (see-through).
local function B(sx: number, sy: number, sz: number, x: number, y: number, z: number, role: string, rx: number?, ry: number?, rz: number?): Spec
	return { wedge = false, shape = Enum.PartType.Block, size = Vector3.new(sx, sy, sz), cf = place(x, y, z, rx, ry, rz), role = role }
end

-- Wedge: bottom and +Z faces are full; the slope runs from the -Z bottom edge up to the +Z top edge.
local function W(sx: number, sy: number, sz: number, x: number, y: number, z: number, role: string, rx: number?, ry: number?, rz: number?): Spec
	return { wedge = true, shape = Enum.PartType.Block, size = Vector3.new(sx, sy, sz), cf = place(x, y, z, rx, ry, rz), role = role }
end

-- Cylinders by diameter and length, with the axis along Z, X or Y.
local function CZ(d: number, len: number, x: number, y: number, z: number, role: string, rx: number?, ry: number?, rz: number?): Spec
	return { wedge = false, shape = Enum.PartType.Cylinder, size = Vector3.new(len, d, d), cf = place(x, y, z, rx, ry, rz) * TO_Z, role = role }
end

local function CX(d: number, len: number, x: number, y: number, z: number, role: string, rx: number?, ry: number?, rz: number?): Spec
	return { wedge = false, shape = Enum.PartType.Cylinder, size = Vector3.new(len, d, d), cf = place(x, y, z, rx, ry, rz), role = role }
end

local function CY(d: number, len: number, x: number, y: number, z: number, role: string): Spec
	return { wedge = false, shape = Enum.PartType.Cylinder, size = Vector3.new(len, d, d), cf = place(x, y, z) * TO_Y, role = role }
end

local function O(d: number, x: number, y: number, z: number, role: string): Spec
	return { wedge = false, shape = Enum.PartType.Ball, size = Vector3.new(d, d, d), cf = place(x, y, z), role = role }
end

local SPECS: { [string]: WeaponSpec } = {}

-- Assault rifle: holo sight, beveled handguard, vertical foregrip, curved mag, adjustable stock.
SPECS.Paragon = {
	muzzle = Vector3.new(0, 0.22, -3.12),
	parts = {
		-- receiver
		B(0.36, 0.28, 1.70, 0, 0.24, -0.45, "body"),
		B(0.30, 0.20, 1.00, 0, 0.02, -0.30, "body"),
		B(0.365, 0.025, 1.50, 0, 0.16, -0.45, "dark"),
		B(0.02, 0.10, 0.34, 0.18, 0.27, -0.30, "accent"),
		B(0.16, 0.04, 2.60, 0, 0.40, -1.05, "metal"),
		-- beveled handguard
		B(0.34, 0.26, 1.10, 0, 0.19, -1.85, "body"),
		B(0.24, 0.06, 1.10, 0, 0.35, -1.85, "body"),
		W(1.10, 0.06, 0.05, -0.145, 0.35, -1.85, "body", 0, 90, 0),
		W(1.10, 0.06, 0.05, 0.145, 0.35, -1.85, "body", 0, -90, 0),
		B(0.345, 0.06, 0.70, 0, 0.12, -1.85, "dark"),
		B(0.02, 0.04, 0.85, 0.172, 0.24, -1.85, "glow"),
		B(0.02, 0.04, 0.85, -0.172, 0.24, -1.85, "glow"),
		B(0.28, 0.26, 0.06, 0, 0.22, -2.43, "accent"),
		-- barrel
		CZ(0.10, 0.50, 0, 0.22, -2.68, "metal"),
		CZ(0.17, 0.24, 0, 0.22, -2.98, "dark"),
		CZ(0.18, 0.03, 0, 0.22, -2.90, "glow"),
		-- foregrip
		CY(0.15, 0.34, 0, -0.10, -1.90, "grip"),
		CY(0.17, 0.04, 0, -0.28, -1.90, "accent"),
		-- magazine
		B(0.26, 0.12, 0.40, 0, -0.12, -0.60, "body"),
		B(0.20, 0.32, 0.30, 0, -0.32, -0.62, "dark", 8),
		B(0.20, 0.30, 0.30, 0, -0.619, -0.693, "dark", 20),
		B(0.24, 0.06, 0.34, 0, -0.788, -0.755, "accent", 20),
		B(0.21, 0.20, 0.05, 0, -0.328, -0.561, "glow", 8),
		-- grip and trigger
		B(0.20, 0.48, 0.26, 0, -0.16, 0.12, "grip", -18),
		B(0.05, 0.04, 0.34, 0, -0.17, -0.20, "dark"),
		B(0.04, 0.13, 0.04, 0, -0.10, -0.16, "metal", -10),
		-- stock
		CZ(0.14, 0.50, 0, 0.24, 0.62, "metal"),
		B(0.24, 0.36, 0.55, 0, 0.14, 1.12, "body"),
		W(0.24, 0.22, 0.40, 0, -0.15, 1.18, "body", 0, 0, 180),
		B(0.26, 0.62, 0.08, 0, 0.04, 1.43, "grip"),
		B(0.245, 0.04, 0.42, 0, 0.22, 1.12, "glow"),
		-- holo sight (window centered on the aim line)
		B(0.22, 0.05, 0.42, 0, 0.445, -0.50, "metal"),
		B(0.04, 0.24, 0.34, 0.12, 0.59, -0.50, "body"),
		B(0.04, 0.24, 0.34, -0.12, 0.59, -0.50, "body"),
		B(0.28, 0.05, 0.34, 0, 0.735, -0.50, "body"),
		B(0.20, 0.24, 0.02, 0, 0.59, -0.66, "pane"),
		B(0.03, 0.03, 0.01, 0, 0.55, -0.64, "glow"),
	},
}

-- Pump shotgun: heavy receiver, shrouded barrel over a tube magazine, ribbed pump, skeleton stock.
SPECS.Breaker = {
	muzzle = Vector3.new(0, 0.24, -2.98),
	parts = {
		-- receiver
		B(0.40, 0.44, 1.30, 0, 0.15, -0.35, "body"),
		B(0.14, 0.04, 1.20, 0, 0.39, -0.35, "metal"),
		B(0.405, 0.18, 0.80, 0, 0.18, -0.45, "dark"),
		B(0.41, 0.03, 0.60, 0, 0.18, -0.45, "glow"),
		B(0.20, 0.03, 0.40, 0, -0.08, -0.60, "dark"),
		-- barrel and heat shield
		CZ(0.16, 1.80, 0, 0.24, -1.90, "metal"),
		B(0.22, 0.08, 1.30, 0, 0.335, -1.75, "body"),
		B(0.225, 0.025, 1.10, 0, 0.31, -1.75, "glow"),
		CZ(0.22, 0.20, 0, 0.24, -2.86, "dark"),
		CZ(0.23, 0.03, 0, 0.24, -2.78, "glow"),
		-- sights
		B(0.04, 0.17, 0.04, 0, 0.435, -2.82, "metal"),
		O(0.06, 0, 0.53, -2.82, "glow"),
		B(0.05, 0.12, 0.08, 0.07, 0.47, -0.05, "metal"),
		B(0.05, 0.12, 0.08, -0.07, 0.47, -0.05, "metal"),
		-- tube magazine
		CZ(0.14, 1.75, 0, 0.04, -1.86, "metal"),
		B(0.12, 0.22, 0.10, 0, 0.14, -2.55, "metal"),
		CZ(0.16, 0.06, 0, 0.04, -2.75, "accent"),
		-- pump
		B(0.28, 0.24, 0.80, 0, 0.04, -1.60, "grip"),
		B(0.29, 0.25, 0.05, 0, 0.04, -1.38, "dark"),
		B(0.29, 0.25, 0.05, 0, 0.04, -1.60, "dark"),
		B(0.29, 0.25, 0.05, 0, 0.04, -1.82, "dark"),
		B(0.30, 0.27, 0.06, 0, 0.04, -2.02, "accent"),
		-- grip and trigger
		B(0.05, 0.04, 0.36, 0, -0.17, -0.12, "dark"),
		B(0.035, 0.12, 0.04, 0, -0.11, -0.08, "metal", -10),
		B(0.22, 0.50, 0.28, 0, -0.22, 0.18, "grip", -22),
		-- skeleton stock
		B(0.24, 0.14, 0.75, 0, 0.27, 0.68, "body"),
		B(0.20, 0.10, 0.86, 0, -0.27, 0.70, "body", -20.6),
		B(0.28, 0.58, 0.30, 0, 0.05, 1.20, "body"),
		B(0.30, 0.62, 0.07, 0, 0.05, 1.385, "grip"),
		B(0.285, 0.04, 0.25, 0, 0.18, 1.20, "glow"),
	},
}

-- SMG: compact boxy frame, long straight mag, folding rod stock, mini reflex sight.
SPECS.Hornet = {
	muzzle = Vector3.new(0, 0.22, -1.78),
	parts = {
		-- frame
		B(0.32, 0.30, 1.30, 0, 0.22, -0.42, "body"),
		B(0.28, 0.20, 0.90, 0, -0.02, -0.38, "body"),
		W(0.28, 0.20, 0.30, 0, -0.02, -0.98, "body", 0, 0, 180),
		B(0.14, 0.04, 1.00, 0, 0.39, -0.45, "metal"),
		B(0.33, 0.03, 0.90, 0, 0.25, -0.55, "glow"),
		B(0.325, 0.02, 1.10, 0, 0.12, -0.45, "dark"),
		B(0.08, 0.06, 0.10, -0.19, 0.30, -0.75, "metal"),
		-- barrel
		CZ(0.10, 0.50, 0, 0.22, -1.30, "metal"),
		CZ(0.16, 0.22, 0, 0.22, -1.65, "dark"),
		CZ(0.17, 0.03, 0, 0.22, -1.57, "glow"),
		-- long magazine
		B(0.22, 0.12, 0.30, 0, -0.17, -0.55, "body"),
		B(0.17, 0.85, 0.24, 0, -0.62, -0.58, "dark", 4),
		B(0.18, 0.55, 0.03, 0, -0.62, -0.58, "glow", 4),
		B(0.20, 0.06, 0.28, 0, -1.074, -0.612, "accent", 4),
		-- grip and trigger
		B(0.18, 0.44, 0.24, 0, -0.20, 0.08, "grip", -15),
		B(0.05, 0.04, 0.30, 0, -0.22, -0.20, "dark"),
		B(0.035, 0.12, 0.04, 0, -0.16, -0.13, "metal", -10),
		-- folding rod stock
		B(0.30, 0.16, 0.10, 0, 0.18, 0.27, "metal"),
		CZ(0.06, 0.70, 0.11, 0.14, 0.62, "metal"),
		CZ(0.06, 0.70, -0.11, 0.14, 0.62, "metal"),
		B(0.28, 0.40, 0.07, 0, 0.04, 1.00, "grip"),
		B(0.29, 0.06, 0.08, 0, -0.16, 1.00, "accent"),
		-- mini reflex sight
		B(0.16, 0.05, 0.24, 0, 0.435, -0.35, "metal"),
		B(0.03, 0.18, 0.20, 0.085, 0.55, -0.37, "body"),
		B(0.03, 0.18, 0.20, -0.085, 0.55, -0.37, "body"),
		B(0.20, 0.04, 0.22, 0, 0.66, -0.37, "body"),
		B(0.14, 0.18, 0.015, 0, 0.55, -0.46, "pane"),
		B(0.025, 0.025, 0.01, 0, 0.55, -0.45, "glow"),
	},
}

-- Burst rifle: bullpup shell (mag behind the grip), full hand guard, triple-dot sight.
SPECS.Triad = {
	muzzle = Vector3.new(0, 0.26, -2.60),
	parts = {
		-- shell
		B(0.38, 0.30, 1.80, 0, 0.23, -0.60, "body"),
		B(0.36, 0.50, 0.95, 0, 0.05, 0.75, "body"),
		W(0.36, 0.08, 0.30, 0, 0.34, 0.45, "body", 0, 180, 0),
		B(0.34, 0.18, 1.65, 0, -0.01, -0.55, "body"),
		W(0.38, 0.30, 0.35, 0, 0.23, -1.675, "body", 0, 0, 180),
		B(0.30, 0.20, 0.08, 0, -0.18, -1.33, "accent"),
		B(0.38, 0.54, 0.07, 0, 0.05, 1.26, "grip"),
		B(0.39, 0.035, 1.60, 0, 0.30, -0.65, "glow"),
		B(0.37, 0.035, 0.70, 0, 0.12, 0.75, "glow"),
		B(0.385, 0.02, 1.75, 0, 0.085, -0.60, "dark"),
		B(0.02, 0.12, 0.40, 0.185, 0.15, 0.70, "dark"),
		-- barrel
		CZ(0.10, 0.65, 0, 0.26, -2.05, "metal"),
		CZ(0.16, 0.25, 0, 0.26, -2.45, "dark"),
		CZ(0.17, 0.03, 0, 0.26, -2.34, "glow"),
		-- grip, full hand guard, trigger
		B(0.18, 0.46, 0.25, 0, -0.26, -0.02, "grip", -15),
		B(0.06, 0.05, 0.56, 0, -0.50, -0.38, "dark"),
		B(0.06, 0.42, 0.06, 0, -0.31, -0.65, "dark"),
		B(0.035, 0.13, 0.045, 0, -0.16, -0.25, "metal", -10),
		-- magazine behind the grip
		B(0.20, 0.42, 0.32, 0, -0.36, 0.50, "dark", 10),
		B(0.205, 0.24, 0.06, 0, -0.36, 0.50, "glow", 10),
		B(0.24, 0.05, 0.36, 0, -0.591, 0.459, "accent", 10),
		-- rail and long holo sight with a three-dot reticle
		B(0.16, 0.04, 1.60, 0, 0.40, -0.55, "metal"),
		B(0.22, 0.05, 0.50, 0, 0.445, -0.45, "metal"),
		B(0.04, 0.22, 0.46, 0.12, 0.58, -0.45, "body"),
		B(0.04, 0.22, 0.46, -0.12, 0.58, -0.45, "body"),
		B(0.28, 0.05, 0.46, 0, 0.715, -0.45, "body"),
		B(0.20, 0.22, 0.02, 0, 0.58, -0.67, "pane"),
		B(0.025, 0.025, 0.01, 0, 0.55, -0.65, "glow"),
		B(0.02, 0.02, 0.01, 0.035, 0.515, -0.65, "glow"),
		B(0.02, 0.02, 0.01, -0.035, 0.515, -0.65, "glow"),
	},
}

-- Bolt sniper: long free-float barrel with brake, bipod, big scope with glass lenses, bolt handle.
SPECS.Meridian = {
	muzzle = Vector3.new(0, 0.20, -4.00),
	parts = {
		-- action and chassis
		CZ(0.26, 1.10, 0, 0.24, -0.35, "metal"),
		B(0.32, 0.24, 1.30, 0, 0.03, -0.35, "body"),
		B(0.30, 0.30, 1.50, 0, 0.20, -1.75, "body"),
		B(0.305, 0.10, 1.20, 0, 0.20, -1.75, "dark"),
		B(0.31, 0.03, 1.10, 0, 0.20, -1.75, "glow"),
		B(0.14, 0.04, 1.30, 0, 0.39, -0.45, "metal"),
		-- scope
		CZ(0.20, 1.30, 0, 0.55, -0.45, "body"),
		CZ(0.26, 0.08, 0, 0.55, -0.10, "metal"),
		CZ(0.26, 0.08, 0, 0.55, -0.80, "metal"),
		CZ(0.26, 0.10, 0, 0.55, -1.15, "metal"),
		CZ(0.32, 0.35, 0, 0.55, -1.375, "body"),
		CZ(0.33, 0.04, 0, 0.55, -1.52, "glow"),
		CZ(0.27, 0.02, 0, 0.55, -1.555, "lens"),
		CZ(0.26, 0.30, 0, 0.55, 0.32, "body"),
		CZ(0.20, 0.02, 0, 0.55, 0.475, "lens"),
		CY(0.12, 0.14, 0, 0.70, -0.45, "metal"),
		CY(0.13, 0.03, 0, 0.775, -0.45, "accent"),
		CX(0.12, 0.14, 0.13, 0.55, -0.45, "metal"),
		-- barrel
		CZ(0.12, 1.30, 0, 0.20, -3.10, "metal"),
		B(0.20, 0.14, 0.26, 0, 0.20, -3.85, "dark"),
		B(0.205, 0.04, 0.16, 0, 0.20, -3.85, "glow"),
		-- bipod
		B(0.16, 0.08, 0.12, 0, 0.02, -2.35, "metal"),
		B(0.06, 0.60, 0.06, 0.153, -0.239, -2.471, "metal", 25, 0, 18),
		B(0.06, 0.60, 0.06, -0.153, -0.239, -2.471, "metal", 25, 0, -18),
		-- bolt
		CX(0.05, 0.28, 0.25, 0.20, 0.05, "metal", 0, 0, -30),
		O(0.11, 0.37, 0.13, 0.05, "accent"),
		CZ(0.20, 0.15, 0, 0.24, 0.27, "dark"),
		-- magazine, grip, trigger
		B(0.20, 0.30, 0.36, 0, -0.22, -0.55, "dark"),
		B(0.22, 0.05, 0.38, 0, -0.39, -0.55, "accent"),
		B(0.05, 0.04, 0.32, 0, -0.20, -0.12, "dark"),
		B(0.035, 0.12, 0.04, 0, -0.12, -0.10, "metal", -10),
		B(0.20, 0.48, 0.26, 0, -0.16, 0.18, "grip", -20),
		-- precision stock
		B(0.24, 0.16, 1.00, 0, 0.16, 0.82, "body"),
		B(0.20, 0.08, 0.50, 0, 0.28, 0.95, "metal"),
		B(0.20, 0.10, 0.86, 0, -0.27, 0.70, "body", -20.6),
		B(0.26, 0.66, 0.14, 0, 0.00, 1.39, "grip"),
		B(0.245, 0.03, 0.80, 0, 0.16, 0.82, "glow"),
	},
}

-- Pistol: beveled slide with serrations, polymer frame, under-barrel light, three-dot style sights.
SPECS.Ward = {
	muzzle = Vector3.new(0, 0.30, -1.18),
	parts = {
		-- slide
		B(0.24, 0.20, 1.30, 0, 0.28, -0.45, "body"),
		B(0.14, 0.06, 1.30, 0, 0.41, -0.45, "body"),
		W(1.30, 0.06, 0.05, -0.095, 0.41, -0.45, "body", 0, 90, 0),
		W(1.30, 0.06, 0.05, 0.095, 0.41, -0.45, "body", 0, -90, 0),
		B(0.245, 0.14, 0.03, 0, 0.29, 0.13, "dark"),
		B(0.245, 0.14, 0.03, 0, 0.29, 0.07, "dark"),
		B(0.245, 0.14, 0.03, 0, 0.29, 0.01, "dark"),
		B(0.245, 0.025, 0.65, 0, 0.23, -0.70, "glow"),
		B(0.245, 0.06, 0.18, 0, 0.33, -0.98, "accent"),
		B(0.20, 0.16, 0.03, 0, 0.30, 0.21, "metal"),
		CZ(0.10, 0.10, 0, 0.30, -1.12, "metal"),
		-- frame and under-barrel light
		B(0.22, 0.12, 1.10, 0, 0.12, -0.48, "dark"),
		B(0.18, 0.06, 0.40, 0, 0.03, -0.80, "metal"),
		B(0.18, 0.12, 0.30, 0, -0.06, -0.88, "body"),
		B(0.12, 0.08, 0.02, 0, -0.06, -1.035, "glow"),
		-- grip and trigger
		B(0.20, 0.62, 0.30, 0, -0.22, 0.08, "dark", -15),
		B(0.215, 0.42, 0.22, 0, -0.24, 0.09, "grip", -15),
		B(0.21, 0.05, 0.30, 0, -0.539, 0.165, "accent", -15),
		B(0.18, 0.06, 0.20, 0, 0.15, 0.15, "dark"),
		B(0.05, 0.18, 0.05, 0, -0.03, -0.42, "dark"),
		B(0.05, 0.04, 0.35, 0, -0.12, -0.26, "dark"),
		B(0.035, 0.13, 0.04, 0, 0.00, -0.18, "metal", -10),
		-- sights
		B(0.05, 0.08, 0.06, 0.05, 0.48, 0.12, "metal"),
		B(0.05, 0.08, 0.06, -0.05, 0.48, 0.12, "metal"),
		B(0.035, 0.08, 0.05, 0, 0.48, -1.00, "metal"),
		B(0.03, 0.03, 0.015, 0, 0.50, -0.97, "glow"),
	},
}

-- Revolver: open frame, fluted cylinder with a glowing band, full-lug barrel, hammer, curved grip.
SPECS.Verdict = {
	muzzle = Vector3.new(0, 0.34, -1.46),
	parts = {
		-- frame
		B(0.22, 0.46, 0.18, 0, 0.21, 0.20, "body"),
		B(0.22, 0.46, 0.14, 0, 0.21, -0.47, "body"),
		B(0.20, 0.07, 0.83, 0, 0.465, -0.125, "body"),
		B(0.20, 0.10, 0.83, 0, -0.03, -0.125, "body"),
		-- cylinder
		CZ(0.40, 0.50, 0, 0.23, -0.15, "metal"),
		B(0.42, 0.05, 0.42, 0, 0.23, -0.15, "dark"),
		B(0.42, 0.05, 0.42, 0, 0.23, -0.15, "dark", 0, 0, 60),
		B(0.42, 0.05, 0.42, 0, 0.23, -0.15, "dark", 0, 0, -60),
		CZ(0.41, 0.04, 0, 0.23, -0.15, "glow"),
		-- barrel
		B(0.20, 0.20, 0.85, 0, 0.34, -0.965, "body"),
		B(0.16, 0.14, 0.85, 0, 0.17, -0.965, "body"),
		B(0.205, 0.03, 0.70, 0, 0.30, -1.00, "glow"),
		CZ(0.12, 0.06, 0, 0.34, -1.42, "metal"),
		-- sights and hammer
		B(0.04, 0.09, 0.12, 0, 0.485, -1.30, "metal"),
		B(0.03, 0.03, 0.02, 0, 0.51, -1.235, "glow"),
		B(0.05, 0.06, 0.06, 0.05, 0.53, 0.22, "metal"),
		B(0.05, 0.06, 0.06, -0.05, 0.53, 0.22, "metal"),
		B(0.06, 0.18, 0.08, 0, 0.47, 0.33, "metal", 25),
		B(0.08, 0.04, 0.10, 0, 0.56, 0.39, "metal", 25),
		-- curved grip
		B(0.20, 0.30, 0.30, 0, -0.15, 0.22, "grip", -25),
		B(0.20, 0.30, 0.32, 0, -0.434, 0.309, "grip", -10),
		B(0.22, 0.04, 0.34, 0, -0.601, 0.339, "accent", -10),
		B(0.21, 0.08, 0.08, 0, -0.25, 0.27, "glow", -18),
		-- trigger
		B(0.05, 0.04, 0.32, 0, -0.17, -0.13, "dark"),
		B(0.05, 0.16, 0.05, 0, -0.09, -0.29, "dark"),
		B(0.035, 0.13, 0.04, 0, -0.07, -0.06, "metal", -12),
	},
}

-- Combat knife: wrapped handle, cross guard, steel blade with a glowing edge and clipped tip.
SPECS.Edge = {
	muzzle = Vector3.new(0, 0.18, -1.50),
	parts = {
		-- handle
		B(0.16, 0.22, 0.60, 0, 0, 0.02, "grip"),
		B(0.17, 0.23, 0.03, 0, 0, 0.20, "dark"),
		B(0.17, 0.23, 0.03, 0, 0, -0.16, "dark"),
		B(0.175, 0.235, 0.03, 0, 0, 0.02, "glow"),
		B(0.20, 0.26, 0.10, 0, 0, 0.37, "metal"),
		B(0.12, 0.14, 0.05, 0, 0, 0.44, "accent"),
		-- guard
		B(0.22, 0.48, 0.08, 0, 0.02, -0.32, "metal"),
		B(0.24, 0.06, 0.10, 0, 0.24, -0.32, "accent"),
		B(0.24, 0.06, 0.10, 0, -0.20, -0.32, "accent"),
		-- blade
		B(0.06, 0.26, 0.08, 0, 0.05, -0.40, "metal"),
		B(0.05, 0.26, 0.85, 0, 0.05, -0.785, "steel"),
		W(0.05, 0.26, 0.29, 0, 0.05, -1.355, "steel", 0, 0, 180),
		B(0.055, 0.025, 0.85, 0, -0.07, -0.785, "glow"),
		B(0.055, 0.025, 0.39, 0, 0.044, -1.36, "glow", 41.8),
		B(0.055, 0.03, 0.60, 0, 0.10, -0.75, "dark"),
		B(0.06, 0.03, 0.50, 0, 0.185, -0.65, "metal"),
	},
}

-- Fallback for utilities and unknown ids: a sci-fi grenade held at the grip.
SPECS.Grenade = {
	muzzle = Vector3.zero,
	parts = {
		CY(0.40, 0.28, 0, 0, 0, "body"),
		O(0.40, 0, 0.14, 0, "body"),
		O(0.40, 0, -0.14, 0, "body"),
		CY(0.42, 0.06, 0, 0, 0, "metal"),
		CY(0.42, 0.04, 0, 0.08, 0, "glow"),
		CY(0.42, 0.04, 0, -0.08, 0, "glow"),
		B(0.42, 0.24, 0.05, 0, 0, 0, "dark"),
		B(0.05, 0.24, 0.42, 0, 0, 0, "dark"),
		CY(0.16, 0.10, 0, 0.37, 0, "metal"),
		CY(0.10, 0.03, 0, 0.43, 0, "glow"),
		B(0.08, 0.32, 0.03, 0, 0.10, -0.215, "metal"),
		B(0.08, 0.21, 0.03, 0, 0.335, -0.143, "metal", 44),
		CX(0.14, 0.02, 0.10, 0.37, 0, "accent"),
		CX(0.08, 0.03, 0.10, 0.37, 0, "dark"),
	},
}

-- Accents too dark to read as light (e.g. Chrome) glow in the ally cyan instead.
local function glowColor(accent: Color3): Color3
	if accent.R * 0.299 + accent.G * 0.587 + accent.B * 0.114 < 0.4 then
		return Config.Colors.Ally
	end
	return accent
end

local function looksFor(palette): { [string]: Look }
	local bodyMaterial = palette.material or Enum.Material.SmoothPlastic
	local glow = glowColor(palette.accent)
	return {
		body = { color = palette.body, material = bodyMaterial },
		accent = { color = palette.accent, material = palette.neon and Enum.Material.Neon or bodyMaterial },
		glow = { color = glow, material = Enum.Material.Neon },
		metal = { color = GUNMETAL, material = Enum.Material.Metal },
		dark = { color = DARK, material = Enum.Material.SmoothPlastic },
		grip = { color = GRIP, material = Enum.Material.DiamondPlate },
		steel = { color = STEEL, material = Enum.Material.Metal, reflectance = 0.15 },
		lens = { color = glow:Lerp(LENS_TINT, 0.6), material = Enum.Material.Glass, transparency = 0.3, reflectance = 0.25 },
		pane = { color = glow, material = Enum.Material.SmoothPlastic, transparency = 0.85 },
	}
end

-- Held and viewmodel parts never collide, get raycast, touch or cast shadows.
local function finish(part: BasePart)
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local WeaponModels = {}

function WeaponModels.build(id: string, paletteName: string?): Model
	local spec = SPECS[id] or SPECS.Grenade
	local palette = Config.Palettes[paletteName or "Default"] or Config.Palettes.Default
	local looks = looksFor(palette)
	local model = Instance.new("Model")
	model.Name = id

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.CFrame = CFrame.identity
	handle.Transparency = 1
	finish(handle)
	handle.Parent = model
	model.PrimaryPart = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = spec.muzzle
	muzzle.Parent = handle

	for _, p in spec.parts do
		local part: BasePart
		if p.wedge then
			part = Instance.new("WedgePart")
		else
			local shaped = Instance.new("Part")
			shaped.Shape = p.shape
			part = shaped
		end
		local look = looks[p.role] or looks.body
		part.Name = string.upper(string.sub(p.role, 1, 1)) .. string.sub(p.role, 2)
		part.Size = p.size
		part.CFrame = p.cf
		part.Color = look.color
		part.Material = look.material
		part.Transparency = look.transparency or 0
		part.Reflectance = look.reflectance or 0
		finish(part)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	return model
end

return WeaponModels
