-- Server-authoritative combat: validates every shot (fire rate, ammo, origin, lag-compensated rewind, line of sight).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)

local Combat = {}

-- Hooks wired up by Match.
Combat.canDamage = function(_attacker: Player, _victim: Player): boolean
	return false
end
Combat.onDamage = function(_attacker: Player, _victim: Player, _amount: number) end
Combat.onKill = function(_attacker: Player?, _victim: Player, _weaponId: string, _info) end
Combat.audience = function(player: Player): { Player }
	return { player }
end

local BODY = { Torso = true, HumanoidRootPart = true, UpperTorso = true, LowerTorso = true }
local state = {}
local history = {}
local lastPos = {}
local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootAt(player: Player, root: BasePart, t: number): CFrame
	local h = history[player]
	if not h or #h == 0 then
		return root.CFrame
	end
	for i = #h, 1, -1 do
		local e = h[i]
		if e[1] <= t then
			local n = h[i + 1]
			if not n then
				return e[2]
			end
			return e[2]:Lerp(n[2], (t - e[1]) / (n[1] - e[1]))
		end
	end
	return h[1][2]
end

local function targetOf(part: any)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return model, hum, Players:GetPlayerFromCharacter(model)
end

local function allowed(attacker: Player, model: Model, victim: Player?): boolean
	if victim then
		return victim ~= attacker and Combat.canDamage(attacker, victim)
	end
	return model:GetAttribute("Dummy") == true and attacker:GetAttribute("MatchId") == 0
end

-- Returns the server-checked distance to the hit, or nil if the shot could not have hit.
-- The shooter sees other players about one network leg + interpolation in the past,
-- so several moments in that window are tested (lag compensation).
local function validHit(origin: Vector3, dir: Vector3, part: BasePart, victim: Player?, fireTime: number, t: number): number?
	local root = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	if victim and not root then
		return nil
	end
	local times = { t }
	if root then
		local cap = Config.Match.RewindCap
		local fired = math.min(fireTime, t)
		local lat = math.clamp(t - fired, 0, cap)
		local earliest = math.max(t - 2 * lat - Config.Match.InterpDelay, t - cap)
		times = {}
		for i = 0, 4 do
			table.insert(times, earliest + (fired - earliest) * i / 4)
		end
	end
	for _, at in times do
		local center = root and (rootAt(victim, root, at) * root.CFrame:ToObjectSpace(part.CFrame)).Position or part.Position
		local toC = center - origin
		local along = toC:Dot(dir)
		if along >= 0 and along <= Config.Range
			and (toC - dir * along).Magnitude <= part.Size.Magnitude / 2 + 1.5
			and workspace:Raycast(origin, dir * math.max(along - 1, 0.01), mapParams) == nil then
			return along
		end
	end
	return nil
end

local function damageFor(w, part: BasePart, dist: number): number
	local head = part.Name == "Head"
	local dmg = head and w.head or w.damage
	if not head and not BODY[part.Name] then
		dmg *= Config.LimbMult
	end
	if w.falloff then
		local a, b, m = w.falloff[1], w.falloff[2], w.falloff[3]
		dmg *= dist <= a and 1 or dist >= b and m or 1 - (1 - m) * (dist - a) / (b - a)
	end
	return dmg
end

