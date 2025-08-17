const std = @import("std");

/// Simple countdown timer for cooldowns and durations
pub const Timer = struct {
    duration: f32,
    remaining: f32,

    pub fn init(duration: f32) Timer {
        return .{
            .duration = duration,
            .remaining = 0,
        };
    }

    /// Start the timer with its full duration
    pub fn start(self: *Timer) void {
        self.remaining = self.duration;
    }

    /// Start the timer with a custom duration
    pub fn startWith(self: *Timer, duration: f32) void {
        self.remaining = duration;
    }

    /// Update the timer by deltaTime
    pub fn update(self: *Timer, deltaTime: f32) void {
        if (self.remaining > 0) {
            self.remaining -= deltaTime;
            if (self.remaining < 0) {
                self.remaining = 0;
            }
        }
    }

    /// Check if timer is finished (reached zero)
    pub fn isFinished(self: *const Timer) bool {
        return self.remaining <= 0;
    }

    /// Check if timer is currently running
    pub fn isRunning(self: *const Timer) bool {
        return self.remaining > 0;
    }

    /// Get progress from 0.0 (just started) to 1.0 (finished)
    pub fn getProgress(self: *const Timer) f32 {
        if (self.duration <= 0) return 1.0;
        return @max(0.0, @min(1.0, (self.duration - self.remaining) / self.duration));
    }

    /// Get remaining time as fraction from 1.0 (full) to 0.0 (finished)
    pub fn getRemainingFraction(self: *const Timer) f32 {
        if (self.duration <= 0) return 0.0;
        return @max(0.0, @min(1.0, self.remaining / self.duration));
    }

    /// Get remaining time in seconds
    pub fn getRemaining(self: *const Timer) f32 {
        return @max(0.0, self.remaining);
    }

    /// Change the base duration
    pub fn setDuration(self: *Timer, new_duration: f32) void {
        self.duration = new_duration;
    }

    /// Reset timer to inactive state
    pub fn reset(self: *Timer) void {
        self.remaining = 0;
    }

    // Aliases for cooldown compatibility
    pub const isReady = isFinished;
    pub const startCooldown = start;
};

/// Cooldown timer specifically for rate-limiting actions
/// This is just an alias to Timer with a different naming convention
pub const CooldownTimer = Timer;

/// Cooldown pattern with cooldown-specific naming
pub const Cooldown = struct {
    timer: Timer,

    pub fn init(duration: f32) Cooldown {
        return .{ .timer = Timer.init(duration) };
    }

    /// Check if cooldown is ready (not on cooldown)
    pub fn isReady(self: *const Cooldown) bool {
        return self.timer.isFinished();
    }

    /// Start the cooldown
    pub fn start(self: *Cooldown) void {
        self.timer.start();
    }

    /// Start cooldown with custom duration (doesn't change base duration)
    pub fn startWithDuration(self: *Cooldown, custom_duration: f32) void {
        self.timer.startWith(custom_duration);
    }

    /// Update cooldown with delta time
    pub fn update(self: *Cooldown, delta_time: f32) void {
        self.timer.update(delta_time);
    }

    /// Get cooldown progress from 0.0 (ready) to 1.0 (just started)
    pub fn getProgress(self: *const Cooldown) f32 {
        return self.timer.getRemainingFraction();
    }

    /// Get remaining time
    pub fn getRemaining(self: *const Cooldown) f32 {
        return self.timer.getRemaining();
    }

    /// Reset cooldown (make it ready immediately)
    pub fn reset(self: *Cooldown) void {
        self.timer.reset();
    }

    /// Change the base duration
    pub fn setDuration(self: *Cooldown, new_duration: f32) void {
        self.timer.setDuration(new_duration);
    }
};

