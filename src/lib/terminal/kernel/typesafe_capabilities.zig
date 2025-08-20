const std = @import("std");
const events = @import("events.zig");

// Import all capability types
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const ReadlineInput = @import("../capabilities/input/readline.zig").ReadlineInput;
const MouseInput = @import("../capabilities/input/mouse.zig").MouseInput;
const BufferedOutput = @import("../capabilities/output/buffered.zig").BufferedOutput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
const AnsiWriter = @import("../capabilities/output/ansi_writer.zig").AnsiWriter;
const Cursor = @import("../capabilities/state/cursor.zig").Cursor;
const LineBuffer = @import("../capabilities/state/line_buffer.zig").LineBuffer;
const History = @import("../capabilities/state/history.zig").History;
const ScreenBuffer = @import("../capabilities/state/screen_buffer.zig").ScreenBuffer;
const Scrollback = @import("../capabilities/state/scrollback.zig").Scrollback;
const Persistence = @import("../capabilities/state/persistence.zig").Persistence;
const Parser = @import("../capabilities/commands/parser.zig").Parser;
const Registry = @import("../capabilities/commands/registry.zig").Registry;
const Executor = @import("../capabilities/commands/executor.zig").Executor;
const Builtin = @import("../capabilities/commands/builtin.zig").Builtin;
const Pipeline = @import("../capabilities/commands/pipeline.zig").Pipeline;

/// Type-safe capability storage using tagged union
pub const CapabilityData = union(enum) {
    // Input capabilities
    keyboard_input: *KeyboardInput,
    readline_input: *ReadlineInput,
    mouse_input: *MouseInput,

    // Output capabilities
    basic_writer: *BasicWriter,
    ansi_writer: *AnsiWriter,
    buffered_output: *BufferedOutput,

    // State capabilities
    cursor: *Cursor,
    line_buffer: *LineBuffer,
    history: *History,
    screen_buffer: *ScreenBuffer,
    scrollback: *Scrollback,
    persistence: *Persistence,

    // Command capabilities
    parser: *Parser,
    registry: *Registry,
    executor: *Executor,
    builtin: *Builtin,
    pipeline: *Pipeline,

    /// Type-safe casting with compile-time validation
    pub fn cast(self: CapabilityData, comptime T: type) ?*T {
        return switch (self) {
            inline else => |capability| {
                if (@TypeOf(capability.*) == T) {
                    return capability;
                } else {
                    return null;
                }
            },
        };
    }

    /// Get the concrete pointer type for vtable operations
    pub fn getPtr(self: CapabilityData) *anyopaque {
        return switch (self) {
            inline else => |capability| @as(*anyopaque, @ptrCast(capability)),
        };
    }

    /// Get capability name via dispatch to concrete type
    pub fn getName(self: CapabilityData) []const u8 {
        return switch (self) {
            inline else => |capability| capability.getName(),
        };
    }

    /// Get capability type via dispatch to concrete type
    pub fn getType(self: CapabilityData) []const u8 {
        return switch (self) {
            inline else => |capability| capability.getType(),
        };
    }

    /// Get dependencies via dispatch to concrete type
    pub fn getDependencies(self: CapabilityData) []const []const u8 {
        return switch (self) {
            inline else => |capability| capability.getDependencies(),
        };
    }

    /// Initialize via dispatch to concrete type
    pub fn initialize(self: CapabilityData, dependencies: []const TypeSafeCapability, event_bus: *events.EventBus) !void {
        return switch (self) {
            inline else => |capability| capability.initialize(dependencies, event_bus),
        };
    }

    /// Deinitialize via dispatch to concrete type
    pub fn deinit(self: CapabilityData) void {
        switch (self) {
            inline else => |capability| capability.deinit(),
        }
    }

    /// Check if active via dispatch to concrete type
    pub fn isActive(self: CapabilityData) bool {
        return switch (self) {
            inline else => |capability| capability.isActive(),
        };
    }
};

