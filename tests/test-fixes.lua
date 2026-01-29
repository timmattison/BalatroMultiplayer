#!/usr/bin/env lua
-- Unit tests for specific bug fixes
-- Run with: lua tests/test-fixes.lua

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

local function assert_true(val, msg)
	if not val then
		error((msg or "Assertion failed") .. ": expected true, got " .. tostring(val))
	end
end

local function assert_not_nil(val, msg)
	if val == nil then
		error((msg or "Assertion failed") .. ": expected non-nil value")
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

-- ================================================
-- Test: reset_mail_rank sort using count_map properly
-- Bug: The original code stored count = 0 in valid_ranks entries,
-- then the sort compared a.count to b.count (always 0 vs 0).
-- Fix: Sort should look up actual counts from count_map.
-- ================================================

print("\n=== reset_mail_rank Sort Fix Tests ===\n")

local function test_reset_mail_rank_sort()
	-- Simulate the fixed sort logic
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

	-- FIXED sort: Uses count_map to get actual counts
	table.sort(valid_ranks, function(a, b)
		local a_count = count_map[a.value].count
		local b_count = count_map[b.value].count
		if a_count ~= b_count then return a_count > b_count end
		return value_order[a.value] < value_order[b.value]
	end)

	return valid_ranks
end

local function test_reset_mail_rank_sort_buggy()
	-- Simulate the BUGGY sort logic (for comparison)
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

	-- BUGGY sort: Uses a.count directly (always 0)
	table.sort(valid_ranks, function(a, b)
		if a.count ~= b.count then return a.count > b.count end  -- Always false since both are 0
		return value_order[a.value] < value_order[b.value]
	end)

	return valid_ranks
end

test("reset_mail_rank: fixed sort orders by count descending", function()
	local result = test_reset_mail_rank_sort()
	-- Ace has count 4, should be first
	assert_eq(result[1].value, "Ace", "Highest count should be first")
	-- Jack has count 3, should be second
	assert_eq(result[2].value, "Jack", "Second highest count should be second")
	-- King has count 2, should be third
	assert_eq(result[3].value, "King", "Third highest count should be third")
	-- Queen has count 1, should be last
	assert_eq(result[4].value, "Queen", "Lowest count should be last")
end)

test("reset_mail_rank: buggy sort ignores counts", function()
	local result = test_reset_mail_rank_sort_buggy()
	-- Buggy version only sorts by value_order since all counts are 0
	-- Jack=10, Queen=11, King=12, Ace=13 in value_order
	assert_eq(result[1].value, "Jack", "Buggy sort uses value order for first")
	assert_eq(result[4].value, "Ace", "Buggy sort puts Ace last (highest value_order)")
end)

test("reset_mail_rank: fixed vs buggy produces different results", function()
	local fixed = test_reset_mail_rank_sort()
	local buggy = test_reset_mail_rank_sort_buggy()
	-- They should be different
	local same = true
	for i = 1, 4 do
		if fixed[i].value ~= buggy[i].value then
			same = false
			break
		end
	end
	assert_true(not same, "Fixed and buggy sorts should produce different orderings")
end)

-- ================================================
-- Test: get_bp() with empty jokers (BB_gradient.lua)
-- Bug: j_brainstorm accessed G.jokers.cards[1] without checking if empty
-- Fix: Return "NULL" if no jokers exist
-- ================================================

print("\n=== get_bp Empty Jokers Tests ===\n")

-- Mock G for get_bp tests
local mock_G_jokers = { cards = {} }

local function mock_get_bp(joker, jokers_cards)
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
			-- FIXED: Check if jokers.cards[1] exists
			if not jokers_cards[1] then return "NULL" end
			key = jokers_cards[1].config.center.key
			pos = 1
		end
		count = count + 1
	end
	return key
end

local function mock_get_bp_buggy(joker, jokers_cards)
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
			-- BUGGY: No check for empty cards
			key = jokers_cards[1].config.center.key  -- Would crash if cards is empty
			pos = 1
		end
		count = count + 1
	end
	return key
end

test("get_bp: brainstorm with empty jokers returns NULL (fixed)", function()
	local brainstorm = { config = { center = { key = "j_brainstorm" } } }
	local result = mock_get_bp(brainstorm, {})
	assert_eq(result, "NULL", "Brainstorm with no jokers should return NULL")
end)

test("get_bp: brainstorm with jokers returns first joker key", function()
	local brainstorm = { config = { center = { key = "j_brainstorm" } } }
	local first_joker = { config = { center = { key = "j_mime" } } }
	local result = mock_get_bp(brainstorm, { first_joker })
	assert_eq(result, "j_mime", "Brainstorm should copy first joker")
end)

test("get_bp: blueprint at end of list returns NULL", function()
	local blueprint = { config = { center = { key = "j_blueprint" } } }
	local result = mock_get_bp(blueprint, { blueprint })
	assert_eq(result, "NULL", "Blueprint at end with no joker to right should return NULL")
end)

