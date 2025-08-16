const std = @import("std");

/// Simple cooldown timer for abilities and actions
pub const Cooldown = struct {
    remaining: f32,
    duration: f32,

    pub fn init(duration_sec: f32) Cooldown {
        return Cooldown{
            .remaining = 0.0,
            .duration = duration_sec,
        };
    }

    /// Check if cooldown is ready (not on cooldown)
    pub fn isReady(self: *const Cooldown) bool {
        return self.remaining <= 0.0;
    }

    /// Start the cooldown
    pub fn start(self: *Cooldown) void {
        self.remaining = self.duration;
    }

    /// Start cooldown with custom duration (doesn't change base duration)
    pub fn startWithDuration(self: *Cooldown, custom_duration: f32) void {
        self.remaining = custom_duration;
    }

    /// Update cooldown with delta time
    pub fn update(self: *Cooldown, delta_time: f32) void {
        if (self.remaining > 0.0) {
            self.remaining -= delta_time;
            if (self.remaining < 0.0) {
                self.remaining = 0.0;
            }
        }
    }

    /// Get cooldown progress from 0.0 (ready) to 1.0 (just started)
    pub fn getProgress(self: *const Cooldown) f32 {
        if (self.duration <= 0.0) return 0.0;
        return @max(0.0, self.remaining / self.duration);
    }

    /// Get remaining time
    pub fn getRemaining(self: *const Cooldown) f32 {
        return @max(0.0, self.remaining);
    }

    /// Reset cooldown (make it ready immediately)
    pub fn reset(self: *Cooldown) void {
        self.remaining = 0.0;
    }

    /// Change the base duration
    pub fn setDuration(self: *Cooldown, new_duration: f32) void {
        self.duration = new_duration;
    }
};

/// Multi-cooldown manager for multiple abilities
pub fn CooldownManager(comptime max_cooldowns: usize) type {
    return struct {
        const Self = @This();
        
        cooldowns: [max_cooldowns]Cooldown,
        count: usize,

        pub fn init() Self {
            return Self{
                .cooldowns = undefined,
                .count = 0,
            };
        }

        /// Add a new cooldown and return its index
        pub fn addCooldown(self: *Self, duration: f32) ?usize {
            if (self.count >= max_cooldowns) return null;
            
            self.cooldowns[self.count] = Cooldown.init(duration);
            const index = self.count;
            self.count += 1;
            return index;
        }

        /// Check if a specific cooldown is ready
        pub fn isReady(self: *const Self, index: usize) bool {
            if (index >= self.count) return false;
            return self.cooldowns[index].isReady();
        }

        /// Start a specific cooldown
        pub fn start(self: *Self, index: usize) void {
            if (index < self.count) {
                self.cooldowns[index].start();
            }
        }

        /// Update all cooldowns
        pub fn updateAll(self: *Self, delta_time: f32) void {
            for (0..self.count) |i| {
                self.cooldowns[i].update(delta_time);
            }
        }

        /// Get remaining time for a specific cooldown
        pub fn getRemaining(self: *const Self, index: usize) f32 {
            if (index >= self.count) return 0.0;
            return self.cooldowns[index].getRemaining();
        }

        /// Get progress for a specific cooldown
        pub fn getProgress(self: *const Self, index: usize) f32 {
            if (index >= self.count) return 0.0;
            return self.cooldowns[index].getProgress();
        }

        /// Reset a specific cooldown
        pub fn reset(self: *Self, index: usize) void {
            if (index < self.count) {
                self.cooldowns[index].reset();
            }
        }

        /// Reset all cooldowns
        pub fn resetAll(self: *Self) void {
            for (0..self.count) |i| {
                self.cooldowns[i].reset();
            }
        }
    };
}

