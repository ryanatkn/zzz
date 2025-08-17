/// Base context for all update operations
/// Provides frame-specific data for consistent parameter passing
const std = @import("std");

// Use engine time utilities instead of standalone implementation
const time_utils = @import("../../core/time.zig");

/// Base context for all update operations
pub const UpdateContext = struct {
    /// Start time for this frame (high-precision ticks)
    frame_start_ticks: u64,
    /// Delta time since last frame in seconds
    delta_time: f32,
    /// Current frame number
    frame_number: u64,
    /// Is the game paused?
    is_paused: bool,
    /// Allocator for temporary allocations during this frame
    frame_allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, delta_time: f32, frame_number: u64) UpdateContext {
        return .{
            .frame_start_ticks = time_utils.Time.getPerformanceCounter(),
            .delta_time = delta_time,
            .frame_number = frame_number,
            .is_paused = false,
            .frame_allocator = allocator,
        };
    }

    pub fn withPause(self: UpdateContext, paused: bool) UpdateContext {
        var result = self;
        result.is_paused = paused;
        return result;
    }

    /// Get effective delta time (0 if paused)
    pub fn effectiveDeltaTime(self: UpdateContext) f32 {
        return if (self.is_paused) 0.0 else self.delta_time;
    }

    /// Get time elapsed since frame start in seconds
    pub fn frameElapsedSec(self: UpdateContext) f32 {
        return time_utils.Time.getElapsedSec(self.frame_start_ticks);
    }

    /// Get time elapsed since frame start in milliseconds
    pub fn frameElapsedMs(self: UpdateContext) f32 {
        return time_utils.Time.getElapsedMs(self.frame_start_ticks);
    }
};