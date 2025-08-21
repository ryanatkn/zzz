/// Layout validation and debugging utilities
///
/// This module provides tools for validating layout calculations, detecting
/// common layout issues, and providing helpful debugging information.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../core/types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Layout validation error types
pub const ValidationError = struct {
    type: ErrorType,
    element_index: ?usize,
    message: []const u8,
    severity: Severity,
    position: ?Vec2,
    size: ?Vec2,

    pub const ErrorType = enum {
        // Constraint violations
        size_constraint_violation,
        position_constraint_violation,
        negative_size,
        infinite_size,

        // Overlap issues
        element_overlap,
        container_overflow,

        // Hierarchy issues
        parent_child_inconsistency,
        circular_dependency,
        orphaned_element,

        // Performance issues
        excessive_elements,
        deep_nesting,
        frequent_recalculation,

        // Configuration issues
        invalid_constraints,
        conflicting_properties,
        missing_required_data,
    };

    pub const Severity = enum {
        info,
        warning,
        err,
        critical,

        pub fn toString(self: Severity) []const u8 {
            return switch (self) {
                .info => "INFO",
                .warning => "WARNING",
                .err => "ERROR",
                .critical => "CRITICAL",
            };
        }
    };
};

/// Layout validator for detecting issues and inconsistencies
pub const LayoutValidator = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(ValidationError),
    config: ValidationConfig,

    pub const ValidationConfig = struct {
        /// Maximum allowed element count before warning
        max_element_count: usize = 1000,
        /// Maximum nesting depth before warning
        max_nesting_depth: usize = 20,
        /// Minimum element size threshold
        min_element_size: f32 = 1.0,
        /// Maximum element size threshold
        max_element_size: f32 = 10000.0,
        /// Whether to check for overlaps
        check_overlaps: bool = true,
        /// Whether to validate constraints
        validate_constraints: bool = true,
        /// Whether to check performance issues
        check_performance: bool = true,
    };

    pub fn init(allocator: std.mem.Allocator, config: ValidationConfig) LayoutValidator {
        return LayoutValidator{
            .allocator = allocator,
            .errors = std.ArrayList(ValidationError).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *LayoutValidator) void {
        // Free error message strings
        for (self.errors.items) |error_item| {
            self.allocator.free(error_item.message);
        }
        self.errors.deinit();
    }

    /// Clear all validation errors
    pub fn clear(self: *LayoutValidator) void {
        for (self.errors.items) |error_item| {
            self.allocator.free(error_item.message);
        }
        self.errors.clearRetainingCapacity();
    }

    /// Add a validation error
    fn addError(
        self: *LayoutValidator,
        error_type: ValidationError.ErrorType,
        severity: ValidationError.Severity,
        element_index: ?usize,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        const message = try std.fmt.allocPrint(self.allocator, fmt, args);

        try self.errors.append(ValidationError{
            .type = error_type,
            .element_index = element_index,
            .message = message,
            .severity = severity,
            .position = null,
            .size = null,
        });
    }

    /// Validate layout results
    pub fn validateLayout(
        self: *LayoutValidator,
        elements: []const types.LayoutResult,
        container_bounds: Rectangle,
    ) !void {
        self.clear();

        if (self.config.check_performance) {
            try self.checkPerformanceIssues(elements);
        }

        if (self.config.validate_constraints) {
            try self.validateSizes(elements);
            try self.validatePositions(elements, container_bounds);
        }

        if (self.config.check_overlaps) {
            try self.checkOverlaps(elements);
            try self.checkContainerOverflow(elements, container_bounds);
        }
    }

    /// Check for performance-related issues
    fn checkPerformanceIssues(self: *LayoutValidator, elements: []const types.LayoutResult) !void {
        // Check element count
        if (elements.len > self.config.max_element_count) {
            try self.addError(
                .excessive_elements,
                .warning,
                null,
                "Layout contains {d} elements, which exceeds recommended maximum of {d}",
                .{ elements.len, self.config.max_element_count },
            );
        }

        // TODO: Check nesting depth (requires hierarchy information)
        // TODO: Check for frequent recalculations (requires timing data)
    }

    /// Validate element sizes
    fn validateSizes(self: *LayoutValidator, elements: []const types.LayoutResult) !void {
        for (elements, 0..) |element, i| {
            // Check for negative sizes
            if (element.size.x < 0 or element.size.y < 0) {
                try self.addError(
                    .negative_size,
                    .err,
                    i,
                    "Element has negative size: {d}x{d}",
                    .{ element.size.x, element.size.y },
                );
            }

            // Check for infinite sizes
            if (!std.math.isFinite(element.size.x) or !std.math.isFinite(element.size.y)) {
                try self.addError(
                    .infinite_size,
                    .critical,
                    i,
                    "Element has infinite size: {d}x{d}",
                    .{ element.size.x, element.size.y },
                );
            }

            // Check size thresholds
            if (element.size.x < self.config.min_element_size or element.size.y < self.config.min_element_size) {
                try self.addError(
                    .size_constraint_violation,
                    .warning,
                    i,
                    "Element size {d}x{d} is below minimum threshold {d}",
                    .{ element.size.x, element.size.y, self.config.min_element_size },
                );
            }

            if (element.size.x > self.config.max_element_size or element.size.y > self.config.max_element_size) {
                try self.addError(
                    .size_constraint_violation,
                    .warning,
                    i,
                    "Element size {d}x{d} exceeds maximum threshold {d}",
                    .{ element.size.x, element.size.y, self.config.max_element_size },
                );
            }
        }
    }

    /// Validate element positions
    fn validatePositions(
        self: *LayoutValidator,
        elements: []const types.LayoutResult,
        container_bounds: Rectangle,
    ) !void {
        _ = container_bounds;

        for (elements, 0..) |element, i| {
            // Check for infinite positions
            if (!std.math.isFinite(element.position.x) or !std.math.isFinite(element.position.y)) {
                try self.addError(
                    .position_constraint_violation,
                    .critical,
                    i,
                    "Element has infinite position: {d}, {d}",
                    .{ element.position.x, element.position.y },
                );
            }

            // TODO: Check if position is within reasonable bounds
            // TODO: Validate position relative to parent (requires hierarchy info)
        }
    }

    /// Check for element overlaps
    fn checkOverlaps(self: *LayoutValidator, elements: []const types.LayoutResult) !void {
        for (elements, 0..) |element_a, i| {
            const rect_a = Rectangle{
                .position = element_a.position,
                .size = element_a.size,
            };

            for (elements[i + 1 ..], i + 1..) |element_b, j| {
                const rect_b = Rectangle{
                    .position = element_b.position,
                    .size = element_b.size,
                };

                if (rect_a.intersects(rect_b)) {
                    try self.addError(
                        .element_overlap,
                        .warning,
                        i,
                        "Element {d} overlaps with element {d}",
                        .{ i, j },
                    );
                }
            }
        }
    }

    /// Check for container overflow
    fn checkContainerOverflow(
        self: *LayoutValidator,
        elements: []const types.LayoutResult,
        container_bounds: Rectangle,
    ) !void {
        for (elements, 0..) |element, i| {
            const element_rect = Rectangle{
                .position = element.position,
                .size = element.size,
            };

            // Check if element rectangle is entirely contained within container bounds
            const element_right = element_rect.position.x + element_rect.size.x;
            const element_bottom = element_rect.position.y + element_rect.size.y;
            const container_right = container_bounds.position.x + container_bounds.size.x;
            const container_bottom = container_bounds.position.y + container_bounds.size.y;

            const is_contained = element_rect.position.x >= container_bounds.position.x and
                element_rect.position.y >= container_bounds.position.y and
                element_right <= container_right and
                element_bottom <= container_bottom;

            if (!is_contained) {
                try self.addError(
                    .container_overflow,
                    .warning,
                    i,
                    "Element extends outside container bounds",
                    .{},
                );
            }
        }
    }

    /// Get validation results
    pub fn getErrors(self: *const LayoutValidator) []const ValidationError {
        return self.errors.items;
    }

    /// Check if validation passed (no errors or critical issues)
    pub fn isValid(self: *const LayoutValidator) bool {
        for (self.errors.items) |error_item| {
            if (error_item.severity == .err or error_item.severity == .critical) {
                return false;
            }
        }
        return true;
    }

    /// Get error count by severity
    pub fn getErrorCountBySeverity(self: *const LayoutValidator, severity: ValidationError.Severity) usize {
        var count: usize = 0;
        for (self.errors.items) |error_item| {
            if (error_item.severity == severity) {
                count += 1;
            }
        }
        return count;
    }

    /// Format validation report
    pub fn formatReport(self: *const LayoutValidator, writer: anytype) !void {
        try writer.print("Layout Validation Report\n");
        try writer.print("========================\n");

        const total_errors = self.errors.items.len;
        if (total_errors == 0) {
            try writer.print("✓ No issues found\n");
            return;
        }

        try writer.print("Total issues: {d}\n", .{total_errors});

        // Count by severity
        const critical_count = self.getErrorCountBySeverity(.critical);
        const error_count = self.getErrorCountBySeverity(.err);
        const warning_count = self.getErrorCountBySeverity(.warning);
        const info_count = self.getErrorCountBySeverity(.info);

        if (critical_count > 0) try writer.print("Critical: {d}\n", .{critical_count});
        if (error_count > 0) try writer.print("Errors: {d}\n", .{error_count});
        if (warning_count > 0) try writer.print("Warnings: {d}\n", .{warning_count});
        if (info_count > 0) try writer.print("Info: {d}\n", .{info_count});

        try writer.print("\nDetailed Issues:\n");
        try writer.print("================\n");

        for (self.errors.items, 0..) |error_item, i| {
            try writer.print("{d}. [{s}] ", .{ i + 1, error_item.severity.toString() });

            if (error_item.element_index) |idx| {
                try writer.print("Element {d}: ", .{idx});
            }

            try writer.print("{s}\n", .{error_item.message});
        }
    }
};

