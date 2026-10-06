-- Queues, in-server matchmaking, Counter-Pick round flow, scoring, rewards, rematch and challenges.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(script.Parent.Combat)
local Data = require(script.Parent.Data)

local M = Config.Match
local Match = {}
local arenas = {}
local queues = { Duel = {}, Doubles = {} }
local byPlayer = {}
local challenges = {}
local rematch = {}
local nextId = 0

local function send(players: { Player }, ...)
	for _, p in players do
		if p.Parent then
			Net.Event:FireClient(p, ...)
		end
	end
end

local function humOf(p: Player): Humanoid?
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return (hum and hum.Health > 0) and hum or nil
end

local function loadoutOf(p: Player)
	local l = {}
	for _, slot in Config.Slots do
		l[slot] = p:GetAttribute(slot)
	end
	return l
end

local function elo(p: Player): number
	local d = Data.get(p)
	return d and d.elo or 1000
end

local function banner(m, p: Player, text: string)
	m.stats[p].banners += 1
	Net.Event:FireClient(p, "Banner", text)
end

local function phase(m, name: string, duration: number)
	m.phase = name
	m.endsAt = workspace:GetServerTimeNow() + duration
	for _, p in m.players do
		if p.Parent then
			Net.Event:FireClient(p, "Phase", {
				phase = name,
				endsAt = m.endsAt,
				round = m.round,
				score = m.score,
				team = p:GetAttribute("Team"),
				mode = m.mode,
				arena = m.arena.name,
				winsNeeded = m.cfg.winsNeeded,
				canPick = m.picking[p] == true,
				reveal = m.reveal,
				roundWinner = m.roundWinner,
			})
		end
	end
end

local function waitFor(m, seconds: number, done: (() -> boolean)?)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not m.over and not (done and done()) do
		task.wait(0.1)
	end
end

local function freeArena(mode: string)
	local preferred = mode == "Doubles" and "Mirrorline" or "Fulcrum"
	local any
	for _, a in arenas do
		if not a.busy then
			if a.name == preferred then
				return a
			end
			any = any or a
		end
	end
	return any
end

function Match.leaveQueue(player: Player)
	for _, q in queues do
		for i = #q, 1, -1 do
			if q[i].player == player then
				table.remove(q, i)
			end
		end
	end
	if player.Parent then
		Net.Event:FireClient(player, "Queue", nil)
	end
end

function Match.queue(player: Player, mode: any)
	if not queues[mode] or byPlayer[player] then
		return
	end
	Match.leaveQueue(player)
	table.insert(queues[mode], { player = player, t = os.clock() })
	Net.Event:FireClient(player, "Queue", mode)
end

---------------------------------------------------------------- picking

local function setPicking(m, team: number?)
	m.picking, m.ready = {}, {}
	for _, p in m.players do
		if team == nil or p:GetAttribute("Team") == team then
			m.picking[p] = true
		end
	end
end

local function allReady(m): boolean
	for p in m.picking do
		if p.Parent and byPlayer[p] == m and not m.ready[p] then
			return false
		end
	end
	return true
end

local function pickPhase(m)
	local winner = m.lastWinner
	m.reveal = nil
	m.roundWinner = nil
	if not winner then
		setPicking(m, nil)
		phase(m, "Pick", M.BlindPick)
		waitFor(m, M.BlindPick, function()
			return allReady(m)
		end)
	else
		setPicking(m, winner)
		phase(m, "Thesis", M.ThesisPick)
		waitFor(m, M.ThesisPick, function()
			return allReady(m)
		end)
		m.reveal = {}
		for _, p in m.teams[winner] do
			table.insert(m.reveal, { name = p.DisplayName, loadout = loadoutOf(p) })
		end
		send(m.players, "Reveal", m.reveal)
		setPicking(m, 3 - winner)
		phase(m, "Antithesis", M.AntithesisPick)
		waitFor(m, M.AntithesisPick, function()
			return allReady(m)
		end)
	end
	m.picking = {}
end

