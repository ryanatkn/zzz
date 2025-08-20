const std = @import("std");
const persistent_text = @import("../text/cache.zig");
const text_renderer = @import("../text/renderer.zig");
const Vec2 = @import("../math/vec2.zig").Vec2;
const Color = @import("../core/colors.zig").Color;
const loggers = @import("../debug/loggers.zig");

/// Rendering Mode Guidelines for the Zzz Game Engine
///
/// This module provides clear guidance on when to use immediate mode vs persistent mode
/// rendering, with helper functions to make the right choice easy for developers.
/// Rendering modes available in the engine
pub const RenderingMode = enum {
    /// IMMEDIATE MODE - Create, use, destroy each frame
    /// - Textures are created fresh each frame
    /// - Textures are immediately released after drawing
    /// - Higher GPU memory allocation/deallocation overhead
    /// - Use for content that changes constantly
    immediate,

    /// PERSISTENT MODE - Create once, reuse until changed
    /// - Textures are cached and reused across frames
    /// - Textures are only recreated when content changes
    /// - Lower overhead for stable content
    /// - Use for content that changes occasionally
    persistent,
};

/// Content change frequency categories
pub const ChangeFrequency = enum {
    /// Changes multiple times per frame (>60 fps)
    /// Example: Mouse position, particle counts
    per_frame,

    /// Changes several times per second (1-60 fps)
    /// Example: Health bars during combat, timer countdown
    frequent,

    /// Changes occasionally (once per few seconds)
    /// Example: FPS counter, current weapon, score
    occasional,

    /// Changes rarely (user actions, scene changes)
    /// Example: Menu labels, player name, settings
    rare,

    /// Static content that never or almost never changes
    /// Example: Title text, fixed UI labels
    static,
};

/// Performance characteristics for different content types
pub const PerformanceProfile = struct {
    recommended_mode: RenderingMode,
    memory_impact: MemoryImpact,
    cpu_overhead: CpuOverhead,
    reasoning: []const u8,
};

pub const MemoryImpact = enum { low, medium, high };
pub const CpuOverhead = enum { low, medium, high };

/// Get recommended rendering mode based on change frequency
pub fn recommendModeByFrequency(frequency: ChangeFrequency) PerformanceProfile {
    return switch (frequency) {
        .per_frame => .{
            .recommended_mode = .immediate,
            .memory_impact = .low,
            .cpu_overhead = .high,
            .reasoning = "Content changes too frequently for caching to be effective",
        },
        .frequent => .{
            .recommended_mode = .immediate,
            .memory_impact = .low,
            .cpu_overhead = .high,
            .reasoning = "Frequent changes would cause cache thrashing",
        },
        .occasional => .{
            .recommended_mode = .persistent,
            .memory_impact = .medium,
            .cpu_overhead = .low,
            .reasoning = "Good balance - cache hits outweigh cache maintenance overhead",
        },
        .rare => .{
            .recommended_mode = .persistent,
            .memory_impact = .medium,
            .cpu_overhead = .low,
            .reasoning = "Excellent caching efficiency for rarely changing content",
        },
        .static => .{
            .recommended_mode = .persistent,
            .memory_impact = .low,
            .cpu_overhead = .low,
            .reasoning = "Perfect for persistent caching - maximum efficiency",
        },
    };
}

/// Get recommended rendering mode based on numeric change rate
pub fn recommendModeByRate(changes_per_second: f32) PerformanceProfile {
    if (changes_per_second > 30.0) {
        return recommendModeByFrequency(.per_frame);
    } else if (changes_per_second > 5.0) {
        return recommendModeByFrequency(.frequent);
    } else if (changes_per_second > 0.5) {
        return recommendModeByFrequency(.occasional);
    } else if (changes_per_second > 0.1) {
        return recommendModeByFrequency(.rare);
    } else {
        return recommendModeByFrequency(.static);
    }
}

/// Common use cases with specific recommendations
pub const UseCases = struct {
    pub const fps_counter = PerformanceProfile{
        .recommended_mode = .persistent,
        .memory_impact = .low,
        .cpu_overhead = .low,
        .reasoning = "FPS typically changes 1-3 times per second, perfect for caching",
    };

    pub const menu_labels = PerformanceProfile{
        .recommended_mode = .persistent,
        .memory_impact = .low,
        .cpu_overhead = .low,
        .reasoning = "Menu text is static, cache once and reuse",
    };

    pub const health_bar = PerformanceProfile{
        .recommended_mode = .immediate,
        .memory_impact = .low,
        .cpu_overhead = .medium,
        .reasoning = "Health changes frequently during combat, caching ineffective",
    };

    pub const particle_count = PerformanceProfile{
        .recommended_mode = .immediate,
        .memory_impact = .low,
        .cpu_overhead = .high,
        .reasoning = "Changes every frame, immediate mode only viable option",
    };

    pub const ui_buttons = PerformanceProfile{
        .recommended_mode = .persistent,
        .memory_impact = .medium,
        .cpu_overhead = .low,
        .reasoning = "Button text is static, hover states can be handled separately",
    };

    pub const debug_info = PerformanceProfile{
        .recommended_mode = .immediate,
        .memory_impact = .low,
        .cpu_overhead = .high,
        .reasoning = "Debug values change frequently, not worth caching",
    };

    pub const score_display = PerformanceProfile{
        .recommended_mode = .persistent,
        .memory_impact = .low,
        .cpu_overhead = .low,
        .reasoning = "Score changes occasionally, good candidate for caching",
    };
};

