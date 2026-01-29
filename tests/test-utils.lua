#!/usr/bin/env lua
-- Unit tests for BalatroMultiplayer utility functions
-- Run with: lua tests/test-utils.lua

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

local function assert_false(val, msg)
	if val then
		error((msg or "Assertion failed") .. ": expected false, got " .. tostring(val))
	end
end

local function assert_nil(val, msg)
	if val ~= nil then
		error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(val))
	end
end

local function assert_not_nil(val, msg)
	if val == nil then
		error((msg or "Assertion failed") .. ": expected non-nil value")
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

-- Setup mock globals that the code expects
MP = { UTILS = {} }

-- Mock number_format function (used by insane_int.lua)
function number_format(num, max)
	if max and num >= max then
		return string.format("%.2e", num)
	end
	return tostring(num)
end

-- Load the source files we're testing
-- We need to load them in order due to dependencies

-- Load string_utils first (needed by insane_int)
dofile("lib/string_utils.lua")

-- Load table_utils
dofile("lib/_table_utils.lua")

-- Load insane_int
dofile("lib/insane_int.lua")

print("\n=== String Utils Tests ===\n")

test("string_split: basic split", function()
	local result = MP.UTILS.string_split("a,b,c", ",")
	assert_eq(#result, 3)
	assert_eq(result[1], "a")
	assert_eq(result[2], "b")
	assert_eq(result[3], "c")
end)

test("string_split: empty string returns empty table", function()
	local result = MP.UTILS.string_split("", ",")
	assert_eq(#result, 0)
end)

test("string_split: no separator found returns single element", function()
	local result = MP.UTILS.string_split("abc", ",")
	assert_eq(#result, 1)
	assert_eq(result[1], "abc")
end)

test("string_split: nil separator defaults to whitespace", function()
	local result = MP.UTILS.string_split("a b c", nil)
	assert_eq(#result, 3)
end)

test("string_split: nil input returns empty table", function()
	local result = MP.UTILS.string_split(nil, ",")
	assert_eq(#result, 0)
end)

test("wrapText: basic wrapping", function()
	local result = MP.UTILS.wrapText("hello world", 5)
	assert_true(result:find("\n") ~= nil, "Should contain newline")
end)

test("wrapText: empty string", function()
	local result = MP.UTILS.wrapText("", 10)
	assert_eq(result, "")
end)

test("wrapText: nil input returns empty string", function()
	local result = MP.UTILS.wrapText(nil, 10)
	assert_eq(result, "")
end)

print("\n=== Table Utils Tests ===\n")

test("shallow_copy: basic copy", function()
	local original = { a = 1, b = 2 }
	local copy = MP.UTILS.shallow_copy(original)
	assert_eq(copy.a, 1)
	assert_eq(copy.b, 2)
	-- Modifying copy shouldn't affect original
	copy.a = 99
	assert_eq(original.a, 1)
end)

test("shallow_copy: empty table", function()
	local result = MP.UTILS.shallow_copy({})
	assert_not_nil(result)
	assert_eq(next(result), nil) -- empty
end)

test("shallow_copy: nil input returns empty table", function()
	local result = MP.UTILS.shallow_copy(nil)
	assert_not_nil(result)
	assert_eq(next(result), nil) -- empty
end)

test("merge_tables: basic merge", function()
	local t1 = { a = 1 }
	local t2 = { b = 2 }
	local result = MP.UTILS.merge_tables(t1, t2)
	assert_eq(result.a, 1)
	assert_eq(result.b, 2)
end)

test("merge_tables: second table overwrites first", function()
	local t1 = { a = 1 }
	local t2 = { a = 2 }
	local result = MP.UTILS.merge_tables(t1, t2)
	assert_eq(result.a, 2)
end)

test("merge_tables: nil first arg treated as empty", function()
	local result = MP.UTILS.merge_tables(nil, { a = 1 })
	assert_eq(result.a, 1)
end)

test("merge_tables: nil second arg treated as empty", function()
	local result = MP.UTILS.merge_tables({ a = 1 }, nil)
	assert_eq(result.a, 1)
end)

test("get_array_index_by_value: finds value", function()
	local options = { "a", "b", "c" }
	assert_eq(MP.UTILS.get_array_index_by_value(options, "b"), 2)
end)

test("get_array_index_by_value: returns nil for missing value", function()
	local options = { "a", "b", "c" }
	assert_nil(MP.UTILS.get_array_index_by_value(options, "z"))
end)

test("get_array_index_by_value: nil options returns nil", function()
	local result = MP.UTILS.get_array_index_by_value(nil, "a")
	assert_nil(result)
end)

test("reverse_key_value_pairs: basic reverse", function()
	local tbl = { a = 1, b = 2 }
	local result = MP.UTILS.reverse_key_value_pairs(tbl)
	assert_eq(result[1], "a")
	assert_eq(result[2], "b")
end)

test("reverse_key_value_pairs: nil input returns empty table", function()
	local result = MP.UTILS.reverse_key_value_pairs(nil)
	assert_not_nil(result)
	assert_eq(next(result), nil) -- empty
end)

test("serialize_table: basic table", function()
	local tbl = { a = 1, b = "test" }
	local result = MP.UTILS.serialize_table(tbl)
	assert_true(result:find("a = 1") ~= nil)
	assert_true(result:find('b = "test"') ~= nil)
end)

test("serialize_table: handles nil value gracefully", function()
	local tbl = { a = nil, b = 1 }
	assert_no_throw(function()
		MP.UTILS.serialize_table(tbl)
	end)
end)

test("serialize_table: handles functions", function()
	local tbl = { fn = function() end }
	local result = MP.UTILS.serialize_table(tbl)
	assert_true(result:find("inserializeable") ~= nil)
end)

print("\n=== Insane Int Tests ===\n")

test("INSANE_INT.empty: creates zero value", function()
	local result = MP.INSANE_INT.empty()
	assert_eq(result.coeffiocient, 0)
	assert_eq(result.exponent, 0)
	assert_eq(result.e_count, 0)
end)

test("INSANE_INT.create: basic creation", function()
	local result = MP.INSANE_INT.create(1.5, 10, 0)
	assert_eq(result.coeffiocient, 1.5)
	assert_eq(result.exponent, 10)
	assert_eq(result.e_count, 0)
end)

test("INSANE_INT.create: handles nil values", function()
	local result = MP.INSANE_INT.create(nil, nil, nil)
	assert_eq(result.coeffiocient, 0)
	assert_eq(result.exponent, 0)
	assert_eq(result.e_count, 0)
end)

test("INSANE_INT.create: handles string numbers", function()
	local result = MP.INSANE_INT.create("1.5", "10", "2")
	assert_eq(result.coeffiocient, 1.5)
	assert_eq(result.exponent, 10)
	assert_eq(result.e_count, 2)
end)

test("INSANE_INT.from_string: basic parsing", function()
	local result = MP.INSANE_INT.from_string("1.5e10")
	assert_eq(result.coeffiocient, 1.5)
	assert_eq(result.exponent, 10)
	assert_eq(result.e_count, 0)
end)

test("INSANE_INT.from_string: leading e's", function()
	local result = MP.INSANE_INT.from_string("ee1.5e10")
	assert_eq(result.e_count, 2)
	assert_eq(result.coeffiocient, 1.5)
	assert_eq(result.exponent, 10)
end)

test("INSANE_INT.from_string: no exponent", function()
	local result = MP.INSANE_INT.from_string("42")
	assert_eq(result.coeffiocient, 42)
	assert_eq(result.exponent, 0)
	assert_eq(result.e_count, 0)
end)

test("INSANE_INT.from_string: BUG - empty string", function()
	-- Empty string causes parts[1] to be nil
	local result = MP.INSANE_INT.from_string("")
	-- This should handle gracefully, not crash or return nil coefficient
	assert_not_nil(result)
	assert_eq(result.coeffiocient, 0) -- Expected: should default to 0
end)

test("INSANE_INT.from_string: BUG - only e's", function()
	-- String of only e's causes parts[1] to be nil after stripping
	local result = MP.INSANE_INT.from_string("eee")
	assert_not_nil(result)
	-- After stripping e's, empty string remains, parts[1] is nil
	assert_eq(result.coeffiocient, 0)
end)

test("INSANE_INT.to_string: basic formatting", function()
	local int = MP.INSANE_INT.create(1.5, 10, 0)
	local result = MP.INSANE_INT.to_string(int)
	assert_true(result:find("1.5") ~= nil)
	assert_true(result:find("e") ~= nil)
	assert_true(result:find("10") ~= nil)
end)

test("INSANE_INT.to_string: zero exponent", function()
	local int = MP.INSANE_INT.create(42, 0, 0)
	local result = MP.INSANE_INT.to_string(int)
	assert_eq(result, "42")
end)

test("INSANE_INT.to_string: with leading e's", function()
	local int = MP.INSANE_INT.create(1.5, 10, 2)
	local result = MP.INSANE_INT.to_string(int)
	assert_true(result:sub(1, 2) == "ee")
end)

test("INSANE_INT.to_string: nil input returns '0'", function()
	local result = MP.INSANE_INT.to_string(nil)
	assert_eq(result, "0")
end)

test("INSANE_INT.greater_than: basic comparison", function()
	local a = MP.INSANE_INT.create(2, 10, 0)
	local b = MP.INSANE_INT.create(1, 10, 0)
	assert_true(MP.INSANE_INT.greater_than(a, b))
	assert_false(MP.INSANE_INT.greater_than(b, a))
end)

test("INSANE_INT.greater_than: e_count takes precedence", function()
	local a = MP.INSANE_INT.create(1, 1, 2)
	local b = MP.INSANE_INT.create(9, 99, 1)
	assert_true(MP.INSANE_INT.greater_than(a, b))
end)

test("INSANE_INT.greater_than: exponent takes precedence over coefficient", function()
	local a = MP.INSANE_INT.create(1, 11, 0)
	local b = MP.INSANE_INT.create(9, 10, 0)
	assert_true(MP.INSANE_INT.greater_than(a, b))
end)

test("INSANE_INT.greater_than: nil first arg returns false", function()
	local b = MP.INSANE_INT.create(1, 10, 0)
	local result = MP.INSANE_INT.greater_than(nil, b)
	assert_false(result)
end)

test("INSANE_INT.greater_than: nil second arg returns false", function()
	local a = MP.INSANE_INT.create(1, 10, 0)
	local result = MP.INSANE_INT.greater_than(a, nil)
	assert_false(result)
end)

test("INSANE_INT.add: basic addition same exponent", function()
	local a = MP.INSANE_INT.create(1, 10, 0)
	local b = MP.INSANE_INT.create(2, 10, 0)
	local result = MP.INSANE_INT.add(a, b)
	assert_eq(result.coeffiocient, 3)
	assert_eq(result.exponent, 10)
end)

test("INSANE_INT.add: different exponents", function()
	local a = MP.INSANE_INT.create(1, 10, 0)
	local b = MP.INSANE_INT.create(1, 9, 0)
	local result = MP.INSANE_INT.add(a, b)
	assert_eq(result.exponent, 10)
	-- 1e10 + 1e9 = 1.1e10
	assert_true(result.coeffiocient > 1 and result.coeffiocient < 1.2)
end)

test("INSANE_INT.add: nil first arg returns second arg", function()
	local b = MP.INSANE_INT.create(1, 10, 0)
	local result = MP.INSANE_INT.add(nil, b)
	assert_eq(result.coeffiocient, 1)
	assert_eq(result.exponent, 10)
end)

test("INSANE_INT.add: nil second arg returns first arg", function()
	local a = MP.INSANE_INT.create(1, 10, 0)
	local result = MP.INSANE_INT.add(a, nil)
	assert_eq(result.coeffiocient, 1)
	assert_eq(result.exponent, 10)
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