-- Alive, not frozen, and somewhere weapons are allowed (a match, or the lobby firing range).
local function alive(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 and not root.Anchored
		and (player:GetAttribute("MatchId") ~= 0 or Config.inRange(root.Position)) then
		return char, root
	end
	return nil
end

function Combat.applyDamage(attacker: Player?, model: Model, hum: Humanoid, victim: Player?, amount: number, weaponId: string, info): boolean
	if hum.Health <= 0 then
		return false
	end
	amount = math.floor(amount + 0.5)
	local lethal = amount >= hum.Health
	if model:GetAttribute("Dummy") then
		hum.Health = lethal and hum.MaxHealth or hum.Health - amount
	else
		hum.Health = math.max(hum.Health - amount, 0)
	end
	if victim then
		if attacker then
			Combat.onDamage(attacker, victim, amount)
		end
		local root = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		Net.Event:FireClient(victim, "Damaged", root and root.Position)
		if lethal then
			Combat.onKill(attacker, victim, weaponId, info)
		end
	end
	return lethal
end

function Combat.reset(player: Player)
	local s = { ammo = {}, reloadUntil = {}, tokens = {}, last = {}, charges = 0, lastMelee = 0 }
	for _, slot in Config.Slots do
		local id = player:GetAttribute(slot)
		local w = Config.Weapons[id]
		if w and w.mag then
			s.ammo[id] = w.mag
		elseif w and w.charges then
			s.charges = w.charges
		end
	end
	state[player] = s
	player:SetAttribute("Charges", s.charges)
end

function Combat.clear(player: Player)
	history[player] = nil
	lastPos[player] = nil
end

-- slot 1-3 shows that weapon in the character's hand; 0 puts it away (lobby hall).
function Combat.equip(player: Player, slot: any)
	if type(slot) ~= "number" or slot < 0 or slot > 3 or slot % 1 ~= 0 then
		return
	end
	local char = player.Character
	local old = char and char:FindFirstChild("HeldWeapon")
	if old then
		old:Destroy()
	end
	local id = slot > 0 and player:GetAttribute(Config.Slots[slot])
	local arm = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"))
	if not (id and arm) then
		return
	end
	local model = WeaponModels.build(id, player:GetAttribute("Palette"))
	model.Name = "HeldWeapon"
	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = model.PrimaryPart
	weld.C0 = CFrame.new(0, -1, -0.5)
	weld.Parent = model.PrimaryPart
	model.Parent = char
end

function Combat.fire(player: Player, weaponId: any, origin: any, shots: any, fireTime: any, scoped: any)
	local s = state[player]
	local w = Config.Weapons[weaponId]
	if not (s and w and w.mag) or typeof(origin) ~= "Vector3" or type(shots) ~= "table" or type(fireTime) ~= "number" then
		return
	end
	local char = alive(player)
	if not char or player:GetAttribute(w.slot) ~= weaponId then
		return
	end
	local head = char.Head.Position
	if (origin - head).Magnitude > 8 then
		return
	end
	-- Never let a shot start on the far side of a wall.
	local blocked = workspace:Raycast(head, origin - head, mapParams)
	if blocked then
		origin = blocked.Position + blocked.Normal * 0.1
	end
	local t = now()
	if (s.reloadUntil[weaponId] or 0) > t or s.ammo[weaponId] <= 0 then
		return
	end
	-- Token bucket: tolerates network bunching but caps sustained fire rate.
	local avg = (w.burst and (w.burstDelay + (w.burst - 1) * w.interval) / w.burst or w.interval) * 0.9
	local cap = w.burst or 2
	local tokens = math.min(cap, (s.tokens[weaponId] or cap) + (t - (s.last[weaponId] or 0)) / avg)
	if tokens < 1 then
		return
	end
	s.tokens[weaponId] = tokens - 1
	s.last[weaponId] = t
	s.ammo[weaponId] -= 1

	local hits = {}
	for i = 1, math.min(#shots, w.pellets or 1) do
		local shot = shots[i]
		if type(shot) ~= "table" then
			continue
		end
		local dir, part, pos = shot[1], shot[2], shot[3]
		if typeof(dir) ~= "Vector3" or typeof(pos) ~= "Vector3" or math.abs(dir.Magnitude - 1) > 0.05 then
			continue
		end
		local model, hum, victim = targetOf(part)
		local along = model and allowed(player, model, victim) and validHit(origin, dir, part, victim, fireTime, t)
		if along then
			local h = hits[model] or { hum = hum, victim = victim, dmg = 0, head = false }
			hits[model] = h
			h.dmg += damageFor(w, part, along) -- falloff uses the server-checked distance
			h.head = h.head or part.Name == "Head"
		end
	end
	for model, h in hits do
		local killed = Combat.applyDamage(player, model, h.hum, h.victim, h.dmg, weaponId, { head = h.head, scoped = scoped == true })
		Net.Event:FireClient(player, "Hit", math.floor(h.dmg + 0.5), h.head, killed)
	end
	local endPos = type(shots[1]) == "table" and shots[1][3]
	if typeof(endPos) == "Vector3" then
		for _, other in Combat.audience(player) do
			if other ~= player then
				Net.FX:FireClient(other, "Tracer", origin, endPos)
			end
		end
	end
end

function Combat.reload(player: Player, weaponId: any)
	local s, w = state[player], Config.Weapons[weaponId]
	if not (s and w and s.ammo[weaponId]) then
		return
	end
	local t = now()
	if s.ammo[weaponId] >= w.mag or (s.reloadUntil[weaponId] or 0) > t then
		return
	end
	-- Finish slightly before the client does so latency never rejects the first shot after a reload.
	local ready = (w.perShell and w.reload * (w.mag - s.ammo[weaponId]) or w.reload) * 0.8
	s.reloadUntil[weaponId] = t + ready
	task.delay(ready, function()
		if state[player] == s then
			s.ammo[weaponId] = w.mag
		end
	end)
end

function Combat.melee(player: Player, part: any)
	local s = state[player]
	local id = player:GetAttribute("Melee")
	local w = Config.Weapons[id]
	local t = now()
	if not (s and w) or t - s.lastMelee < w.interval * 0.8 then
		return
	end
	s.lastMelee = t
	local char, root = alive(player)
	local model, hum, victim = targetOf(part)
	if not (char and model and allowed(player, model, victim)) then
		return
	end
	local troot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local toTarget = (troot.Position - root.Position) * Vector3.new(1, 0, 1)
	if toTarget.Magnitude > w.range + 3 then
		return
	end
	local head = char:FindFirstChild("Head")
	if not head or workspace:Raycast(head.Position, part.Position - head.Position, mapParams) then
		return -- no knifing through walls
	end
	local behind = toTarget.Magnitude > 0.1 and troot.CFrame.LookVector:Dot(toTarget.Unit) > 0.5
	local dmg = behind and w.backstab or w.damage
	local killed = Combat.applyDamage(player, model, hum, victim, dmg, id, { backstab = behind })
	Net.Event:FireClient(player, "Hit", dmg, false, killed)
end

local function frag(attacker: Player, pos: Vector3, w)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastPressure = 0
	e.BlastRadius = w.radius
	e.DestroyJointRadiusPercent = 0
	e.Parent = workspace
	for _, p in Combat.audience(attacker) do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
		if hum and torso and Combat.canDamage(attacker, p) then
			local d = (torso.Position - pos).Magnitude
			if d <= w.radius and not workspace:Raycast(pos, torso.Position - pos, mapParams) then
				local dmg = d <= w.innerRadius and w.damage
					or w.damage - (w.damage - w.minDamage) * (d - w.innerRadius) / (w.radius - w.innerRadius)
				local killed = Combat.applyDamage(attacker, char, hum, p, dmg, "Crack", {})
				if p ~= attacker then
					Net.Event:FireClient(attacker, "Hit", math.floor(dmg), false, killed)
				end
			end
		end
	end
end

local function flash(attacker: Player, pos: Vector3, w)
	local pop = Instance.new("Part")
	pop.Shape = Enum.PartType.Ball
	pop.Size = Vector3.one * 3
	pop.Position = pos
	pop.Anchored = true
	pop.CanCollide = false
	pop.CanQuery = false
	pop.Material = Enum.Material.Neon
	pop.Color = Color3.new(1, 1, 1)
	pop.Parent = workspace
	Debris:AddItem(pop, 0.15)
	for _, p in Combat.audience(attacker) do
		local head = p.Character and p.Character:FindFirstChild("Head")
		local offset = head and pos - head.Position
		if offset and offset.Magnitude < 80 and not workspace:Raycast(head.Position, offset, mapParams) then
			local facing = head.CFrame.LookVector:Dot(offset.Unit) > 0.64
			Net.Event:FireClient(p, "Flash", facing and w.blind or w.peripheral)
		end
	end
end

local function smoke(pos: Vector3, w)
	local s = Instance.new("Part")
	s.Shape = Enum.PartType.Ball
	s.Size = Vector3.one * w.radius * 2
	s.Position = pos
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.CastShadow = false
	s.Material = Enum.Material.SmoothPlastic
	s.Color = Color3.fromRGB(205, 205, 210)
	s.Transparency = 0.05
	s.Parent = workspace
	Debris:AddItem(s, w.duration)
end

function Combat.throw(player: Player, origin: any, dir: any)
	local s = state[player]
	local w = Config.Weapons[player:GetAttribute("Utility")]
	local char = alive(player)
	if not (s and w and char and s.charges > 0) or typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then
		return
	end
	if (origin - char.Head.Position).Magnitude > 8 or dir.Magnitude < 0.5 then
		return
	end
	s.charges -= 1
	player:SetAttribute("Charges", s.charges)
	dir = dir.Unit
	local g = Instance.new("Part")
	g.Shape = Enum.PartType.Ball
	g.Size = Vector3.one * 0.8
	g.Color = Config.Colors.Gold
	g.Material = Enum.Material.Neon
	g.CanQuery = false
	-- Spawn from the server's head position, never past a wall.
	local head = char.Head.Position
	local spawnPos = head + dir * 2
	local hit = workspace:Raycast(head, spawnPos - head, mapParams)
	if hit then
		spawnPos = hit.Position - dir * 0.5
	end
	g.CFrame = CFrame.new(spawnPos)
	g.Parent = workspace
	g:SetNetworkOwner(nil)
	g.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 12, 0)
	task.delay(w.fuse, function()
		local pos = g.Position
		g:Destroy()
		if w.class == "Frag" then
			frag(player, pos, w)
		elseif w.class == "Flash" then
			flash(player, pos, w)
		else
			smoke(pos, w)
		end
	end)
end

function Combat.start()
	mapParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }

	-- Position history for lag compensation (1 second).
	RunService.Heartbeat:Connect(function()
		local t = now()
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local h = history[player] or {}
				history[player] = h
				table.insert(h, { t, root.CFrame })
				if #h > 60 then
					table.remove(h, 1)
				end
			end
		end
	end)

	-- Movement sanity check: snap back players moving faster than any legal movement allows.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = os.clock()
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and not root.Anchored then
					local last = lastPos[player]
					local flat = last and (root.Position - last.pos) * Vector3.new(1, 0, 1)
					if flat and flat.Magnitude / math.max(t - last.t, 0.5) > Config.Movement.MaxAvgSpeed then
						root.CFrame = CFrame.new(last.pos) * root.CFrame.Rotation
						last.t = t
					else
						lastPos[player] = { pos = root.Position, t = t }
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
		Combat.clear(player)
	end)
end

return Combat