/// Recharge timer that accumulates resources over time
pub const RechargeTimer = struct {
    recharge_rate: f32, // units per second
    accumulator: f32,

    pub fn init(recharge_rate: f32) RechargeTimer {
        return .{
            .recharge_rate = recharge_rate,
            .accumulator = 0,
        };
    }

    /// Update the recharge timer and return how many whole units to add
    pub fn update(self: *RechargeTimer, deltaTime: f32) u32 {
        self.accumulator += self.recharge_rate * deltaTime;

        var units_to_add: u32 = 0;
        while (self.accumulator >= 1.0) {
            units_to_add += 1;
            self.accumulator -= 1.0;
        }

        return units_to_add;
    }

    /// Reset accumulator
    pub fn reset(self: *RechargeTimer) void {
        self.accumulator = 0;
    }
};

test "Timer basic functionality" {
    var timer = Timer.init(2.0);

    // Initial state
    try std.testing.expect(timer.isFinished());
    try std.testing.expect(!timer.isRunning());

    // Start timer
    timer.start();
    try std.testing.expect(!timer.isFinished());
    try std.testing.expect(timer.isRunning());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), timer.getProgress(), 0.01);

    // Update partway
    timer.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), timer.getProgress(), 0.01);
    try std.testing.expect(timer.isRunning());

    // Finish timer
    timer.update(1.5);
    try std.testing.expect(timer.isFinished());
    try std.testing.expect(!timer.isRunning());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), timer.getProgress(), 0.01);
}

test "CooldownTimer functionality" {
    var cooldown = CooldownTimer.init(1.0);

    // Initial state - ready
    try std.testing.expect(cooldown.isReady());

    // Trigger cooldown
    cooldown.start();
    try std.testing.expect(!cooldown.isReady());

    // Update partway
    cooldown.update(0.5);
    try std.testing.expect(!cooldown.isReady());

    // Complete cooldown
    cooldown.update(0.6);
    try std.testing.expect(cooldown.isReady());
}