/// Layout debugging utilities
pub const LayoutDebugger = struct {
    allocator: std.mem.Allocator,
    debug_data: std.ArrayList(DebugEntry),

    pub const DebugEntry = struct {
        timestamp: i64,
        element_index: usize,
        operation: Operation,
        before_state: ?ElementState,
        after_state: ?ElementState,

        pub const Operation = enum {
            create,
            update_position,
            update_size,
            update_constraints,
            destroy,
        };

        pub const ElementState = struct {
            position: Vec2,
            size: Vec2,
            constraints: types.Constraints,
        };
    };

    pub fn init(allocator: std.mem.Allocator) LayoutDebugger {
        return LayoutDebugger{
            .allocator = allocator,
            .debug_data = std.ArrayList(DebugEntry).init(allocator),
        };
    }

    pub fn deinit(self: *LayoutDebugger) void {
        self.debug_data.deinit();
    }

    /// Record a debug entry
    pub fn recordOperation(
        self: *LayoutDebugger,
        element_index: usize,
        operation: DebugEntry.Operation,
        before_state: ?DebugEntry.ElementState,
        after_state: ?DebugEntry.ElementState,
    ) !void {
        try self.debug_data.append(DebugEntry{
            .timestamp = @intCast(std.time.nanoTimestamp()),
            .element_index = element_index,
            .operation = operation,
            .before_state = before_state,
            .after_state = after_state,
        });
    }

    /// Clear debug history
    pub fn clear(self: *LayoutDebugger) void {
        self.debug_data.clearRetainingCapacity();
    }

    /// Get debug history
    pub fn getHistory(self: *const LayoutDebugger) []const DebugEntry {
        return self.debug_data.items;
    }

    /// Format debug report
    pub fn formatReport(self: *const LayoutDebugger, writer: anytype) !void {
        try writer.print("Layout Debug History\n");
        try writer.print("===================\n");

        if (self.debug_data.items.len == 0) {
            try writer.print("No debug data recorded\n");
            return;
        }

        for (self.debug_data.items, 0..) |entry, i| {
            try writer.print("{d}. Element {d}: {s}\n", .{ i + 1, entry.element_index, @tagName(entry.operation) });

            if (entry.before_state) |before| {
                try writer.print("   Before: pos({d}, {d}) size({d}, {d})\n", .{
                    before.position.x, before.position.y,
                    before.size.x,     before.size.y,
                });
            }

            if (entry.after_state) |after| {
                try writer.print("   After:  pos({d}, {d}) size({d}, {d})\n", .{
                    after.position.x, after.position.y,
                    after.size.x,     after.size.y,
                });
            }
        }
    }
};

