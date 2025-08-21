/// Layout Engines
///
/// This module contains the various layout engines for calculating element positions:
/// - Box Model: CSS-like box model with padding, border, margin
/// - Flexbox: CSS Flexbox implementation for flexible layouts
/// - Absolute: Absolute positioning engine
///
/// Each engine is specialized for different layout scenarios and can be used
/// independently or in combination to create complex layouts.

pub const box_model = @import("box_model.zig");
pub const flexbox = @import("flexbox.zig");

// Re-export commonly used types
pub const BoxModel = box_model.BoxModel;
pub const FlexboxEngine = flexbox.FlexboxEngine;
pub const Flexbox = flexbox.Flexbox; // Backward compatibility

// Re-export item types
pub const FlexItem = flexbox.FlexboxEngine.FlexItem;

// Future engines (placeholders for now)
// pub const absolute = @import("absolute.zig");
// pub const grid = @import("grid.zig");