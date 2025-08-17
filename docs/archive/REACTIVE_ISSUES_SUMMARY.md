# Reactive System Issues Summary

> ⚠️ AI slop code and docs, is unstable and full of lies

## Current Test Results

✅ **Working correctly:**
- Basic signal get/set operations
- Automatic dependency tracking (effects re-run when signals change)
- Lazy evaluation of computed values (only recompute when accessed)
- Conditional dependency cleanup (old deps removed when conditions change)
- Effect lifecycle (stop/start)
- Computed chains propagate correctly
- No double notifications on simple signal changes

❌ **Issues Found:**

### 1. Batching Doesn't Defer Notifications
**Problem:** Effects run multiple times during batch instead of once at the end
```zig
batch(() => {
    x.set(10);  // Effect runs here
    y.set(20);  // Effect runs again here
});
// Expected: Effect runs once after batch
// Actual: Effect runs twice during batch
```

### 2. Computed Values Notify Even When Value Unchanged
**Problem:** When computed value stays the same, dependents still get notified
```zig
signal: 10 -> 20 (both positive)
computed: true -> true (no change)
effect: runs anyway (should not run)
```

### 3. Diamond Dependencies Cause Double Updates
**Problem:** Shared dependencies trigger multiple updates
```
    A
   / \
  B   C
   \ /
    D
```
When A changes, D computes/notifies twice (once via B, once via C)

### 4. No Peek/Untrack Functionality
**Problem:** Can't read signals without creating dependencies
```zig
effect(() => {
    tracked.get();    // Should create dependency ✅
    untracked.peek(); // Should NOT create dependency ❌ (not implemented)
});
```

### 5. Redundant State in Implementation
- Computed has both `signal` and `cached_value` (redundant)
- Signal has unused `is_dirty` flag
- Computed has unused `dependency_versions` array

## Test Files Created

1. **test_expected_behavior.zig** - Comprehensive test suite showing expected behavior
2. **test_issues.zig** - Specific tests that expose current problems

## Priority Fixes

1. **High Priority:**
   - Fix batching to properly defer notifications
   - Implement peek/untrack for reading without tracking
   - Fix diamond dependency double updates

2. **Medium Priority:**
   - Don't notify when computed value doesn't change
   - Simplify computed implementation (remove redundant state)

3. **Low Priority:**
   - Optimize observer list operations
   - Add debug/trace capabilities

## Next Steps

1. Fix batching implementation to queue notifications
2. Add peek() method to signals
3. Implement value comparison in computed to avoid unnecessary notifications
4. Optimize diamond dependency handling
5. Remove redundant state from implementations