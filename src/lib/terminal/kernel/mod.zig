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
pub const registry = @import("registry.zig");

// Primary interfaces
pub const ITerminal = terminal_trait.ITerminal;
pub const ICapability = registry.ICapability;

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

// Registry
pub const CapabilityRegistry = registry.CapabilityRegistry;

// Utilities
pub const RingBuffer = @import("../core.zig").RingBuffer;

// Kernel version information
pub const VERSION = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

/// Initialize a new capability registry
pub fn createRegistry(allocator: std.mem.Allocator) CapabilityRegistry {
    return CapabilityRegistry.init(allocator);
}

/// Create event bus for capability communication
pub fn createEventBus(allocator: std.mem.Allocator) events.EventBus {
    return events.EventBus.init(allocator);
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

/// Utility function to create a capability interface from implementation
pub fn createCapability(implementation: anytype) ICapability {
    const T = @TypeOf(implementation.*);
    
    const vtable = &ICapability.VTable{
        .getName = struct {
            fn getName(ptr: *anyopaque) []const u8 {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.getName();
            }
        }.getName,
        
        .getType = struct {
            fn getType(ptr: *anyopaque) []const u8 {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.getType();
            }
        }.getType,
        
        .getDependencies = struct {
            fn getDependencies(ptr: *anyopaque) []const []const u8 {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.getDependencies();
            }
        }.getDependencies,
        
        .init = struct {
            fn init(ptr: *anyopaque, dependencies: []const ICapability, event_bus: *events.EventBus) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.initialize(dependencies, event_bus);
            }
        }.init,
        
        .deinit = struct {
            fn deinit(ptr: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.deinit();
            }
        }.deinit,
        
        .isActive = struct {
            fn isActive(ptr: *anyopaque) bool {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.isActive();
            }
        }.isActive,
    };

    return ICapability{
        .ptr = implementation,
        .vtable = vtable,
    };
}