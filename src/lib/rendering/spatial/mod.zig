/// Spatial coordinate and transformation system
///
/// This module provides unified coordinate transformations, viewport management,
/// and spatial queries for the rendering system.
///
/// ## Architecture
/// - transforms.zig: Screen/world/NDC coordinate conversions
/// - viewport.zig: Unified viewport using math.Bounds
/// - visibility.zig: Culling and visibility queries
/// - grid.zig: Spatial partitioning for optimization

// Core spatial types and functions
pub const transforms = @import("transforms.zig");
pub const viewport = @import("viewport.zig");
pub const visibility = @import("visibility.zig");
pub const grid = @import("grid.zig");
pub const culling = @import("culling.zig");

// Re-export commonly used types
pub const CoordinateSpace = transforms.CoordinateSpace;
pub const CoordinateContext = transforms.CoordinateContext;
pub const Viewport = viewport.Viewport;
pub const GridCoordinates = grid.GridCoordinates;

// Re-export commonly used functions
pub const worldToScreen = transforms.worldToScreen;
pub const screenToWorld = transforms.screenToWorld;
pub const screenToNDC = transforms.screenToNDC;
pub const ndcToScreen = transforms.ndcToScreen;
pub const isPointVisible = visibility.isPointVisible;
pub const isCircleVisible = visibility.isCircleVisible;
pub const isRectVisible = visibility.isRectVisible;

// Re-export culling utilities
pub const Culler = culling.Culler;
pub const EntityCuller = culling.EntityCuller;
pub const DistanceCuller = culling.DistanceCuller;
pub const LODCuller = culling.LODCuller;
pub const CullingStats = culling.CullingStats;
