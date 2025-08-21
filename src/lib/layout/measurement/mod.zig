/// Layout Measurement System
///
/// This module provides utilities for measuring content and calculating
/// intrinsic sizes for layout elements:
/// - Constraints: Constraint resolution and validation
/// - Intrinsic: Intrinsic size calculation based on content
/// - Content: Content measurement for different content types
///
/// These utilities help layout engines determine the natural sizes of
/// elements before applying layout algorithms.
pub const constraints = @import("constraints.zig");
pub const intrinsic = @import("intrinsic.zig");
pub const content = @import("content.zig");

// Re-export commonly used types
pub const ConstraintResolver = constraints.ConstraintResolver;
pub const AspectRatioConstraints = constraints.AspectRatioConstraints;
pub const ContentConstraints = constraints.ContentConstraints;
pub const ConstraintValidator = constraints.ConstraintValidator;

pub const IntrinsicSizing = intrinsic.IntrinsicSizing;
pub const ContentSizing = intrinsic.ContentSizing;
pub const ChildBasedSizing = intrinsic.ChildBasedSizing;
pub const FlexIntrinsicSizing = intrinsic.FlexIntrinsicSizing;

pub const ContentMeasurer = content.ContentMeasurer;
pub const ContentType = content.ContentType;
pub const ContentInfo = content.ContentInfo;
pub const ContentMeasurement = content.ContentMeasurement;
pub const CachedContentMeasurer = content.CachedContentMeasurer;

// Re-export utility functions
pub const estimateTextSize = content.estimateTextSize;
