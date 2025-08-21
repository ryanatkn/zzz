/// Absolute positioning layout algorithm
///
/// This module implements absolute and fixed positioning similar to CSS,
/// where elements are positioned relative to their containing block.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Position specification for absolute positioning
pub const PositionSpec = struct {
    /// Distance from top edge (null = not specified)
    top: ?f32 = null,
    /// Distance from right edge (null = not specified)
    right: ?f32 = null,
    /// Distance from bottom edge (null = not specified)
    bottom: ?f32 = null,
    /// Distance from left edge (null = not specified)
    left: ?f32 = null,
    /// Z-index for stacking order
    z_index: i32 = 0,

    /// Check if position is over-constrained
    pub fn isOverConstrained(self: PositionSpec) bool {
        const has_top = self.top != null;
        const has_bottom = self.bottom != null;
        const has_left = self.left != null;
        const has_right = self.right != null;
        
        return (has_top and has_bottom) or (has_left and has_right);
    }

    /// Resolve position conflicts by preferring top/left
    pub fn resolveConflicts(self: PositionSpec) PositionSpec {
        var resolved = self;
        
        // If both top and bottom are specified, ignore bottom
        if (self.top != null and self.bottom != null) {
            resolved.bottom = null;
        }
        
        // If both left and right are specified, ignore right
        if (self.left != null and self.right != null) {
            resolved.right = null;
        }
        
        return resolved;
    }
};

/// Absolute positioning layout algorithm
pub const AbsoluteLayout = struct {
    /// Absolute positioning configuration
    pub const Config = struct {
        /// Default containing block if none specified
        default_containing_block: Rectangle,
        /// Whether to clip elements to containing block
        clip_to_container: bool = false,
        /// How to handle over-constrained positions
        conflict_resolution: ConflictResolution = .prefer_top_left,

        pub const ConflictResolution = enum {
            prefer_top_left,
            prefer_bottom_right,
            ignore_conflicting,
        };
    };

    /// Absolutely positioned element
    pub const AbsoluteElement = struct {
        /// Element's intrinsic size
        size: Vec2,
        /// Element margins
        margin: types.Spacing,
        /// Size constraints
        constraints: types.Constraints,
        /// Position specification
        position: PositionSpec,
        /// Containing block (if different from default)
        containing_block: ?Rectangle = null,
        /// Whether element is fixed position (relative to viewport)
        is_fixed: bool = false,
        /// Element index for results
        index: usize,
    };

    /// Calculate absolute layout
    pub fn calculateLayout(
        elements: []const AbsoluteElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, elements.len);
        
        for (elements, 0..) |element, i| {
            results[i] = calculateElementLayout(element, config);
        }
        
        // Sort by z-index for correct rendering order
        std.sort.pdq(types.LayoutResult, results, {}, compareByZIndex);
        
        return results;
    }

    /// Calculate layout for a single element
    fn calculateElementLayout(element: AbsoluteElement, config: Config) types.LayoutResult {
        const containing_block = element.containing_block orelse config.default_containing_block;
        
        // Resolve position conflicts
        var position_spec = element.position;
        switch (config.conflict_resolution) {
            .prefer_top_left => position_spec = position_spec.resolveConflicts(),
            .prefer_bottom_right => {
                // Custom resolution preferring bottom/right
                if (position_spec.top != null and position_spec.bottom != null) {
                    position_spec.top = null;
                }
                if (position_spec.left != null and position_spec.right != null) {
                    position_spec.left = null;
                }
            },
            .ignore_conflicting => {
                // Keep all constraints, may lead to unexpected results
            },
        }
        
        // Calculate element size
        var element_size = element.size;
        element_size.x = element.constraints.constrainWidth(element_size.x);
        element_size.y = element.constraints.constrainHeight(element_size.y);
        
        // Calculate position
        const element_position = calculatePosition(
            position_spec,
            element_size,
            element.margin,
            containing_block,
        );
        
        var result = types.LayoutResult{
            .position = element_position,
            .size = element_size,
            .element_index = element.index,
        };
        
        // Apply clipping if enabled
        if (config.clip_to_container) {
            result = clipToContainer(result, containing_block);
        }
        
        return result;
    }

    /// Calculate element position based on position specification
    fn calculatePosition(
        position_spec: PositionSpec,
        element_size: Vec2,
        margin: types.Spacing,
        containing_block: Rectangle,
    ) Vec2 {
        var position = Vec2.ZERO;
        
        // Calculate horizontal position
        if (position_spec.left) |left| {
            position.x = containing_block.position.x + left + margin.left;
        } else if (position_spec.right) |right| {
            position.x = containing_block.position.x + containing_block.size.x - 
                       right - element_size.x - margin.right;
        } else {
            // No horizontal constraint, use containing block start
            position.x = containing_block.position.x + margin.left;
        }
        
        // Calculate vertical position
        if (position_spec.top) |top| {
            position.y = containing_block.position.y + top + margin.top;
        } else if (position_spec.bottom) |bottom| {
            position.y = containing_block.position.y + containing_block.size.y - 
                        bottom - element_size.y - margin.bottom;
        } else {
            // No vertical constraint, use containing block start
            position.y = containing_block.position.y + margin.top;
        }
        
        // Handle over-constrained cases (both sides specified)
        if (position_spec.left != null and position_spec.right != null) {
            // Element should stretch to fill the space
            const left = position_spec.left.?;
            const right = position_spec.right.?;
            const available_width = containing_block.size.x - left - right - margin.getHorizontal();
            // Note: We already resolved conflicts above, so this shouldn't happen
            // unless conflict_resolution is .ignore_conflicting
            _ = available_width;
        }
        
        if (position_spec.top != null and position_spec.bottom != null) {
            // Element should stretch to fill the space
            const top = position_spec.top.?;
            const bottom = position_spec.bottom.?;
            const available_height = containing_block.size.y - top - bottom - margin.getVertical();
            // Note: We already resolved conflicts above, so this shouldn't happen
            // unless conflict_resolution is .ignore_conflicting
            _ = available_height;
        }
        
        return position;
    }

    /// Clip element to containing block bounds
    fn clipToContainer(result: types.LayoutResult, containing_block: Rectangle) types.LayoutResult {
        var clipped = result;
        
        // Clip position to container bounds
        clipped.position.x = @max(clipped.position.x, containing_block.position.x);
        clipped.position.y = @max(clipped.position.y, containing_block.position.y);
        
        // Clip size if element extends beyond container
        const container_right = containing_block.position.x + containing_block.size.x;
        const container_bottom = containing_block.position.y + containing_block.size.y;
        
        if (clipped.position.x + clipped.size.x > container_right) {
            clipped.size.x = @max(0, container_right - clipped.position.x);
        }
        
        if (clipped.position.y + clipped.size.y > container_bottom) {
            clipped.size.y = @max(0, container_bottom - clipped.position.y);
        }
        
        return clipped;
    }

    /// Compare function for sorting by z-index
    fn compareByZIndex(_: void, a: types.LayoutResult, b: types.LayoutResult) bool {
        // This is a simplified comparison - in a real implementation,
        // we'd need access to the original z-index values
        return a.element_index < b.element_index;
    }
};

