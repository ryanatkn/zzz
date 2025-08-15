const std = @import("std");

/// Generic save state wrapper with versioning and metadata
pub fn SaveState(comptime GameData: type) type {
    return struct {
        const Self = @This();

        // Metadata
        version: u32,
        timestamp: i64,
        slot: usize,
        name: [64]u8,

        // Game-specific data
        data: GameData,

        pub fn init(slot: usize, data: GameData) Self {
            var save = Self{
                .version = 1,
                .timestamp = std.time.milliTimestamp(),
                .slot = slot,
                .name = [_]u8{0} ** 64,
                .data = data,
            };

            // Generate default name with timestamp
            const time_str = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Save {d} - {d}",
                .{ slot, save.timestamp },
            ) catch "Unnamed Save";
            defer std.heap.page_allocator.free(time_str);

            const copy_len = @min(time_str.len, save.name.len - 1);
            @memcpy(save.name[0..copy_len], time_str[0..copy_len]);

            return save;
        }

        pub fn setName(self: *Self, name: []const u8) void {
            const copy_len = @min(name.len, self.name.len - 1);
            @memset(&self.name, 0);
            @memcpy(self.name[0..copy_len], name[0..copy_len]);
        }

        pub fn getName(self: *const Self) []const u8 {
            const len = std.mem.indexOfScalar(u8, &self.name, 0) orelse self.name.len;
            return self.name[0..len];
        }

        /// Serialize to JSON
        pub fn toJson(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
            return try std.json.stringifyAlloc(allocator, self, .{
                .whitespace = .indent_2,
            });
        }

        /// Deserialize from JSON
        pub fn fromJson(allocator: std.mem.Allocator, json: []const u8) !Self {
            const parsed = try std.json.parseFromSlice(Self, allocator, json, .{
                .ignore_unknown_fields = true,
            });
            defer parsed.deinit();
            return parsed.value;
        }

        /// Check if this save is compatible with current version
        pub fn isCompatible(self: *const Self, current_version: u32) bool {
            // For now, only exact version matches
            // In future, could support migration
            return self.version == current_version;
        }
    };
}

/// Metadata for save slots without loading full data
pub const SaveMetadata = struct {
    exists: bool,
    slot: usize,
    version: u32,
    timestamp: i64,
    name: [64]u8,

    pub fn getName(self: *const SaveMetadata) []const u8 {
        const len = std.mem.indexOfScalar(u8, &self.name, 0) orelse self.name.len;
        return self.name[0..len];
    }

    pub fn getFormattedTime(self: *const SaveMetadata, buf: []u8) ![]u8 {
        const seconds = @divFloor(self.timestamp, 1000);
        const dt = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds) };
        const year_day = dt.getEpochDay().calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        return std.fmt.bufPrint(buf, "{d:0>2}/{d:0>2} {d:0>2}:{d:0>2}", .{
            month_day.month.numeric(),
            month_day.day_index + 1,
            dt.getDaySeconds().getHoursIntoDay(),
            dt.getDaySeconds().getMinutesIntoHour(),
        });
    }
};
