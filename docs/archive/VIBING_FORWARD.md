# Vibe Engineering

## Module-and-Interface Methodology

Vibe engineering applies proven software engineering practices through a module-and-interface lens rather than implementation details. Where "vibe coding" relies on intuition and aesthetic choices, vibe engineering leverages data, measurement, and automated verification to drive architectural decisions.

## Core Principles

### 1. Data-Driven Architecture Changes

Large-scale refactoring requires empirical validation:
- **Before**: Measure baseline performance (iteration speed, memory usage, cache misses)
- **During**: Track migration progress with concrete metrics (errors resolved, functions converted)
- **After**: Verify improvements with real data (20-30% iteration speedup, 60% complexity reduction)

Example from ECS rework:
```
5-layer hierarchy → 2-layer hierarchy (measured)
ArrayList overhead → Fixed arrays (profiled)
40+ function signatures → Systematic conversion tracking
```

### 2. Automated Verification Systems

Manual verification doesn't scale. Automate:
- **Compilation tests**: Zero errors before proceeding
- **Architectural invariants**: Zone isolation verified programmatically
- **Performance regression**: Automated benchmarks catch slowdowns
- **Migration validation**: Parallel systems with result comparison

### 3. Cognitive Offloading to Machines

Engineers focus on interfaces and contracts. Machines handle:
- **Systematic refactoring**: Update 40+ references automatically
- **Dependency tracking**: Find all function signature changes
- **Pattern recognition**: Identify architectural anti-patterns
- **Consistency enforcement**: Apply naming conventions uniformly

### 4. Module Boundaries Over Implementation

Focus on capability exposure, not internal details:
- **Interface contracts**: What does this module promise?
- **Dependency inversion**: Can implementations be swapped?
- **Composition patterns**: How do modules combine?
- **Abstraction cost**: Is indirection worth the flexibility?

## Workflow Evolution

### Current State: Assisted Engineering
- Engineer defines architectural goals
- Machine performs systematic changes
- Automated verification catches issues
- Data drives decision-making

### Future State: Plan-Based Automation
- 24/7 engineering with plan execution
- Continuous verification loops
- Self-healing architectures
- Performance-guided evolution

## Practical Application

### Migration Pattern (ECS Rework Example)

1. **Measure Current State**
   - Profile entity iteration performance
   - Count abstraction layers (5 found)
   - Identify pain points (zone isolation bugs)

2. **Design Target Architecture**
   - Define module boundaries (World → zones[i])
   - Specify performance goals (20% improvement)
   - Create verification criteria (zone isolation)

3. **Systematic Migration**
   - Create adapter layer for parallel running
   - Track conversion progress (85% → 95% → 100%)
   - Validate each phase with data

4. **Verify Results**
   - Build success (zero errors)
   - Performance improvement (measured)
   - Bug fixes confirmed (zone isolation working)
   - Complexity reduction (5 layers → 2 layers)

### Decision Framework

Every architectural choice backed by data:
- **Fixed arrays vs ArrayList**: Measure allocation overhead
- **Direct access vs abstraction**: Profile indirection cost
- **Component system vs arrays**: Benchmark iteration speed
- **Immediate vs persistent rendering**: Track frame timing

## Anti-Patterns to Avoid

### Vibe Coding Traps
- Choosing patterns for aesthetic appeal
- Premature abstraction without measurement
- Manual verification of complex changes
- Implementation-first thinking

### Better Approach
- Measure, then decide
- Verify with automation
- Think modules and interfaces
- Let machines handle tedium

## Metrics That Matter

### Architecture Health
- Module coupling coefficient
- Interface stability over time
- Abstraction depth histogram
- Cache miss rates per pattern

### Migration Quality
- Errors resolved per session
- Functions converted per hour
- Test coverage delta
- Performance regression frequency

### Cognitive Load
- Lines changed by human vs machine
- Time spent on mechanical tasks
- Bug discovery latency
- Architectural decision reversals

## Tools and Techniques

### Verification Automation
```zig
// Architectural invariant checking
test "zone_isolation" {
    for (world.zones) |zone, i| {
        for (zone.entities) |entity| {
            try expect(entity.zone_index == i);
        }
    }
}
```

### Performance Tracking
```zig
// Before/after comparison
const baseline = timer.lap();
iterateEntities(&old_ecs);
const old_time = timer.lap();

iterateEntities(&new_system);
const new_time = timer.lap();

try expect(new_time < old_time * 0.8); // 20% improvement
```

### Migration Validation
```zig
// Parallel system verification
const old_result = old_system.compute();
const new_result = new_system.compute();
try expect(resultsMatch(old_result, new_result));
```

## Evolution Toward Automation

### Phase 1: Human-Directed (Current)
- Engineer identifies problems
- Machine executes changes
- Human verifies results

### Phase 2: Machine-Proposed
- System suggests optimizations
- Engineer approves plans
- Automated execution and verification

### Phase 3: Autonomous Engineering
- Continuous performance monitoring
- Automatic architecture evolution
- Human sets constraints and goals
- System operates within bounds

## Conclusion

Vibe engineering isn't about removing intuition from software development. It's about backing intuition with data, automating mechanical work, and focusing human cognition on module boundaries and interface design. The goal: better software through systematic, measured, and increasingly automated engineering practices.