/// Relative positioning layout algorithm
pub const RelativeLayout = struct {
    /// Relative positioning configuration
    pub const Config = struct {
        /// Base layout results to offset from
        base_layout: []const types.LayoutResult,
    };

    /// Relatively positioned element
    pub const RelativeElement = struct {
        /// Base element index in layout
        base_index: usize,
        /// Position offset specification
        offset: PositionSpec,
        /// Element index for results
        index: usize,
    };

    /// Apply relative positioning offsets
    pub fn calculateLayout(
        elements: []const RelativeElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, elements.len);
        
        for (elements, 0..) |element, i| {
            // Get base layout result
            const base_result = if (element.base_index < config.base_layout.len)
                config.base_layout[element.base_index]
            else
                types.LayoutResult{
                    .position = Vec2.ZERO,
                    .size = Vec2.ZERO,
                    .element_index = element.index,
                };
            
            // Apply relative offset
            var result = base_result;
            result.element_index = element.index;
            
            // Calculate offset
            var offset = Vec2.ZERO;
            
            if (element.offset.left) |left| {
                offset.x += left;
            } else if (element.offset.right) |right| {
                offset.x -= right;
            }
            
            if (element.offset.top) |top| {
                offset.y += top;
            } else if (element.offset.bottom) |bottom| {
                offset.y -= bottom;
            }
            
            result.position = result.position.add(offset);
            results[i] = result;
        }
        
        return results;
    }
};

