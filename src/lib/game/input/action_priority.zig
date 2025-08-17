const std = @import("std");

/// Action priority system for input handling
/// Ensures important actions (like quit) aren't blocked by game state
pub const ActionPrioritySystem = struct {
    /// Priority levels (lower number = higher priority)
    pub const Priority = enum(u8) {
        Critical = 0, // Emergency actions (quit, force respawn)
        System = 1, // System actions (pause, menu)
        Gameplay = 2, // Core gameplay (respawn when dead)
        Combat = 3, // Combat actions (shoot, cast)
        Movement = 4, // Movement and positioning
        UI = 5, // UI interactions
        Debug = 6, // Debug/dev commands

        pub fn canOverride(self: Priority, other: Priority) bool {
            return @intFromEnum(self) <= @intFromEnum(other);
        }

        pub fn isHigherThan(self: Priority, other: Priority) bool {
            return @intFromEnum(self) < @intFromEnum(other);
        }
    };

    /// Action categories with their default priorities
    pub const ActionCategory = enum {
        // Critical actions
        ForceQuit,
        EmergencyRespawn,

        // System actions
        Quit,
        TogglePause,
        ToggleMenu,

        // Gameplay actions
        Respawn,
        UseItem,
        Interact,

        // Combat actions
        Attack,
        Cast,
        Block,

        // Movement actions
        Move,
        Jump,
        Dash,

        // UI actions
        OpenInventory,
        Navigate,
        Confirm,

        // Debug actions
        ToggleDebug,
        Teleport,
        GodMode,

        pub fn getPriority(self: ActionCategory) Priority {
            return switch (self) {
                .ForceQuit, .EmergencyRespawn => .Critical,
                .Quit, .TogglePause, .ToggleMenu => .System,
                .Respawn, .UseItem, .Interact => .Gameplay,
                .Attack, .Cast, .Block => .Combat,
                .Move, .Jump, .Dash => .Movement,
                .OpenInventory, .Navigate, .Confirm => .UI,
                .ToggleDebug, .Teleport, .GodMode => .Debug,
            };
        }
    };

    /// Action queue entry
    pub const ActionEntry = struct {
        category: ActionCategory,
        priority: Priority,
        data: ActionData,

        pub fn init(category: ActionCategory, data: ActionData) ActionEntry {
            return .{
                .category = category,
                .priority = category.getPriority(),
                .data = data,
            };
        }

        pub fn withCustomPriority(category: ActionCategory, priority: Priority, data: ActionData) ActionEntry {
            return .{
                .category = category,
                .priority = priority,
                .data = data,
            };
        }
    };

    /// Generic action data (games extend this)
    pub const ActionData = union(enum) {
        None,
        Position: @Vector(2, f32),
        Entity: u32,
        Key: u32,
        Custom: []const u8,
    };

    /// Priority-based action queue
    actions: std.ArrayList(ActionEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ActionPrioritySystem {
        return .{
            .actions = std.ArrayList(ActionEntry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ActionPrioritySystem) void {
        self.actions.deinit();
    }

    /// Add action to queue (maintains priority order)
    pub fn addAction(self: *ActionPrioritySystem, action: ActionEntry) !void {
        // Find insertion point to maintain priority order
        var insert_index: usize = 0;
        for (self.actions.items, 0..) |existing, i| {
            if (action.priority.isHigherThan(existing.priority)) {
                insert_index = i;
                break;
            }
            insert_index = i + 1;
        }

        try self.actions.insert(insert_index, action);
    }

    /// Get highest priority action without removing it
    pub fn peekAction(self: *const ActionPrioritySystem) ?ActionEntry {
        if (self.actions.items.len == 0) return null;
        return self.actions.items[0];
    }

    /// Get and remove highest priority action
    pub fn popAction(self: *ActionPrioritySystem) ?ActionEntry {
        if (self.actions.items.len == 0) return null;
        return self.actions.orderedRemove(0);
    }

    /// Clear all actions
    pub fn clear(self: *ActionPrioritySystem) void {
        self.actions.clearRetainingCapacity();
    }

    /// Clear actions of specific priority or lower
    pub fn clearLowPriority(self: *ActionPrioritySystem, min_priority: Priority) void {
        var i: usize = 0;
        while (i < self.actions.items.len) {
            if (!self.actions.items[i].priority.isHigherThan(min_priority)) {
                _ = self.actions.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Check if system has actions
    pub fn hasActions(self: *const ActionPrioritySystem) bool {
        return self.actions.items.len > 0;
    }

    /// Get number of queued actions
    pub fn getActionCount(self: *const ActionPrioritySystem) usize {
        return self.actions.items.len;
    }
};
