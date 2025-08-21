/// Unified Layout System
/// 
/// This module provides all layout calculation functionality for the engine:
/// - Box Model: CSS-like box model with padding, border, margin
/// - Text Baseline: Proper text positioning and alignment
/// - Layout Primitives: Flexbox, spacing, sizing, positioning utilities
/// - Text Layout: Full text layout engine with wrapping and alignment
///
/// This consolidates layout functionality from across the engine into a single,
/// capability-based module following the engine's architectural principles.

// Core layout systems
pub const box_model = @import("box_model.zig");
pub const text_baseline = @import("text_baseline.zig");

// Layout primitives (spacing, sizing, positioning, flexbox)
pub const primitives = @import("primitives/mod.zig");

// Text-specific layout engines
pub const text = @import("../text/layout.zig");

// Re-export commonly used types for convenience
pub const BoxModel = box_model.BoxModel;
pub const TextBaseline = text_baseline.TextBaseline; 
pub const TextPositioning = text_baseline.TextPositioning;

// Re-export primitive types
pub const SpacingUtils = primitives.SpacingUtils;
pub const SizingUtils = primitives.SizingUtils;
pub const PositioningUtils = primitives.PositioningUtils;
pub const Flexbox = primitives.Flexbox;
pub const FlexItem = primitives.FlexItem;
pub const FlexItemLayout = primitives.FlexItemLayout;

// Re-export commonly used enums
pub const JustifyContent = primitives.JustifyContent;
pub const AlignItems = primitives.AlignItems;
pub const Direction = primitives.Direction;
pub const PositionMode = primitives.PositionMode;
pub const Alignment = primitives.Alignment;

// Re-export text layout types
pub const TextLayoutEngine = text.TextLayoutEngine;
pub const LayoutOptions = text.LayoutOptions;
pub const LayoutedText = text.LayoutedText;
pub const LayoutedLine = text.LayoutedLine;
pub const LayoutedGlyph = text.LayoutedGlyph;
pub const TextAlign = text.TextAlign;