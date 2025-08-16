const std = @import("std");
const timer = @import("../core/timer.zig");

/// Duration-based effect system for temporary modifiers
/// Supports various stacking strategies and automatic expiration

/// How effects of the same type should combine
pub const StackType = enum {
    replace,   // New effect replaces old ones
    add,       // Values add together
    multiply,  // Values multiply together
    max,       // Take maximum value
    min,       // Take minimum value
    refresh,   // Extend duration but keep same value
};

/// Effect configuration template
pub const EffectConfig = struct {
    stack_type: StackType = .replace,
    max_stacks: u32 = 1,
    unique_sources: bool = false, // If true, each source can only have one effect
};

/// Generic effect with configurable value type
pub fn Effect(comptime ValueType: type) type {
    return struct {
        const Self = @This();
        
        value: ValueType,
        timer: timer.Timer,
        source_id: u32 = 0, // Optional source identifier
        effect_id: u32,     // Unique effect identifier
        active: bool = true,
        
        pub fn init(value: ValueType, duration: f32, effect_id: u32) Self {
            return .{
                .value = value,
                .timer = timer.Timer.init(duration),
                .effect_id = effect_id,
            };
        }
        
        pub fn initWithSource(value: ValueType, duration: f32, effect_id: u32, source_id: u32) Self {
            var effect = Self.init(value, duration, effect_id);
            effect.source_id = source_id;
            return effect;
        }
        
        pub fn start(self: *Self) void {
            self.timer.start();
            self.active = true;
        }
        
        pub fn update(self: *Self, delta_time: f32) void {
            if (!self.active) return;
            
            self.timer.update(delta_time);
            if (self.timer.isFinished()) {
                self.active = false;
            }
        }
        
        pub fn isExpired(self: *const Self) bool {
            return !self.active or self.timer.isFinished();
        }
        
        pub fn getRemainingTime(self: *const Self) f32 {
            return self.timer.remaining;
        }
        
        pub fn getProgress(self: *const Self) f32 {
            return self.timer.getProgress();
        }
        
        pub fn refresh(self: *Self, new_duration: f32) void {
            self.timer.duration = new_duration;
            self.timer.start();
            self.active = true;
        }
    };
}

