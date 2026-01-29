#!/usr/bin/env lua
-- This test file runs the BUGGY versions of the code to demonstrate
-- that the tests would have caught these bugs before the fixes.
-- Expected result: These tests should FAIL, proving the tests are effective.

-- Simple test framework
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

local function assert_eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end

local function assert_nil(val, msg)
	if val ~= nil then
		error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(val))
	end
end

local function assert_no_throw(fn, msg)
	local success, err = pcall(fn)
	if not success then
		error((msg or "Assertion failed") .. ": expected function not to throw, but got: " .. tostring(err))
	end
end

print("\n" .. string.rep("=", 60))
print("RUNNING BUGGY CODE VERSIONS - THESE TESTS SHOULD FAIL")
print(string.rep("=", 60))

-- ================================================
-- BUG 1: reset_mail_rank sort using a.count (always 0)
-- ================================================

print("\n=== BUG 1: reset_mail_rank Sort (BUGGY VERSION) ===\n")

local function test_reset_mail_rank_sort_BUGGY()
	local count_map = {
		["Ace"] = { count = 4, example_card = { base = { value = "Ace", id = 14 } } },
		["King"] = { count = 2, example_card = { base = { value = "King", id = 13 } } },
		["Queen"] = { count = 1, example_card = { base = { value = "Queen", id = 12 } } },
		["Jack"] = { count = 3, example_card = { base = { value = "Jack", id = 11 } } },
	}

	local value_order = {}
	local ranks = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace" }
	for i, rank in ipairs(ranks) do
		value_order[rank] = i
	end

	local valid_ranks = {}
	for val, data in pairs(count_map) do
		table.insert(valid_ranks, { value = val, count = 0, example_card = data.example_card })
	end

	-- BUGGY: Uses a.count directly (always 0) instead of count_map[a.value].count
	table.sort(valid_ranks, function(a, b)
		if a.count ~= b.count then return a.count > b.count end  -- Always false!
		return value_order[a.value] < value_order[b.value]
	end)

	return valid_ranks
end

test("BUGGY reset_mail_rank: should order by count (Ace first with count=4)", function()
	local result = test_reset_mail_rank_sort_BUGGY()
	-- This SHOULD fail because buggy version ignores counts
	assert_eq(result[1].value, "Ace", "Highest count (4) should be first")
end)

-- ================================================
-- BUG 2: get_bp() crashes with empty jokers for brainstorm
-- ================================================

print("\n=== BUG 2: get_bp Empty Jokers (BUGGY VERSION) ===\n")

local function mock_get_bp_BUGGY(joker, jokers_cards)
	local key = joker.config.center.key
	local count = 0
	local pos = 0
	for i, v in ipairs(jokers_cards) do
		if v == joker then pos = i end
	end
	while (key == "j_blueprint" or key == "j_brainstorm") and count <= #jokers_cards do
		if key == "j_blueprint" then
			key = jokers_cards[pos + 1] and jokers_cards[pos + 1].config.center.key or "NULL"
			pos = pos + 1
		elseif key == "j_brainstorm" then
			-- BUGGY: No nil check - crashes if jokers_cards is empty!
			key = jokers_cards[1].config.center.key
			pos = 1
		end
		count = count + 1
	end
	return key
end

test("BUGGY get_bp: brainstorm with empty jokers should not crash", function()
	local brainstorm = { config = { center = { key = "j_brainstorm" } } }
	-- This SHOULD fail because buggy version crashes on empty array
	assert_no_throw(function()
		mock_get_bp_BUGGY(brainstorm, {})
	end)
end)

-- ================================================
-- BUG 3: CorePreview crashes on empty cardarea.cards
-- ================================================

print("\n=== BUG 3: CorePreview Empty Cardarea (BUGGY VERSION) ===\n")

local function mock_update_on_card_order_change_BUGGY(cardarea)
	local prev_order = nil
	-- BUGGY: No check for cardarea.cards[1] before accessing .ability.set
	if cardarea.config.type == "joker" and cardarea.cards[1].ability.set == "Joker" then
		prev_order = "joker_order"
	elseif cardarea.config.type == "hand" then
		prev_order = "hand_order"
	else
		return nil
	end
	return prev_order
end

test("BUGGY CorePreview: empty joker cardarea should not crash", function()
	local cardarea = { config = { type = "joker" }, cards = {} }
	-- This SHOULD fail because buggy version crashes on cards[1] access
	assert_no_throw(function()
		mock_update_on_card_order_change_BUGGY(cardarea)
	end)
end)

-- ================================================
-- BUG 4: polymorph_spam get_area() missing nil checks
-- ================================================

print("\n=== BUG 4: polymorph_spam get_area (BUGGY VERSION) ===\n")

local function mock_get_area_BUGGY(card)
	if not card then return nil end
	-- BUGGY: No check for card.config or card.config.center
	if card.config.center.set == "Joker" then
		return { cards = {} }
	elseif card.config.center.consumeable then
		return { cards = {} }
	end
	return nil
end

test("BUGGY get_area: card with nil config should not crash", function()
	local card = { config = nil }
	-- This SHOULD fail because buggy version crashes on nil config
	assert_no_throw(function()
		mock_get_area_BUGGY(card)
	end)
end)

test("BUGGY get_area: card with nil config.center should not crash", function()
	local card = { config = { center = nil } }
	-- This SHOULD fail because buggy version crashes on nil center
	assert_no_throw(function()
		mock_get_area_BUGGY(card)
	end)
end)

-- ================================================
-- BUG 5: polymorph_spam get_pos() doesn't handle nil area
-- ================================================

print("\n=== BUG 5: polymorph_spam get_pos (BUGGY VERSION) ===\n")

local function mock_get_pos_BUGGY(card, get_area_fn)
	local area = get_area_fn(card)
	-- BUGGY: No check if area is nil before iterating
	for i, v in ipairs(area.cards) do
		if card == v then return i end
	end
	return nil
end

test("BUGGY get_pos: nil area should not crash", function()
	local get_nil_area = function(card) return nil end
	local card = {}
	-- This SHOULD fail because buggy version crashes on nil.cards
	assert_no_throw(function()
		mock_get_pos_BUGGY(card, get_nil_area)
	end)
end)

-- Print summary
print("\n" .. string.rep("=", 60))
print("TEST SUMMARY")
print(string.rep("=", 60))
print(string.format("\nTotal: %d, Passed: %d, Failed: %d", tests_run, tests_passed, tests_failed))

if tests_failed > 0 then
	print("\n*** SUCCESS: " .. tests_failed .. " tests failed as expected! ***")
	print("This proves the tests would have caught these bugs.\n")
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
