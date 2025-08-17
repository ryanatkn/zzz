# Development Workflow

> ⚠️ AI slop code and docs, is unstable and full of lies

## TODO Document Management

Active development uses TODO documents for task tracking and planning:

### Active TODO Documents
- **Location:** Root directory with `TODO_*.md` prefix (e.g., `TODO_ECS.md`)
- **Naming:** All caps prefix for high visibility
- **Purpose:** Track major architectural work and migrations

### Completion Workflow
1. **Update in place** when work is complete:
   - Change title: `# TODO: Task Name` → `# ✅ COMPLETED: Task Name`
   - Add completion date and summary
   - Keep file in root to show accomplishments
2. **Validation session** for complex migrations:
   - Machine develops complete understanding of codebase
   - Validate implementation matches design intent
   - User and machine independently verify results
3. **Archive to `docs/archive/`** only when:
   - Work is fully validated and complete
   - Documentation becomes stale or superseded
   - User explicitly approves archival

### Git Integration
- Always commit TODO docs during work
- Commit completion status updates
- Use git history for granular progress tracking

## Session Workflow (WORKFLOW.md)

Standard development session pattern:

1. Assess TODO_DOC.md
2. Do the thing:
   - Submit optional elicitations to the user for context
   - Use `zz prompt` for language-aware information extraction
   - Run tests and get output
   - Iterate as needed
3. Update TODO_DOC.md
4. Commit with clear message

## Import Guidelines

### Library Import Patterns
- **Capability-based imports:** Import from specific capability directories
- **Core modules:** `core/` - types, maths, colors, viewport, result, pool, id
- **Platform modules:** `platform/` - sdl, input, window, resources
- **Rendering modules:** `rendering/` - interface, gpu, shaders, camera, modes, drawing
- **Physics modules:** `physics/` - collision, shapes
- **Barrel imports:** Use `reactive.zig` and `ui.zig` for complete subsystems

### Import Examples
```zig
// Capability imports
const types = @import("../lib/core/types.zig");
const input = @import("../lib/platform/input.zig");
const camera = @import("../lib/rendering/camera.zig");
const collision = @import("../lib/physics/collision.zig");

// Barrel imports for subsystems
const reactive = @import("../lib/reactive.zig");
const ui = @import("../lib/ui.zig");
```

### DRY Principles
- Prefer shared utilities over duplicate code
- Extract common patterns to lib directory
- Reuse existing components when possible

## Testing Approach

### Test Organization
- Unit tests: Colocated with source files
- Integration tests: In `tests/` directory
- Visual tests: Font grid, vector graphics demos

### Running Tests
```bash
# Run all tests
zig build test

# Run specific test
zig test src/lib/reactive/test_expected_behavior.zig

# Visual debugging
zig build run  # Then navigate to test pages
```

### Test Coverage Areas
- Reactive system: 20+ comprehensive tests
- Font rendering: Visual and unit tests
- Physics: Collision detection validation
- UI components: Lifecycle and rendering tests

## Performance Validation

### Benchmarking
```bash
# Run with performance profiling
zig build -Doptimize=ReleaseFast run

# Monitor in-game metrics
# - FPS counter (always visible)
# - Debug overlay (development builds)
```

### Performance Targets
- 60 FPS minimum with 1000+ entities
- <2ms GPU frame time
- 95%+ cache hit rate for UI
- ~50ns per AI command

## Code Style Guidelines

### General Principles
- Do what has been asked; nothing more, nothing less
- Performance is top priority over backwards compatibility
- Procedural generation over static assets
- Extract constants, avoid magic numbers

### Zig Patterns
- Use `comptime` for compile-time computation
- Prefer `errdefer` for cleanup
- Use `extern struct` for GPU compatibility
- Apply `inline` judiciously for hot paths

### Documentation
- NEVER create docs unless explicitly requested
- Keep comments minimal unless asked
- Update existing docs rather than creating new ones
- Use clear, descriptive names over comments

## Debugging Tools

### Logging System
```zig
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

// Console + file with throttling
const AppLogger = Logger(.{
    .output = outputs.Multi(.{ 
        outputs.Console, 
        outputs.File(.{ .path = "game.log" })
    }),
    .filter = filters.Throttle,
});

var logger = AppLogger.init(allocator);
logger.info("startup", "Game initialized", .{});
```

### Debug Visualization
- Press G: Toggle AI control mode
- Backtick: Toggle HUD overlay
- Debug shapes: Visual collision boxes
- Effect indicators: Spell area visualization

## Reactive System Usage

### Core Patterns
```zig
// State management
const counter = signal(0);
const doubled = derived(&counter, |c| c.get() * 2);

// Effects
const effect = createEffect(&counter, |c| {
    updateUI(c.get());
});

// Component lifecycle
const MyComponent = ReactiveComponent {
    .init = initFn,
    .deinit = deinitFn,
    .update = updateFn,
};
```

### Performance Optimization
- Use `signalRaw()` for non-reactive state
- Batch updates for efficiency
- Use `peek()` to avoid dependencies
- Create snapshots for external APIs

## Build Configuration

### Development Builds
```bash
zig build              # Debug build
zig build run          # Run immediately
zig build test         # Run tests
```

### Release Builds
```bash
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSmall
zig build -Doptimize=ReleaseSafe
```

### Cross-Compilation
```bash
zig build -Dtarget=x86_64-windows
zig build -Dtarget=aarch64-linux
zig build -Dtarget=wasm32-wasi
```

## Dependency Management

### Vendored Dependencies
All dependencies are vendored in `deps/`:
- SDL3: Complete library source
- webref: Web specification references
- No external package requirements

### Updating Dependencies
```bash
zig build update-deps   # Update vendored libraries
zig build check-deps    # Verify dependency status
scripts/update-deps.sh  # Manual update script
```

## Git Workflow

### Commit Messages
- Clear, concise descriptions
- Reference TODO docs when applicable
- Include "wip" for work in progress
- Use conventional prefixes when appropriate:
  - `fix:` Bug fixes
  - `feat:` New features
  - `docs:` Documentation updates
  - `refactor:` Code restructuring

### Branch Strategy
- Main branch: `main`
- Feature branches: Optional for major work
- Direct commits to main for small changes

## AI Assistant Integration

### Working with Claude Code
- CLAUDE.md provides assistant context
- TODO docs guide major tasks
- Use `zz prompt` for code extraction
- Session workflow in WORKFLOW.md

### Best Practices
- Provide clear task descriptions
- Reference specific files/functions
- Use TODO docs for complex work
- Validate outputs before committing