/// Spell-specific cooldown system matching current game patterns
pub const SpellCooldownSystem = struct {
    cooldowns: [8]Cooldown, // 8 spell slots
    
    pub fn init() SpellCooldownSystem {
        return SpellCooldownSystem{
            .cooldowns = [_]Cooldown{Cooldown.init(0.0)} ** 8,
        };
    }

    /// Set cooldown duration for a spell slot
    pub fn setSlotCooldown(self: *SpellCooldownSystem, slot: usize, duration: f32) void {
        if (slot < 8) {
            self.cooldowns[slot].setDuration(duration);
        }
    }

    /// Check if spell slot can be cast
    pub fn canCast(self: *const SpellCooldownSystem, slot: usize) bool {
        if (slot >= 8) return false;
        return self.cooldowns[slot].isReady();
    }

    /// Start cooldown for a spell slot
    pub fn startCooldown(self: *SpellCooldownSystem, slot: usize) void {
        if (slot < 8) {
            self.cooldowns[slot].start();
        }
    }

    /// Update all spell cooldowns
    pub fn update(self: *SpellCooldownSystem, delta_time: f32) void {
        for (0..8) |i| {
            self.cooldowns[i].update(delta_time);
        }
    }

    /// Get remaining cooldown time for a spell slot
    pub fn getRemainingTime(self: *const SpellCooldownSystem, slot: usize) f32 {
        if (slot >= 8) return 0.0;
        return self.cooldowns[slot].getRemaining();
    }

    /// Get cooldown progress for a spell slot (0.0 = ready, 1.0 = just cast)
    pub fn getProgress(self: *const SpellCooldownSystem, slot: usize) f32 {
        if (slot >= 8) return 0.0;
        return self.cooldowns[slot].getProgress();
    }
};

/// Global cooldown tracker for system-wide abilities
pub const GlobalCooldown = struct {
    cooldown: Cooldown,

    pub fn init(duration: f32) GlobalCooldown {
        return GlobalCooldown{
            .cooldown = Cooldown.init(duration),
        };
    }

    /// Check if global cooldown is ready
    pub fn isReady(self: *const GlobalCooldown) bool {
        return self.cooldown.isReady();
    }

    /// Start global cooldown
    pub fn start(self: *GlobalCooldown) void {
        self.cooldown.start();
    }

    /// Update global cooldown
    pub fn update(self: *GlobalCooldown, delta_time: f32) void {
        self.cooldown.update(delta_time);
    }

    /// Get remaining time
    pub fn getRemaining(self: *const GlobalCooldown) f32 {
        return self.cooldown.getRemaining();
    }

    /// Get progress
    pub fn getProgress(self: *const GlobalCooldown) f32 {
        return self.cooldown.getProgress();
    }
};

test "Cooldown basic functionality" {
    var cooldown = Cooldown.init(1.0); // 1 second
    try std.testing.expect(cooldown.isReady()); // Should start ready
    
    cooldown.start();
    try std.testing.expect(!cooldown.isReady()); // Should not be ready after starting
    
    cooldown.update(0.5); // Update with 0.5 seconds
    try std.testing.expect(!cooldown.isReady()); // Still on cooldown
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), cooldown.getRemaining(), 0.001);
    
    cooldown.update(0.6); // Update with another 0.6 seconds (total 1.1s)
    try std.testing.expect(cooldown.isReady()); // Should be ready now
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cooldown.getRemaining(), 0.001);
}

test "CooldownManager functionality" {
    var manager = CooldownManager(4).init();
    
    const spell_cd = manager.addCooldown(2.0); // 2 second spell cooldown
    const item_cd = manager.addCooldown(1.0); // 1 second item cooldown
    
    try std.testing.expect(spell_cd != null);
    try std.testing.expect(item_cd != null);
    try std.testing.expect(manager.isReady(spell_cd.?));
    try std.testing.expect(manager.isReady(item_cd.?));
    
    manager.start(spell_cd.?);
    try std.testing.expect(!manager.isReady(spell_cd.?));
    try std.testing.expect(manager.isReady(item_cd.?)); // Other cooldown unaffected
    
    manager.updateAll(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), manager.getRemaining(spell_cd.?), 0.001);
}

test "SpellCooldownSystem functionality" {
    var spell_system = SpellCooldownSystem.init();
    
    spell_system.setSlotCooldown(0, 3.0); // Slot 0: 3 second cooldown
    spell_system.setSlotCooldown(1, 1.5); // Slot 1: 1.5 second cooldown
    
    try std.testing.expect(spell_system.canCast(0));
    try std.testing.expect(spell_system.canCast(1));
    
    spell_system.startCooldown(0);
    try std.testing.expect(!spell_system.canCast(0));
    try std.testing.expect(spell_system.canCast(1)); // Other slot unaffected
    
    spell_system.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), spell_system.getRemainingTime(0), 0.001);
}