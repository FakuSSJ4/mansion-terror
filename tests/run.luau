--!strict
-- Corre con: lune run tests/run
local process = require("@lune/process")

local suites = {
	MapGraph = require("./MapGraph"),
	Progress = require("./Progress"),
}

local failed = 0
local total = 0
for suiteName, suite in suites :: any do
	for testName, test in suite :: any do
		total += 1
		local ok, err = pcall(test)
		if not ok then
			failed += 1
			print(`FAIL {suiteName}.{testName}: {err}`)
		end
	end
end

print(`{total - failed}/{total} pruebas pasaron`)
process.exit(if failed == 0 then 0 else 1)
