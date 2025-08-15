const std = @import("std");
const Storage = @import("storage.zig").Storage;
const save_state = @import("save_state.zig");

/// Save/load manager for game persistence
pub fn SaveManager(comptime GameData: type) type {
    return struct {
        const Self = @This();
        const SaveState = save_state.SaveState(GameData);

        allocator: std.mem.Allocator,
        storage: Storage,
        current_slot: ?usize,
        autosave_enabled: bool,
        autosave_interval_ms: u64,
        last_autosave_time: u64,

        pub fn init(allocator: std.mem.Allocator, org_name: []const u8, app_name: []const u8) !Self {
            return .{
                .allocator = allocator,
                .storage = try Storage.init(allocator, org_name, app_name),
                .current_slot = null,
                .autosave_enabled = true,
                .autosave_interval_ms = 60000, // 1 minute default
                .last_autosave_time = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.storage.deinit();
        }

        /// Save game data to a specific slot
        pub fn save(self: *Self, slot: usize, data: GameData, name: ?[]const u8) !void {
            var save_data = SaveState.init(slot, data);
            if (name) |n| {
                save_data.setName(n);
            }

            const json = try save_data.toJson(self.allocator);
            defer self.allocator.free(json);

            try self.storage.writeSlot(slot, json);
            self.current_slot = slot;
            self.last_autosave_time = @as(u64, @intCast(std.time.milliTimestamp()));
        }

        /// Load game data from a specific slot
        pub fn load(self: *Self, slot: usize) !GameData {
            const json = try self.storage.readSlot(self.allocator, slot);
            defer self.allocator.free(json);

            const save_data = try SaveState.fromJson(self.allocator, json);
            self.current_slot = slot;

            return save_data.data;
        }

        /// Quick save to the current slot (or slot 0 if none)
        pub fn quickSave(self: *Self, data: GameData) !void {
            const slot = self.current_slot orelse 0;
            try self.save(slot, data, null);
        }

        /// Quick load from the current slot (or most recent)
        pub fn quickLoad(self: *Self) !GameData {
            if (self.current_slot) |slot| {
                return try self.load(slot);
            }

            // Find most recent save
            const metadata = try self.storage.getAllMetadata(self.allocator);
            var newest_slot: ?usize = null;
            var newest_time: i64 = 0;

            for (metadata, 0..) |meta, slot| {
                if (meta) |m| {
                    if (m.timestamp > newest_time) {
                        newest_time = m.timestamp;
                        newest_slot = slot;
                    }
                }
            }

            if (newest_slot) |slot| {
                return try self.load(slot);
            }

            return error.NoSavesFound;
        }

        /// Autosave if enabled and interval has passed
        pub fn autosave(self: *Self, data: GameData) !void {
            if (!self.autosave_enabled) return;

            const now = @as(u64, @intCast(std.time.milliTimestamp()));
            if (now - self.last_autosave_time < self.autosave_interval_ms) return;

            // Always autosave to slot 0
            try self.save(0, data, "Autosave");
            self.last_autosave_time = now;
        }

        /// Check if autosave should trigger
        pub fn shouldAutosave(self: *const Self) bool {
            if (!self.autosave_enabled) return false;

            const now = @as(u64, @intCast(std.time.milliTimestamp()));
            return now - self.last_autosave_time >= self.autosave_interval_ms;
        }

        /// Get metadata for all save slots
        pub fn getAllSaveMetadata(self: *Self) ![Storage.MAX_SLOTS]?save_state.SaveMetadata {
            return try self.storage.getAllMetadata(self.allocator);
        }

        /// Delete a save slot
        pub fn deleteSave(self: *Self, slot: usize) !void {
            try self.storage.deleteSlot(slot);
            if (self.current_slot == slot) {
                self.current_slot = null;
            }
        }

        /// Check if any saves exist
        pub fn hasSaves(self: *const Self) bool {
            for (0..Storage.MAX_SLOTS) |slot| {
                if (self.storage.slotExists(slot)) return true;
            }
            return false;
        }

        /// Set autosave settings
        pub fn setAutosave(self: *Self, enabled: bool, interval_ms: ?u64) void {
            self.autosave_enabled = enabled;
            if (interval_ms) |interval| {
                self.autosave_interval_ms = interval;
            }
        }
    };
}
