/// Constraint management and resolution for layout systems
///
/// This module provides utilities for handling layout constraints including
/// size constraints, aspect ratios, and constraint resolution algorithms.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Constraints = types.Constraints;
const FlexConstraint = types.FlexConstraint;

/// Constraint resolver for handling complex constraint interactions
pub const ConstraintResolver = struct {
    /// Priority levels for constraint resolution
    pub const Priority = enum(u8) {
        low = 0,
        normal = 1,
        high = 2,
        required = 3,
    };

    /// Constraint with priority information
    pub const PriorityConstraint = struct {
        constraint: Constraints,
        priority: Priority,
        name: []const u8 = "", // For debugging
    };

    allocator: std.mem.Allocator,
    constraints: std.ArrayList(PriorityConstraint),

    /// Initialize constraint resolver
    pub fn init(allocator: std.mem.Allocator) ConstraintResolver {
        return ConstraintResolver{
            .allocator = allocator,
            .constraints = std.ArrayList(PriorityConstraint).init(allocator),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *ConstraintResolver) void {
        self.constraints.deinit();
    }

    /// Add a constraint with priority
    pub fn addConstraint(self: *ConstraintResolver, constraint: Constraints, priority: Priority, name: []const u8) !void {
        try self.constraints.append(PriorityConstraint{
            .constraint = constraint,
            .priority = priority,
            .name = name,
        });
    }

    /// Resolve all constraints to find the most restrictive valid size
    pub fn resolve(self: *ConstraintResolver, desired_size: Vec2) Vec2 {
        if (self.constraints.items.len == 0) {
            return desired_size;
        }

        // Sort constraints by priority (highest first)
        std.sort.pdq(PriorityConstraint, self.constraints.items, {}, compareConstraintPriority);

        var result = desired_size;

        // Apply constraints in priority order
        for (self.constraints.items) |priority_constraint| {
            result = priority_constraint.constraint.constrain(result);
        }

        return result;
    }

    /// Clear all constraints
    pub fn clear(self: *ConstraintResolver) void {
        self.constraints.clearRetainingCapacity();
    }

    fn compareConstraintPriority(_: void, a: PriorityConstraint, b: PriorityConstraint) bool {
        return @intFromEnum(a.priority) > @intFromEnum(b.priority);
    }
};

/// Aspect ratio constraint utilities
pub const AspectRatioConstraints = struct {
    /// Apply aspect ratio constraint to a size
    pub fn constrainAspectRatio(desired_size: Vec2, aspect_ratio: ?f32) Vec2 {
        const ratio = aspect_ratio orelse return desired_size;

        if (ratio <= 0) return desired_size;

        // Calculate both potential sizes and pick the smaller one (fit within bounds)
        const width_from_height = desired_size.y * ratio;
        const height_from_width = desired_size.x / ratio;

        if (width_from_height <= desired_size.x) {
            // Height-constrained
            return Vec2{ .x = width_from_height, .y = desired_size.y };
        } else {
            // Width-constrained
            return Vec2{ .x = desired_size.x, .y = height_from_width };
        }
    }

    /// Apply size constraints while maintaining aspect ratio
    pub fn applySizeConstraints(desired_size: Vec2, min_size: Vec2, max_size: Vec2, aspect_ratio: ?f32) Vec2 {
        var result = Vec2{
            .x = std.math.clamp(desired_size.x, min_size.x, max_size.x),
            .y = std.math.clamp(desired_size.y, min_size.y, max_size.y),
        };

        if (aspect_ratio) |ratio| {
            result = constrainAspectRatio(result, ratio);
            // Re-apply constraints after aspect ratio adjustment
            result.x = std.math.clamp(result.x, min_size.x, max_size.x);
            result.y = std.math.clamp(result.y, min_size.y, max_size.y);
        }

        return result;
    }
};

/// Content-based constraint utilities
pub const ContentConstraints = struct {
    /// Calculate minimum content size based on children
    pub fn calculateMinContentSize(children_sizes: []const Vec2) Vec2 {
        if (children_sizes.len == 0) return Vec2.ZERO;

        var max_width: f32 = 0;
        var total_height: f32 = 0;

        for (children_sizes) |size| {
            max_width = @max(max_width, size.x);
            total_height += size.y;
        }

        return Vec2{ .x = max_width, .y = total_height };
    }

    /// Calculate maximum content size based on children
    pub fn calculateMaxContentSize(children_sizes: []const Vec2, container_size: Vec2) Vec2 {
        if (children_sizes.len == 0) return container_size;

        var total_width: f32 = 0;
        var max_height: f32 = 0;

        for (children_sizes) |size| {
            total_width += size.x;
            max_height = @max(max_height, size.y);
        }

        return Vec2{
            .x = @min(total_width, container_size.x),
            .y = @min(max_height, container_size.y),
        };
    }
};

/// Layout constraint validation
pub const ConstraintValidator = struct {
    /// Check if constraints are satisfiable
    pub fn validateConstraints(constraints: Constraints) bool {
        return constraints.min_width <= constraints.max_width and
            constraints.min_height <= constraints.max_height and
            constraints.min_width >= 0 and
            constraints.min_height >= 0;
    }

    /// Check if flex constraints are satisfiable
    pub fn validateFlexConstraints(constraints: FlexConstraint) bool {
        return constraints.min <= constraints.max and
            constraints.min >= 0 and
            constraints.flex_grow >= 0 and
            constraints.flex_shrink >= 0;
    }

    /// Find constraint conflicts
    pub fn findConflicts(constraints: []const Constraints, allocator: std.mem.Allocator) ![]usize {
        var conflicts = std.ArrayList(usize).init(allocator);

        for (constraints, 0..) |constraint, i| {
            if (!validateConstraints(constraint)) {
                try conflicts.append(i);
            }
        }

        return conflicts.toOwnedSlice();
    }
};

// Tests
test "constraint resolver priority" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var resolver = ConstraintResolver.init(allocator);
    defer resolver.deinit();

    // Add constraints with different priorities
    try resolver.addConstraint(Constraints{
        .min_width = 50,
        .max_width = 150,
    }, .normal, "normal");

    try resolver.addConstraint(Constraints{
        .min_width = 75,
        .max_width = 200,
    }, .high, "high");

    // High priority constraint should dominate
    const result = resolver.resolve(Vec2{ .x = 40, .y = 100 });
    try testing.expect(result.x == 75); // From high priority min_width
}