/// Helper functions for common rendering patterns
/// Render text using the recommended mode based on change frequency
/// FontManager and FontCategory types are constrained to have the required methods
pub fn renderTextWithAutoMode(comptime FontManager: type, comptime FontCategory: type, renderer: *text_renderer.TextRenderer, text: []const u8, position: Vec2, font_manager: *FontManager, font_category: FontCategory, font_size: f32, color: Color, changes_per_second: f32) !void {
    const profile = recommendModeByRate(changes_per_second);

    switch (profile.recommended_mode) {
        .immediate => {
            // Create texture immediately and queue for this frame
            const text_result = try font_manager.renderTextToTexture(text, font_category, font_size, color, renderer.device);
            renderer.queueTextTexture(text_result.texture, position, text_result.width, text_result.height, color);
        },
        .persistent => {
            // Use persistent text system
            try renderer.queuePersistentText(text, position, font_manager, font_category, font_size, color);
        },
    }
}

/// Render text with explicit mode choice
/// FontManager and FontCategory types are constrained to have the required methods
pub fn renderTextExplicitMode(comptime FontManager: type, comptime FontCategory: type, renderer: *text_renderer.TextRenderer, text: []const u8, position: Vec2, font_manager: *FontManager, font_category: FontCategory, font_size: f32, color: Color, mode: RenderingMode) !void {
    switch (mode) {
        .immediate => {
            const text_result = try font_manager.renderTextToTexture(text, font_category, font_size, color, renderer.device);
            renderer.queueTextTexture(text_result.texture, position, text_result.width, text_result.height, color);
        },
        .persistent => {
            try renderer.queuePersistentText(text, position, font_manager, font_category, font_size, color);
        },
    }
}

/// Get performance advice for a specific use case
pub fn getPerformanceAdvice(content_type: []const u8) ?PerformanceProfile {
    const content_lower = std.ascii.lowerString(content_type);

    if (std.mem.eql(u8, content_lower, "fps")) return UseCases.fps_counter;
    if (std.mem.eql(u8, content_lower, "menu")) return UseCases.menu_labels;
    if (std.mem.eql(u8, content_lower, "health")) return UseCases.health_bar;
    if (std.mem.eql(u8, content_lower, "particles")) return UseCases.particle_count;
    if (std.mem.eql(u8, content_lower, "button")) return UseCases.ui_buttons;
    if (std.mem.eql(u8, content_lower, "debug")) return UseCases.debug_info;
    if (std.mem.eql(u8, content_lower, "score")) return UseCases.score_display;

    return null;
}

/// Development helper - log recommendations for debugging
pub fn logModeRecommendation(content_type: []const u8, changes_per_second: f32) void {
    const profile = recommendModeByRate(changes_per_second);
    const render_log = loggers.getRenderLog();

    render_log.info("rendering_modes", "Rendering recommendation for '{s}':", .{content_type});
    render_log.info("rendering_modes", "  Changes per second: {d:.2}", .{changes_per_second});
    render_log.info("rendering_modes", "  Recommended mode: {s}", .{@tagName(profile.recommended_mode)});
    render_log.info("rendering_modes", "  Memory impact: {s}", .{@tagName(profile.memory_impact)});
    render_log.info("rendering_modes", "  CPU overhead: {s}", .{@tagName(profile.cpu_overhead)});
    render_log.info("rendering_modes", "  Reasoning: {s}", .{profile.reasoning});
}

/// Quick reference for developers
pub const QuickReference = struct {
    pub const immediate_mode_examples = [_][]const u8{
        "Mouse coordinates (changes every frame)",
        "Particle count displays (updates constantly)",
        "Real-time debug values (frame timing, memory usage)",
        "Health/mana bars during combat (frequent updates)",
        "Timer countdowns (changes multiple times per second)",
    };

    pub const persistent_mode_examples = [_][]const u8{
        "FPS counter (changes 1-3 times per second)",
        "Menu labels and buttons (static text)",
        "Player name and level (rarely changes)",
        "Score displays (occasional updates)",
        "UI status messages (changes on events)",
        "Settings values (user-triggered changes only)",
    };

    pub const decision_tree = [_][]const u8{
        "1. Does the text content change more than 10 times per second?",
        "   → YES: Use immediate mode",
        "   → NO: Continue to step 2",
        "",
        "2. Does the content change based on user actions or game events?",
        "   → YES: Use persistent mode (cache will be efficient)",
        "   → NO: Continue to step 3",
        "",
        "3. Is this debug/development information?",
        "   → YES: Use immediate mode (simpler, values change often)",
        "   → NO: Use persistent mode (likely static or rare changes)",
    };
};

test "rendering mode recommendations" {
    // Test various change frequencies
    const fps_profile = recommendModeByRate(2.0);
    try std.testing.expectEqual(RenderingMode.persistent, fps_profile.recommended_mode);

    const particle_profile = recommendModeByRate(60.0);
    try std.testing.expectEqual(RenderingMode.immediate, particle_profile.recommended_mode);

    const menu_profile = recommendModeByRate(0.01);
    try std.testing.expectEqual(RenderingMode.persistent, menu_profile.recommended_mode);
}

test "use case recommendations" {
    try std.testing.expectEqual(RenderingMode.persistent, UseCases.fps_counter.recommended_mode);
    try std.testing.expectEqual(RenderingMode.immediate, UseCases.particle_count.recommended_mode);
    try std.testing.expectEqual(RenderingMode.persistent, UseCases.menu_labels.recommended_mode);
}
