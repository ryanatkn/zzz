// GPU rendering performance monitoring and metrics
// Centralized performance tracking for rendering subsystem

const std = @import("std");
const loggers = @import("../debug/loggers.zig");

/// Performance metrics for a single frame
pub const FrameMetrics = struct {
    frame_time_ms: f32,
    draw_call_count: u32,
    individual_draw_calls: u32,
    batched_draw_calls: u32,
    
    pub fn init() FrameMetrics {
        return FrameMetrics{
            .frame_time_ms = 0.0,
            .draw_call_count = 0,
            .individual_draw_calls = 0,
            .batched_draw_calls = 0,
        };
    }
};

/// Performance monitoring system for GPU rendering
pub const PerformanceMonitor = struct {
    frame_start_time: i128,
    current_metrics: FrameMetrics,
    frame_counter: u32,
    logging_frequency: u32,
    
    const Self = @This();
    
    pub fn init(logging_frequency: u32) Self {
        return Self{
            .frame_start_time = 0,
            .current_metrics = FrameMetrics.init(),
            .frame_counter = 0,
            .logging_frequency = logging_frequency,
        };
    }
    
    /// Start timing a new frame
    pub fn startFrame(self: *Self) void {
        self.frame_start_time = std.time.nanoTimestamp();
        self.current_metrics = FrameMetrics.init();
    }
    
    /// End frame timing and optionally log performance stats
    pub fn endFrame(self: *Self) void {
        const frame_end_time = std.time.nanoTimestamp();
        const frame_duration_ns = frame_end_time - self.frame_start_time;
        self.current_metrics.frame_time_ms = @as(f32, @floatFromInt(frame_duration_ns)) / 1_000_000.0;
        
        self.frame_counter += 1;
        
        // Log on first frame to confirm monitoring is active
        if (self.frame_counter == 1) {
            loggers.getGameLog().info("gpu_perf_init", "🎯 GPU performance monitoring started - first frame: {d:.2}ms", .{self.current_metrics.frame_time_ms});
        }
        
        // Log performance summary at specified frequency
        if (self.frame_counter % self.logging_frequency == 0) {
            loggers.getGameLog().info("gpu_perf", "📊 Frame: {d:.2}ms | Draw calls: {d} (individual: {d}, batched: {d}) | Frames: {d}", .{
                self.current_metrics.frame_time_ms,
                self.current_metrics.draw_call_count,
                self.current_metrics.individual_draw_calls,
                self.current_metrics.batched_draw_calls,
                self.frame_counter,
            });
        }
    }
    
    /// Record an individual draw call
    pub fn recordIndividualDraw(self: *Self) void {
        self.current_metrics.individual_draw_calls += 1;
        self.current_metrics.draw_call_count += 1;
    }
    
    /// Record a batched draw call
    pub fn recordBatchedDraw(self: *Self) void {
        self.current_metrics.batched_draw_calls += 1;
        self.current_metrics.draw_call_count += 1;
    }
    
    /// Get current frame metrics
    pub fn getMetrics(self: *const Self) FrameMetrics {
        return self.current_metrics;
    }
    
    /// Get total frame count
    pub fn getFrameCount(self: *const Self) u32 {
        return self.frame_counter;
    }
    
    /// Reset all counters (useful for testing)
    pub fn reset(self: *Self) void {
        self.frame_counter = 0;
        self.current_metrics = FrameMetrics.init();
    }
};

/// Global performance monitoring constants
pub const Config = struct {
    pub const DEFAULT_LOGGING_FREQUENCY: u32 = 288; // Log every 60 frames (1 second at 60fps)
    pub const HIGH_FREQUENCY_LOGGING: u32 = 30;    // More frequent logging for debugging
    pub const LOW_FREQUENCY_LOGGING: u32 = 300;    // Less frequent logging for production
};

/// Performance analysis utilities
pub const Analysis = struct {
    /// Check if frame time indicates good performance
    pub fn isGoodPerformance(metrics: FrameMetrics) bool {
        return metrics.frame_time_ms <= 16.67; // 60fps threshold
    }
    
    /// Check if frame time indicates acceptable performance 
    pub fn isAcceptablePerformance(metrics: FrameMetrics) bool {
        return metrics.frame_time_ms <= 33.33; // 30fps threshold
    }
    
    /// Get performance grade as string
    pub fn getPerformanceGrade(metrics: FrameMetrics) []const u8 {
        if (metrics.frame_time_ms <= 8.33) return "Excellent"; // 120fps+
        if (metrics.frame_time_ms <= 16.67) return "Good";     // 60fps+
        if (metrics.frame_time_ms <= 33.33) return "Fair";     // 30fps+
        return "Poor"; // <30fps
    }
    
    /// Calculate approximate FPS from frame time
    pub fn calculateFPS(frame_time_ms: f32) u32 {
        if (frame_time_ms <= 0.0) return 0;
        return @intFromFloat(1000.0 / frame_time_ms);
    }
};

// Tests for performance monitoring
test "performance monitor basic functionality" {
    var monitor = PerformanceMonitor.init(60);
    
    // Test initial state
    try std.testing.expectEqual(@as(u32, 0), monitor.getFrameCount());
    
    // Test frame counting
    monitor.startFrame();
    monitor.recordIndividualDraw();
    monitor.recordBatchedDraw();
    monitor.endFrame();
    
    try std.testing.expectEqual(@as(u32, 1), monitor.getFrameCount());
    
    const metrics = monitor.getMetrics();
    try std.testing.expectEqual(@as(u32, 2), metrics.draw_call_count);
    try std.testing.expectEqual(@as(u32, 1), metrics.individual_draw_calls);
    try std.testing.expectEqual(@as(u32, 1), metrics.batched_draw_calls);
}

test "performance analysis" {
    const good_metrics = FrameMetrics{
        .frame_time_ms = 8.0,
        .draw_call_count = 50,
        .individual_draw_calls = 30,
        .batched_draw_calls = 20,
    };
    
    try std.testing.expect(Analysis.isGoodPerformance(good_metrics));
    try std.testing.expect(Analysis.isAcceptablePerformance(good_metrics));
    try std.testing.expectEqualStrings("Excellent", Analysis.getPerformanceGrade(good_metrics));
    
    const fps = Analysis.calculateFPS(good_metrics.frame_time_ms);
    try std.testing.expectEqual(@as(u32, 125), fps);
}