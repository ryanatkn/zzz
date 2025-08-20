const std = @import("std");
const events = @import("events.zig");

/// Core terminal interface that all terminal implementations must support
pub const ITerminal = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Write text to terminal output
        write: *const fn (ptr: *anyopaque, text: []const u8) anyerror!void,

        /// Read input from terminal (non-blocking)
        read: *const fn (ptr: *anyopaque, buffer: []u8) anyerror!usize,

        /// Clear terminal display
        clear: *const fn (ptr: *anyopaque) void,

        /// Resize terminal dimensions
        resize: *const fn (ptr: *anyopaque, columns: usize, rows: usize) void,

        /// Handle input event
        handleInput: *const fn (ptr: *anyopaque, input: InputEvent) anyerror!void,

        /// Check if capability is supported
        hasCapability: *const fn (ptr: *anyopaque, capability: []const u8) bool,

        /// Get capability instance
        getCapability: *const fn (ptr: *anyopaque, capability: []const u8) ?*anyopaque,

        /// Emit event to subscribed capabilities
        emit: *const fn (ptr: *anyopaque, event: events.Event) anyerror!void,

        /// Subscribe to event type
        subscribe: *const fn (ptr: *anyopaque, event_type: events.EventType, callback: events.EventCallback) anyerror!void,

        /// Cleanup terminal resources
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn write(self: ITerminal, text: []const u8) !void {
        return self.vtable.write(self.ptr, text);
    }

    pub fn read(self: ITerminal, buffer: []u8) !usize {
        return self.vtable.read(self.ptr, buffer);
    }

    pub fn clear(self: ITerminal) void {
        self.vtable.clear(self.ptr);
    }

    pub fn resize(self: ITerminal, columns: usize, rows: usize) void {
        self.vtable.resize(self.ptr, columns, rows);
    }

    pub fn handleInput(self: ITerminal, input: InputEvent) !void {
        return self.vtable.handleInput(self.ptr, input);
    }

    pub fn hasCapability(self: ITerminal, capability: []const u8) bool {
        return self.vtable.hasCapability(self.ptr, capability);
    }

    pub fn getCapability(self: ITerminal, capability: []const u8) ?*anyopaque {
        return self.vtable.getCapability(self.ptr, capability);
    }

    pub fn emit(self: ITerminal, event: events.Event) !void {
        return self.vtable.emit(self.ptr, event);
    }

    pub fn subscribe(self: ITerminal, event_type: events.EventType, callback: events.EventCallback) !void {
        return self.vtable.subscribe(self.ptr, event_type, callback);
    }

    pub fn deinit(self: ITerminal) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Input event types for terminal interface
pub const InputEvent = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: ResizeEvent,
};

pub const KeyEvent = struct {
    key: Key,
    modifiers: KeyModifiers,
};

pub const MouseEvent = struct {
    x: i32,
    y: i32,
    button: MouseButton,
    action: MouseAction,
};

pub const ResizeEvent = struct {
    columns: usize,
    rows: usize,
};

pub const Key = union(enum) {
    char: u8,
    backspace,
    delete,
    enter,
    tab,
    escape,
    up_arrow,
    down_arrow,
    left_arrow,
    right_arrow,
    home,
    end,
    page_up,
    page_down,
    ctrl_c,
    ctrl_d,
    ctrl_l,
    ctrl_z,
};

pub const KeyModifiers = packed struct {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
    meta: bool = false,
};

pub const MouseButton = enum {
    left,
    right,
    middle,
    wheel_up,
    wheel_down,
};

pub const MouseAction = enum {
    press,
    release,
    move,
};
