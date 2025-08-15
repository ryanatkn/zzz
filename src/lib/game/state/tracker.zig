const std = @import("std");

/// Achievement and progress tracking system
pub const ProgressTracker = struct {
    allocator: std.mem.Allocator,
    achievements: std.StringHashMap(Achievement),
    statistics: std.StringHashMap(Statistic),
    
    const Self = @This();
    
    pub const Achievement = struct {
        id: []const u8,
        name: []const u8,
        description: []const u8,
        unlocked: bool,
        unlock_time: ?i64,
        progress: f32, // 0.0 to 1.0
        target: f32,
    };
    
    pub const Statistic = struct {
        id: []const u8,
        name: []const u8,
        value: f64,
        max_value: f64,
        total_accumulated: f64,
    };
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .achievements = std.StringHashMap(Achievement).init(allocator),
            .statistics = std.StringHashMap(Statistic).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.achievements.deinit();
        self.statistics.deinit();
    }
    
    /// Register a new achievement
    pub fn addAchievement(self: *Self, id: []const u8, name: []const u8, description: []const u8, target: f32) !void {
        try self.achievements.put(id, .{
            .id = id,
            .name = name,
            .description = description,
            .unlocked = false,
            .unlock_time = null,
            .progress = 0.0,
            .target = target,
        });
    }
    
    /// Update achievement progress
    pub fn updateAchievementProgress(self: *Self, id: []const u8, progress: f32) !bool {
        if (self.achievements.getPtr(id)) |achievement| {
            if (achievement.unlocked) return false;
            
            achievement.progress = @min(progress, achievement.target);
            
            if (achievement.progress >= achievement.target) {
                achievement.unlocked = true;
                achievement.unlock_time = std.time.milliTimestamp();
                return true; // Achievement unlocked!
            }
        }
        return false;
    }
    
    /// Increment achievement progress
    pub fn incrementAchievement(self: *Self, id: []const u8, amount: f32) !bool {
        if (self.achievements.get(id)) |achievement| {
            return try self.updateAchievementProgress(id, achievement.progress + amount);
        }
        return false;
    }
    
    /// Check if an achievement is unlocked
    pub fn isAchievementUnlocked(self: *const Self, id: []const u8) bool {
        if (self.achievements.get(id)) |achievement| {
            return achievement.unlocked;
        }
        return false;
    }
    
    /// Get achievement progress (0.0 to 1.0)
    pub fn getAchievementProgress(self: *const Self, id: []const u8) f32 {
        if (self.achievements.get(id)) |achievement| {
            if (achievement.target > 0) {
                return achievement.progress / achievement.target;
            }
        }
        return 0.0;
    }
    
    /// Register a new statistic
    pub fn addStatistic(self: *Self, id: []const u8, name: []const u8) !void {
        try self.statistics.put(id, .{
            .id = id,
            .name = name,
            .value = 0.0,
            .max_value = 0.0,
            .total_accumulated = 0.0,
        });
    }
    
    /// Update a statistic value
    pub fn updateStatistic(self: *Self, id: []const u8, value: f64) void {
        if (self.statistics.getPtr(id)) |stat| {
            stat.value = value;
            stat.max_value = @max(stat.max_value, value);
            stat.total_accumulated += @abs(value - stat.value);
        }
    }
    
    /// Increment a statistic
    pub fn incrementStatistic(self: *Self, id: []const u8, amount: f64) void {
        if (self.statistics.getPtr(id)) |stat| {
            stat.value += amount;
            stat.max_value = @max(stat.max_value, stat.value);
            stat.total_accumulated += @abs(amount);
        }
    }
    
    /// Get a statistic value
    pub fn getStatistic(self: *const Self, id: []const u8) ?f64 {
        if (self.statistics.get(id)) |stat| {
            return stat.value;
        }
        return null;
    }
    
    /// Get all unlocked achievements
    pub fn getUnlockedAchievements(self: *const Self, allocator: std.mem.Allocator) ![]Achievement {
        var unlocked = std.ArrayList(Achievement).init(allocator);
        
        var iter = self.achievements.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.unlocked) {
                try unlocked.append(entry.value_ptr.*);
            }
        }
        
        return unlocked.toOwnedSlice();
    }
    
    /// Get overall completion percentage
    pub fn getCompletionPercentage(self: *const Self) f32 {
        if (self.achievements.count() == 0) return 100.0;
        
        var unlocked: f32 = 0.0;
        var iter = self.achievements.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.unlocked) {
                unlocked += 1.0;
            }
        }
        
        return (unlocked / @as(f32, @floatFromInt(self.achievements.count()))) * 100.0;
    }
};