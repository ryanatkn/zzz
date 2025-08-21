const std = @import("std");
const math = @import("../../math/mod.zig");
const loggers = @import("../../debug/loggers.zig");
const box_model = @import("../box_model.zig");
const gpu_layout = @import("mod.zig");
const c = @import("../../platform/sdl.zig");

const Vec2 = math.Vec2;
const BoxModel = box_model.BoxModel;
const GPULayoutEngine = gpu_layout.GPULayoutEngine;
const UIElement = gpu_layout.UIElement;
const LayoutConstraint = gpu_layout.LayoutConstraint;
const SpringState = gpu_layout.SpringState;

/// Hybrid layout manager that can use either CPU or GPU layout depending on conditions
pub const HybridLayoutManager = struct {
    allocator: std.mem.Allocator,
    device: ?*c.sdl.SDL_GPUDevice,

    // Layout backends
    gpu_engine: ?GPULayoutEngine,
    cpu_layouts: std.ArrayList(BoxModel),

    // Configuration
    gpu_threshold: usize, // Minimum elements to use GPU
    force_cpu: bool, // Force CPU mode
    force_gpu: bool, // Force GPU mode

    // State tracking
    element_count: usize,
    last_used_gpu: bool,
    performance_stats: PerformanceStats,

    const Self = @This();

    pub const Config = struct {
        gpu_threshold: usize = 50, // Use GPU when >= 50 elements
        force_cpu: bool = false,
        force_gpu: bool = false,
        gpu_capacity: usize = 1000,
    };

    pub const PerformanceStats = struct {
        cpu_layout_time_us: f64 = 0,
        gpu_layout_time_us: f64 = 0,
        cpu_layout_count: u32 = 0,
        gpu_layout_count: u32 = 0,
        last_frame_cpu: bool = false,

        pub fn getCPUAverage(self: *const PerformanceStats) f64 {
            return if (self.cpu_layout_count > 0) self.cpu_layout_time_us / @as(f64, @floatFromInt(self.cpu_layout_count)) else 0;
        }

        pub fn getGPUAverage(self: *const PerformanceStats) f64 {
            return if (self.gpu_layout_count > 0) self.gpu_layout_time_us / @as(f64, @floatFromInt(self.gpu_layout_count)) else 0;
        }
    };

    pub fn init(allocator: std.mem.Allocator, device: ?*c.sdl.SDL_GPUDevice, config: Config) !Self {
        loggers.getRenderLog().info("hybrid_layout_init", "Initializing hybrid layout manager (threshold: {})", .{config.gpu_threshold});

        // Try to initialize GPU engine if device available
        const gpu_engine: ?GPULayoutEngine = null;
        // TODO: Temporarily disabled until SDL3 compute pipeline issues are resolved
        // if (device != null and !config.force_cpu) {
        //     gpu_engine = GPULayoutEngine.init(allocator, device.?, config.gpu_capacity) catch |err| blk: {
        //         loggers.getRenderLog().err("gpu_layout_init_fail", "Failed to initialize GPU layout engine: {}, falling back to CPU", .{err});
        //         break :blk null;
        //     };
        // }

        const manager = Self{
            .allocator = allocator,
            .device = device,
            .gpu_engine = gpu_engine,
            .cpu_layouts = std.ArrayList(BoxModel).init(allocator),
            .gpu_threshold = config.gpu_threshold,
            .force_cpu = config.force_cpu,
            .force_gpu = config.force_gpu,
            .element_count = 0,
            .last_used_gpu = false,
            .performance_stats = PerformanceStats{},
        };

        // Log configuration
        if (manager.gpu_engine) |_| {
            loggers.getRenderLog().info("hybrid_layout_gpu_ready", "GPU layout engine ready, threshold: {} elements", .{config.gpu_threshold});
        } else {
            loggers.getRenderLog().info("hybrid_layout_cpu_only", "GPU layout unavailable, using CPU-only mode", .{});
        }

        return manager;
    }

    pub fn deinit(self: *Self) void {
        if (self.gpu_engine) |*engine| {
            engine.deinit();
        }

        for (self.cpu_layouts.items) |*layout| {
            layout.deinit(self.allocator);
        }
        self.cpu_layouts.deinit();

        loggers.getRenderLog().info("hybrid_layout_cleanup", "Hybrid layout manager cleaned up", .{});
    }

    /// Decide whether to use GPU or CPU for layout
    fn shouldUseGPU(self: *Self) bool {
        // Force modes override everything
        if (self.force_cpu) return false;
        if (self.force_gpu and self.gpu_engine != null) return true;

        // No GPU engine available
        if (self.gpu_engine == null) return false;

        // Use threshold to decide
        return self.element_count >= self.gpu_threshold;
    }

    /// Perform layout calculation using the appropriate backend
    pub fn performLayout(self: *Self, command_buffer: ?*c.sdl.SDL_GPUCommandBuffer, delta_time: f32, elements: []UIElement, constraints: []const LayoutConstraint, springs: []const SpringState) ![]UIElement {
        self.element_count = elements.len;
        const use_gpu = self.shouldUseGPU();

        // Log backend switches
        if (use_gpu != self.last_used_gpu) {
            loggers.getRenderLog().info("hybrid_layout_switch", "Layout backend switched: {} -> {} (element count: {})", .{ if (self.last_used_gpu) "GPU" else "CPU", if (use_gpu) "GPU" else "CPU", elements.len });
        }
        self.last_used_gpu = use_gpu;

        const start_time = std.time.nanoTimestamp();

        if (use_gpu) {
            const result = try self.performGPULayout(command_buffer.?, delta_time, elements, constraints, springs);

            const end_time = std.time.nanoTimestamp();
            const layout_time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

            self.performance_stats.gpu_layout_time_us += layout_time_us;
            self.performance_stats.gpu_layout_count += 1;
            self.performance_stats.last_frame_cpu = false;

            return result;
        } else {
            const result = try self.performCPULayout(elements);

            const end_time = std.time.nanoTimestamp();
            const layout_time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

            self.performance_stats.cpu_layout_time_us += layout_time_us;
            self.performance_stats.cpu_layout_count += 1;
            self.performance_stats.last_frame_cpu = true;

            return result;
        }
    }

    fn performGPULayout(self: *Self, command_buffer: *c.sdl.SDL_GPUCommandBuffer, delta_time: f32, elements: []UIElement, constraints: []const LayoutConstraint, springs: []const SpringState) ![]UIElement {
        var engine = &self.gpu_engine.?;

        // Upload data to GPU
        try engine.uploadElements(elements);
        try engine.uploadConstraints(constraints);
        try engine.uploadSprings(springs);

        // Perform GPU layout
        try engine.performLayout(command_buffer, delta_time);

        // Download results
        const results = try engine.downloadElements(command_buffer);

        loggers.getRenderLog().info("gpu_layout_complete", "GPU layout completed for {} elements", .{elements.len});

        return results;
    }

    fn performCPULayout(self: *Self, elements: []UIElement) ![]UIElement {
        // For CPU layout, we'll do a simplified version
        // In a real implementation, this would convert UIElements to BoxModels and back

        // For now, just perform basic box model calculations on elements
        const results = try self.allocator.alloc(UIElement, elements.len);
        @memcpy(results, elements);

        // Apply basic box model layout (simplified)
        for (results, 0..) |*elem, i| {
            if (elem.parent_index != UIElement.INVALID_PARENT and elem.parent_index < results.len) {
                const parent = &results[elem.parent_index];

                // Simple relative positioning
                if (elem.layout_mode == @intFromEnum(UIElement.LayoutMode.relative)) {
                    elem.position[0] += parent.position[0] + parent.padding[3]; // Add parent left padding
                    elem.position[1] += parent.position[1] + parent.padding[0]; // Add parent top padding
                }
            }

            // Apply margins
            elem.position[0] += elem.margin[3]; // left margin
            elem.position[1] += elem.margin[0]; // top margin

            // Clear dirty flags
            elem.dirty_flags = 0;

            _ = i; // Suppress unused variable warning
        }

        loggers.getRenderLog().info("cpu_layout_complete", "CPU layout completed for {} elements", .{elements.len});

        return results;
    }

    /// Get performance statistics
    pub fn getPerformanceStats(self: *const Self) PerformanceStats {
        return self.performance_stats;
    }

    /// Reset performance statistics
    pub fn resetPerformanceStats(self: *Self) void {
        self.performance_stats = PerformanceStats{};
    }

    /// Force next layout to use specific backend (for testing)
    pub fn setForceMode(self: *Self, force_cpu: bool, force_gpu: bool) void {
        self.force_cpu = force_cpu;
        self.force_gpu = force_gpu;

        loggers.getRenderLog().info("hybrid_layout_force", "Force mode set: CPU={}, GPU={}", .{ force_cpu, force_gpu });
    }

    /// Update GPU threshold
    pub fn setGPUThreshold(self: *Self, threshold: usize) void {
        self.gpu_threshold = threshold;
        loggers.getRenderLog().info("hybrid_layout_threshold", "GPU threshold updated to: {}", .{threshold});
    }

    /// Check if GPU backend is available
    pub fn hasGPUBackend(self: *const Self) bool {
        return self.gpu_engine != null;
    }

    /// Get current backend being used
    pub fn getCurrentBackend(self: *const Self) enum { cpu, gpu } {
        return if (self.last_used_gpu) .gpu else .cpu;
    }

    /// Get element count from last layout
    pub fn getElementCount(self: *const Self) usize {
        return self.element_count;
    }
};

