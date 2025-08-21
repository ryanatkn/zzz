/// Layout backend interface and abstractions
///
/// This module defines the common interface for layout backends,
/// allowing the system to switch between CPU and GPU implementations
/// transparently based on performance requirements and availability.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const LayoutResult = types.LayoutResult;
const LayoutContext = types.LayoutContext;

/// Backend performance characteristics
pub const BackendCapabilities = struct {
    /// Maximum number of elements this backend can handle efficiently
    max_elements: usize,
    /// Whether this backend supports parallel processing
    supports_parallel: bool,
    /// Whether this backend supports real-time updates
    supports_realtime: bool,
    /// Estimated setup cost (in microseconds)
    setup_cost_us: f64,
    /// Estimated cost per element (in microseconds)
    cost_per_element_us: f64,
    /// Whether this backend is available (e.g., GPU drivers present)
    available: bool,
};

/// Layout backend interface
pub const LayoutBackend = struct {
    /// Pointer to implementation-specific data
    ptr: *anyopaque,
    /// Virtual function table
    vtable: *const VTable,

    pub const VTable = struct {
        /// Perform layout calculation
        performLayout: *const fn (ptr: *anyopaque, elements: []LayoutElement, context: LayoutContext) anyerror![]LayoutResult,
        /// Get backend capabilities
        getCapabilities: *const fn (ptr: *anyopaque) BackendCapabilities,
        /// Initialize backend with specific configuration
        init: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, config: BackendConfig) anyerror!void,
        /// Clean up backend resources
        deinit: *const fn (ptr: *anyopaque) void,
        /// Check if backend can handle the given workload
        canHandle: *const fn (ptr: *anyopaque, element_count: usize, context: LayoutContext) bool,
        /// Get human-readable backend name
        getName: *const fn (ptr: *anyopaque) []const u8,
    };

    /// Perform layout calculation
    pub fn performLayout(self: LayoutBackend, elements: []LayoutElement, context: LayoutContext) ![]LayoutResult {
        return self.vtable.performLayout(self.ptr, elements, context);
    }

    /// Get backend capabilities
    pub fn getCapabilities(self: LayoutBackend) BackendCapabilities {
        return self.vtable.getCapabilities(self.ptr);
    }

    /// Initialize backend
    pub fn init(self: LayoutBackend, allocator: std.mem.Allocator, config: BackendConfig) !void {
        return self.vtable.init(self.ptr, allocator, config);
    }

    /// Clean up backend
    pub fn deinit(self: LayoutBackend) void {
        return self.vtable.deinit(self.ptr);
    }

    /// Check if backend can handle workload
    pub fn canHandle(self: LayoutBackend, element_count: usize, context: LayoutContext) bool {
        return self.vtable.canHandle(self.ptr, element_count, context);
    }

    /// Get backend name
    pub fn getName(self: LayoutBackend) []const u8 {
        return self.vtable.getName(self.ptr);
    }
};

/// Generic layout element for backend interface
pub const LayoutElement = struct {
    /// Element position (will be updated by layout)
    position: Vec2,
    /// Element size (may be updated by layout)
    size: Vec2,
    /// Element margins
    margin: types.Spacing,
    /// Element padding
    padding: types.Spacing,
    /// Parent element index (if any)
    parent_index: ?usize = null,
    /// Layout constraints
    constraints: types.Constraints,
    /// Element-specific data
    user_data: ?*anyopaque = null,
    /// Element index in original array
    element_index: usize = 0,
};

/// Backend configuration options
pub const BackendConfig = struct {
    /// Maximum number of elements to allocate space for
    max_elements: usize = 1000,
    /// Enable debug output
    debug_mode: bool = false,
    /// Performance optimization level
    optimization_level: OptimizationLevel = .balanced,
    /// GPU-specific configuration
    gpu_config: ?GPUConfig = null,

    pub const OptimizationLevel = enum {
        debug, // Prioritize debugging and validation
        balanced, // Balance between performance and memory usage
        performance, // Prioritize raw performance
        memory, // Prioritize memory efficiency
    };

    pub const GPUConfig = struct {
        /// GPU device pointer (implementation-specific)
        device: ?*anyopaque = null,
        /// Shader cache directory
        shader_cache_dir: ?[]const u8 = null,
        /// Enable GPU profiling
        enable_profiling: bool = false,
    };
};

