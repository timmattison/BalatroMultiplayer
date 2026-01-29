#!/usr/bin/env lua
-- Tests that prove the buggy versions crash (validates test effectiveness)
-- These tests SHOULD FAIL - they run the original buggy code
-- Run with: lua tests/test-nil-table-keys-buggy.lua

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

print("\n" .. string.rep("=", 60))
print("RUNNING BUGGY CODE - THESE TESTS SHOULD FAIL")
print("Validates that our tests catch nil-as-table-key bugs")
print(string.rep("=", 60) .. "\n")

-- Buggy implementations

local function gambling_sandbox_count_rares_BUGGY(jokers_cards)
	local rares_owned = { 0 }
	for k, v in ipairs(jokers_cards) do
		-- BUGGY: No nil checks
		if v.config.center.rarity == 3 and not rares_owned[v.config.center.key] then
			rares_owned[1] = rares_owned[1] + 1
			rares_owned[v.config.center.key] = true
		end
	end
	return rares_owned
end

local function smallworld_get_rarity_BUGGY(centers, joker)
	local rarities = { [1] = 0, [2] = 0.9, [3] = 1, [4] = 1 }
	-- BUGGY: No nil checks
	return rarities[centers[joker].rarity] or centers[joker].rarity
end

local function polymorph_get_limit_BUGGY(area)
	-- BUGGY: No nil check
	return area.config.card_limit
end

local function polymorph_get_pool_BUGGY(pools, card)
	-- BUGGY: No nil checks
	return pools[card.config.center.set]
end

-- Tests (should all fail)

print("=== BUGGY gambling_sandbox.lua Tests ===\n")

test("BUGGY gambling_sandbox: joker with nil config", function()
	local jokers = { { config = nil } }
	assert_no_throw(function()
		gambling_sandbox_count_rares_BUGGY(jokers)
	end)
end)

test("BUGGY gambling_sandbox: joker with nil center", function()
	local jokers = { { config = { center = nil } } }
	assert_no_throw(function()
		gambling_sandbox_count_rares_BUGGY(jokers)
	end)
end)

print("\n=== BUGGY smallworld.lua Tests ===\n")

test("BUGGY smallworld: missing joker in centers", function()
	local centers = {}
	assert_no_throw(function()
		smallworld_get_rarity_BUGGY(centers, "j_missing")
	end)
end)

print("\n=== BUGGY polymorph_spam.lua Tests ===\n")

test("BUGGY polymorph: nil area", function()
	assert_no_throw(function()
		polymorph_get_limit_BUGGY(nil)
	end)
end)

test("BUGGY polymorph: card with nil config on pool lookup", function()
	local pools = { Joker = {} }
	assert_no_throw(function()
		polymorph_get_pool_BUGGY(pools, { config = nil })
	end)
end)

-- Print summary
print("\n" .. string.rep("=", 60))
print("TEST SUMMARY")
print(string.rep("=", 60))
print(string.format("\nTotal: %d, Passed: %d, Failed: %d", tests_run, tests_passed, tests_failed))

if tests_failed > 0 then
	print("\n*** SUCCESS: " .. tests_failed .. " tests failed as expected! ***")
	print("This proves the tests catch these nil-as-table-key bugs.\n")
	print("Failed tests (expected):")
	for _, t in ipairs(failed_tests) do
		print("  - " .. t.name)
	end
	os.exit(0)  -- Exit 0 because failures are expected
else
	print("\n*** UNEXPECTED: All tests passed! ***")
	print("The buggy code should have failed these tests.\n")
	os.exit(1)
end
