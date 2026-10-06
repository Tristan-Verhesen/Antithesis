-- Weapon input, firing, recoil, ADS and the first-person viewmodel. The server validates every shot.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Hud = require(script.Parent.Hud)

local Weapons = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ammo = {}
local reloadUntil = {}
local nextShot = 0
local lastShotAt = 0
local fireHeld, triggerPulled = false, false
local viewmodel: Model?
local kick, swing, adsAlpha = 0, 0, 0
local HIP = CFrame.new(1.1, -1.1, -2.2)
local ADS = CFrame.new(0, -0.55, -1.6)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function equippedId(): string?
	return player:GetAttribute(Config.Slots[State.slot])
end

-- Weapons are out in a match or in the lobby firing range; the lobby hall is weapon-free.
local function canHold(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and (player:GetAttribute("MatchId") ~= 0 or State.inRange)
end

local function canAct(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not canHold() or not root or root.Anchored or State.dashing or State.menuOpen then
		return false
	end
	local ph = State.phase
	return player:GetAttribute("MatchId") == 0 or (ph ~= nil and (ph.phase == "Live" or ph.phase == "Collapse"))
end

local function buildViewmodel()
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	local id = equippedId()
	if not id or not State.holding then
		return
	end
	viewmodel = WeaponModels.build(id, player:GetAttribute("Palette"))
	for _, p in viewmodel:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	viewmodel.Parent = camera
end

local function resetAmmo()
	ammo, reloadUntil = {}, {}
	for _, slot in Config.Slots do
		local id = player:GetAttribute(slot)
		local w = Config.Weapons[id or ""]
		if w and w.mag then
			ammo[id] = w.mag
		end
	end
end

local function cone(dir: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return dir
	end
	local r = math.rad(degrees) * math.sqrt(math.random())
	local theta = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, theta) * CFrame.Angles(r, 0, 0)).LookVector
end

function Weapons.reload()
	local id = equippedId()
	local w = Config.Weapons[id or ""]
	if not (w and w.mag) or ammo[id] >= w.mag or os.clock() < (reloadUntil[id] or 0) then
		return
	end
	local time = w.perShell and w.reload * (w.mag - ammo[id]) or w.reload
	reloadUntil[id] = os.clock() + time
	Net.Event:FireServer("Reload", id)
	task.delay(time, function()
		if ammo[id] then
			ammo[id] = w.mag
		end
	end)
end

local function shoot(id: string, w)
	local origin = camera.CFrame.Position
	local root = player.Character.HumanoidRootPart
	local moving = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 4
	local spread = State.ads and w.adsSpread or w.spread
	if moving then
		spread = spread * 1.6 + (State.ads and 0 or 1)
	elseif not w.pellets and not w.scope and os.clock() - lastShotAt > 0.3 then
		spread = 0 -- counter-strafe reward: perfect first shot when stopped
	end
	params.FilterDescendantsInstances = { player.Character, camera }
	local shots = {}
	for i = 1, w.pellets or 1 do
		local dir = cone(camera.CFrame.LookVector, spread)
		local hit = workspace:Raycast(origin, dir * Config.Range, params)
		shots[i] = { dir, hit and hit.Instance, hit and hit.Position or origin + dir * Config.Range }
	end
	Net.Event:FireServer("Fire", id, origin, shots, workspace:GetServerTimeNow(), State.scoped)
	lastShotAt = os.clock()
	ammo[id] -= 1

	local muzzle = viewmodel and viewmodel.PrimaryPart:FindFirstChild("Muzzle")
	local from = muzzle and not State.scoped and muzzle.WorldPosition or origin - Vector3.new(0, 0.3, 0)
	for _, s in shots do
		Hud.tracer(from, s[3])
	end
	UI.sound(Config.Sounds.Shot, w.pellets and 1.1 or w.scope and 0.9 or 1.6, 0.35)
	local recoil = w.recoil * (State.ads and 0.6 or 1)
	camera.CFrame *= CFrame.Angles(math.rad(recoil), math.rad((math.random() - 0.5) * recoil * 0.3), 0)
	kick = math.min(kick + 0.4, 1)
	if ammo[id] <= 0 then
		task.delay(0.15, Weapons.reload)
	end
end

local function tryFire()
	local id = equippedId()
	local w = Config.Weapons[id or ""]
	local now = os.clock()
	if not w or not canAct() or now < nextShot or now < (reloadUntil[id] or 0) then
		return
	end
	if w.slot == "Melee" then
		if not triggerPulled then
			return
		end
		triggerPulled = false
		nextShot = now + w.interval
		swing = 1
		UI.sound(Config.Sounds.Melee, 1, 0.5)
		params.FilterDescendantsInstances = { player.Character, camera }
		local hit = workspace:Spherecast(camera.CFrame.Position, 1.5, camera.CFrame.LookVector * w.range, params)
		if hit then
			Net.Event:FireServer("Melee", hit.Instance)
		end
		return
	end
	if not (w.auto or triggerPulled) then
		return
	end
	triggerPulled = false
	if ammo[id] <= 0 then
		Weapons.reload()
		return
	end
	if w.burst then
		nextShot = now + w.burstDelay + w.interval * (w.burst - 1)
		task.spawn(function()
			for i = 1, w.burst do
				if ammo[id] <= 0 or not canAct() or equippedId() ~= id then
					break
				end
				shoot(id, w)
				if i < w.burst then
					task.wait(w.interval)
				end
			end
		end)
	else
		nextShot = now + w.interval
		shoot(id, w)
	end
end

function Weapons.equip(slot: number)
	if slot == State.slot or not State.holding or not player:GetAttribute(Config.Slots[slot]) then
		return
	end
	State.slot = slot
	nextShot = os.clock() + (slot == 1 and 0.35 or slot == 2 and 0.2 or 0.15)
	buildViewmodel()
	Net.Event:FireServer("Equip", slot)
end

local function refresh()
	resetAmmo()
	buildViewmodel()
	Net.Event:FireServer("Equip", State.holding and State.slot or 0)
end

local function render(dt: number)
	local holding = canHold()
	if holding ~= State.holding then -- entered/left the range, a match, or died
		State.holding = holding
		if not holding then
			State.ads = false
			fireHeld = false
		end
		buildViewmodel()
		Net.Event:FireServer("Equip", holding and State.slot or 0)
	end
	local id = equippedId()
	local w = Config.Weapons[id or ""]
	local wantAds = State.ads and w ~= nil and w.adsFov ~= nil and canAct()
	adsAlpha += ((wantAds and 1 or 0) - adsAlpha) * math.min(dt * 18, 1)
	local baseFov = State.profile and State.profile.fov or 70
	local targetFov = wantAds and w.adsFov or baseFov
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 18, 1)
	State.scoped = wantAds and w.scope == true and adsAlpha > 0.9
	UserInputService.MouseDeltaSensitivity = wantAds and w.adsFov / baseFov or 1

	State.weaponId = id
	State.ammo = ammo[id or ""] or 0
	State.mag = w and w.mag or 0
	State.reloading = os.clock() < (reloadUntil[id or ""] or 0)

	kick = math.max(kick - dt * 8, 0)
	swing = math.max(swing - dt * 5, 0)
	if viewmodel then
		local cf = camera.CFrame
			* HIP:Lerp(ADS, adsAlpha)
			* CFrame.new(0, 0, kick * 0.3)
			* CFrame.Angles(kick * 0.15, swing * 1.2, 0)
		viewmodel:PivotTo(State.scoped and cf * CFrame.new(0, -50, 0) or cf)
	end
	if fireHeld then
		tryFire()
	end
