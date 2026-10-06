-- Lobby side menu (Loadout / Shop / FOV), pad status, results, challenges and toasts.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Menus = {}
local C = Config.Colors
local GREY = Color3.fromRGB(90, 92, 98)
local player = Players.LocalPlayer

local sideBar, coinsLabel, fovLabel
local loadoutPanel, loadoutRows, doneButton
local shopPanel, shopList, shopCoins
local padPill, toastLabel
local resultsPanel, resultsTitle, resultsScore, resultsLines, unlockBar, unlockText, rematchButton
local challengePanel, challengeText
local challenger: Player? = nil

local function focus(button: GuiObject)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = button
	end
end

local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function list(parent: Instance, padding: number)
	return UI.new("UIListLayout", { Padding = UDim.new(0, padding), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent })
end

---------------------------------------------------------------- loadout

local function buildLoadout()
	clear(loadoutRows)
	local p = State.profile
	if not p then
		return
	end
	for order, slot in Config.Slots do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, LayoutOrder = order, Parent = loadoutRows }, {
			UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		UI.label({ Text = string.upper(slot), Size = UDim2.fromOffset(110, 56), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Gold, LayoutOrder = 0, Parent = row })
		for i, id in Config.Order[slot] do
			local w = Config.Weapons[id]
			local owned = p.unlocked[id] == true
			local selected = player:GetAttribute(slot) == id
			UI.button(string.upper(id) .. "\n" .. (owned and w.class or ("LOCKED - " .. w.price)), {
				Size = UDim2.fromOffset(118, 56),
				TextSize = 14,
				TextWrapped = true,
				LayoutOrder = i,
				AutoButtonColor = owned,
				BackgroundColor3 = selected and C.Ally or owned and C.Light or GREY,
				Parent = row,
			}, function()
				if owned then
					Net.Event:FireServer("Pick", slot, id)
				end
			end)
		end
	end
end

---------------------------------------------------------------- shop

local function buildShop()
	clear(shopList)
	local p = State.profile
	if not p then
		return
	end
	shopCoins.Text = p.coins .. " COINS"
	local order = 0
	local function row(name: string, sub: string, status: string, buttonText: string?, enabled: boolean?, onClick: (() -> ())?)
		order += 1
		local r = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 50), BackgroundColor3 = Color3.fromRGB(60, 62, 68), LayoutOrder = order, Parent = shopList }, { UI.new("UICorner") })
		UI.label({ Text = name, Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(260, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = r })
		UI.label({ Text = sub, Position = UDim2.fromOffset(12, 27), Size = UDim2.fromOffset(260, 18), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, TextColor3 = Color3.fromRGB(170, 170, 175), Parent = r })
		UI.label({ Text = status, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -148, 0.5, 0), Size = UDim2.fromOffset(140, 24), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Gold, Parent = r })
		if buttonText then
			UI.button(buttonText, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(130, 36),
				TextSize = 15,
				AutoButtonColor = enabled == true,
				BackgroundColor3 = enabled and C.Light or GREY,
				Parent = r,
			}, function()
				if enabled and onClick then
					onClick()
				end
			end)
		end
	end
	for _, slot in Config.Slots do
		for _, id in Config.Order[slot] do
			local w = Config.Weapons[id]
			local sub = slot .. " - " .. w.class
			if p.unlocked[id] then
				row(string.upper(id), sub, "OWNED")
			else
				row(string.upper(id), sub, w.price .. " COINS", "UNLOCK", p.coins >= w.price, function()
					Net.Event:FireServer("Unlock", id)
				end)
			end
		end
	end
	for _, name in Config.PaletteOrder do
		local pal = Config.Palettes[name]
		local title = string.upper(name) .. " PALETTE"
		if p.palettes[name] then
			local equipped = p.palette == name
			row(title, "Weapon skin", equipped and "EQUIPPED" or "OWNED", not equipped and "EQUIP" or nil, true, function()
				Net.Event:FireServer("Palette", name)
			end)
		elseif pal.price then
			row(title, "Weapon skin", pal.price .. " COINS", "BUY", p.coins >= pal.price, function()
				Net.Event:FireServer("Unlock", name)
			end)
		elseif pal.gamePass and pal.gamePass ~= 0 then
			row(title, "Weapon skin (Robux)", "GAME PASS", "BUY", true, function()
				MarketplaceService:PromptGamePassPurchase(player, pal.gamePass)
			end)
		else
			row(title, "Weapon skin (Robux)", "COMING SOON")
		end
	end
end

---------------------------------------------------------------- public

function Menus.refresh()
	local p = State.profile
	if not p then
		return
	end
	coinsLabel.Text = p.coins .. " COINS  •  " .. p.wins .. " WINS"
	fovLabel.Text = "FOV " .. p.fov
	if shopPanel.Visible then
		buildShop()
	end
	if loadoutPanel.Visible then
		buildLoadout()
	end
end

