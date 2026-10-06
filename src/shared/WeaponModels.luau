-- Builds low-poly weapon models from boxes so no assets are needed.
-- Model space: grip at origin, barrel points toward -Z. Part = {sx, sy, sz, x, y, z, accent?, shape?}
local Config = require(script.Parent.Config)

local SPECS = {
	Paragon = { muzzle = Vector3.new(0, 0.15, -2.9), parts = {
		{ 0.4, 0.5, 2.2, 0, 0.1, -0.7 },
		{ 0.18, 0.18, 1.2, 0, 0.15, -2.3, true },
		{ 0.3, 0.7, 0.35, 0, -0.45, -0.9, true },
		{ 0.3, 0.45, 1.0, 0, 0, 0.8 },
		{ 0.1, 0.15, 0.6, 0, 0.42, -0.6, true },
	} },
	Breaker = { muzzle = Vector3.new(0, 0.2, -2.8), parts = {
		{ 0.45, 0.5, 1.6, 0, 0.1, -0.5 },
		{ 0.22, 0.22, 1.6, 0, 0.2, -2.0, true },
		{ 0.3, 0.3, 0.8, 0, -0.1, -1.6, true },
		{ 0.35, 0.5, 1.0, 0, 0, 0.8 },
	} },
	Hornet = { muzzle = Vector3.new(0, 0.15, -1.7), parts = {
		{ 0.35, 0.5, 1.4, 0, 0.1, -0.4 },
		{ 0.15, 0.15, 0.6, 0, 0.15, -1.4, true },
		{ 0.22, 0.9, 0.25, 0, -0.55, -0.3, true },
		{ 0.15, 0.3, 0.7, 0, 0, 0.6 },
	} },
	Triad = { muzzle = Vector3.new(0, 0.15, -2.6), parts = {
		{ 0.4, 0.55, 2.0, 0, 0.1, -0.6 },
		{ 0.2, 0.2, 1.0, 0, 0.15, -2.1, true },
		{ 0.3, 0.6, 0.35, 0, -0.45, -0.7, true },
		{ 0.35, 0.5, 0.9, 0, 0, 0.75 },
		{ 0.25, 0.25, 0.4, 0, 0.45, -0.5, true },
	} },
	Meridian = { muzzle = Vector3.new(0, 0.15, -3.8), parts = {
		{ 0.4, 0.5, 2.4, 0, 0.1, -0.8 },
		{ 0.15, 0.15, 1.8, 0, 0.15, -2.9, true },
		{ 0.3, 0.3, 1.2, 0, 0.5, -0.7, true },
		{ 0.35, 0.6, 1.2, 0, -0.05, 0.9 },
		{ 0.3, 0.08, 0.08, 0.25, 0.2, -0.2, true },
	} },
	Ward = { muzzle = Vector3.new(0, 0.15, -0.85), parts = {
		{ 0.25, 0.35, 1.0, 0, 0.15, -0.3 },
		{ 0.22, 0.55, 0.3, 0, -0.2, 0, true },
	} },
	Verdict = { muzzle = Vector3.new(0, 0.2, -1.25), parts = {
		{ 0.2, 0.2, 1.2, 0, 0.2, -0.6 },
		{ 0.35, 0.35, 0.4, 0, 0.1, -0.1, true },
		{ 0.22, 0.55, 0.3, 0, -0.25, 0.15, true },
	} },
	Edge = { muzzle = Vector3.new(0, 0, -1.4), parts = {
		{ 0.2, 0.2, 0.6, 0, 0, 0 },
		{ 0.05, 0.25, 1.1, 0, 0.02, -0.85, true },
	} },
	Grenade = { muzzle = Vector3.zero, parts = {
		{ 0.6, 0.6, 0.6, 0, 0, 0, true, Enum.PartType.Ball },
	} },
}

local WeaponModels = {}

function WeaponModels.build(id: string, paletteName: string?): Model
	local spec = SPECS[id] or SPECS.Grenade
	local palette = Config.Palettes[paletteName or "Default"] or Config.Palettes.Default
	local model = Instance.new("Model")
	model.Name = id

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.Massless = true
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Parent = model
	model.PrimaryPart = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = spec.muzzle
	muzzle.Parent = handle

	for _, p in spec.parts do
		local part = Instance.new("Part")
		part.Shape = p[8] or Enum.PartType.Block
		part.Size = Vector3.new(p[1], p[2], p[3])
		part.CFrame = CFrame.new(p[4], p[5], p[6])
		part.Color = p[7] and palette.accent or palette.body
		part.Material = (p[7] and palette.neon) and Enum.Material.Neon or palette.material or Enum.Material.SmoothPlastic
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	return model
end

return WeaponModels
