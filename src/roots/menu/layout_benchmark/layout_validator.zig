const std = @import("std");
const layout_mod = @import("../../../lib/layout/mod.zig");
const math = @import("../../../lib/math/mod.zig");
const loggers = @import("../../../lib/debug/loggers.zig");

const UIElement = layout_mod.UIElement;

/// Layout validation system for cross-checking CPU vs GPU backend results
pub const LayoutValidator = struct {
    allocator: std.mem.Allocator,
    tolerance: f32,
    validation_buffer: std.ArrayList(UIElement),
    validation_enabled: bool,

    // Reusable error message buffer to avoid allocations
    error_message_buffer: [512]u8 = undefined,

    // Statistics
    total_validations: u32 = 0,
    failed_validations: u32 = 0,
    max_position_error: f32 = 0.0,
    max_size_error: f32 = 0.0,

    const Self = @This();

    pub const ValidationResult = struct {
        is_valid: bool,
        max_position_error: f32,
        max_size_error: f32,
        first_error_index: ?usize,
        error_details: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, tolerance: f32) Self {
        return Self{
            .allocator = allocator,
            .tolerance = tolerance,
            .validation_buffer = std.ArrayList(UIElement).init(allocator),
            .validation_enabled = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.validation_buffer.deinit();
    }

    /// Enable or disable validation (useful for performance testing)
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.validation_enabled = enabled;
        loggers.getUILog().info("layout_validation", "Layout validation {s}", .{if (enabled) "enabled" else "disabled"});
    }

    /// Validate that two layout results are equivalent within tolerance
    pub fn validateResults(self: *Self, cpu_results: []const UIElement, gpu_results: []const UIElement) !ValidationResult {
        if (!self.validation_enabled) {
            return ValidationResult{
                .is_valid = true,
                .max_position_error = 0.0,
                .max_size_error = 0.0,
                .first_error_index = null,
                .error_details = "validation disabled",
            };
        }

        self.total_validations += 1;

        if (cpu_results.len != gpu_results.len) {
            self.failed_validations += 1;
            loggers.getUILog().err("layout_validation_fail", "Result count mismatch: CPU={}, GPU={}", .{ cpu_results.len, gpu_results.len });
            return ValidationResult{
                .is_valid = false,
                .max_position_error = std.math.inf(f32),
                .max_size_error = std.math.inf(f32),
                .first_error_index = null,
                .error_details = "mismatched result counts",
            };
        }

        var max_pos_error: f32 = 0.0;
        var max_size_error: f32 = 0.0;
        var first_error_index: ?usize = null;
        var error_details: []const u8 = "";

        for (cpu_results, gpu_results, 0..) |cpu_elem, gpu_elem, i| {
            // Check position differences
            const pos_diff_x = @abs(cpu_elem.position[0] - gpu_elem.position[0]);
            const pos_diff_y = @abs(cpu_elem.position[1] - gpu_elem.position[1]);
            const pos_error = @max(pos_diff_x, pos_diff_y);
            max_pos_error = @max(max_pos_error, pos_error);

            // Check size differences
            const size_diff_x = @abs(cpu_elem.size[0] - gpu_elem.size[0]);
            const size_diff_y = @abs(cpu_elem.size[1] - gpu_elem.size[1]);
            const size_error = @max(size_diff_x, size_diff_y);
            max_size_error = @max(max_size_error, size_error);

            // Record first error for detailed reporting using reusable buffer
            if ((pos_error > self.tolerance or size_error > self.tolerance) and first_error_index == null) {
                first_error_index = i;
                error_details = std.fmt.bufPrint(&self.error_message_buffer, "element[{}]: pos({:.3},{:.3}) vs ({:.3},{:.3}), size({:.3},{:.3}) vs ({:.3},{:.3})", .{ i, cpu_elem.position[0], cpu_elem.position[1], gpu_elem.position[0], gpu_elem.position[1], cpu_elem.size[0], cpu_elem.size[1], gpu_elem.size[0], gpu_elem.size[1] }) catch "error formatting";
            }
        }

        // Update global statistics
        self.max_position_error = @max(self.max_position_error, max_pos_error);
        self.max_size_error = @max(self.max_size_error, max_size_error);

        const is_valid = max_pos_error <= self.tolerance and max_size_error <= self.tolerance;
        if (!is_valid) {
            self.failed_validations += 1;
            loggers.getUILog().err("layout_validation_fail", "Validation failed: pos_error={d:.6}, size_error={d:.6}, tolerance={d:.6}", .{ max_pos_error, max_size_error, self.tolerance });
        } else {
            loggers.getUILog().debug("layout_validation_pass", "Validation passed: {} elements, max_errors: pos={d:.6}, size={d:.6}", .{ cpu_results.len, max_pos_error, max_size_error });
        }

        return ValidationResult{
            .is_valid = is_valid,
            .max_position_error = max_pos_error,
            .max_size_error = max_size_error,
            .first_error_index = first_error_index,
            .error_details = error_details,
        };
    }

    /// Create a copy of elements for validation testing
    pub fn copyElements(self: *Self, elements: []const UIElement) ![]UIElement {
        self.validation_buffer.clearRetainingCapacity();
        try self.validation_buffer.appendSlice(elements);
        return self.validation_buffer.items;
    }

    /// Get validation statistics
    pub fn getStats(self: *const Self) struct {
        total_validations: u32,
        failed_validations: u32,
        success_rate: f32,
        max_position_error: f32,
        max_size_error: f32,
    } {
        const success_rate = if (self.total_validations > 0)
            (1.0 - @as(f32, @floatFromInt(self.failed_validations)) / @as(f32, @floatFromInt(self.total_validations))) * 100.0
        else
            100.0;

        return .{
            .total_validations = self.total_validations,
            .failed_validations = self.failed_validations,
            .success_rate = success_rate,
            .max_position_error = self.max_position_error,
            .max_size_error = self.max_size_error,
        };
    }

    /// Reset validation statistics
    pub fn resetStats(self: *Self) void {
        self.total_validations = 0;
        self.failed_validations = 0;
        self.max_position_error = 0.0;
        self.max_size_error = 0.0;
        loggers.getUILog().info("layout_validation_reset", "Validation statistics reset", .{});
    }

    /// Set tolerance for floating point comparisons
    pub fn setTolerance(self: *Self, tolerance: f32) void {
        self.tolerance = tolerance;
        loggers.getUILog().info("layout_validation_tolerance", "Validation tolerance set to {:.6f} pixels", .{tolerance});
    }
};

