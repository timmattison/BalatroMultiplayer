#!/usr/bin/env lua
-- Tests for nil-as-table-key bugs (similar to Cryptid thalia joker bug)
-- Pattern: Using potentially nil values as table keys causes "table index is nil" crash
-- Run with: lua tests/test-nil-table-keys.lua

local tests_run = 0
local tests_passed = 0
local tests_failed = 0
local failed_tests = {}

local function test(name, fn)
	tests_run = tests_run + 1
	local success, err = pcall(fn)
	if success then
		tests_passed = tests_passed + 1
		print("✓ " .. name)
	else
		tests_failed = tests_failed + 1
		table.insert(failed_tests, { name = name, error = err })
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

local function assert_no_throw(fn, msg)
	local success, err = pcall(fn)
	if not success then
		error((msg or "Assertion failed") .. ": expected function not to throw, but got: " .. tostring(err))
	end
end

local function assert_eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end

print("\n=== Nil Table Key Bug Tests ===\n")
print("Pattern: Using nil as table key causes 'table index is nil' crash")
print("Similar to Cryptid commit 583ae39 (thalia joker fix)\n")

-- ================================================
-- Test: gambling_sandbox.lua rares_owned tracking
-- Bug: Uses v.config.center.rarity and v.config.center.key without nil checks
-- ================================================

print("=== gambling_sandbox.lua Tests ===\n")

local function gambling_sandbox_count_rares_FIXED(jokers_cards)
	local rares_owned = { 0 }
	for k, v in ipairs(jokers_cards) do
		-- FIXED: Check entire chain before using as table key
		local rarity = v.config and v.config.center and v.config.center.rarity
		local key = v.config and v.config.center and v.config.center.key
		if rarity == 3 and key and not rares_owned[key] then
			rares_owned[1] = rares_owned[1] + 1
			rares_owned[key] = true
		end
	end
	return rares_owned
end

local function gambling_sandbox_count_rares_BUGGY(jokers_cards)
	local rares_owned = { 0 }
	for k, v in ipairs(jokers_cards) do
		-- BUGGY: No nil checks - crashes if config/center/rarity/key is nil
		if v.config.center.rarity == 3 and not rares_owned[v.config.center.key] then
			rares_owned[1] = rares_owned[1] + 1
			rares_owned[v.config.center.key] = true
		end
	end
	return rares_owned
end

test("gambling_sandbox: joker with nil config doesn't crash (fixed)", function()
	local jokers = { { config = nil } }
	assert_no_throw(function()
		gambling_sandbox_count_rares_FIXED(jokers)
	end)
end)

test("gambling_sandbox: joker with nil config.center doesn't crash (fixed)", function()
	local jokers = { { config = { center = nil } } }
	assert_no_throw(function()
		gambling_sandbox_count_rares_FIXED(jokers)
	end)
end)

test("gambling_sandbox: joker with nil rarity doesn't crash (fixed)", function()
	local jokers = { { config = { center = { rarity = nil, key = "j_test" } } } }
	assert_no_throw(function()
		gambling_sandbox_count_rares_FIXED(jokers)
	end)
end)

test("gambling_sandbox: joker with nil key doesn't use nil as table key (fixed)", function()
	local jokers = { { config = { center = { rarity = 3, key = nil } } } }
	assert_no_throw(function()
		local result = gambling_sandbox_count_rares_FIXED(jokers)
		-- Should not count this joker since key is nil
		assert_eq(result[1], 0, "should not count joker with nil key")
	end)
end)

test("gambling_sandbox: normal rare joker is counted correctly", function()
	local jokers = { { config = { center = { rarity = 3, key = "j_rare_test" } } } }
	local result = gambling_sandbox_count_rares_FIXED(jokers)
	assert_eq(result[1], 1, "should count one rare joker")
	assert_eq(result["j_rare_test"], true, "should mark joker as owned")
end)

-- ================================================
-- Test: smallworld.lua rarity lookup
-- Bug: Uses G.P_CENTERS[joker].rarity without checking if entry exists
-- ================================================

print("\n=== smallworld.lua Tests ===\n")