end

local function bind(name: string, handler, touch: boolean, ...)
	ContextActionService:BindAction(name, function(_, inputState, input)
		if State.menuOpen and inputState == Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		handler(inputState, input)
		return Enum.ContextActionResult.Pass
	end, touch, ...)
	if touch then
		ContextActionService:SetTitle(name, name)
	end
end

function Weapons.init()
	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 1, render)

	bind("Fire", function(s)
		fireHeld = s == Enum.UserInputState.Begin
		triggerPulled = fireHeld
		if fireHeld then
			tryFire()
		end
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	bind("Aim", function(s, input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if s == Enum.UserInputState.Begin then
				State.ads = not State.ads
			end
		else
			State.ads = s == Enum.UserInputState.Begin
		end
	end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	bind("Reload", function(s)
		if s == Enum.UserInputState.Begin then
			Weapons.reload()
		end
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	bind("Utility", function(s)
		if s == Enum.UserInputState.Begin and canAct() and (player:GetAttribute("Charges") or 0) > 0 then
			Net.Event:FireServer("Throw", camera.CFrame.Position, camera.CFrame.LookVector)
		end
	end, true, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)
	bind("Swap", function(s)
		if s == Enum.UserInputState.Begin then
			Weapons.equip(State.slot % 3 + 1)
		end
	end, true, Enum.KeyCode.ButtonY)
	for i, key in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three } do
		bind("Slot" .. i, function(s)
			if s == Enum.UserInputState.Begin then
				Weapons.equip(i)
			end
		end, false, key)
	end

	local function onCharacter(char: Model)
		State.slot = 1
		State.ads = false
		State.holding = canHold()
		refresh()
		char:WaitForChild("Humanoid").Died:Connect(function()
			if viewmodel then
				viewmodel:Destroy()
				viewmodel = nil
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	for _, attr in { "Primary", "Secondary", "Melee", "Utility", "Palette" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if player.Character then
				refresh()
			end
		end)
	end
end

return Weapons