-- ================================================
-- Test: CorePreview cardarea.cards[1] access
-- Bug: Accessed cardarea.cards[1].ability.set without checking if cards[1] exists
-- Fix: Check cardarea.cards[1] before accessing its properties
-- ================================================

print("\n=== CorePreview Empty Cardarea Tests ===\n")

local function mock_update_on_card_order_change_fixed(cardarea)
	local prev_order = nil
	-- FIXED: Check cardarea.cards[1] exists before accessing ability.set
	if cardarea.config.type == "joker" and cardarea.cards[1] and cardarea.cards[1].ability.set == "Joker" then
		prev_order = "joker_order"
	elseif cardarea.config.type == "hand" then
		prev_order = "hand_order"
	else
		return nil
	end
	return prev_order
end

local function mock_update_on_card_order_change_buggy(cardarea)
	local prev_order = nil
	-- BUGGY: No check for cardarea.cards[1]
	if cardarea.config.type == "joker" and cardarea.cards[1].ability.set == "Joker" then
		prev_order = "joker_order"
	elseif cardarea.config.type == "hand" then
		prev_order = "hand_order"
	else
		return nil
	end
	return prev_order
end

test("CorePreview: empty joker cardarea doesn't crash (fixed)", function()
	local cardarea = { config = { type = "joker" }, cards = {} }
	assert_no_throw(function()
		mock_update_on_card_order_change_fixed(cardarea)
	end)
end)

test("CorePreview: joker cardarea with jokers works", function()
	local cardarea = {
		config = { type = "joker" },
		cards = { { ability = { set = "Joker" } } }
	}
	local result = mock_update_on_card_order_change_fixed(cardarea)
	assert_eq(result, "joker_order")
end)

test("CorePreview: hand cardarea works", function()
	local cardarea = { config = { type = "hand" }, cards = {} }
	local result = mock_update_on_card_order_change_fixed(cardarea)
	assert_eq(result, "hand_order")
end)

-- ================================================
-- Test: polymorph_spam get_area() and get_pos()
-- Bug: get_area() didn't check card.config and card.config.center
-- Bug: get_pos() didn't check if get_area() returned nil
-- ================================================

print("\n=== polymorph_spam Nil Check Tests ===\n")

-- Mock globals
local mock_G_jokers_pool = { cards = {} }
local mock_G_consumeables = { cards = {} }

local function mock_get_area_fixed(card)
	if not card or not card.config or not card.config.center then return nil end
	if card.config.center.set == "Joker" then
		return mock_G_jokers_pool
	elseif card.config.center.consumeable then
		return mock_G_consumeables
	end
	return nil
end

local function mock_get_area_buggy(card)
	if not card then return nil end
	-- BUGGY: No check for card.config or card.config.center
	if card.config.center.set == "Joker" then
		return mock_G_jokers_pool
	elseif card.config.center.consumeable then
		return mock_G_consumeables
	end
	return nil
end

local function mock_get_pos_fixed(card, get_area_fn)
	local area = get_area_fn(card)
	if not area or not area.cards then return nil end
	for i, v in ipairs(area.cards) do
		if card == v then return i end
	end
	return nil
end

local function mock_get_pos_buggy(card, get_area_fn)
	local area = get_area_fn(card)
	-- BUGGY: No check if area is nil
	for i, v in ipairs(area.cards) do
		if card == v then return i end
	end
	return nil
end

test("get_area: card with nil config returns nil (fixed)", function()
	local card = { config = nil }
	local result = mock_get_area_fixed(card)
	assert_nil(result)
end)

test("get_area: card with nil config.center returns nil (fixed)", function()
	local card = { config = { center = nil } }
	local result = mock_get_area_fixed(card)
	assert_nil(result)
end)

test("get_area: joker card returns joker pool", function()
	local card = { config = { center = { set = "Joker" } } }
	local result = mock_get_area_fixed(card)
	assert_eq(result, mock_G_jokers_pool)
end)

test("get_area: consumeable card returns consumeables pool", function()
	local card = { config = { center = { consumeable = true } } }
	local result = mock_get_area_fixed(card)
	assert_eq(result, mock_G_consumeables)
end)

test("get_pos: nil area doesn't crash (fixed)", function()
	local card = { config = nil }  -- Will make get_area return nil
	assert_no_throw(function()
		mock_get_pos_fixed(card, mock_get_area_fixed)
	end)
end)

test("get_pos: area with nil cards doesn't crash (fixed)", function()
	local custom_get_area = function(card) return { cards = nil } end
	local card = {}
	assert_no_throw(function()
		mock_get_pos_fixed(card, custom_get_area)
	end)
end)

test("get_pos: finds card in area", function()
	local card = { config = { center = { set = "Joker" } } }
	mock_G_jokers_pool.cards = { card }
	local result = mock_get_pos_fixed(card, mock_get_area_fixed)
	assert_eq(result, 1)
	mock_G_jokers_pool.cards = {}  -- Reset
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
