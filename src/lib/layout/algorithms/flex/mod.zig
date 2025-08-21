/// Flexbox layout algorithm implementation
///
/// This module implements the CSS Flexbox layout algorithm with support for
/// flex direction, wrapping, alignment, and flex grow/shrink properties.
pub const shared = @import("shared.zig");
pub const flex_layout = @import("flex_layout.zig");

// Re-export shared types for public API
pub const Config = shared.Config;
pub const FlexItem = shared.FlexItem;

// Re-export main implementation
pub const FlexLayout = flex_layout.FlexLayout;
