--!strict
-- Saving.
local Data = {
	StoreName = "ScrapFlightSimulator_v1", -- never rename once live: the saves are in this store
	Retries = 3,
	RetryDelaySeconds = 1,
	AutosaveSeconds = 60,

	-- Session lock: the profile is owned by the server that loaded it (saves refresh it, the leave save frees it).
	LockStaleSeconds = 180, -- a lock not refreshed for this long belongs to a dead server: take it over
	LockWaitSeconds = 30, -- joining while another server still holds the lock: wait this long
	LockRetrySeconds = 4,
	CloseTimeoutSeconds = 25, -- BindToClose waits this long for every save to finish

	ProfileVersion = 1,
}

return Data
