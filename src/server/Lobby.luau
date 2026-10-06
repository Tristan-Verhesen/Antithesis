-- Pad matchmaking (Rivals-style): stand on a pad; when both pads of a station are full,
-- a countdown starts and everyone on the station is sent into a match. Stepping off cancels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(script.Parent.Combat)
local Match = require(script.Parent.Match)
local World = require(script.Parent.World)

local Lobby = {}
local L = Config.Lobby
local lastStatus: { [Player]: string } = {}
local teleportReady: { [Player]: number } = {}

-- maxY: how far above the pad still counts (higher for players already on it, so jumping doesn't drop them).
local function standingOn(player: Player, center: Vector3, maxY: number?): boolean
	if Match.busy(player) then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then
		return false
	end
	local offset = root.Position - center
	return offset.Y > -1 and offset.Y < (maxY or 8) and Vector2.new(offset.X, offset.Z).Magnitude <= L.PadRadius
end

local function onPad(player: Player, pad, maxY: number?): boolean
	return standingOn(player, pad.center, maxY)
end

-- Range teleport pads: lobby arm <-> separate firing range room.
local function teleports()
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		if now >= (teleportReady[p] or 0) then
			for _, tp in World.teleports do
				if standingOn(p, tp.center) then
					p.Character:PivotTo(tp.target)
					Combat.clear(p) -- the anti-speed check must not snap the player back
					teleportReady[p] = now + L.TeleportCooldown
					break
				end
			end
		end
	end
end

local function setText(label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
	end
end

local function tell(player: Player, status)
	local key = status and (status.label .. status.count .. "/" .. status.needed .. tostring(status.startsAt)) or ""
	if lastStatus[player] ~= key then
		lastStatus[player] = key
		Net.Event:FireClient(player, "Pad", status)
	end
end

local function tick()
	local now = workspace:GetServerTimeNow()
	local seen: { [Player]: any } = {}

	for _, station in World.stations do
		-- Keep players who are still standing on their pad, then fill free spots in arrival order.
		local changed = false
		for _, pad in station.pads do
			for i = #pad.occupants, 1, -1 do
				local p = pad.occupants[i]
				if p.Parent and not seen[p] and onPad(p, pad, 14) then
					seen[p] = station
				else
					table.remove(pad.occupants, i)
					changed = true -- someone left: a running countdown is void even if the spot refills now
				end
			end
		end
		for _, pad in station.pads do
			for _, p in Players:GetPlayers() do
				if #pad.occupants >= station.size then
					break
				end
				if not seen[p] and onPad(p, pad) then
					seen[p] = station
					table.insert(pad.occupants, p)
				end
			end
		end

		local count, needed = 0, station.size * 2
		for _, pad in station.pads do
			count += #pad.occupants
		end
		if changed or count ~= needed then
			station.startsAt = nil
		end
		if count == needed then
			station.startsAt = station.startsAt or now + L.PadCountdown
		end

		local left = station.startsAt and math.max(0, math.ceil(station.startsAt - now))
		for _, pad in station.pads do
			local text = #pad.occupants .. "/" .. station.size
			setText(pad.board, left and text .. "\nSTARTING " .. left or text)
			pad.ring.Transparency = #pad.occupants >= station.size and 0 or 0.5
		end

		local status = { label = Config.Modes[station.mode].label, count = count, needed = needed, startsAt = station.startsAt }
		for _, pad in station.pads do
			for _, p in pad.occupants do
				tell(p, status)
			end
		end

		if station.startsAt and now >= station.startsAt then
			local teams = { table.clone(station.pads[1].occupants), table.clone(station.pads[2].occupants) }
			for _, pad in station.pads do
				table.clear(pad.occupants)
			end
			station.startsAt = nil
			for _, team in teams do
				for _, p in team do
					seen[p] = nil
					tell(p, nil)
				end
			end
			Match.begin(station.mode, teams, false)
		end
	end

	for _, p in Players:GetPlayers() do
		if not seen[p] then
			tell(p, nil)
		end
	end
	teleports()
end

function Lobby.start()
	Players.PlayerRemoving:Connect(function(p)
		lastStatus[p] = nil
		teleportReady[p] = nil
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.15)
		end
	end)
end

return Lobby
