const std = @import("std");
const c = @import("../platform/sdl.zig");

/// Time management utilities for SDL-based applications
/// Provides consistent time handling and delta time calculations

/// Static time utilities
pub const Time = struct {
    /// Get current time in milliseconds
    pub fn getTimeMs() f32 {
        return @as(f32, @floatFromInt(c.sdl.SDL_GetTicks()));
    }

    /// Get high-precision current time in seconds  
    pub fn getTimeSec() f32 {
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        return @as(f32, @floatFromInt(current_time)) / @as(f32, @floatFromInt(frequency));
    }

    /// Get high-precision performance counter (raw ticks)
    pub fn getPerformanceCounter() u64 {
        return c.sdl.SDL_GetPerformanceCounter();
    }

    /// Get performance counter frequency (ticks per second)
    pub fn getPerformanceFrequency() u64 {
        return c.sdl.SDL_GetPerformanceFrequency();
    }

    /// Convert performance counter ticks to seconds
    pub fn ticksToSeconds(ticks: u64) f32 {
        const frequency = getPerformanceFrequency();
        return @as(f32, @floatFromInt(ticks)) / @as(f32, @floatFromInt(frequency));
    }

    /// Convert performance counter difference to seconds
    pub fn tickDeltaToSeconds(start_ticks: u64, end_ticks: u64) f32 {
        const delta = end_ticks - start_ticks;
        return ticksToSeconds(delta);
    }

    /// Calculate elapsed time in seconds since a start time
    pub fn getElapsedSec(start_time: u64) f32 {
        const current_time = getPerformanceCounter();
        return tickDeltaToSeconds(start_time, current_time);
    }

    /// Calculate elapsed time in milliseconds since a start time
    pub fn getElapsedMs(start_time: u64) f32 {
        return getElapsedSec(start_time) * 1000.0;
    }
    
    /// Create a new timestamp for current time
    pub fn now() Timestamp {
        return Timestamp{ .ticks = getPerformanceCounter() };
    }
};

/// Timestamp represents a point in time
pub const Timestamp = struct {
    ticks: u64,
    
    /// Get elapsed time in seconds since this timestamp
    pub fn getElapsedSec(self: Timestamp) f32 {
        return Time.getElapsedSec(self.ticks);
    }
    
    /// Get elapsed time in milliseconds since this timestamp  
    pub fn getElapsedMs(self: Timestamp) f32 {
        return Time.getElapsedMs(self.ticks);
    }
    
    /// Check if elapsed time exceeds a duration
    pub fn hasElapsed(self: Timestamp, duration_sec: f32) bool {
        return self.getElapsedSec() >= duration_sec;
    }
};

/// Delta time calculator for consistent frame timing
pub const DeltaTime = struct {
    last_frame_time: u64,
    accumulated_time: f32,
    max_delta: f32,

    const DEFAULT_MAX_DELTA = 1.0 / 30.0; // Cap at 30 FPS minimum

    pub fn init() DeltaTime {
        return DeltaTime{
            .last_frame_time = Time.getPerformanceCounter(),
            .accumulated_time = 0.0,
            .max_delta = DEFAULT_MAX_DELTA,
        };
    }

    pub fn initWithMaxDelta(max_delta: f32) DeltaTime {
        return DeltaTime{
            .last_frame_time = Time.getPerformanceCounter(),
            .accumulated_time = 0.0,
            .max_delta = max_delta,
        };
    }

    /// Update and get delta time for current frame
    pub fn update(self: *DeltaTime) f32 {
        const current_time = Time.getPerformanceCounter();
        const raw_delta = Time.tickDeltaToSeconds(self.last_frame_time, current_time);
        
        // Clamp delta time to prevent large jumps
        const delta = @min(raw_delta, self.max_delta);
        
        self.last_frame_time = current_time;
        self.accumulated_time += delta;
        
        return delta;
    }

    /// Get accumulated time since initialization
    pub fn getAccumulatedTime(self: *const DeltaTime) f32 {
        return self.accumulated_time;
    }

    /// Reset the delta time calculator
    pub fn reset(self: *DeltaTime) void {
        self.last_frame_time = Time.getPerformanceCounter();
        self.accumulated_time = 0.0;
    }
};

/// Timer for measuring durations and timeouts
pub const Timer = struct {
    start_time: u64,
    duration: f32,

    pub fn init(duration_sec: f32) Timer {
        return Timer{
            .start_time = Time.getPerformanceCounter(),
            .duration = duration_sec,
        };
    }

    /// Check if timer has finished
    pub fn isFinished(self: *const Timer) bool {
        return Time.getElapsedSec(self.start_time) >= self.duration;
    }

    /// Get remaining time (0 if finished)
    pub fn getRemaining(self: *const Timer) f32 {
        const elapsed = Time.getElapsedSec(self.start_time);
        return @max(0.0, self.duration - elapsed);
    }

    /// Get progress from 0.0 to 1.0
    pub fn getProgress(self: *const Timer) f32 {
        const elapsed = Time.getElapsedSec(self.start_time);
        return @min(1.0, elapsed / self.duration);
    }

    /// Reset timer to start again
    pub fn reset(self: *Timer) void {
        self.start_time = Time.getPerformanceCounter();
    }

    /// Reset timer with new duration
    pub fn resetWithDuration(self: *Timer, duration_sec: f32) void {
        self.start_time = Time.getPerformanceCounter();
        self.duration = duration_sec;
    }
};

/// Cooldown timer for abilities and actions
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
};

test "Time.getTimeMs returns positive value" {
    const time_ms = Time.getTimeMs();
    try std.testing.expect(time_ms >= 0.0);
}

test "DeltaTime.update returns reasonable values" {
    var delta_timer = DeltaTime.init();
    
    // Sleep briefly to get some delta time
    std.time.sleep(1_000_000); // 1ms
    
    const delta = delta_timer.update();
    try std.testing.expect(delta > 0.0);
    try std.testing.expect(delta < 1.0); // Should be much less than 1 second
}

test "Timer.isFinished works correctly" {
    var timer = Timer.init(0.001); // 1ms
    try std.testing.expect(!timer.isFinished()); // Should not be finished immediately
    
    std.time.sleep(2_000_000); // 2ms
    try std.testing.expect(timer.isFinished()); // Should be finished now
}

test "Cooldown system works correctly" {
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