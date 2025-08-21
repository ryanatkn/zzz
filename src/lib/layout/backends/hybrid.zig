/// Hybrid CPU/GPU layout backend implementation
///
/// This module provides a backend that automatically selects between CPU and GPU
/// implementations based on workload characteristics and system capabilities.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");
const interface = @import("interface.zig");
const cpu_backend = @import("cpu.zig");
const gpu_backend = @import("gpu.zig");

const Vec2 = math.Vec2;
const LayoutResult = types.LayoutResult;
const LayoutContext = types.LayoutContext;
const LayoutBackend = interface.LayoutBackend;
const LayoutElement = interface.LayoutElement;
const BackendCapabilities = interface.BackendCapabilities;
const BackendConfig = interface.BackendConfig;
const BackendStrategy = interface.BackendStrategy;

/// Hybrid layout backend that selects between CPU and GPU
pub const HybridLayoutBackend = struct {
    allocator: std.mem.Allocator,
    cpu_backend: ?LayoutBackend,
    gpu_backend: ?LayoutBackend,
    strategy: BackendStrategy,
    config: BackendConfig,
    initialized: bool = false,

    // Performance tracking
    performance_stats: PerformanceStats,

    const Self = @This();

    pub const PerformanceStats = struct {
        cpu_layout_time_us: f64 = 0,
        gpu_layout_time_us: f64 = 0,
        cpu_layout_count: u32 = 0,
        gpu_layout_count: u32 = 0,
        last_backend_used: []const u8 = "none",

        pub fn getCPUAverage(self: *const PerformanceStats) f64 {
            return if (self.cpu_layout_count > 0) self.cpu_layout_time_us / @as(f64, @floatFromInt(self.cpu_layout_count)) else 0;
        }

        pub fn getGPUAverage(self: *const PerformanceStats) f64 {
            return if (self.gpu_layout_count > 0) self.gpu_layout_time_us / @as(f64, @floatFromInt(self.gpu_layout_count)) else 0;
        }
    };

    /// Create a new hybrid backend
    pub fn create(allocator: std.mem.Allocator, gpu_device: ?*anyopaque) !LayoutBackend {
        const backend = try allocator.create(Self);
        backend.* = Self{
            .allocator = allocator,
            .cpu_backend = null,
            .gpu_backend = null,
            .strategy = BackendStrategy{},
            .config = BackendConfig{},
            .performance_stats = PerformanceStats{},
        };

        // Initialize CPU backend (always available)
        backend.cpu_backend = cpu_backend.createCpuBackend(allocator, BackendConfig{}) catch |err| blk: {
            // TODO: Log error - CPU backend failed to initialize
            std.log.warn("Failed to initialize CPU backend: {}", .{err});
            break :blk null;
        };

        // Initialize GPU backend (if available)
        if (gpu_device) |device| {
            const gpu_config = BackendConfig{
                .gpu_config = BackendConfig.GPUConfig{ .device = device },
            };
            backend.gpu_backend = gpu_backend.createGpuBackend(allocator, @ptrCast(device), gpu_config) catch |err| blk: {
                // TODO: Log error - GPU backend failed to initialize
                std.log.warn("Failed to initialize GPU backend: {}", .{err});
                break :blk null;
            };
        }

        return LayoutBackend{
            .ptr = backend,
            .vtable = &vtable,
        };
    }

    /// Destroy the backend
    pub fn destroy(backend: LayoutBackend, allocator: std.mem.Allocator) void {
        const self: *Self = @ptrCast(@alignCast(backend.ptr));
        self.deinitImpl();
        allocator.destroy(self);
    }

    const vtable = LayoutBackend.VTable{
        .performLayout = performLayoutImpl,
        .getCapabilities = getCapabilitiesImpl,
        .init = initImpl,
        .deinit = deinitImpl,
        .canHandle = canHandleImpl,
        .getName = getNameImpl,
    };

    fn performLayoutImpl(ptr: *anyopaque, elements: []LayoutElement, context: LayoutContext) ![]LayoutResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.performLayout(elements, context);
    }

    fn getCapabilitiesImpl(ptr: *anyopaque) BackendCapabilities {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.getCapabilities();
    }

    fn initImpl(ptr: *anyopaque, allocator: std.mem.Allocator, config: BackendConfig) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.initBackend(allocator, config);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinitBackend();
    }

    fn canHandleImpl(ptr: *anyopaque, element_count: usize, context: LayoutContext) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.canHandle(element_count, context);
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        _ = ptr;
        return "Hybrid (CPU/GPU)";
    }

    /// Initialize the backend
    fn initBackend(self: *Self, allocator: std.mem.Allocator, config: BackendConfig) !void {
        _ = allocator; // Already stored in self
        self.config = config;
        self.initialized = true;
    }

    /// Clean up backend resources
    fn deinitBackend(self: *Self) void {
        if (self.cpu_backend) |cpu| {
            cpu.deinit();
            cpu_backend.CpuLayoutBackend.destroy(cpu, self.allocator);
        }

        if (self.gpu_backend) |gpu| {
            gpu.deinit();
            gpu_backend.GpuLayoutBackend.destroy(gpu, self.allocator);
        }

        self.initialized = false;
    }

    /// Perform layout using the best available backend
    fn performLayout(self: *Self, elements: []LayoutElement, context: LayoutContext) ![]LayoutResult {
        if (!self.initialized) return error.BackendNotInitialized;

        // Select appropriate backend
        var available_backends = std.ArrayList(LayoutBackend).init(self.allocator);
        defer available_backends.deinit();

        if (self.cpu_backend) |cpu| {
            try available_backends.append(cpu);
        }
        if (self.gpu_backend) |gpu| {
            try available_backends.append(gpu);
        }

        if (available_backends.items.len == 0) {
            return error.NoBackendsAvailable;
        }

        const selected_backend = self.strategy.selectBackend(
            available_backends.items,
            elements.len,
            context,
        ) orelse return error.NoSuitableBackend;

        // Measure performance
        const start_time = std.time.nanoTimestamp();
        const results = try selected_backend.performLayout(elements, context);
        const end_time = std.time.nanoTimestamp();

        // Update performance stats
        const layout_time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;
        const backend_name = selected_backend.getName();

        if (std.mem.eql(u8, backend_name, "CPU")) {
            self.performance_stats.cpu_layout_time_us += layout_time_us;
            self.performance_stats.cpu_layout_count += 1;
        } else if (std.mem.startsWith(u8, backend_name, "GPU")) {
            self.performance_stats.gpu_layout_time_us += layout_time_us;
            self.performance_stats.gpu_layout_count += 1;
        }

        self.performance_stats.last_backend_used = backend_name;

        return results;
    }

    /// Get combined capabilities of all backends
    fn getCapabilities(self: *Self) BackendCapabilities {
        var combined_caps = BackendCapabilities{
            .max_elements = 0,
            .supports_parallel = false,
            .supports_realtime = false,
            .setup_cost_us = std.math.inf(f64),
            .cost_per_element_us = std.math.inf(f64),
            .available = false,
        };

        if (self.cpu_backend) |cpu| {
            const cpu_caps = cpu.getCapabilities();
            combined_caps.max_elements = @max(combined_caps.max_elements, cpu_caps.max_elements);
            combined_caps.supports_realtime = combined_caps.supports_realtime or cpu_caps.supports_realtime;
            combined_caps.setup_cost_us = @min(combined_caps.setup_cost_us, cpu_caps.setup_cost_us);
            combined_caps.cost_per_element_us = @min(combined_caps.cost_per_element_us, cpu_caps.cost_per_element_us);
            combined_caps.available = combined_caps.available or cpu_caps.available;
        }

        if (self.gpu_backend) |gpu| {
            const gpu_caps = gpu.getCapabilities();
            combined_caps.max_elements = @max(combined_caps.max_elements, gpu_caps.max_elements);
            combined_caps.supports_parallel = combined_caps.supports_parallel or gpu_caps.supports_parallel;
            combined_caps.supports_realtime = combined_caps.supports_realtime or gpu_caps.supports_realtime;
            combined_caps.setup_cost_us = @min(combined_caps.setup_cost_us, gpu_caps.setup_cost_us);
            combined_caps.cost_per_element_us = @min(combined_caps.cost_per_element_us, gpu_caps.cost_per_element_us);
            combined_caps.available = combined_caps.available or gpu_caps.available;
        }

        return combined_caps;
    }

    /// Check if hybrid backend can handle the workload
    fn canHandle(self: *Self, element_count: usize, context: LayoutContext) bool {
        if (!self.initialized) return false;

        // Can handle if either backend can handle it
        if (self.cpu_backend) |cpu| {
            if (cpu.canHandle(element_count, context)) return true;
        }

        if (self.gpu_backend) |gpu| {
            if (gpu.canHandle(element_count, context)) return true;
        }

        return false;
    }

    /// Configure backend selection strategy
    pub fn setStrategy(backend: LayoutBackend, strategy: BackendStrategy) void {
        const self: *Self = @ptrCast(@alignCast(backend.ptr));
        self.strategy = strategy;
    }

    /// Get performance statistics
    pub fn getPerformanceStats(backend: LayoutBackend) PerformanceStats {
        const self: *Self = @ptrCast(@alignCast(backend.ptr));
        return self.performance_stats;
    }

    /// Reset performance statistics
    pub fn resetPerformanceStats(backend: LayoutBackend) void {
        const self: *Self = @ptrCast(@alignCast(backend.ptr));
        self.performance_stats = PerformanceStats{};
    }
};

