# TODO: Logging System Refactor

## Current Problems

The current logging system has architectural issues:

1. **Mixed Responsibilities**: `unified_logger.zig` combines output destinations with API
2. **Poor Naming**: "unified" doesn't describe what it actually does (console + file)
3. **Tight Coupling**: File output hardcoded, throttling separate from core logging
4. **Duplicate Concerns**: `log_throttle.zig` and `unified_logger.zig` at same level but different purposes
5. **No Composability**: Can't easily configure different output/filter combinations

## Target Architecture: Clean Layered Design

### Directory Structure
```
src/lib/debug/
├── logger.zig           # Core logger with compile-time backend composition
├── outputs/             # Output destination backends
│   ├── console.zig      # Console output (wraps std.log)
│   ├── file.zig         # File output with session tracking
│   └── multi.zig        # Multi-destination compositor
├── filters/             # Optional filtering policies
│   ├── throttle.zig     # Refactored from log_throttle.zig
│   ├── level.zig        # Log level filtering  
│   └── passthrough.zig  # No filtering (identity filter)
└── formatters/          # Message formatting
    └── timestamped.zig  # [timestamp] LEVEL: message format
```

### Target API Design

**Core Logger with Compile-Time Composition:**
```zig
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

// Configure logger with desired backends
const AppLogger = Logger(.{
    .output = outputs.Multi(.{ 
        outputs.Console{}, 
        outputs.File{ .path = "game.log" } 
    }),
    .filter = filters.Throttle{},
    .formatter = formatters.Timestamped{},
});

// Simple, clean usage
const log = AppLogger.init(allocator);
log.info("startup", "Game initialized", .{});
log.debug("frame", "Frame rendered", .{});  // Auto-throttled
log.err("critical", "Failed to load: {}", .{error});
```

**Flexible Configuration:**
```zig
// Console-only logger (no file)
const ConsoleLogger = Logger(.{
    .output = outputs.Console{},
    .filter = filters.Passthrough{},
});

// File-only logger with no throttling
const FileLogger = Logger(.{
    .output = outputs.File{ .path = "debug.log" },
    .filter = filters.Passthrough{},
});

// Custom multi-destination
const ProductionLogger = Logger(.{
    .output = outputs.Multi(.{
        outputs.Console{},
        outputs.File{ .path = "game.log" },
        outputs.Network{ .endpoint = "logging.example.com" },
    }),
    .filter = filters.Level{ .min_level = .info },
});
```

## Implementation Plan

### Phase 1: Core Infrastructure
1. **Create `logger.zig`** - Core logger interface with generic composition
2. **Create `outputs/console.zig`** - Console output backend
3. **Create `outputs/file.zig`** - File output with session tracking
4. **Create `outputs/multi.zig`** - Multi-destination compositor
5. **Create `filters/passthrough.zig`** - Identity filter for no filtering

### Phase 2: Advanced Features  
6. **Create `filters/throttle.zig`** - Refactor existing throttling logic
7. **Create `filters/level.zig`** - Log level filtering
8. **Create `formatters/timestamped.zig`** - Current timestamp format
9. **Create barrel exports** - Clean import interface

### Phase 3: Integration
10. **Update `main.zig`** - Replace unified_logger with new Logger
11. **Update call sites** - Replace log_throttle calls with new API
12. **Remove old files** - Delete unified_logger.zig and log_throttle.zig
13. **Update CLAUDE.md** - Document new logging patterns

## Key Design Principles

1. **Separation of Concerns**: Output destinations, filtering policies, and formatting are independent
2. **Compile-Time Composition**: Zero runtime overhead through generic composition
3. **Extensibility**: Easy to add new outputs (network, database), filters, or formatters
4. **Performance**: No virtual calls, compile-time known dispatch
5. **Simplicity**: Clean API that doesn't expose internal complexity
6. **Type Safety**: Compile-time validation of logger configuration

## Benefits

- ✅ **Clear Architecture**: Each component has single responsibility
- ✅ **Configurable**: File output becomes optional configuration choice
- ✅ **Composable**: Mix and match outputs, filters, formatters
- ✅ **Performant**: Compile-time composition, no runtime overhead
- ✅ **Extensible**: Easy to add new backends without changing core
- ✅ **Clean API**: Simple usage that hides internal complexity

## Migration Notes

**Breaking Changes:**
- Remove `unified_logger.zig` and `log_throttle.zig`
- Replace global functions with configured logger instances
- Update all call sites to use new API

**No Backward Compatibility:**
- Clean slate implementation for better architecture
- All existing logging code will need updates
- Clear migration path with improved developer experience

This refactor transforms logging from an ad-hoc collection of utilities into a professional, composable system with clean separation of concerns.