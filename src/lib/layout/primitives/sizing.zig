const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Size calculation and constraint utilities for layout primitives
pub const SizingUtils = struct {
    
    /// Flexible sizing constraint
    pub const FlexConstraint = struct {
        /// Minimum size (CSS min-width/min-height)
        min: f32 = 0,
        /// Maximum size (CSS max-width/max-height)
        max: f32 = std.math.inf(f32),
        /// Flex grow factor (CSS flex-grow) - how much to grow relative to siblings
        flex_grow: f32 = 0,
        /// Flex shrink factor (CSS flex-shrink) - how much to shrink relative to siblings  
        flex_shrink: f32 = 1,
        /// Flex basis (CSS flex-basis) - initial size before growing/shrinking
        flex_basis: ?f32 = null, // null means auto (use content size)
        
        pub fn constrain(self: FlexConstraint, size: f32) f32 {
            return std.math.clamp(size, self.min, self.max);
        }
    };

    /// Calculate intrinsic size respecting constraints
    pub fn calculateIntrinsicSize(preferred_size: f32, constraint: FlexConstraint) f32 {
        const basis_size = constraint.flex_basis orelse preferred_size;
        return constraint.constrain(basis_size);
    }

    /// Distribute extra space among flexible items using flex-grow
    pub fn distributeExtraSpace(extra_space: f32, items: []const FlexConstraint, current_sizes: []f32) void {
        if (extra_space <= 0 or items.len == 0) return;
        
        // Calculate total grow factor
        var total_grow: f32 = 0;
        for (items) |item| {
            if (item.flex_grow > 0) {
                total_grow += item.flex_grow;
            }
        }
        
        if (total_grow == 0) return; // No flexible items
        
        // Distribute space proportionally
        for (items, current_sizes) |item, *size| {
            if (item.flex_grow > 0) {
                const grow_amount = extra_space * (item.flex_grow / total_grow);
                const new_size = size.* + grow_amount;
                size.* = item.constrain(new_size);
            }
        }
    }

    /// Shrink items that are too large using flex-shrink
    pub fn shrinkOversizedItems(deficit: f32, items: []const FlexConstraint, current_sizes: []f32) void {
        if (deficit <= 0 or items.len == 0) return;
        
        // Calculate weighted shrink factors (flex-shrink * current_size)
        var total_shrink_weight: f32 = 0;
        for (items, current_sizes) |item, size| {
            if (item.flex_shrink > 0 and size > item.min) {
                total_shrink_weight += item.flex_shrink * size;
            }
        }
        
        if (total_shrink_weight == 0) return; // No shrinkable items
        
        // Shrink items proportionally to their weighted shrink factor
        for (items, current_sizes) |item, *size| {
            if (item.flex_shrink > 0 and size.* > item.min) {
                const shrink_weight = item.flex_shrink * size.*;
                const shrink_amount = deficit * (shrink_weight / total_shrink_weight);
                const new_size = size.* - shrink_amount;
                size.* = item.constrain(new_size);
            }
        }
    }

    /// Calculate flex layout sizes for a set of items
    pub fn calculateFlexSizes(
        available_space: f32,
        items: []const FlexConstraint,
        preferred_sizes: []const f32,
        result_sizes: []f32,
    ) void {
        if (items.len != preferred_sizes.len or items.len != result_sizes.len) {
            std.debug.panic("Array length mismatch in calculateFlexSizes", .{});
        }
        
        if (items.len == 0) return;
        
        // Step 1: Calculate initial sizes using flex-basis or preferred size
        var total_initial_size: f32 = 0;
        for (items, preferred_sizes, result_sizes) |item, preferred, *result| {
            result.* = calculateIntrinsicSize(preferred, item);
            total_initial_size += result.*;
        }
        
        // Step 2: Handle growing or shrinking
        const space_difference = available_space - total_initial_size;
        
        if (space_difference > 0) {
            // Extra space available - distribute using flex-grow
            distributeExtraSpace(space_difference, items, result_sizes);
        } else if (space_difference < 0) {
            // Not enough space - shrink using flex-shrink
            shrinkOversizedItems(-space_difference, items, result_sizes);
        }
    }

    /// Calculate aspect ratio constrained size
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
    pub fn applySizeConstraints(
        desired_size: Vec2, 
        min_size: Vec2, 
        max_size: Vec2, 
        aspect_ratio: ?f32
    ) Vec2 {
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

// Tests
test "flex constraint basic operations" {
    const testing = std.testing;
    
    const constraint = SizingUtils.FlexConstraint{
        .min = 50,
        .max = 200,
        .flex_basis = 100,
    };
    
    try testing.expect(constraint.constrain(30) == 50); // Below min
    try testing.expect(constraint.constrain(150) == 150); // Within range
    try testing.expect(constraint.constrain(250) == 200); // Above max
    
    const intrinsic = SizingUtils.calculateIntrinsicSize(80, constraint);
    try testing.expect(intrinsic == 100); // Uses flex-basis
}

test "flex space distribution" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;
    
    const items = [_]SizingUtils.FlexConstraint{
        .{ .flex_grow = 1, .min = 0, .max = std.math.inf(f32) },
        .{ .flex_grow = 2, .min = 0, .max = std.math.inf(f32) },
        .{ .flex_grow = 1, .min = 0, .max = std.math.inf(f32) },
    };
    
    var sizes = [_]f32{ 50, 50, 50 }; // Initial sizes
    
    // Distribute 80px extra space (total grow = 4, so 20px per unit)
    SizingUtils.distributeExtraSpace(80, &items, &sizes);
    
    try testing.expect(@abs(sizes[0] - 70) < 0.01); // 50 + 20
    try testing.expect(@abs(sizes[1] - 90) < 0.01); // 50 + 40 
    try testing.expect(@abs(sizes[2] - 70) < 0.01); // 50 + 20
}

test "flex shrinking" {
    const testing = std.testing;
    
    const items = [_]SizingUtils.FlexConstraint{
        .{ .flex_shrink = 1, .min = 30, .max = std.math.inf(f32) },
        .{ .flex_shrink = 2, .min = 20, .max = std.math.inf(f32) },
        .{ .flex_shrink = 1, .min = 10, .max = std.math.inf(f32) },
    };
    
    var sizes = [_]f32{ 100, 100, 100 }; // Current sizes
    
    // Need to shrink by 150px total
    SizingUtils.shrinkOversizedItems(150, &items, &sizes);
    
    // Each has shrink weight of: item[0]=100*1=100, item[1]=100*2=200, item[2]=100*1=100
    // Total weight = 400, so shrink proportions: 100/400, 200/400, 100/400
    // Shrink amounts: 150*(100/400)=37.5, 150*(200/400)=75, 150*(100/400)=37.5
    try testing.expect(@abs(sizes[0] - 62.5) < 0.1);
    try testing.expect(@abs(sizes[1] - 25.0) < 0.1);
    try testing.expect(@abs(sizes[2] - 62.5) < 0.1);
}

test "aspect ratio constraint" {
    const testing = std.testing;
    
    // 16:9 aspect ratio
    const aspect_ratio: f32 = 16.0 / 9.0;
    
    // Desired size that's too tall for the aspect ratio
    const desired = Vec2{ .x = 160, .y = 120 };
    const constrained = SizingUtils.constrainAspectRatio(desired, aspect_ratio);
    
    // Should be width-constrained (160 wide, 90 tall)
    try testing.expect(@abs(constrained.x - 160) < 0.1);
    try testing.expect(@abs(constrained.y - 90) < 0.1);
    
    // Desired size that's too wide for the aspect ratio
    const desired2 = Vec2{ .x = 200, .y = 90 };
    const constrained2 = SizingUtils.constrainAspectRatio(desired2, aspect_ratio);
    
    // Should be height-constrained (160 wide, 90 tall)
    try testing.expect(@abs(constrained2.x - 160) < 0.1);
    try testing.expect(@abs(constrained2.y - 90) < 0.1);
}