// Tests
test "validator basic functionality" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var validator = LayoutValidator.init(allocator, LayoutValidator.ValidationConfig{});
    defer validator.deinit();

    // Test with valid layout
    const valid_elements = [_]types.LayoutResult{
        types.LayoutResult{
            .position = Vec2{ .x = 0, .y = 0 },
            .size = Vec2{ .x = 100, .y = 50 },
            .content = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 100, .y = 50 } },
            .element_index = 0,
        },
        types.LayoutResult{
            .position = Vec2{ .x = 150, .y = 0 },
            .size = Vec2{ .x = 100, .y = 50 },
            .content = Rectangle{ .position = Vec2{ .x = 150, .y = 0 }, .size = Vec2{ .x = 100, .y = 50 } },
            .element_index = 1,
        },
    };

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 800, .y = 600 },
    };

    try validator.validateLayout(&valid_elements, container);
    try testing.expect(validator.isValid());
    try testing.expect(validator.getErrors().len == 0);
}

test "validator detects negative size" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var validator = LayoutValidator.init(allocator, LayoutValidator.ValidationConfig{});
    defer validator.deinit();

    // Test with invalid layout (negative size)
    const invalid_elements = [_]types.LayoutResult{
        types.LayoutResult{
            .position = Vec2{ .x = 0, .y = 0 },
            .size = Vec2{ .x = -10, .y = 50 }, // Negative width
            .content = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = -10, .y = 50 } },
            .element_index = 0,
        },
    };

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 800, .y = 600 },
    };

    try validator.validateLayout(&invalid_elements, container);
    try testing.expect(!validator.isValid());
    try testing.expect(validator.getErrors().len > 0);
    try testing.expect(validator.getErrors()[0].type == .negative_size);
}