function Match.pick(player: Player, slot: any, id: any)
	local p = Data.get(player)
	local w = Config.Weapons[id]
	if not (p and w and w.slot == slot and p.unlocked[id]) then
		return
	end
	local m = byPlayer[player]
	if m and not m.picking[player] then
		return
	end
	player:SetAttribute(slot, id)
	p.loadout[slot] = id
	if not m then
		Combat.reset(player) -- lobby loadout change
	end
end

function Match.ready(player: Player)
	local m = byPlayer[player]
	if m and m.picking[player] then
		m.ready[player] = true
	end
end

---------------------------------------------------------------- rounds

local function spawnAll(m)
	for t, team in m.teams do
		for i, p in team do
			if p.Parent and byPlayer[p] == m then
				p:LoadCharacter()
				local char = p.Character
				if char then
					char:PivotTo(m.arena.spawns[t][i])
					char.HumanoidRootPart.Anchored = true
					Combat.clear(p)
					Combat.reset(p)
				end
			end
		end
	end
end

local function aliveIn(m, team: number): (number, number)
	local n, hp = 0, 0
	for _, p in m.teams[team] do
		local hum = byPlayer[p] == m and humOf(p)
		if hum then
			n += 1
			hp += hum.Health
		end
	end
	return n, hp
end

local function makeRing(center: Vector3): Part
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Config.Colors.Enemy
	ring.Transparency = 0.75
	ring.CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	return ring
end

local function live(m): number
	for _, p in m.players do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
		end
		m.stats[p].roundKills = 0
	end
	m.clutch = {}
	phase(m, "Live", m.cfg.liveTime)
	local center = m.arena.origin
	local ring, collapseStart
	local result
	while not m.over do
		local a, hpA = aliveIn(m, 1)
		local b, hpB = aliveIn(m, 2)
		if m.mode == "Doubles" then
			for t, n in { a, b } do
				if n == 1 and (t == 1 and b or a) == 2 then
					for _, p in m.teams[t] do
						if humOf(p) then
							m.clutch[p] = true
						end
					end
				end
			end
		end
		if a == 0 or b == 0 then
			result = a > 0 and 1 or b > 0 and 2 or 0
			break
		end
		local t = workspace:GetServerTimeNow()
		if not collapseStart and t >= m.endsAt then
			collapseStart = t
			ring = makeRing(center)
			phase(m, "Collapse", M.Collapse)
		end
		if collapseStart then
			local k = math.min((t - collapseStart) / M.Collapse, 1)
			local radius = m.arena.radius + (M.CollapseMinRadius - m.arena.radius) * k
			ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
			for _, p in m.players do
				local hum = byPlayer[p] == m and humOf(p)
				local root = hum and p.Character:FindFirstChild("HumanoidRootPart")
				if root and ((root.Position - center) * Vector3.new(1, 0, 1)).Magnitude > radius then
					Combat.applyDamage(nil, p.Character, hum, p, M.CollapseDps * 0.1, "Collapse", {})
				end
			end
			if k >= 1 then
				result = hpA > hpB and 1 or hpB > hpA and 2 or 0
				break
			end
		end
		task.wait(0.1)
	end
	if ring then
		ring:Destroy()
	end
	return result or 0
end

local function roundEnd(m, winner: number)
	if winner > 0 then
		m.score[winner] += 1
		local countered = m.lastWinner == 3 - winner
		for _, p in m.teams[winner] do
			if m.stats[p] and byPlayer[p] == m then
				m.stats[p].roundsWon += 1
				local hum = humOf(p)
				if hum and hum.Health >= hum.MaxHealth then
					banner(m, p, "FLAWLESS")
				end
				if hum and m.clutch[p] then
					banner(m, p, "CLUTCH 1v2")
				end
				if countered then
					banner(m, p, "COUNTERED")
				end
			end
		end
		m.lastWinner = winner
	else
		m.lastWinner = nil -- draw: blind picks again
	end
	m.roundWinner = winner
	phase(m, "RoundEnd", M.RoundEnd)
	waitFor(m, M.RoundEnd)
