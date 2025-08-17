# Engine Library - AI Assistant Guide

> ⚠️ AI slop code and docs, is unstable and full of lies

This directory contains the core engine capabilities. When working here, prioritize performance and clean architecture over backwards compatibility.

## Quick Reference

**Architecture:** Capability-based organization - modules grouped by what they enable
**Philosophy:** Procedural generation, GPU-first, zero external dependencies
**Full docs:** See [README.md](./README.md) for complete component documentation

## Directory Structure

```
lib/
├── core/       # Fundamental types (Vec2, Color, Rectangle)
├── platform/   # SDL3 integration, input, window management
├── rendering/  # GPU pipeline, camera, shaders, drawing
├── physics/    # Collision detection, shapes
├── game/       # ECS, zones, state, AI control
├── reactive/   # Svelte 5 implementation
├── font/       # TTF parsing and rasterization
├── text/       # Text rendering and layout
├── vector/     # GPU-accelerated graphics
├── ui/         # Reactive UI components
└── debug/      # Logging and development tools
```

## Working Guidelines

### Import Patterns
```zig
// Direct capability imports
const types = @import("core/types.zig");
const input = @import("platform/input.zig");

// Barrel imports for subsystems
const reactive = @import("reactive.zig");
const ui = @import("ui.zig");
```

### Performance Priorities
- Use squared distances (avoid sqrt)
- Prefer procedural generation over assets
- Batch GPU operations
- Use fixed-size pools
- Compile-time composition when possible

### Adding New Capabilities
1. Identify capability category
2. Create in appropriate directory
3. Follow existing patterns
4. Update barrel exports if needed
5. Document in README.md

### Common Tasks

**Adding a new core type:**
- Place in `core/types.zig` or create new file in `core/`
- Use `extern struct` for GPU compatibility
- Add tests in same file

**Creating a new UI component:**
- Extend `ReactiveComponent` base class
- Place in `ui/` directory
- Use reactive primitives (signal, derived, effect)
- See `ui/fps_counter.zig` as example

**Adding rendering functionality:**
- Implement `RendererInterface` if needed
- Use procedural vertex generation
- Follow SDL3 GPU patterns
- Test with `zig build run`

### Critical Patterns

**Reactive System:**
```zig
const count = signal(0);
const doubled = derived(&count, |c| c.get() * 2);
const effect = createEffect(&count, |c| {
    updateDisplay(c.get());
});
```

**Logger Configuration:**
```zig
const AppLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});
```

**Resource Pools:**
```zig
var pool = ResourcePool.init(6, 2.0); // 6 max, 2/sec recharge
```

## Testing

```bash
# Run all lib tests
zig test src/lib/reactive/test_expected_behavior.zig
zig test src/lib/font/test_font_rendering.zig

# Visual tests
zig build run  # Navigate to test pages in menu
```

## Architecture Notes

- **No arbitrary restrictions:** Any module can import any other
- **Natural layering:** Core → Platform → Rendering → Physics → Subsystems
- **Dependency inversion:** Use interfaces to break circular deps
- **Capability-based:** Organize by what modules enable, not what they are

## Performance Checklist

When modifying engine code:
- [ ] Avoid allocations in hot paths
- [ ] Use comptime where possible
- [ ] Batch similar operations
- [ ] Profile with ReleaseFast build
- [ ] Check cache efficiency
- [ ] Minimize state changes
- [ ] Use procedural generation

## Common Pitfalls

- Don't create circular dependencies between capabilities
- Don't allocate in render loops
- Don't use dynamic dispatch when static will work
- Don't add external dependencies
- Don't break existing game code

## Related Documentation

- [Architecture Overview](../../docs/architecture.md)
- [GPU Performance](../../docs/gpu-performance.md)
- [Development Workflow](../../docs/development-workflow.md)