test "validator detects overlaps" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var validator = LayoutValidator.init(allocator, LayoutValidator.ValidationConfig{});
    defer validator.deinit();

    // Test with overlapping elements
    const overlapping_elements = [_]types.LayoutResult{
        types.LayoutResult{
            .position = Vec2{ .x = 0, .y = 0 },
            .size = Vec2{ .x = 100, .y = 100 },
            .content = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 100, .y = 100 } },
            .element_index = 0,
        },
        types.LayoutResult{
            .position = Vec2{ .x = 50, .y = 50 }, // Overlaps with first element
            .size = Vec2{ .x = 100, .y = 100 },
            .content = Rectangle{ .position = Vec2{ .x = 50, .y = 50 }, .size = Vec2{ .x = 100, .y = 100 } },
            .element_index = 1,
        },
    };

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 800, .y = 600 },
    };

    try validator.validateLayout(&overlapping_elements, container);
    try testing.expect(validator.getErrors().len > 0);

    // Should detect overlap
    var found_overlap = false;
    for (validator.getErrors()) |error_item| {
        if (error_item.type == .element_overlap) {
            found_overlap = true;
            break;
        }
    }
    try testing.expect(found_overlap);
}

test "debugger records operations" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var debugger = LayoutDebugger.init(allocator);
    defer debugger.deinit();

    const before_state = LayoutDebugger.DebugEntry.ElementState{
        .position = Vec2{ .x = 0, .y = 0 },
        .size = Vec2{ .x = 50, .y = 25 },
        .constraints = types.Constraints{},
    };

    const after_state = LayoutDebugger.DebugEntry.ElementState{
        .position = Vec2{ .x = 100, .y = 50 },
        .size = Vec2{ .x = 50, .y = 25 },
        .constraints = types.Constraints{},
    };

    try debugger.recordOperation(0, .update_position, before_state, after_state);

    const history = debugger.getHistory();
    try testing.expect(history.len == 1);
    try testing.expect(history[0].element_index == 0);
    try testing.expect(history[0].operation == .update_position);
}
