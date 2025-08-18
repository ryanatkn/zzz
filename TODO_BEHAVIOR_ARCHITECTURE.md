# TODO: Behavior Architecture Analysis & Alternatives

**Status**: Analysis Phase  
**Date**: August 18, 2025  
**Context**: Evaluating current behavior architecture for optimality

## Current Architecture

### Structure
```
src/hex/behaviors.zig (85 lines)
    ↓
src/lib/game/behaviors/behavior_state_machine.zig
    ↓
src/lib/core/state_machine.zig (generic)
```

### Core Primitives
- **State Machine**: Generic, interruptible, history tracking
- **Behavior Profiles**: Enum-based (aggressive, defensive, wandering, guardian)
- **Context Objects**: Pass unit position, player position, aggro, delta time
- **Direct Component Updates**: Modifies Transform, Visual directly

### Performance Characteristics
- **Persistent state machines**: Zero allocations per frame
- **Direct field access**: No indirection
- **Compile-time dispatch**: Switch statements → jump tables
- **Cache-friendly**: ~64 bytes state per unit

## Alternative Architectures

### Option 1: Pure Data-Driven Tables
```zig
const BehaviorTable = struct {
    states: []const State,
    transitions: []const Transition,
    actions: []const Action,
};

// Runtime interpretation of behavior data
// PRO: Extremely flexible, hot-reloadable
// CON: Slower (indirect calls), harder to debug
```

### Option 2: ECS-Style Behavior Components
```zig
const ChaseComponent = struct { target: EntityId, speed: f32 };
const FleeComponent = struct { threat: EntityId, safe_distance: f32 };
const PatrolComponent = struct { waypoints: []Vec2, index: usize };

// Systems operate on entities with specific component combinations
// PRO: Maximum composability, parallelizable
// CON: More complex, potential cache misses, overhead for simple behaviors
```

### Option 3: Functional Behavior Chains
```zig
const Behavior = fn(Context) ?Action;

const chain = comptime [_]Behavior{
    checkFlee,
    checkChase,
    checkPatrol,
    defaultIdle,
};

// First non-null action wins
// PRO: Simple, composable, testable
// CON: No state persistence, every frame recalculation
```

### Option 4: Coroutine-Based Behaviors
```zig
const BehaviorCoroutine = struct {
    frame: anyframe,
    suspend_point: usize,
    
    fn chase(self: *@This(), ctx: Context) void {
        while (ctx.target_visible) {
            moveToward(ctx.target);
            suspend; // Resume next frame
        }
    }
};

// PRO: Natural async flow, complex behaviors easy
// CON: Zig async incomplete, memory overhead, harder to reason about
```

### Option 5: Decision Trees
```zig
const DecisionNode = union(enum) {
    condition: struct {
        test: fn(Context) bool,
        true_branch: *DecisionNode,
        false_branch: *DecisionNode,
    },
    action: fn(Context) void,
};

// PRO: Visual debugging possible, clear logic flow
// CON: Tree traversal overhead, memory fragmentation
```

## Performance Comparison

| Architecture | Allocation | Cache | Complexity | Flexibility | Debug |
|-------------|------------|-------|------------|-------------|-------|
| **Current** | None | Good | Medium | Good | Good |
| Data Tables | None* | Poor | Low | Excellent | Hard |
| ECS Style | Some | Poor | High | Excellent | Medium |
| Functional | None | Good | Low | Medium | Easy |
| Coroutines | High | Poor | High | Good | Hard |
| Decision Trees | Some | Poor | Medium | Good | Easy |

*If pre-built tables

## Composability Analysis

### Current System Composability
- **Profile-based**: Limited to predefined profiles
- **State transitions**: Fixed in state machine
- **Behavior delegation**: Hard-coded module calls
- **Extension**: Add new states/profiles requires code changes

### Ideal Composability Requirements
1. **Mix behaviors**: Chase + Patrol simultaneously
2. **Runtime configuration**: Change behavior without recompile
3. **Behavior inheritance**: Base behaviors with overrides
4. **Conditional behaviors**: Context-sensitive activation
5. **Behavior priorities**: Dynamic priority resolution

## Performance Requirements

### Critical Metrics
- **Units**: 200+ active units minimum
- **Frame time**: <1ms for all behavior updates
- **Memory**: <100 bytes per unit state
- **Cache**: Minimize misses, batch similar operations
- **Predictability**: Consistent frame times

### Current Performance
- ✅ Zero allocations per frame
- ✅ ~64 bytes per unit
- ✅ Direct memory access patterns
- ✅ Compile-time dispatch
- ⚠️ Limited parallelization

## Recommendation Matrix

### Keep Current If
- Performance is already sufficient ✅
- Behavior complexity is bounded ✅
- Profile-based system meets needs ✅
- Maintenance is manageable ✅

### Switch to Alternative If
- Need runtime behavior modification → Data Tables
- Need maximum composability → ECS Style
- Need simple stateless behaviors → Functional
- Need complex async flows → Coroutines (when ready)
- Need visual debugging → Decision Trees

## Proposed Optimizations (Current System)

### 1. Behavior Composition
```zig
const CompositeBehavior = struct {
    primary: BehaviorState,
    secondary: ?BehaviorState,
    blend_factor: f32,
};
```

### 2. Data-Driven Profiles
```zig
const ProfileData = struct {
    detection_range: f32,
    chase_speed: f32,
    flee_threshold: f32,
    // Load from ZON files
};
```

### 3. Behavior Modifiers
```zig
const Modifier = enum {
    Slowed,
    Confused,
    Enraged,
    Pacified,
};
// Stack modifiers on base behavior
```

### 4. Parallel Updates
```zig
// Batch units by behavior state for SIMD
const chase_units = filterByState(.chasing);
const patrol_units = filterByState(.patrolling);
// Update batches in parallel
```

## Decision Point

### Questions to Answer
1. **Is 200 units enough?** Or need 1000+?
2. **Is compile-time configuration OK?** Or need runtime?
3. **Is profile system sufficient?** Or need arbitrary combinations?
4. **Is debugging adequate?** Or need visual tools?
5. **Is current performance optimal?** Or need parallelization?

### If Current System Is Good Enough
- **Action**: Minor optimizations only
- **Effort**: 1-2 hours
- **Risk**: Very low
- **Benefit**: 10-20% performance gain

### If Need Major Change
- **Best Alternative**: Functional chains or Data tables
- **Effort**: 8-16 hours
- **Risk**: Medium (need extensive testing)
- **Benefit**: 2-5x flexibility, possible performance gain

## Final Assessment

### Current System Strengths
- ✅ Zero-allocation performance
- ✅ Good cache locality
- ✅ Predictable behavior
- ✅ Reasonable complexity
- ✅ Proven working in game

### Current System Weaknesses
- ❌ Limited composability
- ❌ Compile-time configuration
- ❌ No parallelization
- ❌ Profile-based limitations

### Verdict
**Current system is likely optimal for current requirements**. The state machine approach with persistent storage achieves excellent performance with reasonable complexity. Alternative architectures would add complexity without clear benefits unless requirements change significantly.

### Recommended Actions
1. **Keep current architecture**
2. **Add data-driven profile loading** (from ZON)
3. **Consider behavior modifiers** for spell effects
4. **Benchmark with 500+ units** to find limits
5. **Document behavior extension patterns**

---

**Next Step**: Close this TODO unless performance testing reveals issues with 200+ units or gameplay requires more flexible behavior composition.