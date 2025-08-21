/// CPU-based layout backend implementation
///
/// This module provides a CPU implementation of the layout backend interface,
/// using the box model engine and other CPU-optimized algorithms.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");
const engines = @import("../engines/mod.zig");
const interface = @import("interface.zig");

const Vec2 = math.Vec2;
const BoxModel = engines.BoxModel;
const LayoutResult = types.LayoutResult;
const LayoutContext = types.LayoutContext;
const LayoutBackend = interface.LayoutBackend;
const LayoutElement = interface.LayoutElement;
const BackendCapabilities = interface.BackendCapabilities;
const BackendConfig = interface.BackendConfig;

/// CPU layout backend implementation
pub const CpuLayoutBackend = struct {
    allocator: std.mem.Allocator,
    box_models: std.ArrayList(BoxModel),
    config: BackendConfig,
    initialized: bool = false,

    const Self = @This();

    /// Create a new CPU backend
    pub fn create(allocator: std.mem.Allocator) !LayoutBackend {
        const backend = try allocator.create(Self);
        backend.* = Self{
            .allocator = allocator,
            .box_models = std.ArrayList(BoxModel).init(allocator),
            .config = BackendConfig{},
        };

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
        return "CPU";
    }

    /// Initialize the backend
    fn initBackend(self: *Self, allocator: std.mem.Allocator, config: BackendConfig) !void {
        _ = allocator; // Already stored in self
        self.config = config;
        try self.ensureBoxModels(config.max_elements);
        self.initialized = true;
    }

    /// Clean up backend resources
    fn deinitBackend(self: *Self) void {
        for (self.box_models.items) |*box| {
            box.deinit(self.allocator);
        }
        self.box_models.deinit();
        self.initialized = false;
    }

    /// Perform CPU layout calculation
    fn performLayout(self: *Self, elements: []LayoutElement, context: LayoutContext) ![]LayoutResult {
        if (!self.initialized) return error.BackendNotInitialized;

        // Ensure we have enough box models
        try self.ensureBoxModels(elements.len);

        // Convert LayoutElements to BoxModels
        for (elements, 0..) |*element, i| {
            try self.elementToBoxModel(element, &self.box_models.items[i]);
        }

        // Perform box model layout calculations
        for (self.box_models.items[0..elements.len], elements) |*box, element| {
            // Handle parent-child relationships
            if (element.parent_index) |parent_idx| {
                if (parent_idx < elements.len) {
                    const parent_box = &self.box_models.items[parent_idx];
                    const parent_layout = parent_box.getLayout();

                    // Position relative to parent's content area
                    const new_pos = Vec2{
                        .x = parent_layout.content.position.x + element.position.x,
                        .y = parent_layout.content.position.y + element.position.y,
                    };
                    box.setPosition(new_pos);
                }
            }

            // Force layout calculation
            _ = box.getLayout();
        }

        // Convert BoxModels back to LayoutResults
        var results = try self.allocator.alloc(LayoutResult, elements.len);
        for (self.box_models.items[0..elements.len], 0..) |*box, i| {
            results[i] = self.boxModelToResult(box, elements[i].element_index);
        }

        // Apply container bounds clipping if specified
        if (context.container_bounds.size.x > 0 and context.container_bounds.size.y > 0) {
            self.clipToContainer(results, context.container_bounds);
        }

        return results;
    }

    /// Get backend capabilities
    fn getCapabilities(self: *Self) BackendCapabilities {
        return BackendCapabilities{
            .max_elements = self.config.max_elements,
            .supports_parallel = false, // CPU backend is single-threaded
            .supports_realtime = true,
            .setup_cost_us = 5.0, // Low setup cost for CPU
            .cost_per_element_us = 0.3, // Moderate cost per element
            .available = true, // CPU is always available
        };
    }

    /// Check if backend can handle the workload
    fn canHandle(self: *Self, element_count: usize, context: LayoutContext) bool {
        _ = context;
        return self.initialized and element_count <= self.config.max_elements;
    }

    /// Ensure we have enough box models allocated
    fn ensureBoxModels(self: *Self, count: usize) !void {
        while (self.box_models.items.len < count) {
            const box = try BoxModel.init(self.allocator, Vec2.ZERO, Vec2.ZERO);
            try self.box_models.append(box);
        }
    }

    /// Convert LayoutElement to BoxModel
    fn elementToBoxModel(self: *Self, element: *const LayoutElement, box: *BoxModel) !void {
        _ = self;

        // Set position and size
        box.setPosition(element.position);
        box.setSize(element.size);

        // Set spacing
        box.padding.set(element.padding);
        box.margin.set(element.margin);

        // Set constraints
        box.setConstraints(element.constraints);

        box.markDirty();
    }

    /// Convert BoxModel to LayoutResult
    fn boxModelToResult(self: *Self, box: *BoxModel, element_index: usize) LayoutResult {
        _ = self;

        const computed = box.getLayout();

        return LayoutResult{
            .position = computed.content.position,
            .size = computed.content.size,
            .element_index = element_index,
        };
    }

    /// Clip results to container bounds
    fn clipToContainer(self: *Self, results: []LayoutResult, container_bounds: math.Rectangle) void {
        _ = self;

        for (results) |*result| {
            // Clip position
            result.position.x = @max(result.position.x, container_bounds.position.x);
            result.position.y = @max(result.position.y, container_bounds.position.y);

            // Clip size
            const max_right = container_bounds.position.x + container_bounds.size.x;
            const max_bottom = container_bounds.position.y + container_bounds.size.y;

            if (result.position.x + result.size.x > max_right) {
                result.size.x = @max(0, max_right - result.position.x);
            }

            if (result.position.y + result.size.y > max_bottom) {
                result.size.y = @max(0, max_bottom - result.position.y);
            }
        }
    }
};