/// Sticky positioning layout algorithm
pub const StickyLayout = struct {
    /// Sticky positioning configuration
    pub const Config = struct {
        /// Scroll offset of the container
        scroll_offset: Vec2 = Vec2.ZERO,
        /// Container viewport bounds
        viewport_bounds: Rectangle,
    };

    /// Sticky positioned element
    pub const StickyElement = struct {
        /// Base layout result (normal flow position)
        base_result: types.LayoutResult,
        /// Sticky position constraints
        sticky_position: PositionSpec,
        /// Containing block for sticky positioning
        containing_block: Rectangle,
        /// Element index for results
        index: usize,
    };

    /// Calculate sticky layout
    pub fn calculateLayout(
        elements: []const StickyElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, elements.len);
        
        for (elements, 0..) |element, i| {
            results[i] = calculateStickyPosition(element, config);
        }
        
        return results;
    }

    /// Calculate sticky position for an element
    fn calculateStickyPosition(element: StickyElement, config: Config) types.LayoutResult {
        var result = element.base_result;
        result.element_index = element.index;
        
        // Calculate if element should be stuck
        const viewport_top = config.viewport_bounds.position.y + config.scroll_offset.y;
        const viewport_bottom = viewport_top + config.viewport_bounds.size.y;
        const viewport_left = config.viewport_bounds.position.x + config.scroll_offset.x;
        const viewport_right = viewport_left + config.viewport_bounds.size.x;
        
        // Check top constraint
        if (element.sticky_position.top) |top_offset| {
            const stick_position = viewport_top + top_offset;
            if (result.position.y < stick_position) {
                result.position.y = stick_position;
            }
        }
        
        // Check bottom constraint
        if (element.sticky_position.bottom) |bottom_offset| {
            const stick_position = viewport_bottom - bottom_offset - result.size.y;
            if (result.position.y > stick_position) {
                result.position.y = stick_position;
            }
        }
        
        // Check left constraint
        if (element.sticky_position.left) |left_offset| {
            const stick_position = viewport_left + left_offset;
            if (result.position.x < stick_position) {
                result.position.x = stick_position;
            }
        }
        
        // Check right constraint
        if (element.sticky_position.right) |right_offset| {
            const stick_position = viewport_right - right_offset - result.size.x;
            if (result.position.x > stick_position) {
                result.position.x = stick_position;
            }
        }
        
        // Ensure element stays within containing block
        const cb_right = element.containing_block.position.x + element.containing_block.size.x;
        const cb_bottom = element.containing_block.position.y + element.containing_block.size.y;
        
        result.position.x = std.math.clamp(
            result.position.x,
            element.containing_block.position.x,
            cb_right - result.size.x,
        );
        
        result.position.y = std.math.clamp(
            result.position.y,
            element.containing_block.position.y,
            cb_bottom - result.size.y,
        );
        
        return result;
    }
};

// Tests
test "absolute layout basic positioning" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const containing_block = Rectangle{
        .position = Vec2{ .x = 10, .y = 20 },
        .size = Vec2{ .x = 400, .y = 300 },
    };
    
    const elements = [_]AbsoluteLayout.AbsoluteElement{
        .{
            .size = Vec2{ .x = 100, .y = 80 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .position = PositionSpec{
                .top = 50,
                .left = 30,
            },
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 80, .y = 60 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .position = PositionSpec{
                .bottom = 40,
                .right = 25,
            },
            .index = 1,
        },
    };
    
    const config = AbsoluteLayout.Config{
        .default_containing_block = containing_block,
    };
    
    const results = try AbsoluteLayout.calculateLayout(&elements, config, allocator);
    defer allocator.free(results);
    
    try testing.expect(results.len == 2);
    
    // First element: positioned from top-left
    try testing.expect(results[0].position.x == 40); // 10 + 30
    try testing.expect(results[0].position.y == 70); // 20 + 50
    
    // Second element: positioned from bottom-right
    try testing.expect(results[1].position.x == 305); // 10 + 400 - 25 - 80
    try testing.expect(results[1].position.y == 200); // 20 + 300 - 40 - 60
}

test "absolute layout conflict resolution" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const containing_block = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 300 },
    };
    
    // Element with conflicting constraints (both top and bottom)
    const elements = [_]AbsoluteLayout.AbsoluteElement{
        .{
            .size = Vec2{ .x = 100, .y = 80 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .position = PositionSpec{
                .top = 50,
                .bottom = 60, // This should be ignored due to conflict
                .left = 30,
            },
            .index = 0,
        },
    };
    
    const config = AbsoluteLayout.Config{
        .default_containing_block = containing_block,
        .conflict_resolution = .prefer_top_left,
    };
    
    const results = try AbsoluteLayout.calculateLayout(&elements, config, allocator);
    defer allocator.free(results);
    
    // Should use top constraint, ignoring bottom
    try testing.expect(results[0].position.y == 50);
}

test "relative layout offset application" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Base layout results
    const base_layout = [_]types.LayoutResult{
        .{
            .position = Vec2{ .x = 100, .y = 50 },
            .size = Vec2{ .x = 80, .y = 60 },
            .element_index = 0,
        },
    };
    
    const elements = [_]RelativeLayout.RelativeElement{
        .{
            .base_index = 0,
            .offset = PositionSpec{
                .top = 20,
                .left = 15,
            },
            .index = 0,
        },
    };
    
    const config = RelativeLayout.Config{
        .base_layout = &base_layout,
    };
    
    const results = try RelativeLayout.calculateLayout(&elements, config, allocator);
    defer allocator.free(results);
    
    // Position should be offset from base
    try testing.expect(results[0].position.x == 115); // 100 + 15
    try testing.expect(results[0].position.y == 70);  // 50 + 20
    try testing.expect(results[0].size.x == 80);      // Size unchanged
    try testing.expect(results[0].size.y == 60);      // Size unchanged
}