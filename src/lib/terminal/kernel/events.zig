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

/// Special key enum for type-safe keyboard input
pub const SpecialKey = enum {
    enter,
    backspace,
    delete,
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
    ctrl_l,
    ctrl_d,
    ctrl_z,
};

/// Key input tagged union for zero-allocation input handling
pub const KeyInput = union(enum) {
    char: u8,
    special: SpecialKey,
    text: []const u8, // For pasted text or multi-byte input
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
    key: KeyInput,
};

pub const OutputEventData = struct {
    text: []const u8,
    target: ?[]const u8 = null, // Optional output target
};

/// Component types that can emit state changes
pub const ComponentType = enum {
    line_buffer,
    cursor,
    basic_writer,
    keyboard_input,
    registry,
    executor,
    writer,
};

/// Line buffer state changes
pub const LineBufferState = enum {
    char_inserted,
    char_deleted,
    cursor_moved,
    history_loaded,
    line_executed,
    line_cleared,
};

/// Cursor state changes
pub const CursorState = enum {
    blink_toggled,
    shown,
    hidden,
    position_changed,
    dimensions_changed,
};

/// Basic writer state changes
pub const WriterState = enum {
    text_written,
    cleared,
};

/// State change types union
/// Registry state for command registrations
pub const RegistryState = struct {
    command_count: usize,
};

/// Executor state for process execution
pub const ExecutorState = struct {
    exit_code: u8,
};

pub const StateChangeType = union(ComponentType) {
    line_buffer: LineBufferState,
    cursor: CursorState,
    basic_writer: WriterState,
    keyboard_input: void, // No state changes for keyboard
    registry: RegistryState,
    executor: ExecutorState,
    writer: WriterState,
};

pub const StateChangeData = struct {
    component: ComponentType,
    state: StateChangeType,
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
    callback: EventCallback,
    context: ?*anyopaque,
    active: bool,
};

/// Subscription list for a specific event type
const SubscriptionList = struct {
    items: [MAX_SUBSCRIPTIONS_PER_TYPE]Subscription,
    count: usize = 0,

    const MAX_SUBSCRIPTIONS_PER_TYPE = 16;
};

/// Zero-allocation event bus with type-indexed subscriptions for O(1) lookup
pub const EventBus = struct {
    // Group subscriptions by event type for faster dispatch
    subscriptions_by_type: [std.meta.fields(EventType).len]SubscriptionList,
    allocator: std.mem.Allocator,

    const MAX_SUBSCRIPTIONS = 64;

    pub fn init(allocator: std.mem.Allocator) EventBus {
        var bus = EventBus{
            .subscriptions_by_type = undefined,
            .allocator = allocator,
        };
        // Initialize all subscription lists
        for (&bus.subscriptions_by_type) |*list| {
            list.* = SubscriptionList{
                .items = undefined,
                .count = 0,
            };
        }
        
        
        return bus;
    }

    /// Subscribe to event type with callback
    pub fn subscribe(
        self: *EventBus,
        event_type: EventType,
        callback: EventCallback,
        context: ?*anyopaque,
    ) !void {
        const type_index = @intFromEnum(event_type);
        const list = &self.subscriptions_by_type[type_index];

        if (list.count >= SubscriptionList.MAX_SUBSCRIPTIONS_PER_TYPE) {
            return error.TooManySubscriptions;
        }

        list.items[list.count] = Subscription{
            .callback = callback,
            .context = context,
            .active = true,
        };
        list.count += 1;
    }

    /// Unsubscribe from events (mark as inactive)
    pub fn unsubscribe(
        self: *EventBus,
        event_type: EventType,
        callback: EventCallback,
        context: ?*anyopaque,
    ) void {
        const type_index = @intFromEnum(event_type);
        const list = &self.subscriptions_by_type[type_index];

        for (list.items[0..list.count]) |*sub| {
            if (sub.callback == callback and sub.context == context) {
                sub.active = false;
                break;
            }
        }
    }

    /// Emit event to all subscribers (O(1) lookup to relevant subscriptions)
    pub fn emit(self: *EventBus, event: Event) !void {
        const type_index = @intFromEnum(event.type);
        const list = &self.subscriptions_by_type[type_index];

        // Only iterate relevant subscriptions for this event type
        for (list.items[0..list.count]) |sub| {
            if (sub.active) {
                try sub.callback(event, sub.context);
            }
        }
    }

    /// Clean up inactive subscriptions (periodic maintenance)
    pub fn cleanup(self: *EventBus) void {
        for (&self.subscriptions_by_type) |*list| {
            var write_index: usize = 0;
            for (list.items[0..list.count]) |sub| {
                if (sub.active) {
                    list.items[write_index] = sub;
                    write_index += 1;
                }
            }
            list.count = write_index;
        }
    }

    /// Get total count of all subscriptions (including inactive)
    pub fn getSubscriptionCount(self: *const EventBus) usize {
        var total_count: usize = 0;
        for (&self.subscriptions_by_type) |*list| {
            total_count += list.count;
        }
        return total_count;
    }

    /// Get count of active subscriptions only
    pub fn getActiveSubscriptionCount(self: *const EventBus) usize {
        var total_count: usize = 0;
        for (&self.subscriptions_by_type) |*list| {
            for (list.items[0..list.count]) |sub| {
                if (sub.active) total_count += 1;
            }
        }
        return total_count;
    }
};