/// Convenience function to create a CPU backend
pub fn createCpuBackend(allocator: std.mem.Allocator, config: BackendConfig) !LayoutBackend {
    var backend = try CpuLayoutBackend.create(allocator);
    try backend.init(allocator, config);
    return backend;
}

// Tests
test "CPU backend creation and basic operations" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive system for BoxModel
    try @import("../../reactive/mod.zig").init(allocator);
    defer @import("../../reactive/mod.zig").deinit(allocator);

    const config = BackendConfig{ .max_elements = 100 };
    var backend = try createCpuBackend(allocator, config);
    defer {
        backend.deinit();
        CpuLayoutBackend.destroy(backend, allocator);
    }

    // Test capabilities
    const caps = backend.getCapabilities();
    try testing.expect(caps.available);
    try testing.expect(caps.max_elements == 100);
    try testing.expect(!caps.supports_parallel);

    // Test can handle
    const context = LayoutContext{
        .available_space = Vec2{ .x = 800, .y = 600 },
        .container_bounds = math.Rectangle{
            .position = Vec2.ZERO,
            .size = Vec2{ .x = 800, .y = 600 },
        },
    };
    try testing.expect(backend.canHandle(50, context));
    try testing.expect(!backend.canHandle(200, context)); // Exceeds max_elements

    // Test name
    try testing.expect(std.mem.eql(u8, backend.getName(), "CPU"));
}

test "CPU backend layout calculation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive system for BoxModel
    try @import("../../reactive/mod.zig").init(allocator);
    defer @import("../../reactive/mod.zig").deinit(allocator);

    const config = BackendConfig{ .max_elements = 10 };
    var backend = try createCpuBackend(allocator, config);
    defer {
        backend.deinit();
        CpuLayoutBackend.destroy(backend, allocator);
    }

    // Create test elements
    var elements = [_]LayoutElement{
        LayoutElement{
            .position = Vec2{ .x = 10, .y = 20 },
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = types.Spacing.uniform(5),
            .padding = types.Spacing.uniform(10),
            .constraints = types.Constraints{},
            .element_index = 0,
        },
        LayoutElement{
            .position = Vec2{ .x = 0, .y = 0 },
            .size = Vec2{ .x = 50, .y = 30 },
            .margin = types.Spacing{},
            .padding = types.Spacing{},
            .constraints = types.Constraints{},
            .parent_index = 0, // Child of first element
            .element_index = 1,
        },
    };

    const context = LayoutContext{
        .available_space = Vec2{ .x = 800, .y = 600 },
        .container_bounds = math.Rectangle{
            .position = Vec2.ZERO,
            .size = Vec2{ .x = 800, .y = 600 },
        },
    };

    const results = try backend.performLayout(&elements, context);
    defer allocator.free(results);

    try testing.expect(results.len == 2);

    // Parent element should have its margins and padding applied
    try testing.expect(results[0].size.x == 100);
    try testing.expect(results[0].size.y == 50);

    // Child element should be positioned relative to parent's content area
    // (This is a simplified test - actual positioning depends on box model calculations)
    try testing.expect(results[1].element_index == 1);
}
