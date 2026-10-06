-- Slide, dash, crouch and per-weapon move speed. The client moves its own character; the server sanity-checks speed.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Movement = {}
local Mv = Config.Movement
local player = Players.LocalPlayer
local crouchHeld = false
local slideStart, slideEnd = 0, -99
local slideDir = Vector2.zero
local slideForce: LinearVelocity?
local camDrop = 0

local function body()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 and not root.Anchored then
		return hum, root
	end
	return nil
end

-- Horizontal-only velocity constraint; gravity and jumping still work.
local function push(root: BasePart, velocity: Vector2): LinearVelocity
	local att = root:FindFirstChild("MoveAttachment") or Instance.new("Attachment")
	att.Name = "MoveAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 1e6
	lv.PlaneVelocity = velocity
	lv.Parent = root
	return lv
end

local function stopSlide()
	State.sliding = false
	slideEnd = os.clock()
	if slideForce then
		slideForce:Destroy()
		slideForce = nil
	end
end

local function onCrouch(_, inputState)
	crouchHeld = inputState == Enum.UserInputState.Begin
	local hum, root = body()
	if crouchHeld and hum and not State.sliding and os.clock() - slideEnd >= Mv.SlideCooldown then
		local flat = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		if flat.Magnitude >= Mv.SlideMinSpeed and hum.FloorMaterial ~= Enum.Material.Air then
			State.sliding = true
			slideStart = os.clock()
			slideDir = Vector2.new(flat.Unit.X, flat.Unit.Z)
			slideForce = push(root, slideDir * Mv.SlideStart)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onDash(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local hum, root = body()
	if not hum or os.clock() < State.dashReadyAt or State.menuOpen then
		return Enum.ContextActionResult.Sink
	end
	stopSlide()
	State.dashReadyAt = os.clock() + Mv.DashRecharge
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = workspace.CurrentCamera.CFrame.LookVector
	end
	dir = (dir * Vector3.new(1, 0, 1)).Unit
	State.dashing = true
	local lv = push(root, Vector2.new(dir.X, dir.Z) * (Mv.DashDistance / Mv.DashTime))
	task.delay(Mv.DashTime, function()
		lv:Destroy()
		State.dashing = false
	end)
	return Enum.ContextActionResult.Sink
end

function Movement.init()
	ContextActionService:BindAction("Slide", onCrouch, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("Dash", onDash, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("Slide", "Slide")
	ContextActionService:SetTitle("Dash", "Dash")

	player.CharacterAdded:Connect(function()
		stopSlide()
		State.dashing = false
	end)

	RunService.RenderStepped:Connect(function(dt)
		local hum = body()
		if not hum then
			return
		end
		local w = Config.Weapons[State.weaponId or ""]
		local speed = Mv.WalkSpeed * (w and w.speed or 1)
		if State.ads then
			speed *= Mv.AdsMult
		end
		if crouchHeld and not State.sliding then
			speed = math.min(speed, Mv.CrouchSpeed)
		end
		hum.WalkSpeed = speed

		if State.sliding then
			local k = (os.clock() - slideStart) / Mv.SlideTime
			if k >= 1 or not slideForce then
				stopSlide()
			else
				slideForce.PlaneVelocity = slideDir * (Mv.SlideStart + (Mv.SlideEnd - Mv.SlideStart) * k)
			end
		end

		local low = (crouchHeld or State.sliding) and Mv.CrouchDrop or 0
		camDrop += (low - camDrop) * math.min(dt * 15, 1)
		hum.CameraOffset = Vector3.new(0, -camDrop, 0)
	end)
end

return Movement
