--!strict
local EscapePath = require("../src/shared/Rules/EscapePath")

local path = { { 0, 0 }, { 0, -10 }, { 10, -10 } }

return {
	lengthSumsSegments = function()
		assert(EscapePath.length(path) == 20)
	end,
	pointAtStartIsFirst = function()
		local p = EscapePath.pointAt(path, 0)
		assert(p[1] == 0 and p[2] == 0)
	end,
	pointAtMiddleOfSecondSegment = function()
		local p = EscapePath.pointAt(path, 15)
		assert(p[1] == 5 and p[2] == -10)
	end,
	pointAtPastTheEndIsLast = function()
		local p = EscapePath.pointAt(path, 99)
		assert(p[1] == 10 and p[2] == -10)
	end,
	negativeDistanceIsFirst = function()
		local p = EscapePath.pointAt(path, -5)
		assert(p[1] == 0 and p[2] == 0)
	end,
}
