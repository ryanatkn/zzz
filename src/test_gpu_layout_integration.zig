const std = @import("std");
const layout_mod = @import("lib/layout/mod.zig");
const math = @import("lib/math/mod.zig");
const loggers = @import("lib/debug/loggers.zig");
const sdl = @import("lib/platform/sdl.zig");

const GPULayoutEngine = layout_mod.GPULayoutEngine;
const UIElement = layout_mod.UIElement;
const LayoutConstraint = layout_mod.LayoutConstraint;
const SpringState = layout_mod.SpringState;
const Vec2 = math.Vec2;

/// Test integration that can be called from the main game loop
pub const GPULayoutTester = struct {
    engine: GPULayoutEngine,
    test_elements: []UIElement,
    test_constraints: []LayoutConstraint,
    test_springs: []SpringState,
    element_count: usize,
    frame_counter: u32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, device: *sdl.sdl.SDL_GPUDevice) !Self {
        loggers.getRenderLog().info("gpu_layout_tester_init", "🧪 Initializing GPU Layout Tester", .{});

        // Create GPU layout engine
        var engine = try GPULayoutEngine.init(allocator, device, 500);

        // Create test data
        const element_count = 200;
        const elements = try createTestUIElements(allocator, element_count);
        const constraints = try createTestConstraints(allocator, element_count);
        const springs = try createTestSprings(allocator, element_count);

        // Upload initial data
        try engine.uploadElements(elements);
        try engine.uploadConstraints(constraints);
        try engine.uploadSprings(springs);

        engine.setViewportSize(Vec2{ .x = 1920, .y = 1080 });

        loggers.getRenderLog().info("gpu_layout_tester_ready", "GPU Layout Tester ready with {} elements", .{element_count});

        return Self{
            .engine = engine,
            .test_elements = elements,
            .test_constraints = constraints,
            .test_springs = springs,
            .element_count = element_count,
            .frame_counter = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.test_elements);
        self.allocator.free(self.test_constraints);
        self.allocator.free(self.test_springs);
        self.engine.deinit();
        loggers.getRenderLog().info("gpu_layout_tester_cleanup", "GPU Layout Tester cleaned up", .{});
    }

    /// Run a test iteration - call this once per frame
    pub fn runTest(self: *Self, command_buffer: *sdl.sdl.SDL_GPUCommandBuffer, delta_time: f32) !void {
        self.frame_counter += 1;

        // Every 60 frames (about 1 second at 60 FPS), modify some elements to test updates
        if (self.frame_counter % 60 == 0) {
            self.animateTestElements();
            try self.engine.uploadElements(self.test_elements);
        }

        // Perform GPU layout calculation
        const start_time = std.time.nanoTimestamp();
        try self.engine.performLayout(command_buffer, delta_time);
        const end_time = std.time.nanoTimestamp();

        const layout_time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

        // Log performance every 5 seconds
        if (self.frame_counter % 300 == 0) {
            loggers.getRenderLog().info("gpu_layout_perf", "GPU layout: {d:.1}μs for {} elements (frame {})", .{ layout_time_us, self.element_count, self.frame_counter });
        }

        // Optionally download and verify results every 10 seconds
        if (self.frame_counter % 600 == 0) {
            try self.verifyResults(command_buffer);
        }
    }

    fn animateTestElements(self: *Self) void {
        const frame_f = @as(f32, @floatFromInt(self.frame_counter));

        // Animate some elements in a sine wave pattern
        for (self.test_elements[0..@min(50, self.test_elements.len)], 0..) |*elem, i| {
            const fi = @as(f32, @floatFromInt(i));
            const time = frame_f * 0.01;

            // Create wavy motion
            const offset_x = @sin(time + fi * 0.2) * 100;
            const offset_y = @cos(time + fi * 0.3) * 50;

            elem.setPosition(Vec2{ .x = 200 + fi * 30 + offset_x, .y = 100 + @mod(fi * 40, 800) + offset_y });
        }
    }

    fn verifyResults(self: *Self, command_buffer: *sdl.sdl.SDL_GPUCommandBuffer) !void {
        const results = try self.engine.downloadElements(command_buffer);
        defer self.allocator.free(results);

        var valid_count: u32 = 0;
        var changed_count: u32 = 0;

        for (results, 0..) |result, i| {
            const original = self.test_elements[i];

            // Check bounds
            if (result.position[0] >= 0 and result.position[0] <= 1920 and
                result.position[1] >= 0 and result.position[1] <= 1080)
            {
                valid_count += 1;
            }

            // Check for changes
            if (result.position[0] != original.position[0] or result.position[1] != original.position[1]) {
                changed_count += 1;
            }
        }

        loggers.getRenderLog().info("gpu_layout_verify", "Verification: {}/{} valid positions, {} changed elements", .{ valid_count, results.len, changed_count });
    }
};

