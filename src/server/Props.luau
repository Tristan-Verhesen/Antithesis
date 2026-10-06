-- Shared building blocks for the generated map (lobby, range, arenas).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Colors
local Props = {}

function Props.block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?, material: Enum.Material?): Part
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

function Props.neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Props.block(parent, size, cf, color, "Neon", Enum.Material.Neon)
	p.CastShadow = false
	return p
end

-- Flat vertical-axis cylinder (pads, rings).
function Props.disc(parent: Instance, center: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material?): Part
	local p = Props.block(parent, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, "Disc", material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Props.walls(parent: Instance, origin: Vector3, sx: number, sz: number, height: number, color: Color3)
	Props.block(parent, Vector3.new(sx + 2, height, 1), CFrame.new(origin + Vector3.new(0, height / 2, sz / 2 + 0.5)), color)
	Props.block(parent, Vector3.new(sx + 2, height, 1), CFrame.new(origin + Vector3.new(0, height / 2, -sz / 2 - 0.5)), color)
	Props.block(parent, Vector3.new(1, height, sz), CFrame.new(origin + Vector3.new(sx / 2 + 0.5, height / 2, 0)), color)
	Props.block(parent, Vector3.new(1, height, sz), CFrame.new(origin + Vector3.new(-sx / 2 - 0.5, height / 2, 0)), color)
end

-- A flat sign whose front face looks along `facing`.
function Props.sign(parent: Instance, pos: Vector3, facing: Vector3, size: Vector2, text: string, color: Color3?): TextLabel
	local part = Props.block(parent, Vector3.new(size.X, size.Y, 0.4), CFrame.lookAt(pos, pos + facing), C.Metal, "Sign")
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

function Props.glowPad(parent: Instance, center: Vector3, color: Color3): Part
	local ring = Props.disc(parent, center + Vector3.new(0, 0.11, 0), 10, 0.12, color, Enum.Material.Neon)
	Props.disc(parent, center + Vector3.new(0, 0.2, 0), 8.6, 0.3, C.Metal)
	Props.disc(parent, center + Vector3.new(0, 0.21, 0), 3, 0.32, color, Enum.Material.Neon)
	return ring
end

-- Ceiling light: a glowing panel that lights the area below it.
function Props.lightPanel(parent: Instance, cf: CFrame, size: Vector3, color: Color3, brightness: number?, range: number?): Part
	local p = Props.neon(parent, size, cf, color)
	p.Name = "LightPanel"
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = color
	light.Brightness = brightness or 1.5
	light.Range = range or 20
	light.Angle = 120
	light.Shadows = true
	light.Parent = p
	return p
end

function Props.pointLight(part: BasePart, color: Color3, range: number?, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 14
	light.Brightness = brightness or 1
	light.Shadows = false
	light.Parent = part
	return light
end

-- Purely visual part: never collides, blocks shots or triggers touches.
function Props.decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

return Props