end

local function updateElo(m, winner: number)
	local function avg(team)
		local s = 0
		for _, p in team do
			s += elo(p)
		end
		return s / #team
	end
	local expected = 1 / (1 + 10 ^ ((avg(m.teams[2]) - avg(m.teams[1])) / 400))
	local delta = M.EloK * ((winner == 1 and 1 or 0) - expected)
	for t, team in m.teams do
		for _, p in team do
			local d = Data.get(p)
			if d then
				d.elo = math.floor(d.elo + (t == 1 and delta or -delta) + 0.5)
			end
		end
	end
end

local function finish(m)
	local winner = m.forfeit
		or (m.score[1] >= m.cfg.winsNeeded and 1)
		or (m.score[2] >= m.cfg.winsNeeded and 2)
		or 0
	if not m.private and winner > 0 then
		updateElo(m, winner)
	end
	local group = { mode = m.mode, teams = m.teams, votes = {}, expires = os.clock() + M.ResultsTime }
	for _, p in m.players do
		local wasHere = byPlayer[p] == m
		byPlayer[p] = nil
		if wasHere and p.Parent and Data.get(p) then
			local st = m.stats[p]
			local team = p:GetAttribute("Team")
			local won = team == winner
			local lines = Data.reward(p, won, st.roundsWon > 0 or st.damage >= Config.Rewards.MinDamage, st.banners)
			Data.push(p)
			p:SetAttribute("MatchId", 0)
			p:SetAttribute("Team", 0)
			rematch[p] = group
			Net.Event:FireClient(p, "Results", { won = won, lines = lines, score = m.score, team = team, private = m.private })
			task.spawn(p.LoadCharacter, p)
		end
	end
	m.arena.busy = false
end

local function run(m)
	while not m.over do
		m.round += 1
		pickPhase(m)
		if m.over then
			break
		end
		spawnAll(m)
		phase(m, "Countdown", M.Countdown)
		waitFor(m, M.Countdown)
		if m.over then
			break
		end
		local winner = live(m)
		if m.over then
			break
		end
		roundEnd(m, winner)
		if m.score[1] >= m.cfg.winsNeeded or m.score[2] >= m.cfg.winsNeeded then
			break
		end
	end
	finish(m)
end

local function start(mode: string, teams, private: boolean): boolean
	local arena = freeArena(mode)
	if not arena then
		return false
	end
	arena.busy = true
	nextId += 1
	local m = {
		id = nextId,
		mode = mode,
		cfg = Config.Modes[mode],
		arena = arena,
		teams = teams,
		players = {},
		score = { 0, 0 },
		round = 0,
		private = private,
		picking = {},
		ready = {},
		stats = {},
		clutch = {},
		phase = "Pick",
	}
	for t, team in teams do
		for _, p in team do
			Match.leaveQueue(p)
			challenges[p] = nil
			rematch[p] = nil
			byPlayer[p] = m
			table.insert(m.players, p)
			m.stats[p] = { damage = 0, roundsWon = 0, banners = 0, roundKills = 0 }
			p:SetAttribute("MatchId", m.id)
			p:SetAttribute("Team", t)
		end
	end
	task.spawn(run, m)
	return true
end

---------------------------------------------------------------- matchmaking

