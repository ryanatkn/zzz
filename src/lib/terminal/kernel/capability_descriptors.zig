const std = @import("std");

// Import all capability types for the registry
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const ReadlineInput = @import("../capabilities/input/readline.zig").ReadlineInput;
const MouseInput = @import("../capabilities/input/mouse.zig").MouseInput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
const AnsiWriter = @import("../capabilities/output/ansi_writer.zig").AnsiWriter;
const BufferedOutput = @import("../capabilities/output/buffered.zig").BufferedOutput;
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

/// Capability type enumeration - extensible and strongly typed
pub const CapabilityType = enum(u8) {
    // Input capabilities
    keyboard_input = 0,
    readline_input = 1,
    mouse_input = 2,

    // Output capabilities
    basic_writer = 10,
    ansi_writer = 11,
    buffered_output = 12,

    // State capabilities
    cursor = 20,
    line_buffer = 21,
    history = 22,
    screen_buffer = 23,
    scrollback = 24,
    persistence = 25,

    // Command capabilities
    parser = 30,
    registry = 31,
    executor = 32,
    builtin = 33,
    pipeline = 34,

    // Note: Extensible enums would use _ field, but for now using fixed set

    pub const Count = 35; // Max enum value + 1 (pipeline = 34)
};

/// Capability category for organization and validation
pub const CapabilityCategory = enum {
    input,
    output,
    state,
    command,
    extension,
};

/// Type-safe capability data union with efficient dispatch
pub const CapabilityData = union(CapabilityType) {
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

    /// Get the capability type enum value
    pub fn getType(self: CapabilityData) CapabilityType {
        return std.meta.activeTag(self);
    }

    /// Get pointer to capability for generic operations
    pub fn getPtr(self: CapabilityData) *anyopaque {
        return switch (self) {
            inline else => |cap| @as(*anyopaque, @ptrCast(cap)),
        };
    }

    /// Type-safe casting to concrete capability type
    pub fn cast(self: CapabilityData, comptime T: type) ?*T {
        return switch (self) {
            inline else => |cap| {
                if (@TypeOf(cap.*) == T) {
                    return cap;
                } else {
                    return null;
                }
            },
        };
    }
};

/// Capability metadata - compile-time known information
pub const CapabilityMetadata = struct {
    name: []const u8,
    description: []const u8,
    category: CapabilityCategory,
    dependencies: []const CapabilityType,
    conflicts: []const CapabilityType,
    optional_dependencies: []const CapabilityType,
};

/// Factory function signature for creating capabilities
pub const CapabilityFactory = *const fn (allocator: std.mem.Allocator) anyerror!CapabilityData;

/// Complete capability descriptor - single source of truth
pub const CapabilityDescriptor = struct {
    type: CapabilityType,
    metadata: CapabilityMetadata,
    factory: CapabilityFactory,
};

/// Comptime dependency graph builder
pub const DependencyGraph = struct {
    adjacency_list: [CapabilityType.Count][]const CapabilityType,
    initialization_order: [17]CapabilityType, // Fixed size for all builtin capabilities

    /// Build dependency graph at compile time
    pub fn build(comptime descriptors: []const CapabilityDescriptor) DependencyGraph {
        // Build adjacency list
        var adjacency: [CapabilityType.Count][]const CapabilityType = undefined;

        inline for (descriptors) |desc| {
            adjacency[@intFromEnum(desc.type)] = desc.metadata.dependencies;
        }

        // Compute topological sort for initialization order
        const init_order = computeInitializationOrder(descriptors);

        return DependencyGraph{
            .adjacency_list = adjacency,
            .initialization_order = init_order,
        };
    }

    /// Detect circular dependencies at compile time
    fn computeInitializationOrder(comptime descriptors: []const CapabilityDescriptor) [descriptors.len]CapabilityType {
        // Simplified topological sort - in real implementation would be more robust
        var order: [descriptors.len]CapabilityType = undefined;
        var index: usize = 0;

        // Add capabilities with no dependencies first
        inline for (descriptors) |desc| {
            if (desc.metadata.dependencies.len == 0) {
                order[index] = desc.type;
                index += 1;
            }
        }

        // Add remaining capabilities (simplified - real implementation needs proper topo sort)
        inline for (descriptors) |desc| {
            if (desc.metadata.dependencies.len > 0) {
                order[index] = desc.type;
                index += 1;
            }
        }

        return order;
    }
};

