--!strict
-- Saved profile helpers (pure). Session lock: the saved record carries `_lock = { id, at }`; the server that
-- loaded it owns it and refreshes `at` on every save; the leave save clears it.
local Profile = {}

-- The lock belongs to another live server (fresh = refreshed less than `staleSeconds` ago).
function Profile.lockedByOther(lock: any, serverId: string, now: number, staleSeconds: number): boolean
	if typeof(lock) ~= "table" or typeof(lock.id) ~= "string" or typeof(lock.at) ~= "number" then
		return false
	end
	return lock.id ~= serverId and now - lock.at < staleSeconds
end

-- This server still owns the saved profile (it may write it).
function Profile.ownsLock(lock: any, serverId: string): boolean
	return typeof(lock) == "table" and lock.id == serverId
end

-- Deep copy (a save snapshot must not share tables with the live profile).
function Profile.deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = Profile.deepCopy(v)
	end
	return copy :: any
end

-- Fills a loaded record into a default profile: known fields of the same type win, unknown fields (saved by a
-- newer server) are kept so they survive this server's saves. Nested tables are merged one level deep.
function Profile.merge(default: { [string]: any }, saved: any): { [string]: any }
	local profile = Profile.deepCopy(default)
	if typeof(saved) ~= "table" then
		return profile
	end
	for field, value in saved do
		local base = profile[field]
		if base == nil then
			profile[field] = Profile.deepCopy(value)
		elseif typeof(value) == typeof(base) then
			if typeof(value) == "table" and next(base) ~= nil and #base == 0 then
				-- dictionary with defaults (e.g. upgrade levels): keep defaults for missing keys
				for k, v in value do
					if base[k] == nil or typeof(v) == typeof(base[k]) then
						base[k] = Profile.deepCopy(v)
					end
				end
			else
				profile[field] = Profile.deepCopy(value)
			end
		end
	end
	return profile
end

return Profile