test "Cooldown pattern functionality" {
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

test "RechargeTimer functionality" {
    var recharge = RechargeTimer.init(2.0); // 2 units per second

    // No time passed
    try std.testing.expectEqual(@as(u32, 0), recharge.update(0.0));

    // Half a unit worth of time
    try std.testing.expectEqual(@as(u32, 0), recharge.update(0.25));

    // Complete one unit
    try std.testing.expectEqual(@as(u32, 1), recharge.update(0.25));

    // Multiple units at once
    try std.testing.expectEqual(@as(u32, 2), recharge.update(1.0));
}

/// Multi-timer manager for multiple abilities
pub fn TimerManager(comptime max_timers: usize) type {
    return struct {
        const Self = @This();

        timers: [max_timers]Timer,
        count: usize,

        pub fn init() Self {
            return Self{
                .timers = undefined,
                .count = 0,
            };
        }

        /// Add a new timer and return its index
        pub fn addTimer(self: *Self, duration: f32) ?usize {
            if (self.count >= max_timers) return null;

            self.timers[self.count] = Timer.init(duration);
            const index = self.count;
            self.count += 1;
            return index;
        }

        /// Check if a specific timer is finished
        pub fn isFinished(self: *const Self, index: usize) bool {
            if (index >= self.count) return false;
            return self.timers[index].isFinished();
        }

        /// Start a specific timer
        pub fn start(self: *Self, index: usize) void {
            if (index < self.count) {
                self.timers[index].start();
            }
        }

        /// Update all timers
        pub fn updateAll(self: *Self, delta_time: f32) void {
            for (0..self.count) |i| {
                self.timers[i].update(delta_time);
            }
        }

        /// Get remaining time for a specific timer
        pub fn getRemaining(self: *const Self, index: usize) f32 {
            if (index >= self.count) return 0.0;
            return self.timers[index].getRemaining();
        }

        /// Get progress for a specific timer
        pub fn getProgress(self: *const Self, index: usize) f32 {
            if (index >= self.count) return 0.0;
            return self.timers[index].getProgress();
        }

        /// Reset a specific timer
        pub fn reset(self: *Self, index: usize) void {
            if (index < self.count) {
                self.timers[index].reset();
            }
        }

        /// Reset all timers
        pub fn resetAll(self: *Self) void {
            for (0..self.count) |i| {
                self.timers[i].reset();
            }
        }
    };
}

/// Spell-specific timer system for 8-slot spell cooldowns
pub const SpellTimerSystem = struct {
    timers: [8]Timer, // 8 spell slots

    pub fn init() SpellTimerSystem {
        return SpellTimerSystem{
            .timers = [_]Timer{Timer.init(0.0)} ** 8,
        };
    }

    /// Set timer duration for a spell slot
    pub fn setSlotDuration(self: *SpellTimerSystem, slot: usize, duration: f32) void {
        if (slot < 8) {
            self.timers[slot].setDuration(duration);
        }
    }

    /// Check if spell slot can be used (timer finished)
    pub fn canUse(self: *const SpellTimerSystem, slot: usize) bool {
        if (slot >= 8) return false;
        return self.timers[slot].isFinished();
    }

    /// Start timer for a spell slot
    pub fn startTimer(self: *SpellTimerSystem, slot: usize) void {
        if (slot < 8) {
            self.timers[slot].start();
        }
    }

    /// Update all spell timers
    pub fn update(self: *SpellTimerSystem, delta_time: f32) void {
        for (0..8) |i| {
            self.timers[i].update(delta_time);
        }
    }

    /// Get remaining time for a spell slot
    pub fn getRemainingTime(self: *const SpellTimerSystem, slot: usize) f32 {
        if (slot >= 8) return 0.0;
        return self.timers[slot].getRemaining();
    }

    /// Get progress for a spell slot (0.0 = ready, 1.0 = just used)
    pub fn getProgress(self: *const SpellTimerSystem, slot: usize) f32 {
        if (slot >= 8) return 0.0;
        return self.timers[slot].getRemainingFraction();
    }
};

/// Global timer tracker for system-wide abilities
pub const GlobalTimer = struct {
    timer: Timer,

    pub fn init(duration: f32) GlobalTimer {
        return GlobalTimer{
            .timer = Timer.init(duration),
        };
    }

    /// Check if global timer is finished
    pub fn isFinished(self: *const GlobalTimer) bool {
        return self.timer.isFinished();
    }

    /// Start global timer
    pub fn start(self: *GlobalTimer) void {
        self.timer.start();
    }

    /// Update global timer
    pub fn update(self: *GlobalTimer, delta_time: f32) void {
        self.timer.update(delta_time);
    }

    /// Get remaining time
    pub fn getRemaining(self: *const GlobalTimer) f32 {
        return self.timer.getRemaining();
    }

    /// Get progress
    pub fn getProgress(self: *const GlobalTimer) f32 {
        return self.timer.getProgress();
    }
};

test "TimerManager functionality" {
    var manager = TimerManager(4).init();

    const spell_timer = manager.addTimer(2.0); // 2 second spell timer
    const item_timer = manager.addTimer(1.0); // 1 second item timer

    try std.testing.expect(spell_timer != null);
    try std.testing.expect(item_timer != null);
    try std.testing.expect(manager.isFinished(spell_timer.?));
    try std.testing.expect(manager.isFinished(item_timer.?));

    manager.start(spell_timer.?);
    try std.testing.expect(!manager.isFinished(spell_timer.?));
    try std.testing.expect(manager.isFinished(item_timer.?)); // Other timer unaffected

    manager.updateAll(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), manager.getRemaining(spell_timer.?), 0.001);
}

test "SpellTimerSystem functionality" {
    var spell_system = SpellTimerSystem.init();

    spell_system.setSlotDuration(0, 3.0); // Slot 0: 3 second timer
    spell_system.setSlotDuration(1, 1.5); // Slot 1: 1.5 second timer

    try std.testing.expect(spell_system.canUse(0));
    try std.testing.expect(spell_system.canUse(1));

    spell_system.startTimer(0);
    try std.testing.expect(!spell_system.canUse(0));
    try std.testing.expect(spell_system.canUse(1)); // Other slot unaffected

    spell_system.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), spell_system.getRemainingTime(0), 0.001);
}