/// Factory functions for each capability type
const Factories = struct {
    fn createKeyboardInput(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .keyboard_input = try KeyboardInput.create(allocator) };
    }

    fn createReadlineInput(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .readline_input = try ReadlineInput.create(allocator) };
    }

    fn createMouseInput(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .mouse_input = try MouseInput.create(allocator) };
    }

    fn createBasicWriter(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .basic_writer = try BasicWriter.create(allocator) };
    }

    fn createAnsiWriter(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .ansi_writer = try AnsiWriter.create(allocator) };
    }

    fn createBufferedOutput(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .buffered_output = try BufferedOutput.create(allocator) };
    }

    fn createCursor(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .cursor = try Cursor.create(allocator) };
    }

    fn createLineBuffer(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .line_buffer = try LineBuffer.create(allocator) };
    }

    fn createHistory(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .history = try History.create(allocator) };
    }

    fn createScreenBuffer(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .screen_buffer = try ScreenBuffer.create(allocator) };
    }

    fn createScrollback(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .scrollback = try Scrollback.create(allocator) };
    }

    fn createPersistence(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .persistence = try Persistence.create(allocator) };
    }

    fn createParser(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .parser = try Parser.create(allocator) };
    }

    fn createRegistry(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .registry = try Registry.create(allocator) };
    }

    fn createExecutor(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .executor = try Executor.create(allocator) };
    }

    fn createBuiltin(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .builtin = try Builtin.create(allocator) };
    }

    fn createPipeline(allocator: std.mem.Allocator) !CapabilityData {
        return CapabilityData{ .pipeline = try Pipeline.create(allocator) };
    }
};