local function smallworld_get_rarity_FIXED(centers, joker)
	local rarities = { [1] = 0, [2] = 0.9, [3] = 1, [4] = 1 }
	-- FIXED: Check if center exists and has rarity
	local center = centers[joker]
	if not center then return nil end
	local rarity = center.rarity
	if not rarity then return nil end
	return rarities[rarity] or rarity
end

local function smallworld_get_rarity_BUGGY(centers, joker)
	local rarities = { [1] = 0, [2] = 0.9, [3] = 1, [4] = 1 }
	-- BUGGY: No nil checks - crashes if centers[joker] or .rarity is nil
	return rarities[centers[joker].rarity] or centers[joker].rarity
end

test("smallworld: missing joker in centers doesn't crash (fixed)", function()
	local centers = {}  -- joker not in table
	assert_no_throw(function()
		smallworld_get_rarity_FIXED(centers, "j_missing")
	end)
end)

test("smallworld: joker with nil rarity doesn't crash (fixed)", function()
	local centers = { j_test = { set = "Joker", rarity = nil } }
	assert_no_throw(function()
		smallworld_get_rarity_FIXED(centers, "j_test")
	end)
end)

test("smallworld: normal joker rarity lookup works", function()
	local centers = { j_test = { set = "Joker", rarity = 2 } }
	local result = smallworld_get_rarity_FIXED(centers, "j_test")
	assert_eq(result, 0.9, "rarity 2 should map to 0.9")
end)

-- ================================================
-- Test: polymorph_spam.lua area.config access
-- Bug: Uses area.config.card_limit without checking area exists
-- ================================================

print("\n=== polymorph_spam.lua Tests ===\n")

local function polymorph_get_limit_FIXED(area)
	-- FIXED: Check area and area.config before accessing
	if not area or not area.config then return nil end
	return area.config.card_limit
end

local function polymorph_get_limit_BUGGY(area)
	-- BUGGY: No nil check for area
	return area.config.card_limit
end

test("polymorph: nil area doesn't crash (fixed)", function()
	assert_no_throw(function()
		polymorph_get_limit_FIXED(nil)
	end)
end)

test("polymorph: area with nil config doesn't crash (fixed)", function()
	assert_no_throw(function()
		polymorph_get_limit_FIXED({ config = nil })
	end)
end)

test("polymorph: normal area returns card_limit", function()
	local area = { config = { card_limit = 5 } }
	local result = polymorph_get_limit_FIXED(area)
	assert_eq(result, 5, "should return card_limit")
end)

-- ================================================
-- Test: polymorph_spam.lua center.set as table key
-- Bug: Uses card.config.center.set as key for G.P_CENTER_POOLS lookup
-- ================================================

local function polymorph_get_pool_FIXED(pools, card)
	-- FIXED: Check chain before using as table key
	if not card or not card.config or not card.config.center then return nil end
	local set = card.config.center.set
	if not set then return nil end
	return pools[set]
end

local function polymorph_get_pool_BUGGY(pools, card)
	-- BUGGY: No nil checks - crashes if chain is broken or set is nil
	return pools[card.config.center.set]
end

test("polymorph: card with nil config doesn't crash on pool lookup (fixed)", function()
	local pools = { Joker = {} }
	assert_no_throw(function()
		polymorph_get_pool_FIXED(pools, { config = nil })
	end)
end)

test("polymorph: card with nil set doesn't use nil as table key (fixed)", function()
	local pools = { Joker = {} }
	assert_no_throw(function()
		polymorph_get_pool_FIXED(pools, { config = { center = { set = nil } } })
	end)
end)

test("polymorph: normal card returns correct pool", function()
	local pools = { Joker = { "j_joker" } }
	local card = { config = { center = { set = "Joker" } } }
	local result = polymorph_get_pool_FIXED(pools, card)
	assert_eq(result[1], "j_joker", "should return Joker pool")
end)

-- Print summary
print("\n=== Test Summary ===\n")
print(string.format("Total: %d, Passed: %d, Failed: %d", tests_run, tests_passed, tests_failed))

if tests_failed > 0 then
	print("\nFailed tests:")
	for _, t in ipairs(failed_tests) do
		print("  - " .. t.name)
	end
	os.exit(1)
else
	print("\nAll tests passed!")
	os.exit(0)
end
