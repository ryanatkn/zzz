// Terminal Kernel - Micro-Kernel Architecture for Terminal Capabilities
//
// This kernel provides the foundational interfaces and event system for building
// composable terminal implementations. The kernel is designed to be minimal and
// focused on enabling capability composition.
//
// Architecture Principles:
// - Interface-based design for maximum composability
// - Zero-allocation event system using fixed buffers
// - Dependency resolution for capability initialization
// - Decoupled communication via event bus

const std = @import("std");

// Core kernel components
pub const terminal_trait = @import("terminal_trait.zig");
pub const events = @import("events.zig");
pub const typesafe = @import("typesafe_capabilities.zig");

// Primary interfaces
pub const ITerminal = terminal_trait.ITerminal;

// Type-safe capability system (now the primary system)
pub const TypeSafeCapability = typesafe.TypeSafeCapability;
pub const CapabilityData = typesafe.CapabilityData;
pub const TypeSafeCapabilityRegistry = typesafe.TypeSafeCapabilityRegistry;
pub const createCapability = typesafe.createCapability;

// Legacy compatibility
pub const CapabilityRegistry = TypeSafeCapabilityRegistry;

// Event system
pub const Event = events.Event;
pub const EventType = events.EventType;
pub const EventData = events.EventData;
pub const EventBus = events.EventBus;
pub const EventCallback = events.EventCallback;

// Event data types
pub const SpecialKey = events.SpecialKey;
pub const KeyInput = events.KeyInput;
pub const ComponentType = events.ComponentType;
pub const LineBufferState = events.LineBufferState;
pub const CursorState = events.CursorState;
pub const WriterState = events.WriterState;
pub const StateChangeType = events.StateChangeType;

// Input/output types
pub const InputEvent = terminal_trait.InputEvent;
pub const KeyEvent = terminal_trait.KeyEvent;
pub const MouseEvent = terminal_trait.MouseEvent;
pub const ResizeEvent = terminal_trait.ResizeEvent;
pub const Key = terminal_trait.Key;
pub const KeyModifiers = terminal_trait.KeyModifiers;
pub const MouseButton = terminal_trait.MouseButton;
pub const MouseAction = terminal_trait.MouseAction;

// Utilities
pub const RingBuffer = @import("../core.zig").RingBuffer;

// Kernel version information
pub const VERSION = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

/// Initialize a new capability registry
pub fn createRegistry(allocator: std.mem.Allocator) !*TypeSafeCapabilityRegistry {
    const registry = try allocator.create(TypeSafeCapabilityRegistry);
    registry.* = TypeSafeCapabilityRegistry.init(allocator);
    return registry;
}

/// Utility function to create a terminal interface from implementation
pub fn createTerminal(implementation: anytype) ITerminal {
    const T = @TypeOf(implementation.*);

    const vtable = &ITerminal.VTable{
        .write = struct {
            fn write(ptr: *anyopaque, text: []const u8) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.write(text);
            }
        }.write,

        .read = struct {
            fn read(ptr: *anyopaque, buffer: []u8) !usize {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.read(buffer);
            }
        }.read,

        .clear = struct {
            fn clear(ptr: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.clear();
            }
        }.clear,

        .resize = struct {
            fn resize(ptr: *anyopaque, columns: usize, rows: usize) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.resize(columns, rows);
            }
        }.resize,

        .handleInput = struct {
            fn handleInput(ptr: *anyopaque, input: InputEvent) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.handleInput(input);
            }
        }.handleInput,

        .hasCapability = struct {
            fn hasCapability(ptr: *anyopaque, capability: []const u8) bool {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.hasCapability(capability);
            }
        }.hasCapability,

        .getCapability = struct {
            fn getCapability(ptr: *anyopaque, capability: []const u8) ?*anyopaque {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.getCapability(capability);
            }
        }.getCapability,

        .emit = struct {
            fn emit(ptr: *anyopaque, event: Event) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.emit(event);
            }
        }.emit,

        .subscribe = struct {
            fn subscribe(ptr: *anyopaque, event_type: EventType, callback: EventCallback) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.subscribe(event_type, callback);
            }
        }.subscribe,

        .deinit = struct {
            fn deinit(ptr: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.deinit();
            }
        }.deinit,
    };

    return ITerminal{
        .ptr = implementation,
        .vtable = vtable,
    };
}
