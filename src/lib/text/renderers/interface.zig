// Text Renderer Interface - common interface for all text rendering strategies
// Ensures consistent API across vertex, bitmap, and SDF renderers

const std = @import("std");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const font_config = @import("../../font/config.zig");
const strategy_interface = @import("../../font/strategies/interface.zig");
const c = @import("../../platform/sdl.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const RenderingStrategy = strategy_interface.RenderingStrategy;

/// Common interface that all text renderers must implement
pub const TextRendererInterface = struct {
    /// Render a single glyph at the specified position
    renderGlyphFn: *const fn (
        ctx: *anyopaque,
        gpu_renderer: anytype,
        character: u32,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) anyerror!void,

    /// Render a string of text at the specified position
    renderTextFn: *const fn (
        ctx: *anyopaque,
        gpu_renderer: anytype,
        text: []const u8,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) anyerror!Vec2,

    /// Get the rendering strategy used by this renderer
    getStrategyFn: *const fn (ctx: *anyopaque) RenderingStrategy,

    /// Set rendering configuration or strategy
    setStrategyFn: *const fn (ctx: *anyopaque, strategy: RenderingStrategy) void,

    /// Clean up renderer resources
    deinitFn: *const fn (ctx: *anyopaque) void,

    /// Opaque pointer to the actual renderer implementation
    context: *anyopaque,

    /// Render a single glyph
    pub fn renderGlyph(
        self: *const TextRendererInterface,
        gpu_renderer: anytype,
        character: u32,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) !void {
        return self.renderGlyphFn(self.context, gpu_renderer, character, position, font_size, color);
    }

    /// Render text string
    pub fn renderText(
        self: *const TextRendererInterface,
        gpu_renderer: anytype,
        text: []const u8,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) !Vec2 {
        return self.renderTextFn(self.context, gpu_renderer, text, position, font_size, color);
    }

    /// Get the strategy used by this renderer
    pub fn getStrategy(self: *const TextRendererInterface) RenderingStrategy {
        return self.getStrategyFn(self.context);
    }

    /// Set the strategy for this renderer
    pub fn setStrategy(self: *const TextRendererInterface, strategy: RenderingStrategy) void {
        return self.setStrategyFn(self.context, strategy);
    }

    /// Clean up resources
    pub fn deinit(self: *const TextRendererInterface) void {
        return self.deinitFn(self.context);
    }
};

/// Create a text renderer interface from a vertex renderer
pub fn createVertexRendererInterface(allocator: std.mem.Allocator, renderer: anytype) !TextRendererInterface {
    const RendererType = @TypeOf(renderer.*);

    const Wrapper = struct {
        renderer: *RendererType,

        fn renderGlyph(
            ctx: *anyopaque,
            gpu_renderer: anytype,
            character: u32,
            position: Vec2,
            font_size: f32,
            color: Color,
        ) !void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            // TODO: Implement vertex renderer glyph rendering
            _ = self;
            _ = gpu_renderer;
            _ = character;
            _ = position;
            _ = font_size;
            _ = color;
        }

        fn renderText(
            ctx: *anyopaque,
            gpu_renderer: anytype,
            text: []const u8,
            position: Vec2,
            font_size: f32,
            color: Color,
        ) !Vec2 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            // TODO: Implement vertex renderer text rendering
            _ = self;
            _ = gpu_renderer;
            _ = text;
            _ = font_size;
            _ = color;
            return position;
        }

        fn getStrategy(ctx: *anyopaque) RenderingStrategy {
            _ = ctx;
            return .vertex;
        }

        fn setStrategy(ctx: *anyopaque, strategy: RenderingStrategy) void {
            _ = ctx;
            _ = strategy; // Vertex renderer only supports vertex strategy
        }

        fn deinit(ctx: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.renderer.deinit();
        }
    };

    const wrapper = try allocator.create(Wrapper);
    wrapper.* = Wrapper{ .renderer = renderer };

    return TextRendererInterface{
        .renderGlyphFn = Wrapper.renderGlyph,
        .renderTextFn = Wrapper.renderText,
        .getStrategyFn = Wrapper.getStrategy,
        .setStrategyFn = Wrapper.setStrategy,
        .deinitFn = Wrapper.deinit,
        .context = wrapper,
    };
}

/// Create a text renderer interface from a texture renderer
pub fn createTextureRendererInterface(allocator: std.mem.Allocator, renderer: anytype) !TextRendererInterface {
    const RendererType = @TypeOf(renderer.*);

    const Wrapper = struct {
        renderer: *RendererType,

        fn renderGlyph(
            ctx: *anyopaque,
            gpu_renderer: anytype,
            character: u32,
            position: Vec2,
            font_size: f32,
            color: Color,
        ) !void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.renderer.renderGlyph(gpu_renderer, character, position, font_size, color);
        }

        fn renderText(
            ctx: *anyopaque,
            gpu_renderer: anytype,
            text: []const u8,
            position: Vec2,
            font_size: f32,
            color: Color,
        ) !Vec2 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.renderer.renderText(gpu_renderer, text, position, font_size, color);
        }

        fn getStrategy(ctx: *anyopaque) RenderingStrategy {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.renderer.current_strategy;
        }

        fn setStrategy(ctx: *anyopaque, strategy: RenderingStrategy) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.renderer.setStrategy(strategy);
        }

        fn deinit(ctx: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.renderer.deinit();
        }
    };

    const wrapper = try allocator.create(Wrapper);
    wrapper.* = Wrapper{ .renderer = renderer };

    return TextRendererInterface{
        .renderGlyphFn = Wrapper.renderGlyph,
        .renderTextFn = Wrapper.renderText,
        .getStrategyFn = Wrapper.getStrategy,
        .setStrategyFn = Wrapper.setStrategy,
        .deinitFn = Wrapper.deinit,
        .context = wrapper,
    };
}

/// Renderer capabilities and metadata
pub const RendererCapabilities = struct {
    /// Strategies this renderer supports
    supported_strategies: []const RenderingStrategy,

    /// Optimal font size range
    optimal_size_range: struct {
        min: f32,
        max: f32,
    },

    /// Performance characteristics
    performance: struct {
        /// Typical vertices per glyph
        vertices_per_glyph: u32,

        /// Whether this renderer uses textures
        uses_textures: bool,

        /// Whether this renderer supports effects
        supports_effects: bool,

        /// Memory usage per glyph (bytes)
        memory_per_glyph: u32,
    },
};

/// Get capabilities for vertex renderer
pub fn getVertexRendererCapabilities() RendererCapabilities {
    return RendererCapabilities{
        .supported_strategies = &[_]RenderingStrategy{.vertex},
        .optimal_size_range = .{
            .min = 24.0,
            .max = 256.0,
        },
        .performance = .{
            .vertices_per_glyph = 2000,
            .uses_textures = false,
            .supports_effects = false,
            .memory_per_glyph = 0, // No persistent storage
        },
    };
}

/// Get capabilities for texture renderer
pub fn getTextureRendererCapabilities() RendererCapabilities {
    return RendererCapabilities{
        .supported_strategies = &[_]RenderingStrategy{ .bitmap, .sdf },
        .optimal_size_range = .{
            .min = 8.0,
            .max = 128.0,
        },
        .performance = .{
            .vertices_per_glyph = 6,
            .uses_textures = true,
            .supports_effects = true, // SDF supports effects
            .memory_per_glyph = 4096, // Typical texture memory
        },
    };
}