function Menus.phase(ph)
	sideBar.Visible = ph == nil
	if ph then
		loadoutPanel.Visible = false
		shopPanel.Visible = false
		resultsPanel.Visible = false
		challengePanel.Visible = false
	end
end

function Menus.results(data)
	local p = State.profile
	resultsTitle.Text = data.won and "VICTORY" or "DEFEAT"
	resultsTitle.TextColor3 = data.won and C.Ally or C.Enemy
	resultsScore.Text = data.score[data.team] .. "  -  " .. data.score[3 - data.team]
	local lines, total = {}, 0
	for _, l in data.lines do
		table.insert(lines, "+" .. l[2] .. "   " .. l[1])
		total += l[2]
	end
	resultsLines.Text = #lines > 0 and table.concat(lines, "\n") .. "\n= +" .. total .. " COINS" or "No coins this time (deal 100 damage or win a round)"

	-- Progress toward the cheapest locked weapon.
	local nextId, nextPrice
	for id, w in Config.Weapons do
		if p and not p.unlocked[id] and (not nextPrice or w.price < nextPrice) then
			nextId, nextPrice = id, w.price
		end
	end
	if nextId then
		unlockText.Text = string.format("%d / %d COINS  ->  %s", math.min(p.coins, nextPrice), nextPrice, string.upper(nextId))
		unlockBar.Size = UDim2.fromScale(math.clamp(p.coins / nextPrice, 0, 1), 1)
	else
		unlockText.Text = "ALL WEAPONS UNLOCKED: spend coins on palettes in the Shop"
		unlockBar.Size = UDim2.fromScale(1, 1)
	end
	rematchButton.Text = "REMATCH"
	loadoutPanel.Visible = false
	shopPanel.Visible = false
	resultsPanel.Visible = true
	focus(rematchButton)
end

function Menus.challenged(from: Player)
	challenger = from
	challengeText.Text = from.DisplayName .. " challenges you to a 1v1"
	challengePanel.Visible = true
	task.delay(15, function()
		if challenger == from then
			challengePanel.Visible = false
			challenger = nil
		end
	end)
end

function Menus.toast(text: string)
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(3, function()
		if toastLabel.Text == text then
			toastLabel.Visible = false
		end
	end)
end

local function openLoadout()
	if State.phase then
		return
	end
	shopPanel.Visible = false
	loadoutPanel.Visible = not loadoutPanel.Visible
	if loadoutPanel.Visible then
		buildLoadout()
		focus(doneButton)
	end
end

local function openShop()
	if State.phase then
		return
	end
	loadoutPanel.Visible = false
	shopPanel.Visible = not shopPanel.Visible
	if shopPanel.Visible then
		buildShop()
	end
end

