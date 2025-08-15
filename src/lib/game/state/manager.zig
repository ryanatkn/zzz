const std = @import("std");
const Cache = @import("cache.zig").Cache;
const ProgressTracker = @import("tracker.zig").ProgressTracker;
const events = @import("../events/system.zig");
const persistence = @import("../persistence/manager.zig");

/// Comprehensive state management system
pub fn StateManager(comptime GameData: type, comptime EventType: type) type {
    return struct {
        const Self = @This();
        const EventSystem = events.EventSystem(EventType);
        const SaveManager = persistence.SaveManager(GameData);

        allocator: std.mem.Allocator,
        cache: Cache,
        tracker: ProgressTracker,
        event_system: EventSystem,
        save_manager: SaveManager,
        compute_callbacks: std.StringHashMap(ComputeFn),

        const ComputeFn = *const fn (self: *Self) anyerror!void;

        pub fn init(allocator: std.mem.Allocator, org_name: []const u8, app_name: []const u8) !Self {
            return .{
                .allocator = allocator,
                .cache = Cache.init(allocator),
                .tracker = ProgressTracker.init(allocator),
                .event_system = EventSystem.init(allocator),
                .save_manager = try SaveManager.init(allocator, org_name, app_name),
                .compute_callbacks = std.StringHashMap(ComputeFn).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.cache.deinit();
            self.tracker.deinit();
            self.event_system.deinit();
            self.save_manager.deinit();
            self.compute_callbacks.deinit();
        }

        /// Register a compute function for a cached value
        pub fn registerCompute(self: *Self, key: []const u8, compute_fn: ComputeFn) !void {
            try self.compute_callbacks.put(key, compute_fn);
        }

        /// Query a value, computing it if not cached
        pub fn queryBool(self: *Self, key: []const u8) !bool {
            if (self.cache.getBool(key)) |value| {
                return value;
            }

            // Try to compute it
            if (self.compute_callbacks.get(key)) |compute_fn| {
                try compute_fn(self);
                return self.cache.getBool(key) orelse false;
            }

            return false;
        }

        /// Query an integer value
        pub fn queryInt(self: *Self, key: []const u8) !i64 {
            if (self.cache.getInt(key)) |value| {
                return value;
            }

            // Try to compute it
            if (self.compute_callbacks.get(key)) |compute_fn| {
                try compute_fn(self);
                return self.cache.getInt(key) orelse 0;
            }

            return 0;
        }

        /// Query a float value
        pub fn queryFloat(self: *Self, key: []const u8) !f64 {
            if (self.cache.getFloat(key)) |value| {
                return value;
            }

            // Try to compute it
            if (self.compute_callbacks.get(key)) |compute_fn| {
                try compute_fn(self);
                return self.cache.getFloat(key) orelse 0.0;
            }

            return 0.0;
        }

        /// Invalidate a cached value
        pub fn invalidate(self: *Self, key: []const u8) void {
            self.cache.invalidate(key);
        }

        /// Invalidate all cached values
        pub fn invalidateAll(self: *Self) void {
            self.cache.clear();
        }

        /// Emit an event
        pub fn emit(self: *Self, event: EventType) void {
            self.event_system.emit(event);
        }

        /// Register an event listener
        pub fn on(self: *Self, event_tag: @typeInfo(EventType).@"union".tag_type.?, callback: *const fn (EventType, ?*anyopaque) void, context: ?*anyopaque) !void {
            try self.event_system.on(event_tag, callback, context);
        }

        /// Save game state
        pub fn save(self: *Self, slot: usize, data: GameData, name: ?[]const u8) !void {
            try self.save_manager.save(slot, data, name);

            // Emit save event
            self.emit(@unionInit(EventType, "game_saved", .{
                .slot = slot,
                .success = true,
            }));
        }

        /// Load game state
        pub fn load(self: *Self, slot: usize) !GameData {
            const data = try self.save_manager.load(slot);

            // Clear cache when loading
            self.cache.clear();

            // Emit load event
            self.emit(@unionInit(EventType, "game_loaded", .{
                .slot = slot,
                .success = true,
            }));

            return data;
        }

        /// Quick save
        pub fn quickSave(self: *Self, data: GameData) !void {
            try self.save_manager.quickSave(data);
        }

        /// Quick load
        pub fn quickLoad(self: *Self) !GameData {
            return try self.save_manager.quickLoad();
        }

        /// Check if autosave should trigger
        pub fn shouldAutosave(self: *const Self) bool {
            return self.save_manager.shouldAutosave();
        }

        /// Perform autosave if needed
        pub fn autosave(self: *Self, data: GameData) !void {
            try self.save_manager.autosave(data);
        }

        /// Update an achievement
        pub fn updateAchievement(self: *Self, id: []const u8, progress: f32) !void {
            if (try self.tracker.updateAchievementProgress(id, progress)) {
                // Achievement unlocked!
                self.emit(@unionInit(EventType, "achievement_unlocked", .{
                    .achievement_id = id,
                }));
            }
        }

        /// Update a statistic
        pub fn updateStatistic(self: *Self, id: []const u8, value: f64) void {
            self.tracker.updateStatistic(id, value);
        }

        /// Get overall game completion
        pub fn getCompletion(self: *const Self) f32 {
            return self.tracker.getCompletionPercentage();
        }
    };
}
