const std = @import("std");

/// Generic save system interface
/// Games implement specific save data structures but use these patterns
pub const SaveSystemInterface = struct {
    /// Generic save data creation pattern
    pub fn fromGameState(comptime SaveType: type, world: anytype, stats: anytype) !SaveType {
        // Call game-specific implementation
        return SaveType.fromGameStateImpl(world, stats);
    }

    /// Generic save data application pattern
    pub fn applyToGameState(save_data: anytype, world: anytype, stats: anytype) void {
        // Call game-specific implementation
        @TypeOf(save_data.*).applyToGameStateImpl(save_data, world, stats);
    }
};

/// Save system versioning for backward compatibility
pub const SaveVersion = struct {
    major: u16,
    minor: u16,
    patch: u16,

    pub fn init(major: u16, minor: u16, patch: u16) SaveVersion {
        return .{ .major = major, .minor = minor, .patch = patch };
    }

    pub fn isCompatible(self: SaveVersion, other: SaveVersion) bool {
        // Compatible if major version matches and this version is >= other
        return self.major == other.major and
            (self.minor > other.minor or
                (self.minor == other.minor and self.patch >= other.patch));
    }

    pub fn toString(self: SaveVersion, buffer: []u8) []const u8 {
        return std.fmt.bufPrint(buffer, "{}.{}.{}", .{ self.major, self.minor, self.patch }) catch "invalid";
    }
};

/// Checkpoint system for incremental saves
pub fn CheckpointSystem(comptime SaveType: type, comptime max_checkpoints: usize) type {
    return struct {
        const Self = @This();

        checkpoints: [max_checkpoints]Checkpoint,
        count: usize,
        current_checkpoint: usize,

        pub const Checkpoint = struct {
            id: u32,
            timestamp: u64,
            name: []const u8,
            save_data: SaveType,
            version: SaveVersion,
            is_auto: bool,
        };

        pub fn init() Self {
            return .{
                .checkpoints = undefined,
                .count = 0,
                .current_checkpoint = 0,
            };
        }

        /// Create a new checkpoint
        pub fn createCheckpoint(
            self: *Self,
            save_data: SaveType,
            name: []const u8,
            version: SaveVersion,
            is_auto: bool,
            allocator: std.mem.Allocator,
        ) !u32 {
            const id = if (self.count > 0) self.checkpoints[self.count - 1].id + 1 else 1;

            // Make a copy of the name
            const name_copy = try allocator.dupe(u8, name);

            const checkpoint = Checkpoint{
                .id = id,
                .timestamp = std.time.timestamp(),
                .name = name_copy,
                .save_data = save_data,
                .version = version,
                .is_auto = is_auto,
            };

            if (self.count >= max_checkpoints) {
                // Remove oldest checkpoint to make room
                if (self.checkpoints[0].name.len > 0) {
                    allocator.free(self.checkpoints[0].name);
                }

                // Shift checkpoints
                for (1..max_checkpoints) |i| {
                    self.checkpoints[i - 1] = self.checkpoints[i];
                }
                self.count = max_checkpoints - 1;
            }

            self.checkpoints[self.count] = checkpoint;
            self.current_checkpoint = self.count;
            self.count += 1;

            return id;
        }

        /// Load a checkpoint by ID
        pub fn loadCheckpoint(self: *Self, id: u32) ?*const SaveType {
            for (0..self.count) |i| {
                if (self.checkpoints[i].id == id) {
                    self.current_checkpoint = i;
                    return &self.checkpoints[i].save_data;
                }
            }
            return null;
        }

        /// Get current checkpoint
        pub fn getCurrentCheckpoint(self: *const Self) ?*const Checkpoint {
            if (self.count == 0) return null;
            return &self.checkpoints[self.current_checkpoint];
        }

        /// List all checkpoints
        pub fn listCheckpoints(self: *const Self, buffer: []Checkpoint) usize {
            const copy_count = @min(buffer.len, self.count);
            for (0..copy_count) |i| {
                buffer[i] = self.checkpoints[i];
            }
            return copy_count;
        }

        /// Remove old auto-checkpoints (keep manual ones)
        pub fn cleanOldCheckpoints(self: *Self, max_auto_age_seconds: u64, allocator: std.mem.Allocator) void {
            const current_time = std.time.timestamp();
            var write_idx: usize = 0;

            for (0..self.count) |i| {
                const checkpoint = &self.checkpoints[i];
                const age = current_time - checkpoint.timestamp;

                // Keep if it's manual or not too old
                if (!checkpoint.is_auto or age <= max_auto_age_seconds) {
                    if (write_idx != i) {
                        self.checkpoints[write_idx] = self.checkpoints[i];
                    }
                    write_idx += 1;
                } else {
                    // Free the name of the checkpoint being removed
                    allocator.free(checkpoint.name);
                }
            }

            self.count = write_idx;
            if (self.current_checkpoint >= self.count) {
                self.current_checkpoint = if (self.count > 0) self.count - 1 else 0;
            }
        }

        /// Get checkpoint by index
        pub fn getCheckpoint(self: *const Self, index: usize) ?*const Checkpoint {
            if (index >= self.count) return null;
            return &self.checkpoints[index];
        }

        /// Remove checkpoint by ID
        pub fn removeCheckpoint(self: *Self, id: u32, allocator: std.mem.Allocator) bool {
            for (0..self.count) |i| {
                if (self.checkpoints[i].id == id) {
                    // Free the name
                    allocator.free(self.checkpoints[i].name);

                    // Shift remaining checkpoints
                    for (i..self.count - 1) |j| {
                        self.checkpoints[j] = self.checkpoints[j + 1];
                    }
                    self.count -= 1;

                    // Adjust current checkpoint index
                    if (self.current_checkpoint >= i and self.current_checkpoint > 0) {
                        self.current_checkpoint -= 1;
                    }

                    return true;
                }
            }
            return false;
        }
    };
}