/// Type-safe capability interface - replaces ICapability
pub const TypeSafeCapability = struct {
    data: CapabilityData,
    name: []const u8,

    /// Type-safe casting with compile-time validation
    pub fn cast(self: TypeSafeCapability, comptime T: type) ?*T {
        return self.data.cast(T);
    }

    /// Require a specific capability type (panics if wrong type)
    pub fn require(self: TypeSafeCapability, comptime T: type) *T {
        return self.cast(T) orelse std.debug.panic("Expected capability of type {s}, got {s}", .{ @typeName(T), self.data.getName() });
    }

    // Delegate interface methods to the data union
    pub fn getName(self: TypeSafeCapability) []const u8 {
        return self.data.getName();
    }

    pub fn getType(self: TypeSafeCapability) []const u8 {
        return self.data.getType();
    }

    pub fn getDependencies(self: TypeSafeCapability) []const []const u8 {
        return self.data.getDependencies();
    }

    pub fn initialize(self: TypeSafeCapability, dependencies: []const TypeSafeCapability, event_bus: *events.EventBus) !void {
        return self.data.initialize(dependencies, event_bus);
    }

    pub fn deinit(self: TypeSafeCapability) void {
        self.data.deinit();
    }

    pub fn isActive(self: TypeSafeCapability) bool {
        return self.data.isActive();
    }
};

/// Compile-time capability creation with type safety
pub fn createCapability(implementation: anytype) TypeSafeCapability {
    const T = @TypeOf(implementation.*);
    const name = implementation.getName();

    const data = switch (T) {
        KeyboardInput => CapabilityData{ .keyboard_input = implementation },
        ReadlineInput => CapabilityData{ .readline_input = implementation },
        MouseInput => CapabilityData{ .mouse_input = implementation },
        BasicWriter => CapabilityData{ .basic_writer = implementation },
        BufferedOutput => CapabilityData{ .buffered_output = implementation },
        AnsiWriter => CapabilityData{ .ansi_writer = implementation },
        Cursor => CapabilityData{ .cursor = implementation },
        LineBuffer => CapabilityData{ .line_buffer = implementation },
        History => CapabilityData{ .history = implementation },
        ScreenBuffer => CapabilityData{ .screen_buffer = implementation },
        Scrollback => CapabilityData{ .scrollback = implementation },
        Persistence => CapabilityData{ .persistence = implementation },
        Parser => CapabilityData{ .parser = implementation },
        Registry => CapabilityData{ .registry = implementation },
        Executor => CapabilityData{ .executor = implementation },
        Builtin => CapabilityData{ .builtin = implementation },
        Pipeline => CapabilityData{ .pipeline = implementation },
        else => @compileError("Unsupported capability type: " ++ @typeName(T)),
    };

    return TypeSafeCapability{
        .data = data,
        .name = name,
    };
}

