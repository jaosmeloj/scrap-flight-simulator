--!strict
-- The only place with remote names. The server creates them (Remotes.init()), the client fetches them (Remotes.get).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- RemoteEvents
Remotes.Names = {
	FlightInput = "FlightInput", -- client -> server: { rocket: boolean, pitch: number } (pitch input -1/0/1)
	LaunchNow = "LaunchNow", -- client -> server: go down the ramp (SPACE or the LAUNCH button)
	ResetCart = "ResetCart", -- client -> server: back to the ramp
	FlightResult = "FlightResult", -- server -> client: { distance, coins, record, zones, zoneReward }
	Notify = "Notify", -- server -> client: string message
}

-- RemoteFunctions
Remotes.FunctionNames = {
	BuyUpgrade = "BuyUpgrade", -- (partKey) -> (ok, message)
	BuyCart = "BuyCart", -- (cartId) -> (ok, message) buys (if needed) and equips
	Customize = "Customize", -- (action, a, b) -> (ok, message): garage (CustomizeService)
}

local FOLDER_NAME = "Remotes"

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init only on the server")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in Remotes.Names do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in Remotes.FunctionNames do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
