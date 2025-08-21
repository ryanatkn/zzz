/// Common interface for all layout algorithms and implementations
const std = @import("std");
const types = @import("types.zig");

const LayoutResult = types.LayoutResult;
const LayoutContext = types.LayoutContext;
const Vec2 = types.Vec2;
const Constraints = types.Constraints;
const Spacing = types.Spacing;

/// Generic layout element for algorithm interfaces
pub const LayoutElement = struct {
    /// Element position (will be updated by layout)
    position: Vec2,
    /// Element size (may be updated by layout)
    size: Vec2,
    /// Element margins
    margin: Spacing,
    /// Element padding
    padding: Spacing,
    /// Parent element index (if any)
    parent_index: ?usize = null,
    /// Layout constraints
    constraints: Constraints,
    /// Algorithm-specific data
    algorithm_data: ?*anyopaque = null,
    /// Element index in original array
    element_index: usize = 0,
    /// Dirty flags for incremental updates
    dirty_flags: types.DirtyFlags = types.DirtyFlags{},
};

/// Layout algorithm interface
pub const LayoutAlgorithm = struct {
    /// Pointer to implementation-specific data
    ptr: *anyopaque,
    /// Virtual function table
    vtable: *const VTable,

    pub const VTable = struct {
        /// Calculate layout for elements
        calculate: *const fn (ptr: *anyopaque, elements: []LayoutElement, context: LayoutContext, allocator: std.mem.Allocator) anyerror![]LayoutResult,
        /// Get algorithm capabilities
        getCapabilities: *const fn (ptr: *anyopaque) AlgorithmCapabilities,
        /// Initialize algorithm with configuration
        init: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, config: AlgorithmConfig) anyerror!void,
        /// Clean up algorithm resources
        deinit: *const fn (ptr: *anyopaque) void,
        /// Check if algorithm can handle the given elements
        canHandle: *const fn (ptr: *anyopaque, elements: []const LayoutElement, context: LayoutContext) bool,
        /// Get human-readable algorithm name
        getName: *const fn (ptr: *anyopaque) []const u8,
    };

    /// Calculate layout
    pub fn calculate(self: LayoutAlgorithm, elements: []LayoutElement, context: LayoutContext, allocator: std.mem.Allocator) ![]LayoutResult {
        return self.vtable.calculate(self.ptr, elements, context, allocator);
    }

    /// Get algorithm capabilities
    pub fn getCapabilities(self: LayoutAlgorithm) AlgorithmCapabilities {
        return self.vtable.getCapabilities(self.ptr);
    }

    /// Initialize algorithm
    pub fn init(self: LayoutAlgorithm, allocator: std.mem.Allocator, config: AlgorithmConfig) !void {
        return self.vtable.init(self.ptr, allocator, config);
    }

    /// Clean up algorithm
    pub fn deinit(self: LayoutAlgorithm) void {
        return self.vtable.deinit(self.ptr);
    }

    /// Check if algorithm can handle elements
    pub fn canHandle(self: LayoutAlgorithm, elements: []const LayoutElement, context: LayoutContext) bool {
        return self.vtable.canHandle(self.ptr, elements, context);
    }

    /// Get algorithm name
    pub fn getName(self: LayoutAlgorithm) []const u8 {
        return self.vtable.getName(self.ptr);
    }
};

/// Algorithm performance characteristics
pub const AlgorithmCapabilities = struct {
    /// Algorithm name for identification
    name: []const u8,
    /// Maximum number of elements this algorithm can handle efficiently
    max_elements: usize,
    /// Whether this algorithm supports GPU acceleration
    supports_gpu: bool,
    /// Whether this algorithm supports incremental updates
    supports_incremental: bool,
    /// Estimated computational complexity (O(n), O(n²), etc.)
    complexity: Complexity,
    /// Features this algorithm supports
    features: FeatureSet,

    pub const Complexity = enum {
        constant, // O(1)
        logarithmic, // O(log n)
        linear, // O(n)
        linearithmic, // O(n log n)
        quadratic, // O(n²)
        exponential, // O(2^n)
    };

    pub const FeatureSet = packed struct(u32) {
        /// Supports nested layouts
        nesting: bool = false,
        /// Supports flexible sizing
        flexible_sizing: bool = false,
        /// Supports content-based sizing
        content_sizing: bool = false,
        /// Supports alignment
        alignment: bool = false,
        /// Supports wrapping
        wrapping: bool = false,
        /// Supports spacing distribution
        spacing: bool = false,
        /// Supports text layout
        text_layout: bool = false,
        /// Supports animations
        animations: bool = false,
        _reserved: u24 = 0,
    };
};

