// Strategy Interface - Common interface for font rendering strategies
// Provides strategy selection, metadata, and capability information

const std = @import("std");

// Import all strategies
const vertex_strategy = @import("vertex/mod.zig");
const bitmap_strategy = @import("bitmap/mod.zig");
const sdf_strategy = @import("sdf/mod.zig");

/// Available rendering strategies
pub const RenderingStrategy = enum {
    vertex, // High-quality vertex-based rendering (2000+ vertices/glyph)
    bitmap, // Efficient bitmap atlas rendering (6 vertices + texture)
    sdf, // Scalable SDF rendering with effects (6 vertices + SDF texture)

    pub fn getName(self: RenderingStrategy) []const u8 {
        return switch (self) {
            .vertex => vertex_strategy.STRATEGY_NAME,
            .bitmap => bitmap_strategy.STRATEGY_NAME,
            .sdf => sdf_strategy.STRATEGY_NAME,
        };
    }

    pub fn getApproach(self: RenderingStrategy) []const u8 {
        return switch (self) {
            .vertex => vertex_strategy.RENDERING_APPROACH,
            .bitmap => bitmap_strategy.RENDERING_APPROACH,
            .sdf => sdf_strategy.RENDERING_APPROACH,
        };
    }

    pub fn getTypicalVerticesPerGlyph(self: RenderingStrategy) u32 {
        return switch (self) {
            .vertex => vertex_strategy.TYPICAL_VERTICES_PER_GLYPH,
            .bitmap => bitmap_strategy.TYPICAL_VERTICES_PER_GLYPH,
            .sdf => sdf_strategy.TYPICAL_VERTICES_PER_GLYPH,
        };
    }
};

/// Strategy selection criteria
pub const SelectionCriteria = struct {
    font_size: f32,
    text_type: TextType = .ui,
    performance_priority: PerformancePriority = .balanced,
    effects_needed: bool = false,

    pub const TextType = enum {
        ui, // UI labels, buttons, menus
        large_display, // Headers, titles, large text
        body_text, // Paragraphs, reading text
        debug, // Debug text, coordinates, FPS
    };

    pub const PerformancePriority = enum {
        memory, // Minimize memory usage
        speed, // Maximize render speed
        quality, // Maximize visual quality
        balanced, // Balance of all factors
    };
};

/// Strategy capabilities and performance characteristics
pub const StrategyCapabilities = struct {
    min_font_size: f32,
    max_font_size: f32,
    scalable: bool,
    supports_effects: bool,
    memory_efficient: bool,
    render_speed: RenderSpeed,
    quality_level: QualityLevel,

    pub const RenderSpeed = enum { slow, medium, fast };
    pub const QualityLevel = enum { good, better, best };
};

/// Get capabilities for a rendering strategy
pub fn getCapabilities(strategy: RenderingStrategy) StrategyCapabilities {
    return switch (strategy) {
        .vertex => StrategyCapabilities{
            .min_font_size = vertex_strategy.MIN_FONT_SIZE,
            .max_font_size = std.math.inf(f32),
            .scalable = true,
            .supports_effects = false,
            .memory_efficient = false,
            .render_speed = .slow,
            .quality_level = .best,
        },
        .bitmap => StrategyCapabilities{
            .min_font_size = 8.0,
            .max_font_size = bitmap_strategy.MAX_FONT_SIZE,
            .scalable = false,
            .supports_effects = false,
            .memory_efficient = true,
            .render_speed = .fast,
            .quality_level = .good,
        },
        .sdf => StrategyCapabilities{
            .min_font_size = sdf_strategy.OPTIMAL_FONT_SIZE_RANGE.min,
            .max_font_size = sdf_strategy.OPTIMAL_FONT_SIZE_RANGE.max,
            .scalable = true,
            .supports_effects = true,
            .memory_efficient = true,
            .render_speed = .medium,
            .quality_level = .better,
        },
    };
}

/// Select the best rendering strategy for given criteria
pub fn selectStrategy(criteria: SelectionCriteria) RenderingStrategy {
    // Strategy selection logic based on criteria

    // Large text or quality priority -> vertex strategy
    if (criteria.font_size >= 24.0 or criteria.performance_priority == .quality) {
        if (criteria.text_type == .large_display) {
            return .vertex;
        }
    }

    // Effects needed -> SDF strategy
    if (criteria.effects_needed) {
        return .sdf;
    }

    // Small text or memory priority -> bitmap strategy
    if (criteria.font_size <= 16.0 or criteria.performance_priority == .memory) {
        if (criteria.text_type == .ui or criteria.text_type == .debug) {
            return .bitmap;
        }
    }

    // Medium size text or speed priority -> SDF strategy
    if (criteria.font_size >= 14.0 and criteria.font_size <= 32.0) {
        if (criteria.performance_priority == .speed or criteria.performance_priority == .balanced) {
            return .sdf;
        }
    }

    // Default fallback based on font size
    if (criteria.font_size >= 24.0) return .vertex;
    if (criteria.font_size <= 16.0) return .bitmap;
    return .sdf;
}

/// Get fallback strategy chain for a primary strategy
pub fn getFallbackChain(primary: RenderingStrategy) []const RenderingStrategy {
    return switch (primary) {
        .vertex => &[_]RenderingStrategy{ .sdf, .bitmap },
        .bitmap => &[_]RenderingStrategy{ .sdf, .vertex },
        .sdf => &[_]RenderingStrategy{ .bitmap, .vertex },
    };
}

/// Utility functions for strategy management
pub fn isStrategySuitable(strategy: RenderingStrategy, criteria: SelectionCriteria) bool {
    const caps = getCapabilities(strategy);

    // Check font size range
    if (criteria.font_size < caps.min_font_size or criteria.font_size > caps.max_font_size) {
        return false;
    }

    // Check effects requirement
    if (criteria.effects_needed and !caps.supports_effects) {
        return false;
    }

    return true;
}

/// Compare two strategies for given criteria (returns better strategy)
pub fn compareStrategies(a: RenderingStrategy, b: RenderingStrategy, criteria: SelectionCriteria) RenderingStrategy {
    const caps_a = getCapabilities(a);
    const caps_b = getCapabilities(b);

    return switch (criteria.performance_priority) {
        .quality => if (caps_a.quality_level == .best) a else (if (caps_b.quality_level == .best) b else a),
        .speed => if (caps_a.render_speed == .fast) a else (if (caps_b.render_speed == .fast) b else a),
        .memory => if (caps_a.memory_efficient) a else (if (caps_b.memory_efficient) b else a),
        .balanced => selectStrategy(criteria), // Use main selection logic
    };
}
