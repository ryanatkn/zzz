const std = @import("std");

/// Event types supported by the terminal kernel
pub const EventType = enum {
    input,
    output,
    state_change,
    command_execute,
    resize,
    capability_added,
    capability_removed,
};

/// Event data structure
pub const Event = struct {
    type: EventType,
    data: EventData,
    timestamp: i64,

    pub fn init(event_type: EventType, data: EventData) Event {
        return Event{
            .type = event_type,
            .data = data,
            .timestamp = std.time.milliTimestamp(),
        };
    }
};

/// Event data union for different event types
pub const EventData = union(EventType) {
    input: InputEventData,
    output: OutputEventData,
    state_change: StateChangeData,
    command_execute: CommandExecuteData,
    resize: ResizeEventData,
    capability_added: CapabilityEventData,
    capability_removed: CapabilityEventData,
};

pub const InputEventData = struct {
    input_type: InputType,
    data: []const u8,
};

pub const OutputEventData = struct {
    text: []const u8,
    target: ?[]const u8 = null, // Optional output target
};

pub const StateChangeData = struct {
    component: []const u8,
    old_state: ?[]const u8,
    new_state: []const u8,
};

pub const CommandExecuteData = struct {
    command: []const u8,
    args: ?[]const []const u8,
};

pub const ResizeEventData = struct {
    old_columns: usize,
    old_rows: usize,
    new_columns: usize,
    new_rows: usize,
};

pub const CapabilityEventData = struct {
    name: []const u8,
    capability_type: []const u8,
};

pub const InputType = enum {
    keyboard,
    mouse,
    touch,
    clipboard,
};

/// Event callback function type
pub const EventCallback = *const fn (event: Event, context: ?*anyopaque) anyerror!void;

/// Event subscription entry
const Subscription = struct {
    event_type: EventType,
    callback: EventCallback,
    context: ?*anyopaque,
    active: bool,
};

/// Zero-allocation event bus with fixed capacity
pub const EventBus = struct {
    subscriptions: [MAX_SUBSCRIPTIONS]Subscription,
    subscription_count: usize,
    allocator: std.mem.Allocator,

    const MAX_SUBSCRIPTIONS = 64;

    pub fn init(allocator: std.mem.Allocator) EventBus {
        return EventBus{
            .subscriptions = undefined,
            .subscription_count = 0,
            .allocator = allocator,
        };
    }

    /// Subscribe to event type with callback
    pub fn subscribe(
        self: *EventBus,
        event_type: EventType,
        callback: EventCallback,
        context: ?*anyopaque,
    ) !void {
        if (self.subscription_count >= MAX_SUBSCRIPTIONS) {
            return error.TooManySubscriptions;
        }

        self.subscriptions[self.subscription_count] = Subscription{
            .event_type = event_type,
            .callback = callback,
            .context = context,
            .active = true,
        };
        self.subscription_count += 1;
    }

    /// Unsubscribe from events (mark as inactive)
    pub fn unsubscribe(
        self: *EventBus,
        event_type: EventType,
        callback: EventCallback,
        context: ?*anyopaque,
    ) void {
        for (self.subscriptions[0..self.subscription_count]) |*sub| {
            if (sub.event_type == event_type and sub.callback == callback and sub.context == context) {
                sub.active = false;
                break;
            }
        }
    }

    /// Emit event to all subscribers
    pub fn emit(self: *EventBus, event: Event) !void {
        for (self.subscriptions[0..self.subscription_count]) |*sub| {
            if (sub.active and sub.event_type == event.type) {
                try sub.callback(event, sub.context);
            }
        }
    }

    /// Clean up inactive subscriptions (periodic maintenance)
    pub fn cleanup(self: *EventBus) void {
        var write_index: usize = 0;
        for (self.subscriptions[0..self.subscription_count]) |sub| {
            if (sub.active) {
                self.subscriptions[write_index] = sub;
                write_index += 1;
            }
        }
        self.subscription_count = write_index;
    }

    /// Get count of active subscriptions
    pub fn getSubscriptionCount(self: *const EventBus) usize {
        var count: usize = 0;
        for (self.subscriptions[0..self.subscription_count]) |sub| {
            if (sub.active) count += 1;
        }
        return count;
    }
};