-- Lobby menu, shop, Counter-Pick screen, reveal card, results, challenges, toasts.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Menus = {}
local C = Config.Colors
local GREY = Color3.fromRGB(90, 92, 98)
local player = Players.LocalPlayer

local menuButton, lobbyPanel, lobbyCoins, duelButton, doublesButton, fovLabel
local shopPanel, shopList, shopCoins
local pickPanel, pickTitle, pickTimer, revealLabel, pickRows, readyButton
local waitLabel, queuePill, revealCard, revealCardText, toastLabel
local resultsPanel, resultsTitle, resultsScore, resultsLines, unlockBar, unlockText, requeueButton, rematchButton
local challengePanel, challengeText
local pickMode = "match"
local requeueAt: number? = nil
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

local function revealText(reveal): string
	if not reveal then
		return ""
	end
	local lines = {}
	for _, e in reveal do
		local l = e.loadout
		table.insert(lines, string.format("THESIS  %s:  %s / %s / %s / %s", e.name, l.Primary, l.Secondary, l.Melee, l.Utility))
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------- pick screen

local function buildPick()
	clear(pickRows)
	local p = State.profile
	if not p then
		return
	end
	local ph = State.phase
	local hints = {}
	if pickMode == "match" and ph and ph.reveal then
		for _, e in ph.reveal do
			for _, id in Config.Counters[e.loadout.Primary] or {} do
				hints[id] = true
			end
			for _, id in Config.Counters[e.loadout.Utility] or {} do
				hints[id] = true
			end
		end
	end
	for order, slot in Config.Slots do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, LayoutOrder = order, Parent = pickRows }, {
			UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		UI.label({ Text = string.upper(slot), Size = UDim2.fromOffset(110, 56), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Gold, LayoutOrder = 0, Parent = row })
		for i, id in Config.Order[slot] do
			local w = Config.Weapons[id]
			local owned = p.unlocked[id]
			local selected = player:GetAttribute(slot) == id
			local sub = hints[id] and "COUNTER" or owned and w.class or ("LOCKED - " .. w.price)
			local b = UI.button(string.upper(id) .. "\n" .. sub, {
				Size = UDim2.fromOffset(118, 56),
				TextSize = 14,
				TextWrapped = true,
				LayoutOrder = i,
				AutoButtonColor = owned == true,
				BackgroundColor3 = selected and C.Ally or owned and C.Light or GREY,
			}, function()
				if owned then
					Net.Event:FireServer("Pick", slot, id)
				end
			end)
			if hints[id] then
				UI.new("UIStroke", { Color = C.Good, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
			end
			b.Parent = row
		end
	end
end

local function openLoadout()
	pickMode = "lobby"
	lobbyPanel.Visible = false
	pickTitle.Text = "LOADOUT (used in the firing range and as your default)"
	revealLabel.Text = ""
	readyButton.Text = "DONE"
	pickPanel.Visible = true
	buildPick()
	focus(readyButton)
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
	if p then
		lobbyCoins.Text = p.coins .. " COINS   •   " .. p.wins .. " WINS"
		fovLabel.Text = "FOV " .. p.fov
		if shopPanel.Visible then
			buildShop()
		end
	end
	duelButton.Text = State.queue == "Duel" and "CANCEL SEARCH" or Config.Modes.Duel.label
	doublesButton.Text = State.queue == "Doubles" and "CANCEL SEARCH" or Config.Modes.Doubles.label
end

function Menus.phase(ph)
	menuButton.Visible = ph == nil
	waitLabel.Visible = false
	if ph then
		lobbyPanel.Visible = false
		shopPanel.Visible = false
		resultsPanel.Visible = false
		requeueAt = nil
	end
	local picking = ph and (ph.phase == "Pick" or ph.phase == "Thesis" or ph.phase == "Antithesis")
	if picking and ph.canPick then
		pickMode = "match"
		pickTitle.Text = ({
			Pick = "PICK YOUR LOADOUT",
			Thesis = "YOU WON THE ROUND: LOCK YOUR THESIS (they will see it)",
			Antithesis = "THEY LOCKED IN: PICK YOUR ANTITHESIS",
		})[ph.phase]
		revealLabel.Text = revealText(ph.reveal)
		readyButton.Text = "READY"
		pickPanel.Visible = true
		buildPick()
		focus(readyButton)
	elseif pickMode == "match" or ph then
		pickPanel.Visible = false
		if picking then
			waitLabel.Visible = true
			waitLabel.Text = ph.phase == "Thesis" and "Opponent is locking their Thesis..." or "Opponent is picking their Antithesis..."
		end
	end
end

function Menus.reveal(reveal)
	revealCardText.Text = revealText(reveal)
	revealCard.Visible = true
	revealCard.Size = UDim2.fromOffset(820, 240)
	TweenService:Create(revealCard, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(640, 170) }):Play()
	UI.sound(Config.Sounds.Lock, 0.8, 0.8)
	task.delay(1.4, function()
		revealCard.Visible = false
	end)
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
	requeueAt = (not data.private and State.lastMode) and os.clock() + 5 or nil
	requeueButton.Visible = State.lastMode ~= nil
	resultsPanel.Visible = true
	focus(rematchButton)
end

function Menus.challenged(from: Player)
	challenger = from
	challengeText.Text = from.DisplayName .. " challenges you to a Duel"
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

local function toggleLobby()
	if State.phase then
		return
	end
	local open = lobbyPanel.Visible or shopPanel.Visible or pickPanel.Visible
	lobbyPanel.Visible = not open
	shopPanel.Visible = false
	pickPanel.Visible = false
	if lobbyPanel.Visible then
		focus(duelButton)
	end
end

local function queue(mode: string)
	if State.queue == mode then
		Net.Event:FireServer("Cancel")
	else
		State.lastMode = mode
		Net.Event:FireServer("Queue", mode)
		lobbyPanel.Visible = false
	end
end

function Menus.init(gui: ScreenGui)
	menuButton = UI.button("MENU [M]", { Position = UDim2.new(0, 16, 0.3, 0), Size = UDim2.fromOffset(120, 40), TextSize = 16, Parent = gui }, toggleLobby)

	-- Lobby
	lobbyPanel = UI.panel({ Size = UDim2.fromOffset(420, 440), Parent = gui })
	list(lobbyPanel, 10)
	UI.new("UIPadding", { PaddingTop = UDim.new(0, 18), Parent = lobbyPanel })
	UI.label({ Text = "ANTITHESIS", Size = UDim2.fromOffset(380, 44), TextSize = 40, Font = Enum.Font.GothamBlack, Parent = lobbyPanel })
	lobbyCoins = UI.label({ Text = "", TextColor3 = C.Gold, Size = UDim2.fromOffset(380, 24), Parent = lobbyPanel })
	duelButton = UI.button(Config.Modes.Duel.label, { BackgroundColor3 = C.Ally, Parent = lobbyPanel }, function()
		queue("Duel")
	end)
	doublesButton = UI.button(Config.Modes.Doubles.label, { BackgroundColor3 = C.Ally, Parent = lobbyPanel }, function()
		queue("Doubles")
	end)
	UI.button("LOADOUT", { Parent = lobbyPanel }, openLoadout)
	UI.button("SHOP", { Parent = lobbyPanel }, function()
		lobbyPanel.Visible = false
		shopPanel.Visible = true
		buildShop()
	end)
	local fovRow = UI.new("Frame", { Size = UDim2.fromOffset(220, 44), BackgroundTransparency = 1, Parent = lobbyPanel })
	local function fov(delta: number)
		local p = State.profile
		if p then
			p.fov = math.clamp(p.fov + delta, 70, 90)
			fovLabel.Text = "FOV " .. p.fov
			Net.Event:FireServer("Fov", p.fov)
		end
	end
	UI.button("-", { Size = UDim2.fromOffset(44, 44), Parent = fovRow }, function()
		fov(-5)
	end)
	fovLabel = UI.label({ Text = "FOV 70", Position = UDim2.fromOffset(44, 7), Size = UDim2.fromOffset(132, 30), Parent = fovRow })
	UI.button("+", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(176, 0), Parent = fovRow }, function()
		fov(5)
	end)
	UI.button("CLOSE", { BackgroundColor3 = GREY, TextColor3 = C.Light, Parent = lobbyPanel }, toggleLobby)

	-- Shop
	shopPanel = UI.panel({ Size = UDim2.fromOffset(580, 500), Parent = gui })
	UI.label({ Text = "SHOP", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(200, 36), TextSize = 30, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopPanel })
	shopCoins = UI.label({ Position = UDim2.fromOffset(220, 16), Size = UDim2.fromOffset(200, 30), TextColor3 = C.Gold, Parent = shopPanel })
	UI.button("BACK", { Position = UDim2.new(1, -120, 0, 12), Size = UDim2.fromOffset(100, 36), BackgroundColor3 = GREY, TextColor3 = C.Light, Parent = shopPanel }, function()
		shopPanel.Visible = false
		lobbyPanel.Visible = true
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

	-- Pick screen
	pickPanel = UI.panel({ Size = UDim2.fromOffset(780, 470), Parent = gui })
	pickTitle = UI.label({ Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -160, 0, 30), TextSize = 22, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = pickPanel })
	pickTimer = UI.label({ Position = UDim2.new(1, -130, 0, 12), Size = UDim2.fromOffset(110, 30), TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = pickPanel })
	revealLabel = UI.label({ Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 36), TextSize = 15, TextColor3 = C.Enemy, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = pickPanel })
	pickRows = UI.new("Frame", { Position = UDim2.fromOffset(20, 86), Size = UDim2.new(1, -40, 0, 270), BackgroundTransparency = 1, Parent = pickPanel })
	list(pickRows, 6)
	readyButton = UI.button("READY", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), BackgroundColor3 = C.Ally, Parent = pickPanel }, function()
		pickPanel.Visible = false
		if pickMode == "match" then
			Net.Event:FireServer("Ready")
			waitLabel.Text = "Ready. Waiting for the other side..."
			waitLabel.Visible = true
		else
			lobbyPanel.Visible = true
		end
	end)
	for _, slot in Config.Slots do
		player:GetAttributeChangedSignal(slot):Connect(function()
			if pickPanel.Visible then
				buildPick()
			end
		end)
	end

	waitLabel = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(600, 30), TextSize = 22, Visible = false, Parent = gui })
	queuePill = UI.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.fromOffset(460, 32), BackgroundTransparency = 0.2, BackgroundColor3 = C.Dark, TextColor3 = C.Ally, Visible = false, Parent = gui })
	toastLabel = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.fromOffset(500, 30), BackgroundTransparency = 0.2, BackgroundColor3 = C.Dark, Visible = false, Parent = gui })

	revealCard = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(640, 170), BackgroundColor3 = C.Enemy, Visible = false, ZIndex = 5, Parent = gui }, {
		UI.new("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	UI.label({ Text = "THESIS LOCKED", Size = UDim2.new(1, 0, 0.45, 0), TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = C.Dark, ZIndex = 5, Parent = revealCard })
	revealCardText = UI.label({ Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.45, 0), TextScaled = true, TextColor3 = C.Dark, ZIndex = 5, Parent = revealCard })

	-- Results
	resultsPanel = UI.panel({ Size = UDim2.fromOffset(480, 470), Parent = gui })
	list(resultsPanel, 8)
	UI.new("UIPadding", { PaddingTop = UDim.new(0, 16), Parent = resultsPanel })
	resultsTitle = UI.label({ Size = UDim2.fromOffset(440, 56), TextSize = 52, Font = Enum.Font.GothamBlack, Parent = resultsPanel })
	resultsScore = UI.label({ Size = UDim2.fromOffset(440, 30), TextSize = 26, Parent = resultsPanel })
	resultsLines = UI.label({ Size = UDim2.fromOffset(420, 120), TextSize = 16, TextColor3 = C.Gold, TextYAlignment = Enum.TextYAlignment.Top, Parent = resultsPanel })
	unlockText = UI.label({ Size = UDim2.fromOffset(420, 22), TextSize = 15, Parent = resultsPanel })
	local barBack = UI.new("Frame", { Size = UDim2.fromOffset(420, 10), BackgroundColor3 = GREY, BorderSizePixel = 0, Parent = resultsPanel })
	unlockBar = UI.new("Frame", { BackgroundColor3 = C.Gold, BorderSizePixel = 0, Parent = barBack })
	rematchButton = UI.button("REMATCH", { BackgroundColor3 = C.Ally, Parent = resultsPanel }, function()
		requeueAt = nil
		rematchButton.Text = "WAITING..."
		Net.Event:FireServer("Rematch")
	end)
	requeueButton = UI.button("PLAY AGAIN", { Parent = resultsPanel }, function()
		requeueAt = os.clock()
	end)
	UI.button("LOBBY", { BackgroundColor3 = GREY, TextColor3 = C.Light, Parent = resultsPanel }, function()
		requeueAt = nil
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
			toggleLobby()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

	RunService.RenderStepped:Connect(function()
		State.menuOpen = lobbyPanel.Visible or shopPanel.Visible or pickPanel.Visible or resultsPanel.Visible or challengePanel.Visible
		local ph = State.phase
		if pickPanel.Visible and ph and pickMode == "match" then
			pickTimer.Text = tostring(math.ceil(math.max(0, ph.endsAt - workspace:GetServerTimeNow())))
		else
			pickTimer.Text = ""
		end
		queuePill.Visible = State.queue ~= nil and ph == nil
		if queuePill.Visible then
			local t = math.floor(os.clock() - State.queuedAt)
			queuePill.Text = string.format("SEARCHING %s   %d:%02d   ([M] to cancel)", Config.Modes[State.queue].label, t // 60, t % 60)
		end
		if requeueAt and resultsPanel.Visible then
			local left = math.ceil(requeueAt - os.clock())
			requeueButton.Text = "PLAY AGAIN (" .. math.max(left, 0) .. ")"
			if left <= 0 then
				requeueAt = nil
				resultsPanel.Visible = false
				Net.Event:FireServer("Queue", State.lastMode)
			end
		elseif resultsPanel.Visible then
			requeueButton.Text = "PLAY AGAIN"
		end
	end)
end

return Menus
