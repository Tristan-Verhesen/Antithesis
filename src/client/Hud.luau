-- In-match HUD and feedback: crosshair, hit markers, HP/ammo, score/timer, killfeed, banners, flash, tracers, enemy outlines.
-- Everything important sits in the center column so 9:16 crops of recordings keep it (Shorts-safe HUD).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Hud = {}
local C = Config.Colors
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local root: Frame
local crosshair, marker, dmgNumber, hpBar, hpText, ammoText, utilText, dashText
local bottom, scoreText, timerText, phaseText, bigText, feed, bannerText, flashFrame, scope
local edges = {}
local correction: ColorCorrectionEffect
local killsThisRound = 0
local dmgAccum, dmgAt = 0, 0

local function myTeam(): number
	return player:GetAttribute("Team") or 0
end

function Hud.init(gui: ScreenGui)
	root = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	crosshair = UI.new("Frame", { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = root })
	for _, cfg in { { 2, 7, 0.5, 0 }, { 2, 7, 0.5, 1 }, { 7, 2, 0, 0.5 }, { 7, 2, 1, 0.5 } } do
		UI.new("Frame", { Size = UDim2.fromOffset(cfg[1], cfg[2]), AnchorPoint = Vector2.new(cfg[3], cfg[4]), Position = UDim2.fromScale(cfg[3], cfg[4]), BackgroundColor3 = C.Light, BorderSizePixel = 0, Parent = crosshair })
	end

	marker = UI.new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = root })
	for _, rot in { 45, -45 } do
		UI.new("Frame", { Size = UDim2.new(1, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = rot, BorderSizePixel = 0, BackgroundColor3 = C.Light, Parent = marker })
	end
	dmgNumber = UI.label({ Position = UDim2.new(0.5, 30, 0.5, -40), Size = UDim2.fromOffset(80, 24), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 20, Visible = false, Parent = root })

	-- Bottom center: HP, ammo, utility, dash
	bottom = UI.new("Frame", { Size = UDim2.fromOffset(420, 70), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), BackgroundTransparency = 1, Parent = root })
	local hpBack = UI.new("Frame", { Size = UDim2.fromOffset(200, 14), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = C.Dark, BorderSizePixel = 0, Parent = bottom })
	hpBar = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ally, BorderSizePixel = 0, Parent = hpBack })
	hpText = UI.label({ Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(200, 30), TextSize = 28, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = bottom })
	ammoText = UI.label({ Position = UDim2.fromOffset(220, 8), Size = UDim2.fromOffset(200, 30), TextSize = 28, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right, Parent = bottom })
	utilText = UI.label({ Position = UDim2.fromOffset(220, 40), Size = UDim2.fromOffset(200, 18), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Parent = bottom })
	dashText = UI.label({ Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(200, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = bottom })

	-- Top center: score, timer, phase
	scoreText = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(300, 36), TextSize = 32, Font = Enum.Font.GothamBlack, RichText = true, Visible = false, Parent = root })
	timerText = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(300, 22), TextSize = 20, Visible = false, Parent = root })
	phaseText = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102), Size = UDim2.fromOffset(400, 20), TextSize = 14, TextColor3 = C.Gold, Visible = false, Parent = root })
	feed = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(420, 100), BackgroundTransparency = 1, Parent = root }, {
		UI.new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	bigText = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(600, 80), TextSize = 64, Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.5, Visible = false, Parent = root })
	bannerText = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(500, 50), TextSize = 40, Font = Enum.Font.GothamBlack, TextColor3 = C.Gold, TextStrokeTransparency = 0.4, Visible = false, Parent = root })

	-- Directional damage edges (left, right, top=front, bottom=behind)
	for name, cfg in { Left = { 0, 0, 0.012, 1 }, Right = { 0.988, 0, 0.012, 1 }, Front = { 0, 0, 1, 0.02 }, Back = { 0, 0.98, 1, 0.02 } } do
		edges[name] = UI.new("Frame", { Position = UDim2.fromScale(cfg[1], cfg[2]), Size = UDim2.fromScale(cfg[3], cfg[4]), BackgroundColor3 = C.Bad, BorderSizePixel = 0, BackgroundTransparency = 1, Parent = root })
	end

	scope = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = root }, {
		UI.new("Frame", { Size = UDim2.new(0.5, -260, 1, 0), BackgroundColor3 = Color3.new(), BorderSizePixel = 0 }),
		UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -260, 1, 0), BackgroundColor3 = Color3.new(), BorderSizePixel = 0 }),
		UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 520, 0, 1), BackgroundColor3 = Color3.new(), BorderSizePixel = 0 }),
		UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.new(), BorderSizePixel = 0 }),
	})
	flashFrame = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = root })

	correction = Instance.new("ColorCorrectionEffect")
	correction.Parent = Lighting

	RunService.RenderStepped:Connect(Hud.update)
	task.spawn(function()
		while true do
			Hud.outlines()
			task.wait(0.5)
		end
	end)