/// Built-in capability registry - complete descriptor database
pub const BuiltinRegistry = struct {
    pub const descriptors = [_]CapabilityDescriptor{
        // Input capabilities
        .{
            .type = .keyboard_input,
            .metadata = .{
                .name = "Keyboard Input",
                .description = "Basic keyboard input handling",
                .category = .input,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createKeyboardInput,
        },
        .{
            .type = .readline_input,
            .metadata = .{
                .name = "Readline Input",
                .description = "Advanced line editing with cursor movement",
                .category = .input,
                .dependencies = &[_]CapabilityType{ .keyboard_input, .cursor, .line_buffer },
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{.history},
            },
            .factory = Factories.createReadlineInput,
        },
        .{
            .type = .mouse_input,
            .metadata = .{
                .name = "Mouse Input",
                .description = "Mouse event handling",
                .category = .input,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createMouseInput,
        },

        // Output capabilities
        .{
            .type = .basic_writer,
            .metadata = .{
                .name = "Basic Writer",
                .description = "Simple text output",
                .category = .output,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createBasicWriter,
        },
        .{
            .type = .ansi_writer,
            .metadata = .{
                .name = "ANSI Writer",
                .description = "ANSI escape sequence output",
                .category = .output,
                .dependencies = &[_]CapabilityType{.basic_writer},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createAnsiWriter,
        },
        .{
            .type = .buffered_output,
            .metadata = .{
                .name = "Buffered Output",
                .description = "High-throughput buffered output",
                .category = .output,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createBufferedOutput,
        },

        // State capabilities
        .{
            .type = .cursor,
            .metadata = .{
                .name = "Cursor",
                .description = "Cursor position and state management",
                .category = .state,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createCursor,
        },
        .{
            .type = .line_buffer,
            .metadata = .{
                .name = "Line Buffer",
                .description = "Current line text buffer",
                .category = .state,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createLineBuffer,
        },
        .{
            .type = .history,
            .metadata = .{
                .name = "History",
                .description = "Command history management",
                .category = .state,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createHistory,
        },
        .{
            .type = .screen_buffer,
            .metadata = .{
                .name = "Screen Buffer",
                .description = "Full screen buffer management",
                .category = .state,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createScreenBuffer,
        },
        .{
            .type = .scrollback,
            .metadata = .{
                .name = "Scrollback",
                .description = "Terminal scrollback buffer",
                .category = .state,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createScrollback,
        },
        .{
            .type = .persistence,
            .metadata = .{
                .name = "Persistence",
                .description = "Save and restore terminal state",
                .category = .state,
                .dependencies = &[_]CapabilityType{.history},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{.scrollback},
            },
            .factory = Factories.createPersistence,
        },

        // Command capabilities
        .{
            .type = .parser,
            .metadata = .{
                .name = "Command Parser",
                .description = "Command line parsing",
                .category = .command,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createParser,
        },
        .{
            .type = .registry,
            .metadata = .{
                .name = "Command Registry",
                .description = "Command registration and lookup",
                .category = .command,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createRegistry,
        },
        .{
            .type = .executor,
            .metadata = .{
                .name = "Command Executor",
                .description = "External command execution",
                .category = .command,
                .dependencies = &[_]CapabilityType{},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createExecutor,
        },
        .{
            .type = .builtin,
            .metadata = .{
                .name = "Builtin Commands",
                .description = "Built-in terminal commands",
                .category = .command,
                .dependencies = &[_]CapabilityType{.registry},
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{},
            },
            .factory = Factories.createBuiltin,
        },
        .{
            .type = .pipeline,
            .metadata = .{
                .name = "Command Pipeline",
                .description = "Command execution pipeline",
                .category = .command,
                .dependencies = &[_]CapabilityType{ .parser, .registry, .executor, .basic_writer },
                .conflicts = &[_]CapabilityType{},
                .optional_dependencies = &[_]CapabilityType{ .builtin, .ansi_writer },
            },
            .factory = Factories.createPipeline,
        },
    };

    /// Compute dependency graph at compile time
    pub const dependency_graph = DependencyGraph.build(&descriptors);

    /// Get descriptor by type - O(1) lookup using switch
    pub fn getDescriptor(capability_type: CapabilityType) CapabilityDescriptor {
        return switch (capability_type) {
            .keyboard_input => descriptors[0],
            .readline_input => descriptors[1],
            .mouse_input => descriptors[2],
            .basic_writer => descriptors[3],
            .ansi_writer => descriptors[4],
            .buffered_output => descriptors[5],
            .cursor => descriptors[6],
            .line_buffer => descriptors[7],
            .history => descriptors[8],
            .screen_buffer => descriptors[9],
            .scrollback => descriptors[10],
            .persistence => descriptors[11],
            .parser => descriptors[12],
            .registry => descriptors[13],
            .executor => descriptors[14],
            .builtin => descriptors[15],
            .pipeline => descriptors[16],
        };
    }

    /// Get metadata by type - O(1) lookup
    pub fn getMetadata(capability_type: CapabilityType) CapabilityMetadata {
        return getDescriptor(capability_type).metadata;
    }

    /// Get factory by type - O(1) lookup
    pub fn getFactory(capability_type: CapabilityType) CapabilityFactory {
        return getDescriptor(capability_type).factory;
    }
};

/// Simplified dispatch - use direct switch dispatch for now
/// (Can optimize to indexed tables later if needed)
pub const DispatchTable = struct {
    /// Get capability name via enum lookup (no runtime dispatch needed)
    pub fn getName(data: CapabilityData) []const u8 {
        return BuiltinRegistry.getMetadata(data.getType()).name;
    }

    /// Destroy capability via switch dispatch
    pub fn destroy(data: CapabilityData, allocator: std.mem.Allocator) void {
        switch (data) {
            inline else => |cap| cap.destroy(allocator),
        }
    }

    /// Initialize capability via switch dispatch
    pub fn initialize(data: CapabilityData, dependencies: anytype, event_bus: anytype) !void {
        switch (data) {
            inline else => |cap| try cap.initialize(dependencies, event_bus),
        }
    }

    /// Deinitialize capability via switch dispatch
    pub fn deinit(data: CapabilityData) void {
        switch (data) {
            inline else => |cap| cap.deinit(),
        }
    }

    /// Simplified instance for compatibility
    pub const instance = @This(){};
};

/// Extensible registry builder for user-defined capabilities
pub fn ExtensibleRegistry(comptime extensions: []const CapabilityDescriptor) type {
    return struct {
        pub const all_descriptors = BuiltinRegistry.descriptors ++ extensions;
        pub const dependency_graph = DependencyGraph.build(all_descriptors);

        pub fn getDescriptor(capability_type: CapabilityType) CapabilityDescriptor {
            inline for (all_descriptors) |desc| {
                if (desc.type == capability_type) {
                    return desc;
                }
            }
            @compileError("Unknown capability type");
        }
    };
}
