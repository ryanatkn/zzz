# Logging System Guidelines

> ⚠️ AI slop code and docs, is unstable and full of lies

## Architecture

The logging system uses composable components with compile-time configuration for zero runtime overhead.

### Core Components

#### Outputs
- **Console:** Direct stdout/stderr output
- **File:** Persistent file logging with session tracking
- **Multi:** Combine multiple outputs

#### Filters
- **Throttle:** Rate limiting to prevent spam
- **Level:** Filter by severity (debug/info/warn/error)
- **Passthrough:** No filtering (development)

#### Formatters
- **Timestamped:** Add timestamps to messages
- **Passthrough:** Raw message output

## Configuration Patterns

### Main Application Logger
```zig
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

// Console + file with throttling (main.zig pattern)
const AppLogger = Logger(.{
    .output = outputs.Multi(.{ 
        outputs.Console, 
        outputs.File(.{ .path = "game.log" })
    }),
    .filter = filters.Throttle,
});

var logger = AppLogger.init(allocator);
defer logger.deinit();

// Usage
logger.info("startup", "Game initialized", .{});
logger.error("physics", "Collision detection failed: {}", .{error_msg});
```

### Module-Specific Loggers
```zig
// Console-only with throttling for modules
const ModuleLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

var logger = ModuleLogger.init(allocator);
logger.debug("render", "Frame time: {}ms", .{frame_time});
```

### Development Logger
```zig
// Verbose output for debugging
const DevLogger = Logger(.{
    .output = outputs.Multi(.{
        outputs.Console,
        outputs.File(.{ .path = "debug.log" })
    }),
    .filter = filters.Passthrough,
    .formatter = formatters.Timestamped,
});
```

## Log Levels

### Usage Guidelines
- **Debug:** Detailed diagnostic information
- **Info:** General informational messages
- **Warn:** Warning conditions that should be addressed
- **Error:** Error conditions that need immediate attention

### Examples
```zig
logger.debug("ecs", "Entity {} updated position to {},{}", .{id, x, y});
logger.info("game", "Level {} loaded successfully", .{level_num});
logger.warn("resource", "Texture cache at 90% capacity", .{});
logger.error("network", "Connection failed: {}", .{error});
```

## Performance Considerations

### Compile-Time Composition
The logger uses compile-time generics to ensure zero runtime overhead:
```zig
// Configuration is resolved at compile time
const Logger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});
```

### Throttling
Prevents log spam in hot paths:
```zig
// Throttle filter limits identical messages
// Default: 1 message per 100ms for same category/format
logger.debug("physics", "Collision check", .{}); // Printed
logger.debug("physics", "Collision check", .{}); // Throttled
```

### File Output
- Automatic session tracking with timestamps
- Buffered writes for performance
- Rotation support for long-running sessions

## Category Conventions

Use consistent categories for easy filtering:

### System Categories
- `startup` - Initialization messages
- `shutdown` - Cleanup messages
- `config` - Configuration loading/saving

### Engine Categories
- `render` - Rendering pipeline
- `physics` - Physics and collision
- `input` - Input handling
- `audio` - Audio system
- `resource` - Resource loading

### Game Categories
- `game` - Game state and logic
- `ecs` - Entity component system
- `ai` - AI behavior
- `network` - Multiplayer/networking

### Debug Categories
- `perf` - Performance metrics
- `memory` - Memory usage
- `debug` - General debugging

## Integration Patterns

### Conditional Logging
```zig
const debug_mode = @import("builtin").mode == .Debug;

if (debug_mode) {
    logger.debug("verbose", "Detailed state: {}", .{state});
}
```

### Scoped Logging
```zig
pub fn processFrame(logger: *Logger) void {
    logger.info("frame", "Starting frame {}", .{frame_num});
    defer logger.info("frame", "Completed frame {}", .{frame_num});
    
    // Frame processing...
}
```

### Error Logging
```zig
fn loadResource(path: []const u8) !Resource {
    return resource_loader.load(path) catch |err| {
        logger.error("resource", "Failed to load {}: {}", .{path, err});
        return err;
    };
}
```

## File Output Details

### Session Tracking
Log files automatically include session information:
```
=== New Session: 2025-01-15 14:23:45 ===
Platform: Linux x86_64
Zig Version: 0.14.1
Build Mode: Debug
```

### Log Format
```
[timestamp] [level] [category] message
[14:23:45.123] [INFO] [startup] Game initialized
[14:23:45.456] [ERROR] [physics] Collision detection failed: invalid bounds
```

### Rotation Policy
- Files rotate at 10MB by default
- Keep last 5 rotated files
- Configurable via `.log_rotate_size` and `.log_rotate_count`

## Best Practices

### DO
- Use appropriate log levels
- Include relevant context in messages
- Use consistent categories
- Configure per-module loggers
- Throttle high-frequency logs

### DON'T
- Log sensitive information (passwords, keys)
- Use logging for control flow
- Create log messages in tight loops without throttling
- Mix formatting styles within a module
- Ignore error returns from logger methods

## Migration from Old System

### Old Pattern (Deprecated)
```zig
std.log.info("Message", .{});
std.debug.print("Debug: {}\n", .{value});
```

### New Pattern
```zig
logger.info("category", "Message", .{});
logger.debug("category", "Debug: {}", .{value});
```

### Benefits
- Structured categories
- Compile-time configuration
- Multiple outputs
- Automatic throttling
- Session tracking

## Troubleshooting

### Common Issues

#### No Output
- Check filter configuration (not filtering too aggressively)
- Verify output is properly initialized
- Ensure logger.init() was called

#### Performance Impact
- Enable throttling for high-frequency logs
- Use appropriate log levels (debug only in debug builds)
- Consider conditional compilation for verbose logging

#### File Permission Errors
- Ensure write permissions for log directory
- Check disk space availability
- Verify file isn't locked by another process