/// Backend selection strategy
pub const BackendStrategy = struct {
    /// Strategy for selecting between available backends
    pub const SelectionMode = enum {
        /// Always prefer CPU backend
        prefer_cpu,
        /// Always prefer GPU backend (if available)
        prefer_gpu,
        /// Automatically select based on workload characteristics
        auto_select,
        /// Use fastest backend for current workload
        fastest,
        /// Use most memory-efficient backend
        memory_efficient,
    };

    mode: SelectionMode = .auto_select,
    /// Minimum elements before considering GPU backend
    gpu_threshold: usize = 50,
    /// Maximum elements before forcing GPU backend (if available)
    force_gpu_threshold: usize = 500,
    /// Fallback to CPU if GPU fails
    allow_fallback: bool = true,

    /// Select backend based on strategy and available backends
    pub fn selectBackend(
        self: BackendStrategy,
        backends: []LayoutBackend,
        element_count: usize,
        context: LayoutContext,
    ) ?LayoutBackend {
        if (backends.len == 0) return null;

        switch (self.mode) {
            .prefer_cpu => {
                // Find first CPU backend that can handle the workload
                for (backends) |backend| {
                    if (std.mem.eql(u8, backend.getName(), "CPU") and backend.canHandle(element_count, context)) {
                        return backend;
                    }
                }
                // Fallback to any backend if no CPU backend available
                return if (self.allow_fallback) backends[0] else null;
            },
            .prefer_gpu => {
                // Find first GPU backend that can handle the workload
                for (backends) |backend| {
                    if (std.mem.startsWith(u8, backend.getName(), "GPU") and backend.canHandle(element_count, context)) {
                        return backend;
                    }
                }
                // Fallback to CPU if no GPU backend available
                return if (self.allow_fallback) self.selectCPUBackend(backends, element_count, context) else null;
            },
            .auto_select => {
                if (element_count < self.gpu_threshold) {
                    return self.selectCPUBackend(backends, element_count, context) orelse 
                           self.selectGPUBackend(backends, element_count, context);
                } else if (element_count > self.force_gpu_threshold) {
                    return self.selectGPUBackend(backends, element_count, context) orelse
                           self.selectCPUBackend(backends, element_count, context);
                } else {
                    // In the middle range - compare performance estimates
                    return self.selectFastestBackend(backends, element_count, context);
                }
            },
            .fastest => {
                return self.selectFastestBackend(backends, element_count, context);
            },
            .memory_efficient => {
                return self.selectMemoryEfficientBackend(backends, element_count, context);
            },
        }
    }

    fn selectCPUBackend(self: BackendStrategy, backends: []LayoutBackend, element_count: usize, context: LayoutContext) ?LayoutBackend {
        _ = self;
        for (backends) |backend| {
            if (std.mem.eql(u8, backend.getName(), "CPU") and backend.canHandle(element_count, context)) {
                return backend;
            }
        }
        return null;
    }

    fn selectGPUBackend(self: BackendStrategy, backends: []LayoutBackend, element_count: usize, context: LayoutContext) ?LayoutBackend {
        _ = self;
        for (backends) |backend| {
            if (std.mem.startsWith(u8, backend.getName(), "GPU") and backend.canHandle(element_count, context)) {
                return backend;
            }
        }
        return null;
    }

    fn selectFastestBackend(self: BackendStrategy, backends: []LayoutBackend, element_count: usize, context: LayoutContext) ?LayoutBackend {
        _ = self;
        var fastest_backend: ?LayoutBackend = null;
        var fastest_time: f64 = std.math.inf(f64);

        for (backends) |backend| {
            if (!backend.canHandle(element_count, context)) continue;

            const capabilities = backend.getCapabilities();
            if (!capabilities.available) continue;

            const estimated_time = capabilities.setup_cost_us + 
                                 capabilities.cost_per_element_us * @as(f64, @floatFromInt(element_count));

            if (estimated_time < fastest_time) {
                fastest_time = estimated_time;
                fastest_backend = backend;
            }
        }

        return fastest_backend;
    }

    fn selectMemoryEfficientBackend(self: BackendStrategy, backends: []LayoutBackend, element_count: usize, context: LayoutContext) ?LayoutBackend {
        // For now, just prefer CPU backend as it typically uses less memory
        // In a real implementation, this would consider actual memory usage
        return self.selectCPUBackend(backends, element_count, context) orelse
               backends[0]; // Fallback to first available
    }
};

/// Backend error types
pub const BackendError = error{
    BackendNotAvailable,
    UnsupportedWorkload,
    InitializationFailed,
    ExecutionFailed,
    OutOfMemory,
    InvalidConfiguration,
};

// Tests
test "backend strategy selection" {
    const testing = std.testing;

    const strategy = BackendStrategy{
        .mode = .auto_select,
        .gpu_threshold = 100,
        .force_gpu_threshold = 1000,
    };

    // Mock backends (we can't actually test with real backends without complex setup)
    // This test is more for demonstrating the interface
    try testing.expect(strategy.gpu_threshold == 100);
    try testing.expect(strategy.force_gpu_threshold == 1000);
}

test "backend capabilities" {
    const testing = std.testing;

    const cpu_caps = BackendCapabilities{
        .max_elements = 10000,
        .supports_parallel = false,
        .supports_realtime = true,
        .setup_cost_us = 10.0,
        .cost_per_element_us = 0.5,
        .available = true,
    };

    try testing.expect(cpu_caps.max_elements == 10000);
    try testing.expect(cpu_caps.available);
    try testing.expect(!cpu_caps.supports_parallel);
}