local function tryDuel()
	local q = queues.Duel
	for i = 1, #q do
		for j = i + 1, #q do
			local a, b = q[i], q[j]
			local waited = os.clock() - math.min(a.t, b.t)
			local window = M.EloWindow * (1 + waited // M.EloWindowEvery)
			if math.abs(elo(a.player) - elo(b.player)) <= window then
				return { { a.player }, { b.player } }
			end
		end
	end
	return nil
end

local function tryDoubles()
	local q = queues.Doubles
	if #q < 4 then
		return nil
	end
	local four = { q[1].player, q[2].player, q[3].player, q[4].player }
	table.sort(four, function(x, y)
		return elo(x) > elo(y)
	end)
	return { { four[1], four[4] }, { four[2], four[3] } }
end

---------------------------------------------------------------- social

function Match.challenge(player: Player, target: Player)
	if target == player or byPlayer[player] or byPlayer[target] then
		return
	end
	challenges[target] = challenges[target] or {}
	challenges[target][player] = os.clock()
	Net.Event:FireClient(target, "Challenged", player)
	Net.Event:FireClient(player, "Notify", "Challenge sent to " .. target.DisplayName)
end

function Match.challengeReply(player: Player, from: any, accept: any)
	local list = challenges[player]
	local sentAt = list and typeof(from) == "Instance" and list[from]
	if not sentAt then
		return
	end
	list[from] = nil
	if not from.Parent then
		return
	end
	if accept ~= true then
		Net.Event:FireClient(from, "Notify", player.DisplayName .. " declined your challenge")
	elseif os.clock() - sentAt < 20 and not byPlayer[player] and not byPlayer[from] then
		if not start("Duel", { { from }, { player } }, true) then
			send({ player, from }, "Notify", "All arenas are busy, try again in a moment")
		end
	end
end

function Match.rematch(player: Player)
	local g = rematch[player]
	if not g or os.clock() > g.expires or byPlayer[player] then
		return
	end
	g.votes[player] = true
	local everyone = {}
	for _, team in g.teams do
		for _, p in team do
			table.insert(everyone, p)
		end
	end
	for _, p in everyone do
		if not g.votes[p] or not p.Parent or byPlayer[p] then
			send(everyone, "Notify", player.DisplayName .. " wants a rematch")
			return
		end
	end
	for _, p in everyone do
		rematch[p] = nil
	end
	start(g.mode, g.teams, true)
end

function Match.onLeave(player: Player)
	Match.leaveQueue(player)
	challenges[player] = nil
	rematch[player] = nil
	local m = byPlayer[player]
	if not m then
		return
	end
	byPlayer[player] = nil
	local team = player:GetAttribute("Team")
	for _, p in m.teams[team] do
		if p ~= player and byPlayer[p] == m then
			return
		end
	end
	m.forfeit = 3 - team
	m.over = true
end

function Match.start(worldArenas)
	arenas = worldArenas

	Combat.canDamage = function(a, v)
		local m = byPlayer[a]
		return m ~= nil and m == byPlayer[v] and (m.phase == "Live" or m.phase == "Collapse")
			and a:GetAttribute("Team") ~= v:GetAttribute("Team")
	end
	Combat.audience = function(p)
		local m = byPlayer[p]
		if m then
			return m.players
		end
		local list = {}
		for _, o in Players:GetPlayers() do
			if not byPlayer[o] then
				table.insert(list, o)
			end
		end
		return list
	end
	Combat.onDamage = function(a, _v, amount)
		local m = byPlayer[a]
		if m and m.stats[a] then
			m.stats[a].damage += amount
		end
	end
	Combat.onKill = function(a, v, weaponId, info)
		local m = byPlayer[v]
		if not m then
			return
		end
		local root = v.Character and v.Character:FindFirstChild("HumanoidRootPart")
		send(m.players, "Feed", {
			killer = a and a.DisplayName or "Collapse",
			killerTeam = a and a:GetAttribute("Team") or 0,
			victim = v.DisplayName,
			victimTeam = v:GetAttribute("Team"),
			weapon = weaponId,
			head = info and info.head == true,
			pos = root and root.Position,
		})
		if a and a ~= v and m.stats[a] then
			local st = m.stats[a]
			st.roundKills += 1
			if weaponId == "Meridian" and not info.scoped then
				banner(m, a, "NO-SCOPE")
			end
			if m.mode == "Doubles" and st.roundKills == 2 then
				banner(m, a, "DOUBLE")
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			for mode, try in { Duel = tryDuel, Doubles = tryDoubles } do
				local teams = freeArena(mode) and try()
				if teams then
					start(mode, teams, false)
				end
			end
		end
	end)
end

return Match