/// Type-safe capability registry
pub const TypeSafeCapabilityRegistry = struct {
    entries: [MAX_CAPABILITIES]CapabilityEntry,
    entry_count: usize,
    allocator: std.mem.Allocator,
    event_bus: events.EventBus,

    const MAX_CAPABILITIES = 32;

    const CapabilityEntry = struct {
        name: []const u8,
        capability: TypeSafeCapability,
        initialized: bool,
        dependencies_resolved: bool,
    };

    pub fn init(allocator: std.mem.Allocator) TypeSafeCapabilityRegistry {
        const registry = TypeSafeCapabilityRegistry{
            .entries = undefined,
            .entry_count = 0,
            .allocator = allocator,
            .event_bus = events.EventBus.init(allocator),
        };
        
        return registry;
    }

    pub fn deinit(self: *TypeSafeCapabilityRegistry) void {
        // Deinitialize all capabilities in reverse order
        var i = self.entry_count;
        while (i > 0) {
            i -= 1;
            if (self.entries[i].initialized) {
                self.entries[i].capability.deinit();
            }
        }
    }

    /// Register a new capability
    pub fn register(self: *TypeSafeCapabilityRegistry, name: []const u8, capability: TypeSafeCapability) !void {
        if (self.entry_count >= MAX_CAPABILITIES) {
            return error.TooManyCapabilities;
        }

        // Check for duplicate names
        for (self.entries[0..self.entry_count]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return error.CapabilityAlreadyExists;
            }
        }

        self.entries[self.entry_count] = CapabilityEntry{
            .name = name,
            .capability = capability,
            .initialized = false,
            .dependencies_resolved = false,
        };
        self.entry_count += 1;
    }

    /// Get capability by name
    pub fn getCapability(self: *const TypeSafeCapabilityRegistry, name: []const u8) ?TypeSafeCapability {
        for (self.entries[0..self.entry_count]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.capability;
            }
        }
        return null;
    }

    /// Get capability with compile-time type checking
    pub fn getCapabilityTyped(self: *const TypeSafeCapabilityRegistry, comptime T: type) ?*T {
        const capability_name = T.name;
        const capability = self.getCapability(capability_name) orelse return null;
        return capability.cast(T);
    }

    /// Require a capability (panics if not found)
    pub fn requireCapability(self: *const TypeSafeCapabilityRegistry, comptime T: type) *T {
        return self.getCapabilityTyped(T) orelse std.debug.panic("Required capability not found: {s}", .{T.name});
    }

    /// Check if capability exists
    pub fn hasCapability(self: *const TypeSafeCapabilityRegistry, name: []const u8) bool {
        return self.getCapability(name) != null;
    }

    /// Initialize all capabilities with dependency resolution
    pub fn initializeAll(self: *TypeSafeCapabilityRegistry) !void {
        // Initialize in dependency order
        var initialized_any = true;
        while (initialized_any) {
            initialized_any = false;
            // Re-resolve dependencies each iteration since they depend on what's initialized
            try self.resolveDependencies();

            for (self.entries[0..self.entry_count]) |*entry| {
                if (!entry.initialized and entry.dependencies_resolved) {
                    try self.initializeCapability(entry);
                    initialized_any = true;
                }
            }
        }

        // Check for uninitialized capabilities (circular dependencies)
        for (self.entries[0..self.entry_count]) |entry| {
            if (!entry.initialized) {
                return error.CircularDependency;
            }
        }
    }

    /// Resolve dependencies for all capabilities
    fn resolveDependencies(self: *TypeSafeCapabilityRegistry) !void {
        for (self.entries[0..self.entry_count]) |*entry| {
            entry.dependencies_resolved = self.canResolveDependencies(entry.capability);
        }
    }

    /// Check if capability dependencies can be resolved
    fn canResolveDependencies(self: *const TypeSafeCapabilityRegistry, capability: TypeSafeCapability) bool {
        const deps = capability.getDependencies();
        for (deps) |dep_name| {
            // Check if dependency exists and is already initialized
            var found_and_initialized = false;
            for (self.entries[0..self.entry_count]) |entry| {
                if (std.mem.eql(u8, entry.name, dep_name) and entry.initialized) {
                    found_and_initialized = true;
                    break;
                }
            }
            if (!found_and_initialized) {
                return false;
            }
        }
        return true;
    }

    /// Initialize a single capability with its dependencies
    fn initializeCapability(self: *TypeSafeCapabilityRegistry, entry: *CapabilityEntry) !void {
        const deps = entry.capability.getDependencies();
        var resolved_deps = std.ArrayList(TypeSafeCapability).init(self.allocator);
        defer resolved_deps.deinit();

        // Collect resolved dependencies
        for (deps) |dep_name| {
            if (self.getCapability(dep_name)) |dep_cap| {
                try resolved_deps.append(dep_cap);
            } else {
                return error.UnresolvedDependency;
            }
        }

        // Initialize capability
        try entry.capability.initialize(resolved_deps.items, &self.event_bus);
        entry.initialized = true;
    }

    /// Get event bus for capability communication
    pub fn getEventBus(self: *TypeSafeCapabilityRegistry) *events.EventBus {
        return &self.event_bus;
    }

    /// Get count of registered capabilities
    pub fn getCapabilityCount(self: *const TypeSafeCapabilityRegistry) usize {
        return self.entry_count;
    }

    /// Get count of initialized capabilities
    pub fn getInitializedCount(self: *const TypeSafeCapabilityRegistry) usize {
        var count: usize = 0;
        for (self.entries[0..self.entry_count]) |entry| {
            if (entry.initialized) count += 1;
        }
        return count;
    }
};

// Tests
test "TypeSafeCapability creation and casting" {
    // Test would require actual capability instances - this is a placeholder
    // showing the expected API usage

    // const allocator = std.testing.allocator;
    // const keyboard = try KeyboardInput.create(allocator);
    // defer keyboard.destroy(allocator);
    //
    // const capability = createCapability(keyboard);
    // try std.testing.expect(capability.cast(KeyboardInput) != null);
    // try std.testing.expect(capability.cast(BasicWriter) == null);
}

test "TypeSafeCapabilityRegistry operations" {
    const allocator = std.testing.allocator;

    var registry = TypeSafeCapabilityRegistry.init(allocator);
    defer registry.deinit();

    try std.testing.expect(registry.getCapabilityCount() == 0);
    try std.testing.expect(!registry.hasCapability("test"));
}
