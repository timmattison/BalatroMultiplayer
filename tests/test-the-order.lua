#!/usr/bin/env lua
-- Unit tests for TheOrder.lua edge cases
-- Run with: lua tests/test-the-order.lua

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

local function assert_throws(fn, msg)
	local success, _ = pcall(fn)
	if success then
		error((msg or "Assertion failed") .. ": expected function to throw an error")
	end
end

local function assert_no_throw(fn, msg)
	local success, err = pcall(fn)
	if not success then
		error((msg or "Assertion failed") .. ": expected function not to throw, but got: " .. tostring(err))
	end
end

-- Setup mock globals
MP = {
	UTILS = {},
	should_use_the_order = function() return true end
}
G = {
	GAME = {
		round_resets = { ante = 1 },
		hands = {},
		blind = { config = { blind = { key = "test" } } }
	}
}
SMODS = {
	Rank = { obj_buffer = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace" } },
	Suit = { obj_buffer = { "Spades", "Hearts", "Clubs", "Diamonds" } }
}

-- Mock pseudorandom function
local seed_counter = 0
function pseudorandom(seed)
	seed_counter = seed_counter + 1
	-- Return deterministic value based on seed
	if type(seed) == "string" then
		local sum = 0
		for i = 1, #seed do
			sum = sum + string.byte(seed, i)
		end
		return (sum % 100) / 100
	end
	return 0.5
end

function pseudoseed(name)
	return name .. "_seed"
end

-- Original function placeholder
local function orig_pseudorandom_element(_t, seed, args)
	-- Simple implementation: return first element
	for k, v in pairs(_t) do
		return v, k
	end
	return nil, nil
end

-- Load string utils (dependency)
dofile("lib/string_utils.lua")

print("\n=== TheOrder.lua Edge Case Tests ===\n")

-- Test the pseudorandom_element logic directly
-- Simulating the function from TheOrder.lua

local function test_pseudorandom_element(_t, seed, args)
	if MP.should_use_the_order() then
		local is_joker = true
		for k, v in pairs(_t) do
			if not (type(v) == "table" and v.ability and v.ability.set == "Joker") then
				is_joker = false
				break
			end
		end
		if is_joker then
			local tables = {}
			local keys = {}
			for k, v in pairs(_t) do
				keys[#keys + 1] = { k = k, v = v }
				-- Safely access nested key, fall back to original function if missing
				if not v.config or not v.config.center then
					return orig_pseudorandom_element(_t, seed, args)
				end
				local key = v.config.center.key
				tables[key] = tables[key] or {}
				tables[key][#tables[key] + 1] = v
			end
			local true_seed = pseudorandom(seed or math.random())
			for k, v in pairs(tables) do
				table.sort(v, function(a, b)
					-- Handle nil sort_id by treating nil as 0
					local a_sort = a.sort_id or 0
					local b_sort = b.sort_id or 0
					return a_sort < b_sort
				end)
				local mega_seed = k .. true_seed
				for i, card in ipairs(v) do
					card.mp_shuffleval = pseudorandom(mega_seed)
				end
			end

			table.sort(keys, function(a, b)
				return a.v.mp_shuffleval > b.v.mp_shuffleval
			end)

			-- Handle empty table case to avoid nil access
			if #keys == 0 then
				return orig_pseudorandom_element(_t, seed, args)
			end

			local key = keys[1].k
			return _t[key], key
		end
	end
	return orig_pseudorandom_element(_t, seed, args)
end

-- Helper to create mock joker
local function make_joker(id, center_key, sort_id)
	return {
		ability = { set = "Joker" },
		config = { center = { key = center_key } },
		sort_id = sort_id  -- explicitly allow nil for testing
	}
end

test("pseudorandom_element: empty table returns nil (after fix)", function()
	local result, key = test_pseudorandom_element({}, "test_seed")
	-- Should not crash, should return nil from orig function
	assert_eq(result, nil)
	assert_eq(key, nil)
end)

test("pseudorandom_element: single joker works", function()
	local joker = make_joker(1, "j_joker", 1)
	local t = { [1] = joker }
	local result, key = test_pseudorandom_element(t, "test_seed")
	assert_not_nil(result)
	assert_eq(key, 1)
end)

test("pseudorandom_element: multiple jokers of same type", function()
	local t = {
		[1] = make_joker(1, "j_joker", 1),
		[2] = make_joker(2, "j_joker", 2),
	}
	local result, key = test_pseudorandom_element(t, "test_seed")
	assert_not_nil(result)
end)

test("pseudorandom_element: different joker types", function()
	local t = {
		[1] = make_joker(1, "j_joker", 1),
		[2] = make_joker(2, "j_mime", 2),
	}
	local result, key = test_pseudorandom_element(t, "test_seed")
	assert_not_nil(result)
end)

test("pseudorandom_element: joker with nil config falls back gracefully", function()
	local bad_joker = {
		ability = { set = "Joker" },
		config = nil,  -- Missing config
		sort_id = 1
	}
	local t = { [1] = bad_joker }
	-- Should fall back to orig function, not crash
	assert_no_throw(function()
		test_pseudorandom_element(t, "test_seed")
	end)
end)

test("pseudorandom_element: joker with nil config.center falls back gracefully", function()
	local bad_joker = {
		ability = { set = "Joker" },
		config = { center = nil },  -- Missing center
		sort_id = 1
	}
	local t = { [1] = bad_joker }
	-- Should fall back to orig function, not crash
	assert_no_throw(function()
		test_pseudorandom_element(t, "test_seed")
	end)
end)

test("pseudorandom_element: joker with nil sort_id handled gracefully", function()
	-- Need 3+ elements with same key to reliably trigger sort comparison
	local joker1 = make_joker(1, "j_joker", nil)  -- nil sort_id, treated as 0
	local joker2 = make_joker(2, "j_joker", 2)
	local joker3 = make_joker(3, "j_joker", 1)
	local t = { [1] = joker1, [2] = joker2, [3] = joker3 }
	-- Should handle nil sort_id by treating as 0, not crash
	assert_no_throw(function()
		test_pseudorandom_element(t, "test_seed")
	end)
end)

test("pseudorandom_element: non-joker table falls through", function()
	local t = { [1] = { name = "not a joker" } }
	local result, key = test_pseudorandom_element(t, "test_seed")
	-- Should fall through to orig function
	assert_not_nil(result)
end)

test("pseudorandom_element: mixed table (joker + non-joker) falls through", function()
	local t = {
		[1] = make_joker(1, "j_joker", 1),
		[2] = { name = "not a joker" }
	}
	local result, key = test_pseudorandom_element(t, "test_seed")
	-- Should fall through since not all are jokers
	assert_not_nil(result)
end)

-- Test get_culled function edge cases
local function get_culled(_pool)
	if _pool == nil then return {} end
	local culled = {}
	for i = 1, #_pool, 2 do
		local first = _pool[i]
		local second = _pool[i + 1]

		if second == nil then
			culled[#culled + 1] = (first ~= "UNAVAILABLE") and first or "UNAVAILABLE"
		elseif first ~= "UNAVAILABLE" and second ~= "UNAVAILABLE" then
			culled[#culled + 1] = first
			culled[#culled + 1] = second
		elseif first ~= "UNAVAILABLE" then
			culled[#culled + 1] = first
		elseif second ~= "UNAVAILABLE" then
			culled[#culled + 1] = second
		else
			culled[#culled + 1] = "UNAVAILABLE"
		end
	end
	return culled
end

print("\n=== get_culled Edge Cases ===\n")

test("get_culled: empty pool", function()
	local result = get_culled({})
	assert_eq(#result, 0)
end)

test("get_culled: single element pool", function()
	local result = get_culled({ "voucher_a" })
	assert_eq(#result, 1)
	assert_eq(result[1], "voucher_a")
end)

test("get_culled: odd number of elements", function()
	local result = get_culled({ "a", "b", "c" })
	assert_eq(#result, 3)
end)

test("get_culled: all UNAVAILABLE", function()
	local result = get_culled({ "UNAVAILABLE", "UNAVAILABLE" })
	assert_eq(#result, 1)
	assert_eq(result[1], "UNAVAILABLE")
end)

test("get_culled: first UNAVAILABLE", function()
	local result = get_culled({ "UNAVAILABLE", "voucher_b" })
	assert_eq(#result, 1)
	assert_eq(result[1], "voucher_b")
end)

test("get_culled: second UNAVAILABLE", function()
	local result = get_culled({ "voucher_a", "UNAVAILABLE" })
	assert_eq(#result, 1)
	assert_eq(result[1], "voucher_a")
end)

test("get_culled: nil pool returns empty table", function()
	local result = get_culled(nil)
	assert_not_nil(result)
	assert_eq(#result, 0)
end)

-- Test CardArea.shuffle edge cases simulation
print("\n=== Shuffle Edge Cases ===\n")

local function test_shuffle_card_values(cards)
	local centers = {
		c_base = 0,
		m_stone = 106,
	}
	local seals = {
		Gold = 122,
	}
	local editions = {
		foil = 157,
	}

	local tables = {}
	for i, v in ipairs(cards) do
		-- Skip cards with missing config or base to avoid crashes
		if not v.config or not v.base then
			return nil, "fallback"  -- Signal that we should fall back
		end
		v.mp_stdval = 0 + (centers[v.config.center_key] or 0)
		v.mp_stdval = v.mp_stdval + (seals[v.seal or "nil"] or 0)
		v.mp_stdval = v.mp_stdval + (editions[v.edition and v.edition.type or "nil"] or 0)
		local key = v.config.center_key == "m_stone" and "Stone" or v.base.suit .. v.base.id
		tables[key] = tables[key] or {}
		tables[key][#tables[key] + 1] = v
	end
	return tables
end

local function make_card(center_key, suit, id, seal, edition)
	return {
		config = { center_key = center_key },
		base = { suit = suit, id = id },
		seal = seal,
		edition = edition
	}
end

test("shuffle: empty cards array", function()
	local result = test_shuffle_card_values({})
	assert_eq(next(result), nil) -- empty tables
end)

test("shuffle: basic card", function()
	local cards = { make_card("c_base", "Spades", 1) }
	local result = test_shuffle_card_values(cards)
	assert_not_nil(result["Spades1"])
end)

test("shuffle: stone card uses 'Stone' key", function()
	local cards = { make_card("m_stone", "Spades", 1) }
	local result = test_shuffle_card_values(cards)
	assert_not_nil(result["Stone"])
end)

test("shuffle: card with nil config triggers fallback", function()
	local bad_card = { config = nil, base = { suit = "Spades", id = 1 } }
	local result, fallback = test_shuffle_card_values({ bad_card })
	assert_nil(result)
	assert_eq(fallback, "fallback")
end)

test("shuffle: card with nil base triggers fallback", function()
	local bad_card = { config = { center_key = "c_base" }, base = nil }
	local result, fallback = test_shuffle_card_values({ bad_card })
	assert_nil(result)
	assert_eq(fallback, "fallback")
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
