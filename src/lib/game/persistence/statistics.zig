const std = @import("std");

/// Generic game statistics tracking
/// Games implement specific fields but use this interface for persistence
pub const StatisticsInterface = struct {
    /// Update statistics with elapsed time
    pub fn updatePlayTime(self: anytype, delta_ms: u64) void {
        self.play_time_ms += delta_ms;
    }

    /// Generic increment pattern for any counter field
    pub fn increment(self: anytype, comptime field: []const u8) void {
        @field(self, field) += 1;
    }

    /// Generic add pattern for any numeric field
    pub fn add(self: anytype, comptime field: []const u8, value: anytype) void {
        @field(self, field) += value;
    }

    /// Reset all statistics to zero
    pub fn reset(self: anytype) void {
        const T = @TypeOf(self.*);
        const fields = @typeInfo(T).Struct.fields;
        inline for (fields) |field| {
            if (field.type == usize or field.type == u64 or field.type == f32) {
                @field(self, field.name) = 0;
            } else if (field.type == bool) {
                @field(self, field.name) = false;
            }
        }
    }
};

/// Example statistics structure for reference
/// Games should define their own with relevant fields
pub const ExampleStatistics = struct {
    total_deaths: usize = 0,
    total_projectiles_fired: usize = 0,
    total_spells_cast: usize = 0,
    play_time_ms: u64 = 0,

    pub usingnamespace StatisticsInterface;
};
