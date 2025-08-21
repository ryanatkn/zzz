/// Layout primitives for the UI system
///
/// This module provides the core building blocks for layout calculations:
/// - Spacing: distribution of space between elements
/// - Sizing: flexible and constraint-based sizing
/// - Positioning: absolute, relative, and aligned positioning
/// - Flexbox: CSS flexbox layout implementation
///
/// These primitives are designed to be composable and efficient, with
/// minimal allocations and cache-friendly data structures.
pub const spacing = @import("spacing.zig");
pub const sizing = @import("sizing.zig");
pub const positioning = @import("positioning.zig");
pub const flexbox = @import("flexbox.zig");

// Re-export commonly used types for convenience
pub const SpacingUtils = spacing.SpacingUtils;
pub const SizingUtils = sizing.SizingUtils;
pub const PositioningUtils = positioning.PositioningUtils;
pub const Flexbox = flexbox.Flexbox;
pub const FlexItem = flexbox.Flexbox.FlexItem;
pub const FlexItemLayout = flexbox.Flexbox.FlexItemLayout;

// Re-export commonly used enums
pub const JustifyContent = flexbox.Flexbox.JustifyContent;
pub const AlignItems = flexbox.Flexbox.AlignItems;
pub const Direction = flexbox.Flexbox.Direction;
pub const PositionMode = positioning.PositioningUtils.PositionMode;
pub const Alignment = positioning.PositioningUtils.Alignment;
