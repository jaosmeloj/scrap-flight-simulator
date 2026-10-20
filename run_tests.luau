-- Roda todos os testes das Rules fora do Roblox: `lune run run_tests`
-- Para adicionar um teste: crie tests/<Nome>.spec.luau e inclua na lista abaixo.
local specs = {
	"Upgrades",
	"Flight",
	"Lanes",
	"Customize",
	"FlightSim",
	"Profile",
}

local failures = 0
local total = 0

local function check(name: string, ok: boolean)
	total += 1
	if ok then
		print("  ok   " .. name)
	else
		failures += 1
		print("  FALHOU " .. name)
	end
end

for _, spec in specs do
	print("[" .. spec .. "]")
	local run = require("./tests/" .. spec .. ".spec")
	run(check)
end

print(string.format("%d/%d testes passaram", total - failures, total))
if failures > 0 then
	error("testes falharam")
end