function Menus.init(gui: ScreenGui)
	-- Left-side lobby menu (Rivals-style buttons).
	sideBar = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(200, 250), BackgroundTransparency = 1, Parent = gui })
	list(sideBar, 8)
	coinsLabel = UI.label({ Text = "", TextColor3 = C.Gold, Size = UDim2.fromOffset(200, 24), TextStrokeTransparency = 0.5, Parent = sideBar })
	UI.button("LOADOUT [M]", { Size = UDim2.fromOffset(200, 48), BackgroundColor3 = C.Ally, Parent = sideBar }, openLoadout)
	UI.button("SHOP", { Size = UDim2.fromOffset(200, 48), BackgroundColor3 = C.Gold, Parent = sideBar }, openShop)
	local fovRow = UI.new("Frame", { Size = UDim2.fromOffset(200, 40), BackgroundTransparency = 1, Parent = sideBar })
	local function fov(delta: number)
		local p = State.profile
		if p then
			p.fov = math.clamp(p.fov + delta, 70, 90)
			fovLabel.Text = "FOV " .. p.fov
			Net.Event:FireServer("Fov", p.fov)
		end
	end
	UI.button("-", { Size = UDim2.fromOffset(40, 40), Parent = fovRow }, function()
		fov(-5)
	end)
	fovLabel = UI.label({ Text = "FOV 70", Position = UDim2.fromOffset(40, 5), Size = UDim2.fromOffset(120, 30), TextStrokeTransparency = 0.5, Parent = fovRow })
	UI.button("+", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(160, 0), Parent = fovRow }, function()
		fov(5)
	end)

	-- Loadout
	loadoutPanel = UI.panel({ Size = UDim2.fromOffset(780, 400), Parent = gui })
	UI.label({ Text = "LOADOUT", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(300, 30), TextSize = 26, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = loadoutPanel })
	UI.label({ Text = "Locked in for the whole match. Unlock more in the Shop.", Position = UDim2.fromOffset(20, 42), Size = UDim2.new(1, -40, 0, 20), TextSize = 14, TextColor3 = Color3.fromRGB(170, 170, 175), TextXAlignment = Enum.TextXAlignment.Left, Parent = loadoutPanel })
	loadoutRows = UI.new("Frame", { Position = UDim2.fromOffset(20, 70), Size = UDim2.new(1, -40, 0, 260), BackgroundTransparency = 1, Parent = loadoutPanel })
	list(loadoutRows, 6)
	doneButton = UI.button("DONE", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), BackgroundColor3 = C.Ally, Parent = loadoutPanel }, function()
		loadoutPanel.Visible = false
	end)
	for _, slot in Config.Slots do
		player:GetAttributeChangedSignal(slot):Connect(function()
			if loadoutPanel.Visible then
				buildLoadout()
			end
		end)
	end

	-- Shop
	shopPanel = UI.panel({ Size = UDim2.fromOffset(580, 500), Parent = gui })
	UI.label({ Text = "SHOP", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(200, 36), TextSize = 30, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopPanel })
	shopCoins = UI.label({ Position = UDim2.fromOffset(220, 16), Size = UDim2.fromOffset(200, 30), TextColor3 = C.Gold, Parent = shopPanel })
	UI.button("CLOSE", { Position = UDim2.new(1, -120, 0, 12), Size = UDim2.fromOffset(100, 36), BackgroundColor3 = GREY, TextColor3 = C.Light, Parent = shopPanel }, function()
		shopPanel.Visible = false
	end)
	shopList = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 1, -70),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = shopPanel,
	})
	list(shopList, 6)

	padPill = UI.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(460, 40), TextSize = 20, BackgroundTransparency = 0.15, BackgroundColor3 = C.Metal, TextColor3 = C.Light, Visible = false, Parent = gui })
	UI.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = padPill })
	toastLabel = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(500, 30), BackgroundTransparency = 0.2, BackgroundColor3 = C.Dark, Visible = false, Parent = gui })

	-- Results
	resultsPanel = UI.panel({ Size = UDim2.fromOffset(480, 420), Parent = gui })
	list(resultsPanel, 8)
	UI.new("UIPadding", { PaddingTop = UDim.new(0, 16), Parent = resultsPanel })
	resultsTitle = UI.label({ Size = UDim2.fromOffset(440, 56), TextSize = 52, Font = Enum.Font.GothamBlack, Parent = resultsPanel })
	resultsScore = UI.label({ Size = UDim2.fromOffset(440, 30), TextSize = 26, Parent = resultsPanel })
	resultsLines = UI.label({ Size = UDim2.fromOffset(420, 120), TextSize = 16, TextColor3 = C.Gold, TextYAlignment = Enum.TextYAlignment.Top, Parent = resultsPanel })
	unlockText = UI.label({ Size = UDim2.fromOffset(420, 22), TextSize = 15, Parent = resultsPanel })
	local barBack = UI.new("Frame", { Size = UDim2.fromOffset(420, 10), BackgroundColor3 = GREY, BorderSizePixel = 0, Parent = resultsPanel })
	unlockBar = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Parent = barBack })
	rematchButton = UI.button("REMATCH", { BackgroundColor3 = C.Ally, Parent = resultsPanel }, function()
		rematchButton.Text = "WAITING..."
		Net.Event:FireServer("Rematch")
	end)
	UI.button("BACK TO LOBBY", { BackgroundColor3 = GREY, TextColor3 = C.Light, Parent = resultsPanel }, function()
		resultsPanel.Visible = false
	end)

	-- Challenge
	challengePanel = UI.panel({ Size = UDim2.fromOffset(400, 150), Position = UDim2.fromScale(0.5, 0.25), Parent = gui })
	challengeText = UI.label({ Position = UDim2.fromOffset(10, 14), Size = UDim2.new(1, -20, 0, 40), TextSize = 20, TextWrapped = true, Parent = challengePanel })
	local function reply(accept: boolean)
		if challenger then
			Net.Event:FireServer("ChallengeReply", challenger, accept)
		end
		challenger = nil
		challengePanel.Visible = false
	end
	UI.button("ACCEPT", { Position = UDim2.fromOffset(20, 80), Size = UDim2.fromOffset(170, 48), BackgroundColor3 = C.Good, Parent = challengePanel }, function()
		reply(true)
	end)
	UI.button("DECLINE", { Position = UDim2.fromOffset(210, 80), Size = UDim2.fromOffset(170, 48), BackgroundColor3 = GREY, TextColor3 = C.Light, Parent = challengePanel }, function()
		reply(false)
	end)

	ContextActionService:BindAction("Menu", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			openLoadout()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

	RunService.RenderStepped:Connect(function()
		State.menuOpen = loadoutPanel.Visible or shopPanel.Visible or resultsPanel.Visible or challengePanel.Visible
		local pad = State.pad
		padPill.Visible = pad ~= nil and State.phase == nil
		if padPill.Visible then
			if pad.startsAt then
				local left = math.max(0, math.ceil(pad.startsAt - workspace:GetServerTimeNow()))
				padPill.Text = string.format("%s  •  MATCH STARTING IN %d", pad.label, left)
				padPill.TextColor3 = C.Good
			else
				padPill.Text = string.format("%s  •  WAITING FOR PLAYERS  %d/%d", pad.label, pad.count, pad.needed)
				padPill.TextColor3 = C.Light
			end
		end
	end)
end

return Menus
