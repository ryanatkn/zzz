# noUncheckedIndexedAccess - Fix Patterns

TypeScript's `noUncheckedIndexedAccess` treats all indexed access as potentially undefined. This guide provides patterns for fixing these errors correctly.

## Decision Tree

```
Is this a test file?
├─ YES → Does code verify length/existence first?
│         ├─ YES → Use `!` assertion (fails fast, catches bugs)
│         └─ NO  → Add length check, then use `!`
│
└─ NO (production code) → Is access provably safe?
          ├─ YES → Use `!` with comment explaining guarantee
          └─ NO  → Use defensive check with appropriate fallback
```

## Test Files: Use `!` Assertions

**Why**: Tests should fail fast. `!` immediately throws if undefined, catching bugs.

```typescript
// ✅ CORRECT - Fails immediately if array is wrong
expect(items).toHaveLength(3);
expect(items[0]!.name).toBe('Alice');
expect(items[1]!.name).toBe('Bob');

// ❌ WRONG - Silently skips assertions, hides bugs
const first = items[0];
if (!first) return; // or continue
expect(first.name).toBe('Alice');

// ❌ WRONG - Verbose, no benefit over `!`
const first = items[0];
if (!first) throw new Error('Expected first item');
expect(first.name).toBe('Alice');

// ✅ ALSO CORRECT - When extracting for reuse
const first = items[0]!;
const second = items[1]!;
expect(first.name).toBe('Alice');
expect(second.name).toBe('Bob');
```

## Production Code: Context-Dependent

### Pattern 1: Provable Guarantees → Use `!`

When you have a guarantee TypeScript can't track:

```typescript
// ✅ Length check guarantees first element exists
if (sorters.length > 0) {
    this.active_key = sorters[0]!.key;
}

// ✅ Loop bounds guarantee element exists
for (let i = 0; i < items.length; i++) {
    process(items[i]!);
}

// ✅ Regex match groups (when pattern guarantees capture)
const match = /^(\w+)=(.+)$/.exec(line);
if (match) {
    const key = match[1]!;    // Pattern guarantees group 1
    const value = match[2]!;  // Pattern guarantees group 2
    return {key, value};
}
```

### Pattern 2: Uncertain Access → Defensive Check

When access might genuinely fail:

```typescript
// ✅ Extract and check when unsure
const firstEntry = history.entries[0];
if (!firstEntry) {
    console.error('Unexpected empty history');
    return fallback;
}
return firstEntry;

// ✅ Nullish coalescing for simple fallback
const first = array[0] ?? defaultValue;

// ✅ Optional chaining for property access
const value = array[0]?.property;
```

### Pattern 3: Array Methods → Type Assertion

`slice()` with `noUncheckedIndexedAccess` returns `(T | undefined)[]`:

```typescript
// ✅ Safe: bounds are validated, slice preserves elements
if (from_index < items.length && to_index <= items.length) {
    return [
        ...(items.slice(0, from_index) as T[]),
        item,
        ...(items.slice(from_index) as T[]),
    ];
}
```

## Anti-Patterns

### ❌ Never: `continue` in tests
```typescript
// WRONG - Silently skips assertions
for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (!item) continue;  // Test passes even if items[i] is undefined!
    expect(item.value).toBe(expected[i]);
}

// CORRECT - Fails immediately
for (let i = 0; i < items.length; i++) {
    expect(items[i]!.value).toBe(expected[i]);
}
```

### ❌ Avoid: Over-defensive in production
```typescript
// WRONG - Unnecessary after length check
if (sorters.length > 0) {
    const first = sorters[0];
    if (first) {  // Redundant!
        this.active_key = first.key;
    }
}

// CORRECT
if (sorters.length > 0) {
    this.active_key = sorters[0]!.key;
}
```

### ❌ Avoid: Verbose extract-check in tests
```typescript
// WRONG - Adds lines without adding safety
const first = part.attributes[0];
if (!first) throw new Error('Expected first attribute');
expect(first.key).toBe('class');

// CORRECT - Concise and equally safe
expect(part.attributes[0]!.key).toBe('class');
```

## Real-World Examples

### Loop Access
```typescript
// Test file - use `!`
for (let i = 0; i < popovers.length; i++) {
    popovers[i]!.hide();
    expect(popovers[i]!.visible).toBe(false);
}

// Production - use `!` with guarantee
for (let i = 0; i < this.tab_order.length; i++) {
    const tab = this.tab_order[i]!;  // Loop bounds guarantee
    tab.update();
}
```

### Array After Length Check
```typescript
// Test file
expect(collection.values).toHaveLength(3);
expect(collection.values[0]!.id).toBe(item1.id);
expect(collection.values[1]!.id).toBe(item2.id);
expect(collection.values[2]!.id).toBe(item3.id);

// Production with fallback
if (this.entries.length > 0) {
    return this.entries[0]!;  // Length check guarantees
}
return null;
```

### Derived Access (TypeScript Can't Track)
```typescript
// ✅ Re-check at point of use, even if derived
const hasItems = $derived(this.items.length > 0);

if (hasItems) {
    // TypeScript can't track derived through $derived
    const first = this.items[0];
    if (first) {  // Defensive: derived guard isn't tracked
        useItem(first);
    }
}
```

## PR Review Checklist

When reviewing diffs with indexed access fixes:

1. **Test file?**
   - ✅ Uses `!` after length checks
   - ❌ No `continue` or silent skips

2. **Production with guarantee?**
   - ✅ Uses `!` (loop bounds, length checks, etc.)
   - ✅ Has comment if non-obvious

3. **Production without guarantee?**
   - ✅ Has defensive check
   - ✅ Has appropriate fallback/error handling

4. **Avoids anti-patterns?**
   - ✅ No verbose extract-check in tests
   - ✅ No redundant checks after guarantees
   - ✅ No `continue` hiding test assertions

## Summary

- **Tests**: Use `!` after length checks (fail fast)
- **Production with guarantees**: Use `!` (loop bounds, length checks)
- **Production without guarantees**: Defensive checks
- **Never**: `continue` in tests, verbose patterns when `!` suffices
- **When uncertain**: Defensive checks are better than wrong `!`
