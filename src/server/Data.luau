-- Player profiles (DataStore), coin shop, palettes, weekly wins board.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Data = {}
local profiles: { [Player]: any } = {}
local store
pcall(function()
	store = DataStoreService:GetDataStore("Antithesis_v1")
end)

-- Resolved per use so a long-running server rolls over to the new week.
local function weeklyStore()
	local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "WeeklyWins_" .. os.time() // 604800)
	return ok and s or nil
end

local function today(): number
	return os.time() // 86400
end

local questById = {}
for _, q in Config.Quests do
	questById[q.id] = q
end

-- Roll 3 fresh daily quests when the day changes.
local function ensureQuests(p)
	local d = today()
	if p.questDay == d and #p.quests > 0 then
		return
	end
	local pool = table.clone(Config.Quests)
	p.quests = {}
	for _ = 1, math.min(Config.DailyQuestCount, #pool) do
		local q = table.remove(pool, math.random(#pool))
		table.insert(p.quests, { id = q.id, progress = 0, claimed = false })
	end
	p.questDay = d
end

local function default()
	local unlocked = {}
	for id, w in Config.Weapons do
		if w.price == 0 then
			unlocked[id] = true
		end
	end
	return {
		coins = 0,
		unlocked = unlocked,
		palettes = { Default = true },
		palette = "Default",
		loadout = table.clone(Config.Starter),
		wins = 0,
		losses = 0,
		matches = 0,
		streak = 0,
		dayStreak = 0,
		lastDay = 0,
		lastWinDay = 0,
		fov = 70,
		questDay = 0,
		quests = {},
	}
end

function Data.get(player: Player)
	return profiles[player]
end

function Data.push(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	ensureQuests(p)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = p.coins
		stats.Wins.Value = p.wins
	end
	Net.Event:FireClient(player, "Profile", p)
end

function Data.load(player: Player)
	local p, ok = default(), true
	if store then
		for _ = 1, 3 do
			local success, saved = pcall(store.GetAsync, store, "u" .. player.UserId)
			if success then
				for k, v in saved or {} do
					p[k] = v
				end
				ok = true
				break
			end
			ok = false
			task.wait(1)
		end
	end
	p._noSave = not ok -- never overwrite real data with defaults after a failed load
	if not player.Parent then
		return p -- left while loading; don't keep (and keep saving) a stale profile
	end
	profiles[player] = p

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	Instance.new("IntValue", stats).Name = "Wins"
	Instance.new("IntValue", stats).Name = "Coins"
	stats.Parent = player

	-- Game Pass palettes are owned on Roblox's side; re-check each join.
	for name, pal in Config.Palettes do
		if pal.gamePass and pal.gamePass ~= 0 then
			local s, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pal.gamePass)
			if s and owns then
				p.palettes[name] = true
			end
		end
	end
	return p
end

function Data.save(player: Player)
	local p = profiles[player]
	if not (store and p) or p._noSave then
		return
	end
	local copy = table.clone(p)
	copy._noSave = nil
	pcall(store.UpdateAsync, store, "u" .. player.UserId, function()
		return copy
	end)
end

function Data.release(player: Player)
	Data.save(player)
	profiles[player] = nil
end

-- Count progress toward today's quests (stat names come from Config.Quests).
function Data.questProgress(player: Player, stat: string, amount: number)
	local p = profiles[player]
	if not p then
		return
	end
	ensureQuests(p)
	for _, entry in p.quests do
		local q = questById[entry.id]
		if q and q.stat == stat and not entry.claimed then
			entry.progress = math.min(q.goal, entry.progress + amount)
		end
	end
end

function Data.claimQuest(player: Player, index: any)
	local p = profiles[player]
	local entry = p and type(index) == "number" and p.quests[index]
	local q = entry and questById[entry.id]
	if not q or entry.claimed or entry.progress < q.goal then
		return
	end
	entry.claimed = true
	p.coins += q.reward
	Data.push(player)
end

function Data.addWeeklyWin(player: Player)
	local weekly = weeklyStore()
	if weekly then
		task.spawn(pcall, weekly.IncrementAsync, weekly, tostring(player.UserId), 1)
	end
end

-- Coins for a finished match. Returns lines for the results screen.
function Data.reward(player: Player, won: boolean, participated: boolean, banners: number)
	local p = profiles[player]
	local R = Config.Rewards
	local lines = {}
	local function add(label, amount)
		if amount > 0 then
			table.insert(lines, { label, amount })
			p.coins += amount
		end
	end
	p.matches += 1
	if won then
		p.wins += 1
		p.streak += 1
	else
		p.losses += 1
		p.streak = 0
	end
	if participated then
		add(won and "Victory" or "Match played", won and R.Win or R.Loss)
		if won then
			add("Win streak x" .. p.streak, math.min((p.streak - 1) * R.StreakBonus, R.StreakMax))
		end
		add("Banners", banners * R.Banner)
	end
	local d = today()
	if won and p.lastWinDay ~= d then
		p.lastWinDay = d
		add("First win of the day", R.FirstWin)
	end
	if p.lastDay ~= d then -- play-to-claim daily streak
		p.dayStreak = (p.lastDay == d - 1) and (p.dayStreak % #R.Daily) + 1 or 1
		p.lastDay = d
		add("Daily streak day " .. p.dayStreak, R.Daily[p.dayStreak])
	end
	if won then
		Data.addWeeklyWin(player)
	end
	return lines
end

function Data.unlock(player: Player, id: any)
	local p = profiles[player]
	local item = Config.Weapons[id] or Config.Palettes[id]
	if not (p and item and item.price) then
		return
	end
	local owned = Config.Weapons[id] and p.unlocked or p.palettes
	if owned[id] or p.coins < item.price then
		return
	end
	p.coins -= item.price
	owned[id] = true
	Data.push(player)
end

function Data.setPalette(player: Player, id: any)
	local p = profiles[player]
	if p and p.palettes[id] then
		p.palette = id
		player:SetAttribute("Palette", id)
		Data.push(player)
	end
end

function Data.setFov(player: Player, fov: any)
	local p = profiles[player]
	if p and type(fov) == "number" then
		p.fov = math.clamp(math.floor(fov), 70, 90)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local p = profiles[player]
	if not (purchased and p) then
		return
	end
	for name, pal in Config.Palettes do
		if pal.gamePass == passId then
			p.palettes[name] = true
		end
	end
	Data.push(player)
end)

local names = {}
local function refreshBoard(World)
	local weekly = weeklyStore()
	if not weekly then
		return
	end
	local ok, pages = pcall(weekly.GetSortedAsync, weekly, false, 10)
	if not ok then
		return
	end
	local lines = {}
	for rank, entry in pages:GetCurrentPage() do
		local id = tonumber(entry.key)
		if not names[id] then
			local s, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
			names[id] = s and name or "?"
		end
		table.insert(lines, rank .. ". " .. names[id] .. "  " .. entry.value)
	end
	World.setBoard(lines)
end

function Data.start(World)
	task.spawn(function()
		while true do
			refreshBoard(World)
			for player in profiles do
				Data.save(player)
			end
			task.wait(60)
		end
	end)
	game:BindToClose(function()
		for player in profiles do
			task.spawn(Data.save, player)
		end
		task.wait(3)
	end)
end

return Data