fn createTestUIElements(allocator: std.mem.Allocator, count: usize) ![]UIElement {
    const elements = try allocator.alloc(UIElement, count);

    for (elements, 0..) |*elem, i| {
        const fi = @as(f32, @floatFromInt(i));

        if (i == 0) {
            // Root container
            elem.* = UIElement.init(Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 1920, .y = 1080 });
            elem.setLayoutMode(.absolute);
        } else if (i < 20) {
            // Top-level containers in a grid
            const cols = 5;
            const row = (i - 1) / cols;
            const col = (i - 1) % cols;

            elem.* = UIElement.init(Vec2{ .x = @as(f32, @floatFromInt(col)) * 350 + 50, .y = @as(f32, @floatFromInt(row)) * 250 + 50 }, Vec2{ .x = 300, .y = 200 });
            elem.setParent(0);
            elem.setLayoutMode(.relative);
            elem.setPadding(10);
        } else {
            // Random child elements
            const parent_index = 1 + @as(u32, @intCast((i - 20) % 19));
            elem.* = UIElement.init(Vec2{ .x = @mod(fi * 17, 200), .y = @mod(fi * 23, 150) }, Vec2{ .x = 30 + @mod(fi * 13, 50), .y = 15 + @mod(fi * 19, 30) });
            elem.setParent(parent_index);
            elem.setLayoutMode(.relative);
        }

        elem.markDirty(.layout);
    }

    return elements;
}

fn createTestConstraints(allocator: std.mem.Allocator, count: usize) ![]LayoutConstraint {
    const constraints = try allocator.alloc(LayoutConstraint, count);

    for (constraints, 0..) |*constraint, i| {
        if (i == 0) {
            // Root - fixed size
            constraint.* = LayoutConstraint.sizeConstraint(1920, 1920, 1080, 1080);
            constraint.priority = 10;
        } else if (i < 20) {
            // Containers - flexible
            constraint.* = LayoutConstraint.sizeConstraint(200, 400, 150, 300);
            constraint.priority = 5;
        } else {
            // Children - basic constraints
            constraint.* = LayoutConstraint.sizeConstraint(20, 100, 10, 50);
            constraint.priority = 1;
        }
    }

    return constraints;
}

fn createTestSprings(allocator: std.mem.Allocator, count: usize) ![]SpringState {
    const springs = try allocator.alloc(SpringState, count);

    for (springs, 0..) |*spring, i| {
        if (i == 0) {
            spring.* = SpringState.init(100.0, 20.0, 10.0); // Root - very stiff
        } else if (i < 20) {
            spring.* = SpringState.init(30.0, 8.0, 3.0); // Containers - medium
        } else {
            spring.* = SpringState.init(15.0, 4.0, 1.5); // Children - responsive
        }
    }

    return springs;
}

// Global instance for integration (optional)
var global_tester: ?GPULayoutTester = null;

/// Initialize global GPU layout tester
pub fn initGlobalGPULayoutTester(allocator: std.mem.Allocator, device: *sdl.sdl.SDL_GPUDevice) !void {
    if (global_tester != null) return; // Already initialized

    global_tester = try GPULayoutTester.init(allocator, device);
    loggers.getRenderLog().info("global_gpu_tester", "Global GPU Layout Tester initialized", .{});
}

/// Run global GPU layout test
pub fn runGlobalGPULayoutTest(command_buffer: *sdl.sdl.SDL_GPUCommandBuffer, delta_time: f32) !void {
    if (global_tester) |*tester| {
        try tester.runTest(command_buffer, delta_time);
    }
}

/// Cleanup global GPU layout tester
pub fn deinitGlobalGPULayoutTester() void {
    if (global_tester) |*tester| {
        tester.deinit();
        global_tester = null;
        loggers.getRenderLog().info("global_gpu_tester_cleanup", "Global GPU Layout Tester cleaned up", .{});
    }
}
