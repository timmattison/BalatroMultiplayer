# Bug Fixes and Test Coverage

This document describes the bugs that were identified and fixed, the tests that were written to prevent regressions, and the common patterns that caused these issues.

## Summary

- **Bugs Fixed:** ~25
- **Tests Written:** 88
  - 82 passing tests (verify code works correctly)
  - 6 intentionally failing tests (prove tests catch bugs)

## How to Run Tests

```bash
# Run all test suites
lua tests/test-utils.lua
lua tests/test-the-order.lua
lua tests/test-fixes.lua

# Run buggy version tests (these should fail, proving test effectiveness)
lua tests/test-buggy-versions.lua
```

## Bugs Fixed

### Logic Bugs

#### 1. reset_mail_rank Sort Using Wrong Count Values
**File:** `compatibility/TheOrder.lua`

The sort function was comparing `a.count` and `b.count` directly, but these values were always 0 because the count was stored in a separate `count_map` table, not in the `valid_ranks` entries themselves.

```lua
-- BEFORE (buggy): a.count and b.count are always 0
table.sort(valid_ranks, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return value_order[a.value] < value_order[b.value]
end)

-- AFTER (fixed): Look up actual counts from count_map
table.sort(valid_ranks, function(a, b)
    local a_count = count_map[a.value].count
    local b_count = count_map[b.value].count
    if a_count ~= b_count then return a_count > b_count end
    return value_order[a.value] < value_order[b.value]
end)
```

### Nil Access Crashes

#### 2. Empty Jokers Array Access (Brainstorm)
**File:** `objects/decks/BB_gradient.lua`

The `get_bp()` function accessed `G.jokers.cards[1]` without checking if the jokers array was empty when handling the brainstorm joker.

```lua
-- BEFORE: Crashes if no jokers exist
elseif key == "j_brainstorm" then
    key = G.jokers.cards[1].config.center.key

-- AFTER: Return "NULL" if no jokers
elseif key == "j_brainstorm" then
    if not G.jokers.cards[1] then return "NULL" end
    key = G.jokers.cards[1].config.center.key
```

#### 3. Empty Cardarea Access
**File:** `compatibility/Preview/CorePreview.lua`

Accessed `cardarea.cards[1].ability.set` without checking if `cards[1]` exists.

```lua
-- BEFORE: Crashes on empty cardarea
if cardarea.config.type == "joker" and cardarea.cards[1].ability.set == "Joker" then

-- AFTER: Check cards[1] exists first
if cardarea.config.type == "joker" and cardarea.cards[1] and cardarea.cards[1].ability.set == "Joker" then
```

#### 4. Missing Config/Center Nil Checks
**File:** `objects/challenges/polymorph_spam.lua`

The `get_area()` function accessed `card.config.center` without checking if `config` or `center` existed.

```lua
-- BEFORE: Crashes on missing config or center
local function get_area(card)
    if not card then return end
    if card.config.center.set == "Joker" then

-- AFTER: Check entire chain
local function get_area(card)
    if not card or not card.config or not card.config.center then return nil end
    if card.config.center.set == "Joker" then
```

#### 5. Nil Area Handling
**File:** `objects/challenges/polymorph_spam.lua`

The `get_pos()` function didn't check if `get_area()` returned nil before iterating.

```lua
-- BEFORE: Crashes if area is nil
local function get_pos(card)
    local area = get_area(card)
    for i, v in ipairs(area.cards) do

-- AFTER: Check area exists
local function get_pos(card)
    local area = get_area(card)
    if not area or not area.cards then return nil end
    for i, v in ipairs(area.cards) do
```

#### 6. TheOrder.lua pseudorandom_element Fixes
**File:** `compatibility/TheOrder.lua`

Multiple nil access issues in the `pseudorandom_element` function:
- Empty table causing nil access on `keys[1]`
- Missing `config` or `config.center` on joker objects
- Nil `sort_id` causing sort comparison failures

#### 7. Utility Function Nil Handling
**Files:** `lib/string_utils.lua`, `lib/_table_utils.lua`, `lib/insane_int.lua`

Added nil checks to utility functions:
- `wrapText(nil)` → returns `""`
- `string_split(nil)` → returns `{}`
- `shallow_copy(nil)` → returns `{}`
- `merge_tables(nil, x)` → treats nil as `{}`
- `get_array_index_by_value(nil, x)` → returns `nil`
- `reverse_key_value_pairs(nil)` → returns `{}`
- `INSANE_INT.to_string(nil)` → returns `"0"`
- `INSANE_INT.greater_than(nil, x)` → returns `false`
- `INSANE_INT.add(nil, x)` → returns other argument

#### 8. Other Nil Access Fixes
- `ui/game/functions.lua:278` - Check `args.colour` before accessing `args.colour[4]`
- `compatibility/Preview/Jokers/_Vanilla.lua:763` - Array bounds check before accessing `idx + 1`
- `objects/decks/_decks.lua:13` - Check `G.shared_stickers["mp_sticker_balanced"]` exists
- `ui/main_menu/title_card.lua:81` - Check `G.title_top.cards[1]` exists

## Common Bug Patterns

### Pattern 1: Array Access Without Bounds Check
Accessing `array[1]` or `array[index + 1]` without verifying the array has elements.

**Prevention:**
```lua
-- Always check before accessing
if array[1] then
    -- safe to use array[1]
end

-- For index + 1 access
if index < #array then
    local next_item = array[index + 1]
end
```

### Pattern 2: Chained Property Access Without Nil Checks
Accessing nested properties like `obj.config.center.key` without checking intermediate values.

**Prevention:**
```lua
-- Check entire chain
if obj and obj.config and obj.config.center then
    local key = obj.config.center.key
end

-- Or use early return
if not obj or not obj.config or not obj.config.center then return nil end
```

### Pattern 3: Using Wrong Variable in Closures/Callbacks
Sort functions or callbacks using variables that don't contain expected values (like `a.count` being 0 when count is stored elsewhere).

**Prevention:**
- Verify what data is actually stored in the objects being compared
- Use explicit lookups when data is stored in separate structures

### Pattern 4: Not Handling Nil Returns from Functions
Calling a function that can return nil and immediately using the result without checking.

**Prevention:**
```lua
local result = some_function(arg)
if not result then return nil end
-- now safe to use result
```

### Pattern 5: Assuming Collections Are Non-Empty
Iterating or accessing elements without checking if the collection has any items.

**Prevention:**
```lua
-- Check before first element access
if #collection > 0 then
    local first = collection[1]
end

-- Or check inside conditions
if collection[1] and collection[1].property then
```

## Test Files

| File | Tests | Purpose |
|------|-------|---------|
| `tests/test-utils.lua` | 45 | Tests for utility functions (string, table, insane_int) |
| `tests/test-the-order.lua` | 21 | Tests for TheOrder.lua edge cases |
| `tests/test-fixes.lua` | 16 | Tests for specific bug fixes |
| `tests/test-buggy-versions.lua` | 6 | Validates tests catch bugs (intentionally fails) |

## Adding New Tests

When fixing a bug, follow this pattern:

1. **Write a test that reproduces the bug** (should fail initially)
2. **Fix the bug**
3. **Verify the test passes**
4. **Optionally add the buggy version to `test-buggy-versions.lua`** to prove test effectiveness

Example test structure:
```lua
test("descriptive name of what should work", function()
    -- Setup
    local input = create_test_input()

    -- Execute
    local result = function_under_test(input)

    -- Assert
    assert_eq(result, expected_value, "helpful error message")
end)
```