/// Convenience function to create a hybrid backend
pub fn createHybridBackend(allocator: std.mem.Allocator, gpu_device: ?*anyopaque, config: BackendConfig) !LayoutBackend {
    var backend = try HybridLayoutBackend.create(allocator, gpu_device);
    try backend.init(allocator, config);
    return backend;
}

// Tests
test "hybrid backend creation and selection" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = BackendConfig{ .max_elements = 100, .debug_mode = true };
    var backend = try createHybridBackend(allocator, null, config);
    defer {
        backend.deinit();
        HybridLayoutBackend.destroy(backend, allocator);
    }

    // Test capabilities - should combine CPU and GPU (simulated) capabilities
    const caps = backend.getCapabilities();
    try testing.expect(caps.available);
    try testing.expect(caps.max_elements > 0);

    // Test can handle
    const context = LayoutContext{
        .available_space = Vec2{ .x = 800, .y = 600 },
        .container_bounds = math.Rectangle{
            .position = Vec2.ZERO,
            .size = Vec2{ .x = 800, .y = 600 },
        },
    };
    try testing.expect(backend.canHandle(50, context));

    // Test name
    try testing.expect(std.mem.eql(u8, backend.getName(), "Hybrid (CPU/GPU)"));
}

test "hybrid backend strategy configuration" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = BackendConfig{ .debug_mode = true };
    var backend = try createHybridBackend(allocator, null, config);
    defer {
        backend.deinit();
        HybridLayoutBackend.destroy(backend, allocator);
    }

    // Test strategy configuration
    const strategy = BackendStrategy{
        .mode = .prefer_cpu,
        .gpu_threshold = 200,
    };
    HybridLayoutBackend.setStrategy(backend, strategy);

    // Performance stats should be initially empty
    const stats = HybridLayoutBackend.getPerformanceStats(backend);
    try testing.expect(stats.cpu_layout_count == 0);
    try testing.expect(stats.gpu_layout_count == 0);
}
