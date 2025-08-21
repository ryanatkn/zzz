/// Relative positioning layout algorithm
const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../../core/types.zig");
const shared = @import("shared.zig");

const Vec2 = math.Vec2;
const PositionSpec = shared.PositionSpec;

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

// Tests
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
    try testing.expect(results[0].position.y == 70); // 50 + 20
    try testing.expect(results[0].size.x == 80); // Size unchanged
    try testing.expect(results[0].size.y == 60); // Size unchanged
}