test "aspect ratio constraint" {
    const testing = std.testing;

    // 16:9 aspect ratio
    const aspect_ratio: f32 = 16.0 / 9.0;

    // Desired size that's too tall for the aspect ratio
    const desired = Vec2{ .x = 160, .y = 120 };
    const constrained = AspectRatioConstraints.constrainAspectRatio(desired, aspect_ratio);

    // Should be width-constrained (160 wide, 90 tall)
    try testing.expect(@abs(constrained.x - 160) < 0.1);
    try testing.expect(@abs(constrained.y - 90) < 0.1);

    // Desired size that's too wide for the aspect ratio
    const desired2 = Vec2{ .x = 200, .y = 90 };
    const constrained2 = AspectRatioConstraints.constrainAspectRatio(desired2, aspect_ratio);

    // Should be height-constrained (160 wide, 90 tall)
    try testing.expect(@abs(constrained2.x - 160) < 0.1);
    try testing.expect(@abs(constrained2.y - 90) < 0.1);
}

test "constraint validation" {
    const testing = std.testing;

    // Valid constraints
    const valid = Constraints{
        .min_width = 10,
        .max_width = 100,
        .min_height = 20,
        .max_height = 200,
    };
    try testing.expect(ConstraintValidator.validateConstraints(valid));

    // Invalid constraints (min > max)
    const invalid = Constraints{
        .min_width = 100,
        .max_width = 10, // min > max
    };
    try testing.expect(!ConstraintValidator.validateConstraints(invalid));

    // Invalid constraints (negative min)
    const invalid2 = Constraints{
        .min_width = -10, // negative
        .max_width = 100,
    };
    try testing.expect(!ConstraintValidator.validateConstraints(invalid2));
}

test "content constraints" {
    const testing = std.testing;

    const children = [_]Vec2{
        Vec2{ .x = 50, .y = 30 },
        Vec2{ .x = 80, .y = 40 },
        Vec2{ .x = 60, .y = 20 },
    };

    const min_content = ContentConstraints.calculateMinContentSize(&children);
    try testing.expect(min_content.x == 80); // Max width
    try testing.expect(min_content.y == 90); // Sum of heights

    const container = Vec2{ .x = 300, .y = 200 };
    const max_content = ContentConstraints.calculateMaxContentSize(&children, container);
    try testing.expect(max_content.x == 190); // Sum of widths (50+80+60)
    try testing.expect(max_content.y == 40); // Max height
}