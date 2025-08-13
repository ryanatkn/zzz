const std = @import("std");
const signal = @import("signal.zig");
const derived = @import("derived.zig");
const effect = @import("effect.zig");
const c = @import("../c.zig");

pub const TimeInterval = enum {
    Frame,        // Every frame (~16ms at 60fps)
    Second,       // Every second (1000ms)
    Minute,       // Every minute (60000ms)
    Custom,       // Custom interval in ms
};

pub const Time = struct {
    allocator: std.mem.Allocator,
    
    // Core time signals - updated at different granularities
    now_ms: *signal.Signal(u64),           // Current time in ms (updated per interval)
    now_seconds: *signal.Signal(u64),      // Current time in seconds
    frame_count: *signal.Signal(u64),      // Total frames since start
    
    // Cached derived values at different granularities
    fps: *derived.Derived(u32),          // FPS derived once per second
    frame_time_ms: *derived.Derived(f32), // Average frame time
    uptime_seconds: *derived.Derived(u64), // Time since start
    
    // Configuration
    update_interval_ms: u32,
    is_running: bool,
    
    // Internal state for FPS calculation
    start_time: u64,
    last_fps_time: u64,
    last_fps_frame_count: u64,
    performance_frequency: u64,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, interval: TimeInterval) !*Time {
        const self = try allocator.create(Time);
        
        const interval_ms: u32 = switch (interval) {
            .Frame => 16,    // ~60fps
            .Second => 1000,
            .Minute => 60000,
            .Custom => 1000,  // Default
        };
        
        const start_time = c.sdl.SDL_GetPerformanceCounter();
        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        
        // Create signal instances
        const now_ms_signal = try allocator.create(signal.Signal(u64));
        now_ms_signal.* = try signal.Signal(u64).init(allocator, 0);
        
        const now_seconds_signal = try allocator.create(signal.Signal(u64));
        now_seconds_signal.* = try signal.Signal(u64).init(allocator, 0);
        
        const frame_count_signal = try allocator.create(signal.Signal(u64));
        frame_count_signal.* = try signal.Signal(u64).init(allocator, 0);

        self.* = .{
            .allocator = allocator,
            .now_ms = now_ms_signal,
            .now_seconds = now_seconds_signal,
            .frame_count = frame_count_signal,
            .fps = undefined, // Set below
            .frame_time_ms = undefined,
            .uptime_seconds = undefined,
            .update_interval_ms = interval_ms,
            .is_running = false,
            .start_time = start_time,
            .last_fps_time = start_time,
            .last_fps_frame_count = 0,
            .performance_frequency = frequency,
        };
        
        // Create derived values with caching
        self.fps = try self.createFPSDerived();
        self.frame_time_ms = try self.createFrameTimeDerived();
        self.uptime_seconds = try self.createUptimeDerived();
        
        return self;
    }
    
    fn createFPSDerived(self: *Time) !*derived.Derived(u32) {
        const TimeRef = struct {
            var time_ref: *Time = undefined;
        };
        TimeRef.time_ref = self;
        
        return try derived.derived(self.allocator, u32, struct {
            fn compute() u32 {
                const time = TimeRef.time_ref;
                
                // Depend on seconds to trigger recomputation once per second
                const current_seconds = time.now_seconds.get();
                _ = current_seconds; // Track dependency
                
                // Get current time and frame count
                const current_time = c.sdl.SDL_GetPerformanceCounter();
                const current_frames = time.frame_count.peek(); // Don't track frames
                
                // Calculate time elapsed since last FPS calculation
                const elapsed_ticks = current_time - time.last_fps_time;
                const elapsed_seconds = @as(f64, @floatFromInt(elapsed_ticks)) / @as(f64, @floatFromInt(time.performance_frequency));
                
                // If at least one second has passed, calculate FPS
                if (elapsed_seconds >= 1.0) {
                    const frames_elapsed = current_frames - time.last_fps_frame_count;
                    const fps = @as(u32, @intFromFloat(@as(f64, @floatFromInt(frames_elapsed)) / elapsed_seconds));
                    
                    // Update internal state for next calculation
                    // Cast away const for internal state updates
                    const mutable_time = @as(*Time, @constCast(@ptrCast(time)));
                    mutable_time.last_fps_time = current_time;
                    mutable_time.last_fps_frame_count = current_frames;
                    
                    return fps;
                }
                
                // Return previous FPS if less than a second has passed
                return 60; // Default reasonable value
            }
        }.compute);
    }
    
    fn createFrameTimeDerived(self: *Time) !*derived.Derived(f32) {
        const TimeRef = struct {
            var time_ref: *Time = undefined;
        };
        TimeRef.time_ref = self;
        
        return try derived.derived(self.allocator, f32, struct {
            fn compute() f32 {
                const time = TimeRef.time_ref;
                const fps = time.fps.get(); // Depend on FPS computation
                if (fps == 0) return 0.0;
                return 1000.0 / @as(f32, @floatFromInt(fps));
            }
        }.compute);
    }
    
    fn createUptimeDerived(self: *Time) !*derived.Derived(u64) {
        const TimeRef = struct {
            var time_ref: *Time = undefined;
        };
        TimeRef.time_ref = self;
        
        return try derived.derived(self.allocator, u64, struct {
            fn compute() u64 {
                const time = TimeRef.time_ref;
                return time.now_seconds.get(); // Simple passthrough with caching
            }
        }.compute);
    }
    
    pub fn start(self: *Time) void {
        if (self.is_running) return;
        self.is_running = true;
        
        // Update initial time
        self.updateTime();
    }
    
    pub fn stop(self: *Time) void {
        self.is_running = false;
    }
    
    pub fn tick(self: *Time) void {
        if (!self.is_running) return;
        
        // Increment frame counter every frame
        const current_frames = self.frame_count.peek() + 1;
        self.frame_count.set(current_frames);
        
        // Update time signals if interval has passed
        self.updateTime();
    }
    
    fn updateTime(self: *Time) void {
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        const elapsed_ms = (current_time - self.start_time) * 1000 / self.performance_frequency;
        
        // Update milliseconds signal if interval has passed
        const last_ms = self.now_ms.peek();
        if (elapsed_ms >= last_ms + self.update_interval_ms) {
            self.now_ms.set(elapsed_ms);
        }
        
        // Update seconds signal every second
        const elapsed_seconds = elapsed_ms / 1000;
        const last_seconds = self.now_seconds.peek();
        if (elapsed_seconds != last_seconds) {
            self.now_seconds.set(elapsed_seconds);
        }
    }
    
    pub fn deinit(self: *Time) void {
        self.stop();
        
        // Clean up signals
        self.now_ms.deinit();
        self.allocator.destroy(self.now_ms);
        self.now_seconds.deinit();
        self.allocator.destroy(self.now_seconds);
        self.frame_count.deinit();
        self.allocator.destroy(self.frame_count);
        
        // Clean up derived values
        self.fps.deinit();
        self.allocator.destroy(self.fps);
        self.frame_time_ms.deinit();
        self.allocator.destroy(self.frame_time_ms);
        self.uptime_seconds.deinit();
        self.allocator.destroy(self.uptime_seconds);
        
        self.allocator.destroy(self);
    }
    
    // Convenience methods
    pub fn getFPS(self: *Time) u32 {
        return self.fps.get();
    }
    
    pub fn getFrameTimeMS(self: *Time) f32 {
        return self.frame_time_ms.get();
    }
    
    pub fn getUptimeSeconds(self: *Time) u64 {
        return self.uptime_seconds.get();
    }
};

// Global time instance for convenience
var global_time: ?*Time = null;

pub fn initGlobalTime(allocator: std.mem.Allocator, interval: TimeInterval) !void {
    if (global_time != null) return;
    
    global_time = try Time.init(allocator, interval);
    global_time.?.start();
}

pub fn deinitGlobalTime() void {
    if (global_time) |time| {
        time.deinit();
        global_time = null;
    }
}

pub fn getGlobalTime() ?*Time {
    return global_time;
}

pub fn tickGlobalTime() void {
    if (global_time) |time| {
        time.tick();
    }
}

// Convenience functions for accessing global time
pub fn getFPS() u32 {
    if (global_time) |time| {
        return time.getFPS();
    }
    return 0;
}

pub fn getFrameTimeMS() f32 {
    if (global_time) |time| {
        return time.getFrameTimeMS();
    }
    return 0.0;
}

pub fn getUptimeSeconds() u64 {
    if (global_time) |time| {
        return time.getUptimeSeconds();
    }
    return 0;
}

// Convenience function to create FPS display text
pub fn getFPSText(allocator: std.mem.Allocator) ![]const u8 {
    const fps = getFPS();
    return try std.fmt.allocPrint(allocator, "FPS: {d}", .{fps});
}