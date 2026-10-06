-- Match flow (Rivals-style): spawn → countdown → one-life round → repeat until a team has 5 round wins.
-- Loadouts are whatever players equipped in the lobby. Also handles rematches and player challenges.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(script.Parent.Combat)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)

local M = Config.Match
local Match = {}
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

local function banner(m, p: Player, text: string)
	m.stats[p].banners += 1
	Net.Event:FireClient(p, "Banner", text)
end

local function phase(m, name: string, duration: number)
	m.phase = name
	m.endsAt = workspace:GetServerTimeNow() + duration
	for _, p in m.players do
		if p.Parent and byPlayer[p] == m then
			Net.Event:FireClient(p, "Phase", {
				phase = name,
				endsAt = m.endsAt,
				round = m.round,
				score = m.score,
				team = p:GetAttribute("Team"),
				mode = m.mode,
				arena = m.arena.name,
				winsNeeded = m.cfg.winsNeeded,
				roundWinner = m.roundWinner,
			})
		end
	end
end

local function waitFor(m, seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not m.over do
		task.wait(0.1)
	end
end

function Match.busy(player: Player): boolean
	return byPlayer[player] ~= nil
end

-- Lobby loadout changes only; loadouts are locked during a match.
function Match.pick(player: Player, slot: any, id: any)
	local p = Data.get(player)
	local w = Config.Weapons[id]
	if byPlayer[player] or not (p and w and w.slot == slot and p.unlocked[id]) then
		return
	end
	player:SetAttribute(slot, id)
	p.loadout[slot] = id
	Combat.reset(player)
end

---------------------------------------------------------------- rounds

local function spawnAll(m)
	for t, team in m.teams do
		for i, p in team do
			if p.Parent and byPlayer[p] == m then
				local ok, err = pcall(p.LoadCharacter, p)
				if not ok then
					warn("[Match] LoadCharacter failed for", p.Name, err)
					continue
				end
				-- LoadCharacter yields: re-check the player is still here and in this match.
				local char = p.Character
				local root = char and byPlayer[p] == m and char:FindFirstChild("HumanoidRootPart")
				if root then
					char:PivotTo(m.arena.spawns[t][i])
					root.Anchored = true
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
		for _, p in m.teams[winner] do
			if byPlayer[p] == m then
				m.stats[p].roundsWon += 1
				Data.questProgress(p, "rounds", 1)
				local hum = humOf(p)
				if hum and hum.Health >= hum.MaxHealth then
					banner(m, p, "FLAWLESS")
					Data.questProgress(p, "flawless", 1)
				end
				if hum and m.clutch[p] then
					banner(m, p, "CLUTCH 1v2")
				end
			end
		end
	end
	m.roundWinner = winner -- 0 = draw, round is replayed
	phase(m, "RoundEnd", M.RoundEnd)
	waitFor(m, M.RoundEnd)
	m.roundWinner = nil
end

local function finish(m)
	-- A decided score wins over a forfeit (someone leaving during the final round-end screen).
	local winner = (m.score[1] >= m.cfg.winsNeeded and 1)
		or (m.score[2] >= m.cfg.winsNeeded and 2)
		or m.forfeit
		or 0
	local group = { mode = m.mode, teams = m.teams, votes = {}, expires = os.clock() + M.ResultsTime }
	for _, p in m.players do
		local wasHere = byPlayer[p] == m
		byPlayer[p] = nil
		if wasHere and p.Parent and Data.get(p) then
			local st = m.stats[p]
			local team = p:GetAttribute("Team")
			local won = team == winner
			Data.questProgress(p, "matches", 1)
			if won then
				Data.questProgress(p, "wins", 1)
			end
			local lines = Data.reward(p, won, st.roundsWon > 0 or st.damage >= Config.Rewards.MinDamage, st.banners)
			Data.push(p)
			p:SetAttribute("MatchId", 0)
			p:SetAttribute("Team", 0)
			rematch[p] = group
			Net.Event:FireClient(p, "Results", { won = won, lines = lines, score = m.score, team = team })
			task.spawn(p.LoadCharacter, p)
		end
	end
	World.destroyArena(m.arena)
end

local function play(m)
	while not m.over do
		m.round += 1
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
end

-- finish always runs, even after an error, so players are never stranded in an arena.
local function run(m)
	local ok, err = pcall(play, m)
	if not ok then
		warn("[Match] match error:", err)
	end
	finish(m)
end

function Match.begin(mode: string, teams: { { Player } }, private: boolean)
	nextId += 1
	local m = {
		id = nextId,
		mode = mode,
		cfg = Config.Modes[mode],
		arena = World.createArena(),
		teams = teams,
		players = {},
		score = { 0, 0 },
		round = 0,
		private = private,
		stats = {},
		clutch = {},
		phase = "Countdown",
	}
	for t, team in teams do
		for _, p in team do
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
		Match.begin("Duel", { { from }, { player } }, true)
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
	Match.begin(g.mode, g.teams, true)
end

function Match.onLeave(player: Player)
	challenges[player] = nil
	rematch[player] = nil
	local m = byPlayer[player]
	if not m then
		return
	end
	byPlayer[player] = nil
	local team = player:GetAttribute("Team")
	-- Leaving counts as a loss unless this player's team had already won (profile still exists here).
	local profile = Data.get(player)
	if profile and m.score[team] < m.cfg.winsNeeded and m.forfeit ~= team then
		profile.matches += 1
		profile.losses += 1
		profile.streak = 0
	end
	for _, p in m.teams[team] do
		if p ~= player and byPlayer[p] == m then
			return
		end
	end
	m.forfeit = 3 - team
	m.over = true
end

function Match.start()
	Combat.canDamage = function(a, v)
		local m = byPlayer[a]
		return m ~= nil and m == byPlayer[v] and (m.phase == "Live" or m.phase == "Collapse")
			and (a == v or a:GetAttribute("Team") ~= v:GetAttribute("Team")) -- a == v: own frag
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
	Combat.onDamage = function(a, v, amount)
		local m = byPlayer[a]
		if m and m.stats[a] and a ~= v then
			m.stats[a].damage += amount
			Data.questProgress(a, "damage", amount)
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
			Data.questProgress(a, "kills", 1)
			if info and info.head then
				Data.questProgress(a, "headshots", 1)
			end
			if weaponId == "Edge" then
				Data.questProgress(a, "knifeKills", 1)
			end
			if weaponId == "Meridian" and not info.scoped then
				banner(m, a, "NO-SCOPE")
			end
			if m.mode == "Doubles" and st.roundKills == 2 then
				banner(m, a, "DOUBLE")
			end
		end
	end
end

return Match
