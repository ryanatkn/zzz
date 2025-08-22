/// Core layout algorithms
///
/// This module provides implementations of various layout algorithms
/// including block, flexbox, grid, and positioning.
pub const block = @import("block.zig");
pub const flex = @import("flex/mod.zig");
pub const position = @import("position/mod.zig");
pub const box_model = @import("box_model/mod.zig");
pub const text = @import("text/mod.zig");

// Re-export commonly used types
pub const BlockLayout = block.BlockLayout;
pub const OverflowBlockLayout = block.OverflowBlockLayout;

pub const FlexLayout = flex.FlexLayout;
pub const FlexItem = flex.FlexItem;

pub const AbsoluteLayout = position.AbsoluteLayout;
pub const RelativeLayout = position.RelativeLayout;
pub const StickyLayout = position.StickyLayout;
pub const PositionSpec = position.PositionSpec;
