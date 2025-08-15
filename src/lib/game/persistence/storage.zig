const std = @import("std");
const c = @import("../../platform/sdl.zig");

/// Storage backend for save files using SDL's preference path
pub const Storage = struct {
    allocator: std.mem.Allocator,
    save_dir: []u8,

    const Self = @This();
    const SAVE_EXTENSION = ".json";
    const MAX_SLOTS = 3;

    pub fn init(allocator: std.mem.Allocator, org_name: []const u8, app_name: []const u8) !Self {
        // Get platform-specific save directory
        const pref_path = c.sdl.SDL_GetPrefPath(org_name.ptr, app_name.ptr);
        if (pref_path == null) {
            return error.FailedToGetPrefPath;
        }
        defer c.sdl.SDL_free(pref_path);

        const path_len = std.mem.len(pref_path);
        const save_dir = try allocator.alloc(u8, path_len);
        @memcpy(save_dir, pref_path[0..path_len]);

        // Ensure directory exists
        std.fs.makeDirAbsolute(save_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // That's fine
            else => return err,
        };

        return .{
            .allocator = allocator,
            .save_dir = save_dir,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.save_dir);
    }

    /// Get the full path for a save slot
    pub fn getSlotPath(self: *const Self, slot: usize, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(buf, "{s}save_{d}{s}", .{
            self.save_dir,
            slot,
            SAVE_EXTENSION,
        });
    }

    /// Write data to a save slot
    pub fn writeSlot(self: *const Self, slot: usize, data: []const u8) !void {
        if (slot >= MAX_SLOTS) return error.InvalidSlot;

        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try self.getSlotPath(slot, &path_buf);

        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        try file.writeAll(data);
    }

    /// Read data from a save slot
    pub fn readSlot(self: *const Self, allocator: std.mem.Allocator, slot: usize) ![]u8 {
        if (slot >= MAX_SLOTS) return error.InvalidSlot;

        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try self.getSlotPath(slot, &path_buf);

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const data = try allocator.alloc(u8, file_size);
        _ = try file.read(data);

        return data;
    }

    /// Check if a save slot exists
    pub fn slotExists(self: *const Self, slot: usize) bool {
        if (slot >= MAX_SLOTS) return false;

        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = self.getSlotPath(slot, &path_buf) catch return false;

        std.fs.accessAbsolute(path, .{}) catch return false;
        return true;
    }

    /// Delete a save slot
    pub fn deleteSlot(self: *const Self, slot: usize) !void {
        if (slot >= MAX_SLOTS) return error.InvalidSlot;

        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try self.getSlotPath(slot, &path_buf);

        try std.fs.deleteFileAbsolute(path);
    }

    /// Get metadata for all slots without loading full saves
    pub fn getAllMetadata(self: *const Self, allocator: std.mem.Allocator) ![MAX_SLOTS]?@import("save_state.zig").SaveMetadata {
        var metadata: [MAX_SLOTS]?@import("save_state.zig").SaveMetadata = [_]?@import("save_state.zig").SaveMetadata{null} ** MAX_SLOTS;

        for (0..MAX_SLOTS) |slot| {
            if (!self.slotExists(slot)) continue;

            // Read just enough to get metadata
            const data = self.readSlot(allocator, slot) catch continue;
            defer allocator.free(data);

            // Parse just the metadata fields
            const parsed = std.json.parseFromSlice(
                @import("save_state.zig").SaveMetadata,
                allocator,
                data,
                .{ .ignore_unknown_fields = true },
            ) catch continue;
            defer parsed.deinit();

            metadata[slot] = parsed.value;
            metadata[slot].?.exists = true;
            metadata[slot].?.slot = slot;
        }

        return metadata;
    }

    /// Get the save directory path
    pub fn getSaveDir(self: *const Self) []const u8 {
        return self.save_dir;
    }
};
