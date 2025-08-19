# Terminal Library - AI Assistant Guide

Micro-kernel architecture with composable capabilities for building terminals.

## Architecture

```
kernel/     - Core interfaces (ICapability, ITerminal, EventBus, Registry)
capabilities/
  input/    - keyboard.zig
  output/   - basic_writer.zig, ansi_writer.zig  
  state/    - line_buffer.zig, cursor.zig, history.zig, screen_buffer.zig, scrollback.zig, persistence.zig
  commands/ - parser.zig, registry.zig, executor.zig, builtin.zig, pipeline.zig
presets/    - minimal.zig, standard.zig, command.zig
```

## Key Patterns

**Capability Interface:**
```zig
pub fn create(allocator) !*Self        // Factory creation
pub fn destroy(self, allocator) void   // Factory destruction  
pub fn getName() []const u8
pub fn getType() []const u8
pub fn getDependencies() []const []const u8
pub fn initialize(deps, event_bus) !void
pub fn deinit() void                   // Called by registry
pub fn isActive() bool
```

**Memory Management:**
- Registry calls `capability.deinit()` for cleanup
- Preset calls `allocator.destroy()` after registry cleanup
- EnvMap handles its own string memory (don't manually free)

**Known Issues:**
- Capability pointer alignment errors - use workarounds in pipeline.zig
- TODO: Fix alignment for proper pointer casting

## Usage

```zig
// Minimal
var terminal = try MinimalTerminal.init(allocator);
defer terminal.deinit();

// With commands  
var terminal = try CommandTerminal.init(allocator);
defer terminal.deinit();
try terminal.executeCommand("ls -la");
```

## Testing

```bash
zig build test                    # All tests (226 passing)
zig build test -Dtest-filter="X"  # Specific tests
```

## Status

✅ Phase 1-4 complete: 14 capabilities, 3 presets, production ready