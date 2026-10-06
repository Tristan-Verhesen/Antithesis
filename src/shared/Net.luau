-- One reliable RemoteEvent for everything ("Action", ...args) and one unreliable one for cosmetic FX.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsServer() and not ReplicatedStorage:FindFirstChild("Remotes") then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	local event = Instance.new("RemoteEvent")
	event.Name = "Net"
	event.Parent = folder
	local fx = Instance.new("UnreliableRemoteEvent")
	fx.Name = "FX"
	fx.Parent = folder
	folder.Parent = ReplicatedStorage
end

local folder = ReplicatedStorage:WaitForChild("Remotes")
return {
	Event = folder:WaitForChild("Net") :: RemoteEvent,
	FX = folder:WaitForChild("FX") :: UnreliableRemoteEvent,
}