/// Generic entity save data pattern
/// Games can use this as a base or define their own
pub fn EntitySaveData(comptime EntityId: type) type {
    return struct {
        entity_id: EntityId,
        pos: @Vector(2, f32),
        alive: bool,
        // Games can extend with additional fields
    };
}

/// Generic zone save data pattern
/// Games customize with their specific entity types and limits
pub fn ZoneSaveData(comptime EntityId: type, comptime max_entities: usize) type {
    return struct {
        entities: std.BoundedArray(EntitySaveData(EntityId), max_entities),

        pub fn init() @This() {
            return .{
                // Safe: initializing with 0 elements when capacity is max_entities
                .entities = std.BoundedArray(EntitySaveData(EntityId), max_entities).init(0) catch unreachable,
            };
        }
    };
}

/// Delta save patterns for incremental saves
pub const DeltaSave = struct {
    /// Simple delta between two save states
    pub fn calculateDelta(
        comptime SaveType: type,
        old_save: SaveType,
        new_save: SaveType,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        // Simple implementation: serialize both and store the new one
        // Games can implement more sophisticated delta compression
        _ = old_save;
        _ = allocator;

        // For now, just return the full new save as "delta"
        // TODO: Implement actual delta compression if needed
        return std.mem.asBytes(&new_save);
    }

    /// Apply delta to a save state
    pub fn applyDelta(
        comptime SaveType: type,
        base_save: SaveType,
        delta_data: []const u8,
    ) !SaveType {
        _ = base_save;

        // Simple implementation: treat delta as full save
        if (delta_data.len != @sizeOf(SaveType)) {
            return error.InvalidDelta;
        }

        return std.mem.bytesToValue(SaveType, delta_data[0..@sizeOf(SaveType)]);
    }
};

/// Simple migration system with fail-fast behavior
pub const Migration = struct {
    /// Check if save version is compatible (fail fast if not)
    pub fn checkCompatibility(save_version: SaveVersion, current_version: SaveVersion) !void {
        if (!current_version.isCompatible(save_version)) {
            return error.IncompatibleSaveVersion;
        }
    }

    /// Validate save data basic structure
    pub fn validateSaveData(comptime SaveType: type, data: []const u8) !SaveType {
        if (data.len != @sizeOf(SaveType)) {
            return error.CorruptSaveData;
        }

        // Basic structure validation - just try to read it
        const save_data = std.mem.bytesToValue(SaveType, data[0..@sizeOf(SaveType)]);

        // Games can add their own validation here by implementing validateSave()
        if (@hasDecl(SaveType, "validateSave")) {
            try SaveType.validateSave(save_data);
        }

        return save_data;
    }
};

/// Cached data calculation patterns
pub const CachePatterns = struct {
    /// Calculate completion percentage from completed/total
    pub fn completionPercentage(completed: usize, total: usize) f32 {
        if (total == 0) return 0.0;
        return @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(total)) * 100.0;
    }

    /// Check if all items in array are completed
    pub fn allCompleted(items: anytype) bool {
        for (items) |item| {
            if (!item) return false;
        }
        return items.len > 0;
    }
};
