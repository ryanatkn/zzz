# noUncheckedIndexedAccess Type Errors - Resolution Guide

TypeScript's `noUncheckedIndexedAccess` flag treats all indexed array/object access as potentially undefined. This document provides guidance for systematically fixing these errors.

## Resolution Strategy

When encountering a type error from array/object indexed access:

### 1. Assess Safety

**Ask: Is this access actually safe?**
- Are there bounds checks?
- Is there validation logic?
- Could the array/object actually be empty or missing the key?

### 2. Choose Fix Pattern

**For UNSAFE access** (could genuinely be undefined):
```typescript
// Extract to variable and check
const item = array[index];
if (!item) return; // or handle appropriately
// Now use item safely

// Or use optional chaining for property access
const value = array[index]?.property;
```

**For SAFE access** (TypeScript can't prove it but you know it's safe):
```typescript
// Add defensive runtime check with early return
const item = array[index];
if (!item) {
    // Should never happen due to [explain why]
    console.error('Unexpected undefined at index', index);
    return fallback;
}

// DO NOT use `!` assertions unless absolutely necessary
// If you must: array[index]! // with comment explaining why safe
```

**For derived/computed guards:**
```typescript
// TypeScript may not track guards through $derived or function boundaries
// Solution: Re-check at point of use
if (array.length > 0) {
    const item = array[0];
    if (item) { // Re-check despite length guard
        useItem(item);
    }
}
```

## Common Patterns

### Array bounds that TypeScript doesn't trust
```typescript
// Before
if (index >= 0 && index < array.length) {
    array[index].property; // Error
}

// After
if (index >= 0 && index < array.length) {
    const item = array[index];
    if (item) item.property;
}
```

### Regex destructuring
```typescript
// Before
const [, group1, group2] = /regex/.exec(str);

// After
const match = /regex/.exec(str);
const group1 = match?.[1];
const group2 = match?.[2];
if (!group1 || !group2) throw new Error('Invalid match');
```

### Loop index access
```typescript
// Before
for (let i = 0; i < array.length; i++) {
    array[i].property; // Error
}

// After
for (let i = 0; i < array.length; i++) {
    const item = array[i];
    if (item) item.property;
}
```

### First element access
```typescript
// Before
if (array.length > 0) {
    array[0].property; // Error
}

// After - nullish coalescing
const first = array[0] ?? null;

// Or - explicit check
if (array.length > 0) {
    const first = array[0];
    if (first) first.property;
}
```

## Guidelines

1. **Prefer explicit checks over `!` assertions**
2. **Add defensive programming even for "impossible" cases**
3. **Use nullish coalescing (`??`) for simple fallbacks**
4. **Extract to variables before checking** (clearer than inline checks)
5. **Only use `!` when truly impossible to be undefined** - and add a comment explaining why

## Workflow

1. Run typecheck to see errors
2. For each error, assess if access is genuinely safe
3. Apply appropriate fix pattern
4. Add runtime safety checks even if you believe it's impossible
5. Move to next error

The goal is defensive, safe code that handles edge cases gracefully.
