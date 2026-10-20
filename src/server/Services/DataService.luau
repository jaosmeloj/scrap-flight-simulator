--!strict
-- Loads and saves profiles in the DataStore (pcall + retry, PlayerRemoving + BindToClose).
-- If the DataStore is unavailable (Studio without API access, unpublished place) the player gets a fresh profile
-- and NOTHING is saved, so a real save is never overwritten by an empty one.
-- Session lock (Rules/Profile): the record carries `_lock = { id = this server, at }`. A server joining while another
-- one still holds a fresh lock waits for its leave save, then takes over; a server that lost the lock never writes.
-- Saves of one player run one at a time and BindToClose waits for every save still running.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local ProfileRules = require(ReplicatedStorage.Shared.Rules.Profile)
local State = require(script.Parent.State)

local DataService = {}

local SERVER_ID = HttpService:GenerateGUID(false) -- JobId is empty in Studio
local LOCK_FIELD = "_lock"

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore unavailable:", result)
	end
end

local busy: { [Player]: boolean } = {}
local inFlight = 0

local function key(player: Player): string
	return "p_" .. player.UserId
end

local function withRetry<T>(fn: () -> T): (boolean, T?)
	for attempt = 1, DataConfig.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[Data] attempt %d failed: %s", attempt, tostring(result)))
		task.wait(DataConfig.RetryDelaySeconds)
	end
	return false, nil
end

local function toProfile(saved: any): State.Profile
	local record = if typeof(saved) == "table" then table.clone(saved) else nil
	if record then
		record[LOCK_FIELD] = nil
	end
	local profile = ProfileRules.merge(State.defaultProfile() :: any, record) :: any
	profile.version = DataConfig.ProfileVersion
	return profile
end

-- Loads and locks the profile. Returns (profile, saveEnabled).
function DataService.load(player: Player): (State.Profile, boolean)
	local currentStore = store
	if currentStore == nil then
		warn("[Data] no DataStore: playing with a fresh profile, saving is OFF")
		return State.defaultProfile(), false
	end
	local deadline = os.clock() + DataConfig.LockWaitSeconds
	while true do
		local outcome: string? = nil
		local loaded: any = nil
		local ok = withRetry(function()
			outcome = nil
			currentStore:UpdateAsync(key(player), function(old: any)
				local now = os.time()
				local record = if typeof(old) == "table" then old else nil
				local lockedByOther = record ~= nil
					and ProfileRules.lockedByOther(
						record[LOCK_FIELD],
						SERVER_ID,
						now,
						DataConfig.LockStaleSeconds
					)
				if lockedByOther and os.clock() < deadline then
					outcome = "locked"
					return nil -- cancels the write
				end
				if lockedByOther then
					warn("[Data] taking over the lock of", player.Name, "from another server")
				end
				loaded = if record then ProfileRules.deepCopy(record) else nil
				local data = record or {}
				data[LOCK_FIELD] = { id = SERVER_ID, at = now }
				outcome = "ok"
				return data, { player.UserId }
			end)
			return true
		end)
		if not ok then
			warn("[Data] load failed for", player.Name, ": saving is OFF this session")
			return State.defaultProfile(), false
		end
		if outcome == "ok" then
			return toProfile(loaded), true
		end
		if not player.Parent then
			return State.defaultProfile(), false
		end
		task.wait(DataConfig.LockRetrySeconds)
	end
end

-- One write; `leaving` frees the lock. Returns true when written.
local function write(currentStore: DataStore, player: Player, leaving: boolean): boolean
	local profile = State.profiles[player]
	local session = State.sessions[player]
	if not profile or not session or not session.saveEnabled then
		return false
	end
	local written, lost = false, false
	local ok = withRetry(function()
		written, lost = false, false
		local data: any = ProfileRules.deepCopy(profile) -- snapshot inside the attempt: a retry saves the newest data
		currentStore:UpdateAsync(key(player), function(old: any)
			local lock = if typeof(old) == "table" then old[LOCK_FIELD] else nil
			if not ProfileRules.ownsLock(lock, SERVER_ID) then
				lost = true
				return nil -- another server took this profile over: never overwrite
			end
			data[LOCK_FIELD] = if leaving then nil else { id = SERVER_ID, at = os.time() }
			written = true
			return data, { player.UserId }
		end)
		return true
	end)
	if lost then
		session.saveEnabled = false
		warn("[Data] lost the lock of", player.Name, ": this server stops saving them")
	end
	return ok and written
end

-- Frees this server's lock without writing the profile (player left during the load, or saving is off).
function DataService.releaseLock(player: Player)
	local currentStore = store
	if currentStore == nil then
		return
	end
	inFlight += 1
	withRetry(function()
		currentStore:UpdateAsync(key(player), function(old: any)
			if typeof(old) ~= "table" or not ProfileRules.ownsLock(old[LOCK_FIELD], SERVER_ID) then
				return nil
			end
			old[LOCK_FIELD] = nil
			return old, { player.UserId }
		end)
		return true
	end)
	inFlight -= 1
end

function DataService.save(player: Player, leaving: boolean): boolean
	local currentStore = store
	local session = State.sessions[player]
	if currentStore == nil or not State.profiles[player] or not session then
		return false
	end
	if not session.saveEnabled then
		if leaving then
			DataService.releaseLock(player)
		end
		return false
	end
	inFlight += 1
	while busy[player] do
		task.wait(0.1)
	end
	busy[player] = true
	local ok, result = pcall(write, currentStore, player, leaving)
	busy[player] = nil
	inFlight -= 1
	if not ok then
		warn("[Data] save error:", result)
		return false
	end
	return result
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player, true)
		end
		-- also waits for saves started before the shutdown (the last player's leave save)
		local deadline = os.clock() + DataConfig.CloseTimeoutSeconds
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
