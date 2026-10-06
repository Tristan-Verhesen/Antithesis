-- Battle arenas: one is built for every match and destroyed afterwards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

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
	local model = Instance.new("Model")
	model.Name = "Arena" .. slot
	local sx, sz = layout.size[1], layout.size[2]
	Props.block(model, Vector3.new(sx / 2, 1, sz), CFrame.new(origin + Vector3.new(-sx / 4, -0.5, 0)), C.Light, "Floor")
	Props.block(model, Vector3.new(sx / 2, 1, sz), CFrame.new(origin + Vector3.new(sx / 4, -0.5, 0)), C.Dark, "Floor")
	Props.block(model, Vector3.new(0.4, 0.05, sz), CFrame.new(origin + Vector3.new(0, 0.025, 0)), C.Gold, "CenterLine")
	Props.walls(model, origin, sx, sz, 20, GRAY)

	for _, b in layout.boxes do
		local size = Vector3.new(b[3], b[4], b[5])
		local y = (b[6] or 0) + b[4] / 2
		if b[1] == 0 then
			Props.block(model, size, CFrame.new(origin + Vector3.new(0, y, b[2])), GRAY)
		else
			Props.block(model, size, CFrame.new(origin + Vector3.new(b[1], y, b[2])), C.Dark)
			Props.block(model, size, CFrame.new(origin + Vector3.new(-b[1], y, b[2])), C.Light)
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

function Arena.destroy(arena)
	arena.model:Destroy()
	usedSlots[arena.slot] = nil
end

return Arena
