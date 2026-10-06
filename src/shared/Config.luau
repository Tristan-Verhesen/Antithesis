-- All tuning lives here. Change numbers, not code.
local Config = {}

Config.Colors = {
	Light = Color3.fromRGB(232, 230, 225),
	Dark = Color3.fromRGB(43, 45, 49),
	Ally = Color3.fromRGB(34, 211, 238),
	Enemy = Color3.fromRGB(251, 146, 60),
	Gold = Color3.fromRGB(250, 204, 21),
	Good = Color3.fromRGB(74, 222, 128),
	Bad = Color3.fromRGB(239, 68, 68),
}

Config.Movement = {
	WalkSpeed = 18,
	CrouchSpeed = 9,
	AdsMult = 0.65,
	CrouchDrop = 2.5, -- camera drop in studs
	SlideMinSpeed = 14,
	SlideStart = 30,
	SlideEnd = 12,
	SlideTime = 0.75,
	SlideCooldown = 1.0,
	DashDistance = 20,
	DashTime = 0.18,
	DashRecharge = 4.0,
	MaxAvgSpeed = 60, -- server anti-speed check, studs/s averaged over 0.5s
}

Config.Modes = {
	Duel = { teamSize = 1, winsNeeded = 3, liveTime = 60, label = "DUEL 1v1" },
	Doubles = { teamSize = 2, winsNeeded = 3, liveTime = 75, label = "DOUBLES 2v2" },
}

Config.Match = {
	BlindPick = 12,
	ThesisPick = 5,
	AntithesisPick = 7,
	Countdown = 3,
	Collapse = 15,
	CollapseDps = 20,
	CollapseMinRadius = 8,
	RoundEnd = 3,
	ResultsTime = 8, -- rematch window
	EloWindow = 100, -- grows by this every EloWindowEvery seconds waited
	EloWindowEvery = 5,
	EloK = 32,
	RewindCap = 0.2,
}

Config.Rewards = {
	Win = 40,
	Loss = 15,
	StreakBonus = 5,
	StreakMax = 25,
	Banner = 5,
	FirstWin = 100,
	MinDamage = 100,
	Daily = { 25, 25, 50, 50, 75, 75, 150 },
}

-- slot: Primary/Secondary/Melee/Utility. interval = seconds between shots.
-- falloff = {fullRange, minRange, minMultiplier}. spread/adsSpread in degrees.
Config.Weapons = {
	Paragon = { slot = "Primary", class = "Assault Rifle", auto = true, damage = 24, head = 48, interval = 0.1, mag = 30, reload = 2.0, falloff = { 70, 140, 0.75 }, spread = 2, adsSpread = 0.3, recoil = 0.5, speed = 1.0, adsFov = 55, price = 0 },
	Breaker = { slot = "Primary", class = "Pump Shotgun", pellets = 10, damage = 12, head = 18, interval = 0.83, mag = 6, reload = 0.45, perShell = true, falloff = { 10, 30, 0.3 }, spread = 6, adsSpread = 4.5, recoil = 3, speed = 0.97, adsFov = 60, price = 0 },
	Hornet = { slot = "Primary", class = "SMG", auto = true, damage = 17, head = 30, interval = 60 / 900, mag = 34, reload = 1.7, falloff = { 25, 60, 0.55 }, spread = 2.5, adsSpread = 1, recoil = 0.35, speed = 1.05, adsFov = 60, price = 150 },
	Triad = { slot = "Primary", class = "Burst Rifle", burst = 3, burstDelay = 0.32, damage = 30, head = 60, interval = 60 / 1100, mag = 24, reload = 2.1, falloff = { 80, 160, 0.8 }, spread = 1.5, adsSpread = 0.2, recoil = 0.6, speed = 1.0, adsFov = 50, price = 400 },
	Meridian = { slot = "Primary", class = "Bolt Sniper", scope = true, damage = 95, head = 250, interval = 1.4, mag = 5, reload = 2.6, spread = 8, adsSpread = 0, recoil = 4, speed = 0.92, adsFov = 20, price = 600 },
	Ward = { slot = "Secondary", class = "Pistol", damage = 22, head = 50, interval = 0.15, mag = 12, reload = 1.3, falloff = { 40, 90, 0.7 }, spread = 1.5, adsSpread = 0.3, recoil = 0.8, speed = 1.0, adsFov = 60, price = 0 },
	Verdict = { slot = "Secondary", class = "Revolver", damage = 50, head = 110, interval = 0.46, mag = 6, reload = 2.2, falloff = { 50, 110, 0.7 }, spread = 2, adsSpread = 0, recoil = 3, speed = 1.0, adsFov = 55, price = 300 },
	Edge = { slot = "Melee", class = "Knife", damage = 45, backstab = 100, interval = 0.4, range = 7, speed = 1.1, price = 0 },
	Glare = { slot = "Utility", class = "Flash", charges = 2, fuse = 1.2, blind = 2.0, peripheral = 0.8, price = 0 },
	Veil = { slot = "Utility", class = "Smoke", charges = 1, fuse = 1.0, radius = 11, duration = 7, price = 250 },
	Crack = { slot = "Utility", class = "Frag", charges = 1, fuse = 2.4, damage = 100, minDamage = 25, innerRadius = 3, radius = 10, price = 400 },
}