/// Create test data for hybrid layout testing
pub fn createTestData(allocator: std.mem.Allocator, element_count: usize) !struct {
    elements: []UIElement,
    constraints: []LayoutConstraint,
    springs: []SpringState,

    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        alloc.free(self.elements);
        alloc.free(self.constraints);
        alloc.free(self.springs);
    }
} {
    const elements = try allocator.alloc(UIElement, element_count);
    const constraints = try allocator.alloc(LayoutConstraint, element_count);
    const springs = try allocator.alloc(SpringState, element_count);

    // Create test hierarchy
    for (elements, 0..) |*elem, i| {
        const fi = @as(f32, @floatFromInt(i));

        if (i == 0) {
            // Root element
            elem.* = UIElement.init(Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 1920, .y = 1080 });
            elem.setLayoutMode(.absolute);
        } else if (i < 10) {
            // Top-level containers
            elem.* = UIElement.init(Vec2{ .x = @mod(fi * 200, 1600), .y = @mod(fi * 150, 800) }, Vec2{ .x = 180, .y = 120 });
            elem.setParent(0);
            elem.setLayoutMode(.relative);
            elem.setPadding(5);
        } else {
            // Child elements
            const parent_idx = 1 + @as(u32, @intCast((i - 10) % 9));
            elem.* = UIElement.init(Vec2{ .x = @mod(fi * 15, 150), .y = @mod(fi * 20, 100) }, Vec2{ .x = 40 + @mod(fi * 5, 30), .y = 20 + @mod(fi * 3, 15) });
            elem.setParent(parent_idx);
            elem.setLayoutMode(.relative);
        }

        elem.markDirty(.layout);
    }

    // Create constraints
    for (constraints, 0..) |*constraint, i| {
        if (i == 0) {
            constraint.* = LayoutConstraint.sizeConstraint(1920, 1920, 1080, 1080);
        } else if (i < 10) {
            constraint.* = LayoutConstraint.sizeConstraint(100, 250, 80, 200);
        } else {
            constraint.* = LayoutConstraint.sizeConstraint(20, 80, 15, 40);
        }
    }

    // Create springs
    for (springs, 0..) |*spring, i| {
        if (i == 0) {
            spring.* = SpringState.init(100.0, 20.0, 10.0); // Stiff root
        } else if (i < 10) {
            spring.* = SpringState.init(25.0, 6.0, 3.0); // Medium containers
        } else {
            spring.* = SpringState.init(15.0, 4.0, 1.5); // Responsive children
        }
    }

    return .{
        .elements = elements,
        .constraints = constraints,
        .springs = springs,
    };
}

// Tests
test "hybrid layout manager creation" {
    const allocator = std.testing.allocator;

    const config = HybridLayoutManager.Config{
        .gpu_threshold = 100,
        .force_cpu = true, // Force CPU for test
    };

    var manager = try HybridLayoutManager.init(allocator, null, config);
    defer manager.deinit();

    try std.testing.expect(!manager.hasGPUBackend());
    try std.testing.expect(manager.getCurrentBackend() == .cpu);
}

test "performance stats" {
    var stats = HybridLayoutManager.PerformanceStats{};

    stats.cpu_layout_time_us = 1000.0;
    stats.cpu_layout_count = 10;

    try std.testing.expect(stats.getCPUAverage() == 100.0);
    try std.testing.expect(stats.getGPUAverage() == 0.0);
}
