/// Layout Arrangement System
///
/// This module provides algorithms for arranging elements within containers:
/// - Flow: Block flow, inline flow, and floating algorithms
/// - Alignment: Content alignment, baseline alignment, and distribution
/// - Stacking: Z-index management and stacking context handling
///
/// These algorithms determine the final positions and rendering order of
/// elements after their sizes have been calculated by layout engines.
pub const flow = @import("flow.zig");
pub const alignment = @import("alignment.zig");
pub const stacking = @import("stacking.zig");

// Re-export commonly used flow types
pub const BlockFlow = flow.BlockFlow;
pub const InlineFlow = flow.InlineFlow;
pub const FloatLayout = flow.FloatLayout;
pub const FloatDirection = flow.FloatLayout.FloatDirection;
pub const FloatInfo = flow.FloatLayout.FloatInfo;
pub const FloatArea = flow.FloatLayout.FloatArea;
pub const LineInfo = flow.InlineFlow.LineInfo;

// Re-export alignment types
pub const ContentAlignment = alignment.ContentAlignment;
pub const BaselineAlignment = alignment.BaselineAlignment;
pub const GridAlignment = alignment.GridAlignment;
pub const Distribution = alignment.Distribution;

// Re-export stacking types
pub const StackingManager = stacking.StackingManager;
pub const StackingContext = stacking.StackingContext;
pub const StackingInfo = stacking.StackingInfo;
pub const StackingContextType = stacking.StackingContextType;
pub const ZIndex = stacking.ZIndex;
pub const ZIndexSorting = stacking.ZIndexSorting;
pub const LayerManager = stacking.LayerManager;

// Re-export commonly used constants
pub const AUTO_Z_INDEX = stacking.AUTO_Z_INDEX;
pub const NEGATIVE_Z_INDEX = stacking.NEGATIVE_Z_INDEX;
pub const POSITIVE_Z_INDEX = stacking.POSITIVE_Z_INDEX;
