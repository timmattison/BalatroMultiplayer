# Claude Code Guidelines for BalatroMultiplayer

## Bug Fix Process (MANDATORY)

When you discover a possible bug, you MUST follow this test-first process for every fix:

### Step 1: Write a Failing Test First
Before writing any fix, create a test that reproduces the bug:

```lua
test("descriptive name of the bug", function()
    -- Setup: Create the conditions that trigger the bug
    local input = create_buggy_input()

    -- Execute: Run the code that should work
    assert_no_throw(function()
        local result = function_under_test(input)
    end)

    -- Or assert expected behavior
    assert_eq(result, expected_value, "what should happen")
end)
```

### Step 2: Validate the Test Fails
Run the test to confirm it fails with the current buggy code:

```bash
lua tests/test-fixes.lua
```

The test MUST fail before you proceed. If it passes, your test doesn't actually catch the bug.

### Step 3: Implement the Fix
Now fix the bug in the source code.

### Step 4: Validate the Test Passes
Run the test again to confirm your fix works:

```bash
lua tests/test-fixes.lua
```

The test MUST pass after your fix.

### Step 5: Add Buggy Version Test (Optional but Recommended)
Add the buggy implementation to `tests/test-buggy-versions.lua` to prove the test catches the bug:

```lua
test("BUGGY function_name: should not crash", function()
    -- Buggy implementation inline
    local function buggy_version(input)
        -- Original buggy code here
    end

    assert_no_throw(function()
        buggy_version(problematic_input)
    end)
end)
```

## Test Files

| File | Purpose |
|------|---------|
| `tests/test-utils.lua` | Utility function tests |
| `tests/test-the-order.lua` | TheOrder.lua edge cases |
| `tests/test-fixes.lua` | Specific bug fix tests |
| `tests/test-buggy-versions.lua` | Validates tests catch bugs (intentionally fails) |

## Running Tests

```bash
# Run all passing tests
lua tests/test-utils.lua
lua tests/test-the-order.lua
lua tests/test-fixes.lua

# Run buggy version tests (should fail)
lua tests/test-buggy-versions.lua
```

## Common Bug Patterns to Watch For

1. **Array access without bounds check** - Always check `array[1]` exists before using
2. **Chained property access** - Check `obj.config.center` chain for nil at each level
3. **Wrong variable in closures** - Verify sort/callback functions use correct data
4. **Not handling nil returns** - Check function results before using
5. **Assuming non-empty collections** - Verify collections have elements before accessing

See `docs/bug-fixes-and-tests.md` for detailed examples of each pattern.

## Do NOT

- Fix a bug without writing a test first
- Skip validating the test fails before fixing
- Skip validating the test passes after fixing
- Commit bug fixes without corresponding tests
