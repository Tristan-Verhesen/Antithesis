-- Tiny UI and sound helpers.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage.Shared.Config)

local UI = {}
local C = Config.Colors

function UI.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.label(props): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = C.Light,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Size = UDim2.fromOffset(200, 30),
	}
	for k, v in props do
		defaults[k] = v
	end
	return UI.new("TextLabel", defaults)
end

function UI.panel(props): Frame
	local defaults = {
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.08,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = UI.new("Frame", defaults, { UI.new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	-- A visible Modal button frees the mouse from first-person lock while the panel is open.
	UI.new("TextButton", { Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Parent = frame })
	return frame
end

function UI.button(text: string, props, onClick: () -> ()): TextButton
	local defaults = {
		Text = text,
		BackgroundColor3 = C.Light,
		TextColor3 = C.Dark,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(220, 44),
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	local b = UI.new("TextButton", defaults, { UI.new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	b.Activated:Connect(function()
		UI.sound(Config.Sounds.Button, 1, 0.3)
		onClick()
	end)
	return b
end

function UI.sound(id: string?, speed: number?, volume: number?)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed or 1
	s.Volume = volume or 0.5
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

function UI.relColor(team: number?, myTeam: number?): Color3
	return team == myTeam and C.Ally or C.Enemy
end

return UI