/// Algorithm configuration
pub const AlgorithmConfig = struct {
    /// Implementation type preference
    implementation: ImplementationType = .auto,
    /// Performance optimization level
    optimization_level: OptimizationLevel = .balanced,
    /// Enable debug validation
    debug_mode: bool = false,
    /// GPU-specific configuration
    gpu_config: ?GPUConfig = null,

    pub const ImplementationType = enum {
        /// Automatically select best implementation
        auto,
        /// Force CPU implementation
        cpu_only,
        /// Force GPU implementation (if available)
        gpu_only,
        /// Use hybrid CPU/GPU approach
        hybrid,
    };

    pub const OptimizationLevel = enum {
        /// Prioritize debugging and validation
        debug,
        /// Balance between performance and memory
        balanced,
        /// Prioritize raw performance
        performance,
        /// Prioritize memory efficiency
        memory,
    };

    pub const GPUConfig = struct {
        /// GPU device pointer (implementation-specific)
        device: ?*anyopaque = null,
        /// Maximum GPU memory to use (bytes)
        max_memory: usize = 256 * 1024 * 1024, // 256MB default
        /// Enable GPU profiling
        enable_profiling: bool = false,
    };
};

/// Algorithm selection strategy
pub const AlgorithmSelector = struct {
    /// Select best algorithm for given requirements
    pub fn selectAlgorithm(requirements: LayoutRequirements) types.LayoutMode {
        // Grid layout for 2D positioning
        if (requirements.needs_2d_positioning) {
            return .grid;
        }

        // Flexbox for flexible 1D layouts
        if (requirements.needs_flexible_sizing or requirements.needs_alignment) {
            return .flex;
        }

        // Block layout for simple stacking
        if (requirements.element_count > 1) {
            return .block;
        }

        // Absolute for single elements or precise positioning
        return .absolute;
    }

    pub const LayoutRequirements = struct {
        /// Number of elements to layout
        element_count: usize,
        /// Whether flexible sizing is needed
        needs_flexible_sizing: bool = false,
        /// Whether alignment is important
        needs_alignment: bool = false,
        /// Whether 2D grid positioning is needed
        needs_2d_positioning: bool = false,
        /// Whether text layout is involved
        has_text_content: bool = false,
        /// Whether animations are needed
        needs_animations: bool = false,
        /// Performance requirements
        performance_critical: bool = false,
    };
};

/// Layout execution errors
pub const LayoutError = error{
    /// Algorithm not available or not initialized
    AlgorithmNotAvailable,
    /// Elements exceed algorithm capabilities
    TooManyElements,
    /// Invalid element configuration
    InvalidElements,
    /// Calculation failed
    CalculationFailed,
    /// GPU operation failed
    GPUError,
    /// Out of memory
    OutOfMemory,
    /// Invalid configuration
    InvalidConfiguration,
};

// Tests
test "algorithm selector" {
    const testing = std.testing;

    // Test simple requirements
    const simple_req = AlgorithmSelector.LayoutRequirements{
        .element_count = 3,
        .needs_flexible_sizing = false,
    };

    const selected = AlgorithmSelector.selectAlgorithm(simple_req);
    try testing.expect(selected == .block);

    // Test flex requirements
    const flex_req = AlgorithmSelector.LayoutRequirements{
        .element_count = 5,
        .needs_flexible_sizing = true,
    };

    const flex_selected = AlgorithmSelector.selectAlgorithm(flex_req);
    try testing.expect(flex_selected == .flex);
}

test "algorithm capabilities" {
    const testing = std.testing;

    const caps = AlgorithmCapabilities{
        .name = "test",
        .max_elements = 1000,
        .supports_gpu = true,
        .supports_incremental = false,
        .complexity = .linear,
        .features = .{
            .nesting = true,
            .flexible_sizing = true,
            .alignment = true,
        },
    };

    try testing.expect(caps.features.nesting);
    try testing.expect(caps.features.flexible_sizing);
    try testing.expect(caps.features.alignment);
    try testing.expect(!caps.features.wrapping);
}