end

function Hud.update()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = hum and math.ceil(hum.Health) or 0
	hpText.Text = tostring(hp)
	hpBar.Size = UDim2.fromScale(math.clamp(hp / 100, 0, 1), 1)
	hpBar.BackgroundColor3 = hp < 30 and C.Bad or C.Ally
	correction.Saturation = (hum and hp < 30 and hp > 0) and -0.4 or 0

	local w = Config.Weapons[State.weaponId or ""]
	ammoText.Text = (w and w.mag) and (State.reloading and "RELOADING" or (State.ammo .. " / " .. State.mag)) or (w and string.upper(State.weaponId) or "")
	local util = player:GetAttribute("Utility")
	utilText.Text = (util and string.upper(util) .. "  x" .. (player:GetAttribute("Charges") or 0) or "") .. "   [G]"
	local dashLeft = State.dashReadyAt - os.clock()
	dashText.Text = dashLeft > 0 and string.format("DASH %.1fs", dashLeft) or "DASH READY [SHIFT]"

	bottom.Visible = State.holding
	crosshair.Visible = State.holding and not State.scoped and not State.menuOpen
	scope.Visible = State.scoped
	if os.clock() - dmgAt > 0.6 then
		dmgNumber.Visible = false
		dmgAccum = 0
	end

	local ph = State.phase
	if ph then
		local left = math.ceil(math.max(0, ph.endsAt - workspace:GetServerTimeNow()))
		timerText.Text = string.format("ROUND %d   %d:%02d", ph.round, left // 60, left % 60)
		if ph.phase == "Countdown" then
			bigText.Visible = true
			bigText.TextColor3 = C.Light
			bigText.Text = tostring(left)
		end
	end
end

function Hud.phase(ph)
	local inMatch = ph ~= nil
	scoreText.Visible = inMatch
	timerText.Visible = inMatch
	phaseText.Visible = inMatch
	bigText.Visible = false
	if not ph then
		return
	end
	local me, them = ph.team, 3 - ph.team
	scoreText.Text = string.format('<font color="#%s">%d</font>  -  <font color="#%s">%d</font>', C.Ally:ToHex(), ph.score[me], C.Enemy:ToHex(), ph.score[them])
	phaseText.Text = ({
		Countdown = "FIRST TO " .. ph.winsNeeded .. "  •  " .. string.upper(ph.arena),
		Live = "FIRST TO " .. ph.winsNeeded .. "  •  " .. string.upper(ph.arena),
		Collapse = "COLLAPSE: GET TO THE CENTER",
		RoundEnd = "",
	})[ph.phase] or ""
	if ph.phase == "Live" then
		killsThisRound = 0
	elseif ph.phase == "RoundEnd" then
		bigText.Visible = true
		local w = ph.roundWinner
		bigText.Text = w == 0 and "DRAW" or w == me and "ROUND WON" or "ROUND LOST"
		bigText.TextColor3 = w == 0 and C.Light or w == me and C.Ally or C.Enemy
	end
end

function Hud.hit(damage: number, head: boolean, killed: boolean)
	marker.Visible = true
	marker.Size = UDim2.fromOffset(head and 30 or 22, head and 30 or 22)
	for _, line in marker:GetChildren() do
		line.BackgroundColor3 = killed and C.Bad or head and C.Gold or C.Light
	end
	task.delay(head and 0.16 or 0.12, function()
		marker.Visible = false
	end)
	dmgAccum += damage
	dmgAt = os.clock()
	dmgNumber.Text = tostring(dmgAccum)
	dmgNumber.TextColor3 = head and C.Gold or C.Light
	dmgNumber.Visible = true
	if killed then
		killsThisRound += 1
		UI.sound(Config.Sounds.Kill, 2 ^ (2 * math.min(killsThisRound - 1, 4) / 12), 0.6)
		if head then
			camera.FieldOfView += 2
		end
	else
		UI.sound(head and Config.Sounds.Headshot or Config.Sounds.Hit, head and 1.4 or 1, 0.5)
	end
end

function Hud.damaged(fromPos: Vector3?)
	local edge = edges.Front
	if fromPos then
		local rel = camera.CFrame:PointToObjectSpace(fromPos)
		if math.abs(rel.X) > math.abs(rel.Z) then
			edge = rel.X > 0 and edges.Right or edges.Left
		else
			edge = rel.Z < 0 and edges.Front or edges.Back
		end
	end
	edge.BackgroundTransparency = 0.2
	TweenService:Create(edge, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

local function shatter(pos: Vector3, color: Color3)
	for _ = 1, 8 do
		local p = Instance.new("Part")
		p.Size = Vector3.one * (0.4 + math.random() * 0.5)
		p.CFrame = CFrame.new(pos + Vector3.new(math.random() - 0.5, math.random() * 2, math.random() - 0.5) * 2)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(10, 25), math.random(-15, 15))
		p.Parent = workspace
		Debris:AddItem(p, 1.5)
	end
end

function Hud.feed(data)
	local me = myTeam()
	local killerColor = data.killerTeam == 0 and C.Gold or UI.relColor(data.killerTeam, me)
	local entry = UI.label({
		Size = UDim2.fromOffset(420, 22),
		TextSize = 16,
		RichText = true,
		TextStrokeTransparency = 0.6,
		Text = string.format('<font color="#%s">%s</font>  [%s%s]  <font color="#%s">%s</font>',
			killerColor:ToHex(), data.killer, string.upper(data.weapon), data.head and " •HS" or "", UI.relColor(data.victimTeam, me):ToHex(), data.victim),
		Parent = feed,
	})
	local entries = feed:GetChildren()
	if #entries > 5 then -- layout + 4 entries
		for _, e in entries do
			if e:IsA("TextLabel") and e ~= entry then
				e:Destroy()
				break
			end
		end
	end
	Debris:AddItem(entry, 5)
	if data.pos then
		shatter(data.pos, UI.relColor(data.victimTeam, me))
	end
end

function Hud.banner(text: string)
	bannerText.Text = text
	bannerText.Visible = true
	bannerText.TextSize = 60
	TweenService:Create(bannerText, TweenInfo.new(0.2), { TextSize = 40 }):Play()
	task.delay(1.5, function()
		if bannerText.Text == text then
			bannerText.Visible = false
		end
	end)
end

function Hud.flash(duration: number)
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
end

function Hud.tracer(from: Vector3, to: Vector3)
	local dist = (to - from).Magnitude
	if dist < 1 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = C.Gold
	p.Size = Vector3.new(0.06, 0.06, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = camera
	Debris:AddItem(p, 0.06)
end

-- Outline match players: allies cyan, enemies orange. Dark outfits can't hide anyone.
function Hud.outlines()
	local myMatch = player:GetAttribute("MatchId") or 0
	for _, other in Players:GetPlayers() do
		local char = other.Character
		if other ~= player and char then
			local h = char:FindFirstChild("TeamOutline")
			if myMatch ~= 0 and other:GetAttribute("MatchId") == myMatch then
				h = h or UI.new("Highlight", { Name = "TeamOutline", FillTransparency = 1, OutlineTransparency = 0.3, Parent = char })
				local ally = other:GetAttribute("Team") == myTeam()
				h.OutlineColor = UI.relColor(other:GetAttribute("Team"), myTeam())
				-- Enemies only outline where visible; allies show through walls.
				h.DepthMode = if ally then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
			elseif h then
				h:Destroy()
			end
		end
	end
end

return Hud