/// Duration manager for a specific effect type
pub fn DurationManager(comptime ValueType: type) type {
    return struct {
        const Self = @This();
        const EffectType = Effect(ValueType);
        
        effects: std.ArrayList(EffectType),
        config: EffectConfig,
        allocator: std.mem.Allocator,
        next_effect_id: u32 = 1,
        
        pub fn init(allocator: std.mem.Allocator, config: EffectConfig) Self {
            return .{
                .effects = std.ArrayList(EffectType).init(allocator),
                .config = config,
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.effects.deinit();
        }
        
        /// Add a new effect with stacking rules
        pub fn addEffect(self: *Self, value: ValueType, duration: f32, source_id: u32) !u32 {
            const effect_id = self.next_effect_id;
            self.next_effect_id += 1;
            
            switch (self.config.stack_type) {
                .replace => {
                    // Remove all existing effects and add new one
                    self.effects.clearRetainingCapacity();
                    var effect = EffectType.initWithSource(value, duration, effect_id, source_id);
                    effect.start();
                    try self.effects.append(effect);
                },
                .refresh => {
                    // Find existing effect from same source and refresh it
                    if (self.config.unique_sources) {
                        for (self.effects.items) |*effect| {
                            if (effect.source_id == source_id and effect.active) {
                                effect.refresh(duration);
                                return effect.effect_id;
                            }
                        }
                    }
                    // If no existing effect found, add new one
                    var effect = EffectType.initWithSource(value, duration, effect_id, source_id);
                    effect.start();
                    try self.effects.append(effect);
                },
                else => {
                    // Check stack limits
                    const active_count = self.countActiveEffects();
                    if (active_count >= self.config.max_stacks) {
                        // Remove oldest effect
                        self.removeOldestEffect();
                    }
                    
                    // Add new effect
                    var effect = EffectType.initWithSource(value, duration, effect_id, source_id);
                    effect.start();
                    try self.effects.append(effect);
                },
            }
            
            return effect_id;
        }
        
        /// Remove an effect by ID
        pub fn removeEffect(self: *Self, effect_id: u32) bool {
            for (self.effects.items, 0..) |*effect, i| {
                if (effect.effect_id == effect_id) {
                    _ = self.effects.swapRemove(i);
                    return true;
                }
            }
            return false;
        }
        
        /// Remove all effects from a specific source
        pub fn removeEffectsFromSource(self: *Self, source_id: u32) void {
            var i: usize = 0;
            while (i < self.effects.items.len) {
                if (self.effects.items[i].source_id == source_id) {
                    _ = self.effects.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }
        
        /// Update all effects and remove expired ones
        pub fn update(self: *Self, delta_time: f32) void {
            var i: usize = 0;
            while (i < self.effects.items.len) {
                self.effects.items[i].update(delta_time);
                if (self.effects.items[i].isExpired()) {
                    _ = self.effects.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }
        
        /// Calculate final value based on stacking rules
        pub fn calculateValue(self: *const Self, base_value: ValueType) ValueType {
            if (self.effects.items.len == 0) return base_value;
            
            return switch (self.config.stack_type) {
                .replace => if (self.effects.items.len > 0) self.effects.items[self.effects.items.len - 1].value else base_value,
                .add => self.addValues(base_value),
                .multiply => self.multiplyValues(base_value),
                .max => self.maxValue(base_value),
                .min => self.minValue(base_value),
                .refresh => if (self.effects.items.len > 0) self.effects.items[self.effects.items.len - 1].value else base_value,
            };
        }
        
        /// Get all active effects
        pub fn getActiveEffects(self: *const Self) []const EffectType {
            // This returns all effects since we remove expired ones in update()
            return self.effects.items;
        }
        
        /// Clear all effects
        pub fn clearAll(self: *Self) void {
            self.effects.clearRetainingCapacity();
        }
        
        /// Get count of active effects
        pub fn countActiveEffects(self: *const Self) usize {
            return self.effects.items.len;
        }
        
        // Helper methods for different value types
        fn addValues(self: *const Self, base_value: ValueType) ValueType {
            var result = base_value;
            for (self.effects.items) |effect| {
                if (effect.active) {
                    switch (@typeInfo(ValueType)) {
                        .Float, .ComptimeFloat => result += effect.value,
                        .Int, .ComptimeInt => result += effect.value,
                        else => @compileError("Add operation not supported for type " ++ @typeName(ValueType)),
                    }
                }
            }
            return result;
        }
        
        fn multiplyValues(self: *const Self, base_value: ValueType) ValueType {
            var result = base_value;
            for (self.effects.items) |effect| {
                if (effect.active) {
                    switch (@typeInfo(ValueType)) {
                        .Float, .ComptimeFloat => result *= effect.value,
                        .Int, .ComptimeInt => result = @intFromFloat(@as(f32, @floatFromInt(result)) * @as(f32, @floatFromInt(effect.value))),
                        else => @compileError("Multiply operation not supported for type " ++ @typeName(ValueType)),
                    }
                }
            }
            return result;
        }
        
        fn maxValue(self: *const Self, base_value: ValueType) ValueType {
            var result = base_value;
            for (self.effects.items) |effect| {
                if (effect.active) {
                    result = @max(result, effect.value);
                }
            }
            return result;
        }
        
        fn minValue(self: *const Self, base_value: ValueType) ValueType {
            var result = base_value;
            for (self.effects.items) |effect| {
                if (effect.active) {
                    result = @min(result, effect.value);
                }
            }
            return result;
        }
        
        fn removeOldestEffect(self: *Self) void {
            if (self.effects.items.len > 0) {
                _ = self.effects.orderedRemove(0); // Remove first (oldest) effect
            }
        }
    };
}

/// Common effect managers for typical use cases
pub const SpeedManager = DurationManager(f32);
pub const DamageManager = DurationManager(f32);
pub const IntManager = DurationManager(i32);
pub const BoolManager = DurationManager(bool);

/// Multi-effect system that manages multiple effect types
pub const MultiEffectSystem = struct {
    speed_effects: SpeedManager,
    damage_effects: DamageManager,
    health_effects: DamageManager,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) MultiEffectSystem {
        return .{
            .speed_effects = SpeedManager.init(allocator, .{ .stack_type = .multiply, .max_stacks = 5 }),
            .damage_effects = DamageManager.init(allocator, .{ .stack_type = .multiply, .max_stacks = 5 }),
            .health_effects = DamageManager.init(allocator, .{ .stack_type = .add, .max_stacks = 10 }),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *MultiEffectSystem) void {
        self.speed_effects.deinit();
        self.damage_effects.deinit();
        self.health_effects.deinit();
    }
    
    pub fn update(self: *MultiEffectSystem, delta_time: f32) void {
        self.speed_effects.update(delta_time);
        self.damage_effects.update(delta_time);
        self.health_effects.update(delta_time);
    }
    
    pub fn clearAll(self: *MultiEffectSystem) void {
        self.speed_effects.clearAll();
        self.damage_effects.clearAll();
        self.health_effects.clearAll();
    }
    
    /// Get modified speed value
    pub fn getModifiedSpeed(self: *const MultiEffectSystem, base_speed: f32) f32 {
        return self.speed_effects.calculateValue(base_speed);
    }
    
    /// Get modified damage value
    pub fn getModifiedDamage(self: *const MultiEffectSystem, base_damage: f32) f32 {
        return self.damage_effects.calculateValue(base_damage);
    }
    
    /// Get health modification (for regeneration/poison)
    pub fn getHealthModification(self: *const MultiEffectSystem) f32 {
        return self.health_effects.calculateValue(0.0); // Base of 0 since we're adding
    }
};

test "effect basic functionality" {
    const allocator = std.testing.allocator;
    
    // Test speed effect with multiply stacking
    var speed_mgr = SpeedManager.init(allocator, .{ .stack_type = .multiply, .max_stacks = 3 });
    defer speed_mgr.deinit();
    
    // Add speed boost effect
    _ = try speed_mgr.addEffect(1.5, 2.0, 1); // 50% speed boost
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), speed_mgr.calculateValue(100.0), 0.1);
    
    // Add another speed boost
    _ = try speed_mgr.addEffect(1.2, 1.0, 2); // 20% speed boost  
    try std.testing.expectApproxEqAbs(@as(f32, 180.0), speed_mgr.calculateValue(100.0), 0.1); // 1.5 * 1.2 * 100
    
    // Update and let first effect expire
    speed_mgr.update(2.1);
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), speed_mgr.calculateValue(100.0), 0.1); // Only 1.2 multiplier remains
}

test "effect stacking types" {
    const allocator = std.testing.allocator;
    
    // Test replace stacking
    var replace_mgr = DamageManager.init(allocator, .{ .stack_type = .replace });
    defer replace_mgr.deinit();
    
    _ = try replace_mgr.addEffect(50.0, 1.0, 1);
    _ = try replace_mgr.addEffect(75.0, 1.0, 2);
    
    try std.testing.expectApproxEqAbs(@as(f32, 75.0), replace_mgr.calculateValue(25.0), 0.1); // Should be replaced value
    
    // Test add stacking
    var add_mgr = DamageManager.init(allocator, .{ .stack_type = .add });
    defer add_mgr.deinit();
    
    _ = try add_mgr.addEffect(10.0, 1.0, 1);
    _ = try add_mgr.addEffect(5.0, 1.0, 2);
    
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), add_mgr.calculateValue(25.0), 0.1); // 25 + 10 + 5
}

test "multi-effect system" {
    const allocator = std.testing.allocator;
    
    var system = MultiEffectSystem.init(allocator);
    defer system.deinit();
    
    // Add effects
    _ = try system.speed_effects.addEffect(1.5, 1.0, 1);
    _ = try system.damage_effects.addEffect(2.0, 1.0, 1);
    
    // Test calculations
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), system.getModifiedSpeed(100.0), 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), system.getModifiedDamage(25.0), 0.1);
    
    // Update system
    system.update(0.5);
    try std.testing.expect(system.speed_effects.countActiveEffects() == 1);
    
    // Let effects expire
    system.update(1.0);
    try std.testing.expect(system.speed_effects.countActiveEffects() == 0);
}