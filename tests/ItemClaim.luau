--!strict
local ItemClaim = require("../src/shared/Rules/ItemClaim")

return {
	onlyFirstPlayerClaims = function()
		local c = ItemClaim.new()
		assert(ItemClaim.tryClaim(c, "key1", 1))
		assert(not ItemClaim.tryClaim(c, "key1", 2))
		assert(not ItemClaim.tryClaim(c, "key1", 1))
	end,
	differentItemsAreIndependent = function()
		local c = ItemClaim.new()
		assert(ItemClaim.tryClaim(c, "key1", 1))
		assert(ItemClaim.tryClaim(c, "key2", 2))
	end,
}
