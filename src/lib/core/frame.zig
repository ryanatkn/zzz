const std = @import("std");
const time_utils = @import("time.zig");

/// Minimal frame context for consistent timing and allocation
/// Replaces the complex multi-layered context system with essential frame data
pub const FrameContext = struct {
    /// Delta time since last frame in seconds
    delta_time: f32,
    /// Is the game paused?
    is_paused: bool,
    /// Current frame number
    frame_number: u64,
    /// Allocator for temporary allocations during this frame
    frame_allocator: std.mem.Allocator,
    /// High-precision frame start time for profiling
    frame_start_ticks: u64,

    pub fn init(allocator: std.mem.Allocator, delta_time: f32, frame_number: u64, is_paused: bool) FrameContext {
        return .{
            .delta_time = delta_time,
            .is_paused = is_paused,
            .frame_number = frame_number,
            .frame_allocator = allocator,
            .frame_start_ticks = time_utils.Time.getPerformanceCounter(),
        };
    }

    /// Get effective delta time (0 if paused, normal delta if not)
    /// This is the primary way systems should get deltaTime to respect pause state
    pub fn effectiveDelta(self: FrameContext) f32 {
        return if (self.is_paused) 0.0 else self.delta_time;
    }

    /// Get raw delta time regardless of pause state
    /// Use sparingly - most systems should use effectiveDelta()
    pub fn rawDelta(self: FrameContext) f32 {
        return self.delta_time;
    }

    /// Get time elapsed since frame start in seconds (for profiling)
    pub fn frameElapsedSec(self: FrameContext) f32 {
        return time_utils.Time.getElapsedSec(self.frame_start_ticks);
    }

    /// Get time elapsed since frame start in milliseconds (for profiling)
    pub fn frameElapsedMs(self: FrameContext) f32 {
        return time_utils.Time.getElapsedMs(self.frame_start_ticks);
    }
};