// Tests
test "layout validator basic functionality" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var validator = LayoutValidator.init(allocator, 0.01);
    defer validator.deinit();

    // Create identical elements
    const elem1 = UIElement.init(math.Vec2{ .x = 10.0, .y = 20.0 }, math.Vec2{ .x = 100.0, .y = 50.0 });
    const elem2 = UIElement.init(math.Vec2{ .x = 10.0, .y = 20.0 }, math.Vec2{ .x = 100.0, .y = 50.0 });

    const cpu_results = [_]UIElement{elem1};
    const gpu_results = [_]UIElement{elem2};

    const result = try validator.validateResults(&cpu_results, &gpu_results);

    try testing.expect(result.is_valid);
    try testing.expect(result.max_position_error == 0.0);
    try testing.expect(result.max_size_error == 0.0);
}

test "layout validator detects differences" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var validator = LayoutValidator.init(allocator, 0.01);
    defer validator.deinit();

    // Create different elements (beyond tolerance)
    const elem1 = UIElement.init(math.Vec2{ .x = 10.0, .y = 20.0 }, math.Vec2{ .x = 100.0, .y = 50.0 });
    var elem2 = UIElement.init(math.Vec2{ .x = 10.0, .y = 20.0 }, math.Vec2{ .x = 100.0, .y = 50.0 });
    elem2.position[0] = 10.1; // 0.1 pixel difference (beyond 0.01 tolerance)

    const cpu_results = [_]UIElement{elem1};
    const gpu_results = [_]UIElement{elem2};

    const result = try validator.validateResults(&cpu_results, &gpu_results);

    try testing.expect(!result.is_valid);
    try testing.expect(result.max_position_error == 0.1);
    try testing.expect(result.first_error_index.? == 0);
}
