const std = @import("std");

/// Event listener helper for easier registration and cleanup
pub fn EventListener(comptime EventType: type) type {
    return struct {
        const Self = @This();

        event_system: *anyopaque,
        callbacks: std.ArrayList(CallbackEntry),
        allocator: std.mem.Allocator,

        const CallbackEntry = struct {
            event_tag: @typeInfo(EventType).@"union".tag_type.?,
            callback: *const fn (event: EventType, ctx: ?*anyopaque) void,
            context: ?*anyopaque,
        };

        pub fn init(allocator: std.mem.Allocator, event_system: *anyopaque) Self {
            return .{
                .event_system = event_system,
                .callbacks = std.ArrayList(CallbackEntry).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.callbacks.deinit();
        }

        /// Register a callback and track it for later cleanup
        pub fn on(self: *Self, event_tag: @typeInfo(EventType).@"union".tag_type.?, callback: *const fn (EventType, ?*anyopaque) void, context: ?*anyopaque) !void {
            try self.callbacks.append(.{
                .event_tag = event_tag,
                .callback = callback,
                .context = context,
            });

            // Register with the actual event system
            const system = @as(*@import("system.zig").EventSystem(EventType), @ptrCast(@alignCast(self.event_system)));
            try system.on(event_tag, callback, context);
        }

        /// Unregister all callbacks registered through this listener
        pub fn removeAll(self: *Self) void {
            const system = @as(*@import("system.zig").EventSystem(EventType), @ptrCast(@alignCast(self.event_system)));

            for (self.callbacks.items) |entry| {
                // Note: This removes ALL listeners for the event type
                // A more sophisticated implementation would track individual callbacks
                system.off(entry.event_tag);
            }

            self.callbacks.clearRetainingCapacity();
        }
    };
}

/// Macro-like helper for creating event handlers
pub fn createHandler(comptime EventType: type, comptime Context: type, comptime handler_fn: fn (*Context, EventType) void) fn (EventType, ?*anyopaque) void {
    return struct {
        fn handle(event: EventType, ctx: ?*anyopaque) void {
            if (ctx) |context| {
                const typed_ctx = @as(*Context, @ptrCast(@alignCast(context)));
                handler_fn(typed_ctx, event);
            }
        }
    }.handle;
}
