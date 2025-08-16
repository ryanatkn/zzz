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

    /// Reset timer to inactive state
    pub fn reset(self: *Timer) void {
        self.remaining = 0;
    }
};

/// Cooldown timer specifically for rate-limiting actions
pub const CooldownTimer = struct {
    cooldown: f32,
    remaining: f32,

    pub fn init(cooldown: f32) CooldownTimer {
        return .{
            .cooldown = cooldown,
            .remaining = 0,
        };
    }

    /// Check if the cooldown is ready (no remaining time)
    pub fn isReady(self: *const CooldownTimer) bool {
        return self.remaining <= 0;
    }

    /// Trigger the cooldown (start the countdown)
    pub fn trigger(self: *CooldownTimer) void {
        self.remaining = self.cooldown;
    }

    /// Update the cooldown timer
    pub fn update(self: *CooldownTimer, deltaTime: f32) void {
        if (self.remaining > 0) {
            self.remaining -= deltaTime;
            if (self.remaining < 0) {
                self.remaining = 0;
            }
        }
    }

    /// Reset to ready state
    pub fn reset(self: *CooldownTimer) void {
        self.remaining = 0;
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
    cooldown.trigger();
    try std.testing.expect(!cooldown.isReady());
    
    // Update partway
    cooldown.update(0.5);
    try std.testing.expect(!cooldown.isReady());
    
    // Complete cooldown
    cooldown.update(0.6);
    try std.testing.expect(cooldown.isReady());
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