Config.Range = 500
Config.LimbMult = 0.85
Config.Slots = { "Primary", "Secondary", "Melee", "Utility" }
Config.Order = {
	Primary = { "Paragon", "Breaker", "Hornet", "Triad", "Meridian" },
	Secondary = { "Ward", "Verdict" },
	Melee = { "Edge" },
	Utility = { "Glare", "Veil", "Crack" },
}
Config.Starter = { Primary = "Paragon", Secondary = "Ward", Melee = "Edge", Utility = "Glare" }

-- Thesis item -> suggested Antithesis answers (pick-screen hints)
Config.Counters = {
	Meridian = { "Veil", "Hornet", "Breaker" },
	Breaker = { "Paragon", "Triad", "Crack" },
	Hornet = { "Triad", "Meridian", "Glare" },
	Paragon = { "Triad", "Breaker" },
	Triad = { "Hornet", "Meridian" },
	Veil = { "Glare", "Crack" },
}

-- Weapon palettes (skins). price = Coins; gamePass = Robux Game Pass id (0 = not on sale yet).
Config.Palettes = {
	Default = { body = Color3.fromRGB(43, 45, 49), accent = Color3.fromRGB(232, 230, 225), price = 0 },
	Chrome = { body = Color3.fromRGB(190, 195, 200), accent = Color3.fromRGB(60, 64, 70), material = Enum.Material.Metal, price = 300 },
	Ember = { body = Color3.fromRGB(40, 20, 15), accent = Color3.fromRGB(255, 120, 40), price = 500 },
	Void = { body = Color3.fromRGB(15, 10, 30), accent = Color3.fromRGB(160, 90, 255), price = 800 },
	Neon = { body = Color3.fromRGB(20, 20, 24), accent = Color3.fromRGB(34, 211, 238), neon = true, gamePass = 0 },
}
Config.PaletteOrder = { "Default", "Chrome", "Ember", "Void", "Neon" }

-- Built-in engine sounds so it works out of the box. Swap for Creator Store sound ids ("rbxassetid://123").
Config.Sounds = {
	Shot = "rbxasset://sounds/Rocket shot.wav",
	Hit = "rbxasset://sounds/clickfast.wav",
	Headshot = "rbxasset://sounds/collide.wav",
	Kill = "rbxasset://sounds/electronicpingshort.wav",
	Melee = "rbxasset://sounds/swordslash.wav",
	Lock = "rbxasset://sounds/swordlunge.wav",
	Button = "rbxasset://sounds/button.wav",
}

return Config
