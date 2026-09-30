-- Minimal test harness for pure Luau modules (runs with the `luau` CLI).
local TestRunner = {}

local results = { passed = 0, failed = 0, failures = {} }

function TestRunner.describe(name, fn)
	fn(function(caseName, body)
		local ok, err = pcall(body)
		if ok then
			results.passed += 1
		else
			results.failed += 1
			table.insert(results.failures, name .. " > " .. caseName .. ": " .. tostring(err))
		end
	end)
end

function TestRunner.expectEqual(actual, expected, message)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(message and (message .. ": ") or "", tostring(expected), tostring(actual)), 2)
	end
end

function TestRunner.expectNear(actual, expected, epsilon, message)
	if math.abs(actual - expected) > (epsilon or 1e-6) then
		error(("%sexpected ~%s, got %s"):format(message and (message .. ": ") or "", tostring(expected), tostring(actual)), 2)
	end
end

function TestRunner.expectTrue(value, message)
	if not value then
		error(message or "expected true", 2)
	end
end

function TestRunner.finish()
	for _, failure in ipairs(results.failures) do
		print("FAIL " .. failure)
	end
	print(("%d passed, %d failed"):format(results.passed, results.failed))
	return results.failed == 0
end

return TestRunner
