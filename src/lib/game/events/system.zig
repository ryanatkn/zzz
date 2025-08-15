const std = @import("std");
const ArrayList = std.ArrayList;

/// Generic event system that can be specialized with any event type
pub fn EventSystem(comptime EventType: type) type {
    return struct {
        const Self = @This();
        const Callback = *const fn (event: EventType, ctx: ?*anyopaque) void;

        const Listener = struct {
            callback: Callback,
            context: ?*anyopaque,
        };

        allocator: std.mem.Allocator,
        listeners: std.AutoHashMap(@typeInfo(EventType).@"union".tag_type.?, ArrayList(Listener)),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .listeners = std.AutoHashMap(@typeInfo(EventType).@"union".tag_type.?, ArrayList(Listener)).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            var iter = self.listeners.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.listeners.deinit();
        }

        /// Register a listener for a specific event type
        pub fn on(self: *Self, event_tag: @typeInfo(EventType).@"union".tag_type.?, callback: Callback, context: ?*anyopaque) !void {
            const result = try self.listeners.getOrPut(event_tag);
            if (!result.found_existing) {
                result.value_ptr.* = ArrayList(Listener).init(self.allocator);
            }
            try result.value_ptr.append(.{
                .callback = callback,
                .context = context,
            });
        }

        /// Emit an event to all registered listeners
        pub fn emit(self: *Self, event: EventType) void {
            const event_tag = std.meta.activeTag(event);
            if (self.listeners.get(event_tag)) |listener_list| {
                for (listener_list.items) |listener| {
                    listener.callback(event, listener.context);
                }
            }
        }

        /// Remove all listeners for a specific event type
        pub fn off(self: *Self, event_tag: @typeInfo(EventType).@"union".tag_type.?) void {
            if (self.listeners.fetchRemove(event_tag)) |entry| {
                var list = entry.value;
                list.deinit();
            }
        }

        /// Clear all event listeners
        pub fn clear(self: *Self) void {
            var iter = self.listeners.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.listeners.clearRetainingCapacity();
        }
    };
}
