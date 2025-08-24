const std = @import("std");
const c = @import("../platform/sdl.zig");
const colors = @import("../core/colors.zig");
const ttf_parser = @import("core/ttf_parser.zig");
const font_config = @import("config.zig");
const loggers = @import("../debug/loggers.zig");
const strategy_interface = @import("strategies/interface.zig");
const core_types = @import("core/types.zig");

// Re-export strategy interfaces for backward compatibility
pub const RenderingStrategy = strategy_interface.RenderingStrategy;
pub const SelectionCriteria = strategy_interface.SelectionCriteria;
pub const StrategyCapabilities = strategy_interface.StrategyCapabilities;

// Re-export strategy components for direct access
pub const vertex_strategy = @import("strategies/vertex/mod.zig");
pub const bitmap_strategy = @import("strategies/bitmap/mod.zig");
pub const sdf_strategy = @import("strategies/sdf/mod.zig");

// Legacy re-exports for moved components (backward compatibility)
pub const GlyphTriangulator = vertex_strategy.GlyphTriangulator;
pub const GlyphVertexBuilder = vertex_strategy.GlyphVertexBuilder;
pub const FontAtlas = bitmap_strategy.FontAtlas;
pub const RasterizedGlyph = bitmap_strategy.RasterizedGlyph;

/// Enhanced loaded font structure supporting both buffer and bitmap rendering
pub const LoadedFont = struct {
    id: u32,
    path: []const u8,
    data: []u8,
    parser: *ttf_parser.TTFParser,

    // Bitmap strategy components (initialized on demand)
    bitmap_atlas: ?*bitmap_strategy.FontAtlas,
    bitmap_rasterizer: ?*bitmap_strategy.rasterizer.RasterizerCore,
};

/// Enhanced Font Manager - TTF parsing with bitmap strategy support
pub const FontManager = struct {
    allocator: std.mem.Allocator,
    settings: font_config.FontSettings,
    loaded_fonts: std.ArrayList(LoadedFont),
    next_font_id: u32,
    gpu_device: ?*c.sdl.SDL_GPUDevice, // For bitmap atlas creation

    pub fn init(allocator: std.mem.Allocator) !FontManager {
        return FontManager{
            .allocator = allocator,
            .settings = font_config.FontSettings{},
            .loaded_fonts = std.ArrayList(LoadedFont).init(allocator),
            .next_font_id = 1,
            .gpu_device = null,
        };
    }

    /// Set GPU device for bitmap atlas creation (optional)
    pub fn setGPUDevice(self: *FontManager, device: *c.sdl.SDL_GPUDevice) void {
        self.gpu_device = device;
    }

    pub fn deinit(self: *FontManager) void {
        for (self.loaded_fonts.items) |*font| {
            // Clean up bitmap strategy components if they exist
            if (font.bitmap_atlas) |atlas| {
                atlas.deinit();
                self.allocator.destroy(atlas);
            }
            if (font.bitmap_rasterizer) |rasterizer| {
                // RasterizerCore doesn't have a deinit method - just free the allocation
                self.allocator.destroy(rasterizer);
            }

            font.parser.deinit();
            self.allocator.destroy(font.parser);
            self.allocator.free(font.data);
        }
        self.loaded_fonts.deinit();
    }

    /// Load a font for buffer-based rendering (no rasterization, size parameter ignored)
    pub fn loadFont(self: *FontManager, category: font_config.FontCategory, size: f32) !u32 {
        const font_log = loggers.getFontLog();
        font_log.info("load_font", "Loading font for category: {} size: {d}", .{ category, size });

        const family_name = switch (category) {
            .mono => self.settings.mono_family,
            .sans => self.settings.sans_family,
            .serif_display => self.settings.serif_display_family,
            .serif_text => self.settings.serif_text_family,
        };

        font_log.info("load_font", "Looking for font family: {s}", .{family_name});

        const weight = switch (category) {
            .mono => self.settings.mono_weight,
            .sans => self.settings.sans_weight,
            .serif_display => self.settings.serif_display_weight,
            .serif_text => self.settings.serif_text_weight,
        };

        const italic = switch (category) {
            .mono => self.settings.mono_italic,
            .sans => self.settings.sans_italic,
            .serif_display => self.settings.serif_display_italic,
            .serif_text => self.settings.serif_text_italic,
        };

        var font_family: ?font_config.FontFamily = null;
        for (font_config.available_fonts) |family| {
            if (std.mem.eql(u8, family.name, family_name)) {
                font_family = family;
                break;
            }
        }

        if (font_family == null) {
            const error_log = loggers.getFontLog();
            error_log.err("buffer_font_manager", "Font family not found: {s}", .{family_name});
            return error.FontFamilyNotFound;
        }

        var best_variant: ?font_config.FontVariant = null;
        var best_score: i32 = std.math.maxInt(i32);

        for (font_family.?.variants) |variant| {
            const weight_diff: i32 = @intCast(@abs(variant.weight - weight));
            const italic_match: i32 = if (variant.italic == italic) 0 else 1000;
            const score = weight_diff + italic_match;

            if (score < best_score) {
                best_score = score;
                best_variant = variant;
            }
        }

        if (best_variant == null) {
            return error.FontVariantNotFound;
        }

        // Check if font is already loaded (no size-based variants needed)
        for (self.loaded_fonts.items) |font| {
            if (std.mem.eql(u8, font.path, best_variant.?.path)) {
                return font.id;
            }
        }

        // Load new font file
        const file = std.fs.cwd().openFile(best_variant.?.path, .{}) catch |err| {
            const file_log = loggers.getFontLog();
            file_log.err("buffer_font_manager", "Failed to open font file {s}: {}", .{ best_variant.?.path, err });
            return error.FontLoadFailed;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const data = try self.allocator.alloc(u8, file_size);
        _ = try file.read(data);

        const parser_ptr = try self.allocator.create(ttf_parser.TTFParser);
        parser_ptr.* = try ttf_parser.TTFParser.init(self.allocator, data);

        const font_id = self.next_font_id;
        self.next_font_id += 1;

        try self.loaded_fonts.append(LoadedFont{
            .id = font_id,
            .path = best_variant.?.path,
            .data = data,
            .parser = parser_ptr,
            .bitmap_atlas = null,
            .bitmap_rasterizer = null,
        });

        const success_log = loggers.getFontLog();
        success_log.info("buffer_font_manager", "Loaded font for buffer rendering: {s} (id: {})", .{ best_variant.?.path, font_id });

        return font_id;
    }

    /// Get font parser for direct access (buffer-based rendering)
    pub fn getParser(self: *FontManager, font_id: u32) ?*ttf_parser.TTFParser {
        for (self.loaded_fonts.items) |font| {
            if (font.id == font_id) {
                return font.parser;
            }
        }
        return null;
    }

    /// Basic glyph metrics structure for layout calculations
    // Use the standard GlyphMetrics from core types
    pub const GlyphMetrics = core_types.GlyphMetrics;

    /// Get basic glyph metrics without rasterization (for layout calculations)
    pub fn getBasicGlyphMetrics(self: *FontManager, font_id: u32, codepoint: u32) ?GlyphMetrics {
        if (self.getParser(font_id)) |parser| {
            const glyph_id = parser.getGlyphIndex(codepoint) catch return null;
            const metrics = parser.getGlyphMetrics(glyph_id) catch return null;
            return GlyphMetrics{
                .advance_width = @floatFromInt(metrics.advance_width),
                .left_side_bearing = @floatFromInt(metrics.left_side_bearing),
            };
        }
        return null;
    }

    /// Get kerning adjustment between two characters
    pub fn getKerning(self: *FontManager, font_id: u32, left_codepoint: u32, right_codepoint: u32, scale: f32) f32 {
        if (self.getParser(font_id)) |parser| {
            const left_glyph = parser.getGlyphIndex(left_codepoint) catch return 0.0;
            const right_glyph = parser.getGlyphIndex(right_codepoint) catch return 0.0;
            const kern_value = parser.getKerning(@intCast(left_glyph), @intCast(right_glyph));
            return @as(f32, @floatFromInt(kern_value)) * scale;
        }
        return 0.0;
    }

    // Strategy Selection Methods

    /// Select the optimal rendering strategy for given font size and text type
    pub fn selectRenderingStrategy(self: *FontManager, font_size: f32, text_type: strategy_interface.SelectionCriteria.TextType) strategy_interface.RenderingStrategy {
        _ = self; // FontManager doesn't affect strategy selection currently

        const criteria = strategy_interface.SelectionCriteria{
            .font_size = font_size,
            .text_type = text_type,
            .performance_priority = .balanced,
            .effects_needed = false,
        };

        return strategy_interface.selectStrategy(criteria);
    }

    /// Select rendering strategy with custom criteria
    pub fn selectRenderingStrategyWithCriteria(self: *FontManager, criteria: strategy_interface.SelectionCriteria) strategy_interface.RenderingStrategy {
        _ = self;
        return strategy_interface.selectStrategy(criteria);
    }

    /// Check if a strategy is suitable for given requirements
    pub fn isStrategySuitable(self: *FontManager, strategy: strategy_interface.RenderingStrategy, font_size: f32, text_type: strategy_interface.SelectionCriteria.TextType) bool {
        _ = self;

        const criteria = strategy_interface.SelectionCriteria{
            .font_size = font_size,
            .text_type = text_type,
        };

        return strategy_interface.isStrategySuitable(strategy, criteria);
    }

    /// Get strategy capabilities
    pub fn getStrategyCapabilities(self: *FontManager, strategy: strategy_interface.RenderingStrategy) strategy_interface.StrategyCapabilities {
        _ = self;
        return strategy_interface.getCapabilities(strategy);
    }

    /// Get fallback strategy chain
    pub fn getFallbackStrategies(self: *FontManager, primary_strategy: strategy_interface.RenderingStrategy) []const strategy_interface.RenderingStrategy {
        _ = self;
        return strategy_interface.getFallbackChain(primary_strategy);
    }

    // Additional Methods for Text Integration

    /// Get glyph advance width scaled to font size
    pub fn getGlyphAdvance(self: *FontManager, font_id: u32, codepoint: u32, font_size: f32) !f32 {
        if (self.getBasicGlyphMetrics(font_id, codepoint)) |metrics| {
            // Get parser to calculate scale
            if (self.getParser(font_id)) |parser| {
                const units_per_em = if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0;
                const scale = font_size / units_per_em;
                return @as(f32, @floatFromInt(metrics.advance_width)) * scale;
            }
        }
        return error.FontNotFound;
    }

    /// Get font metrics for the given font
    pub fn getFontMetrics(self: *FontManager, font_id: u32) !struct {
        ascender: i16,
        descender: i16,
        line_gap: i16,
    } {
        if (self.getParser(font_id)) |parser| {
            if (parser.hhea) |hhea| {
                return .{
                    .ascender = hhea.ascender,
                    .descender = hhea.descender,
                    .line_gap = hhea.line_gap,
                };
            }
        }
        return error.FontNotFound;
    }

    /// Get or create bitmap atlas for the font
    pub fn getBitmapAtlas(self: *FontManager, font_id: u32) !*bitmap_strategy.FontAtlas {
        for (self.loaded_fonts.items) |*font| {
            if (font.id == font_id) {
                if (font.bitmap_atlas == null) {
                    if (self.gpu_device) |device| {
                        const atlas_ptr = try self.allocator.create(bitmap_strategy.FontAtlas);
                        atlas_ptr.* = try bitmap_strategy.FontAtlas.init(self.allocator, device, 2048);
                        font.bitmap_atlas = atlas_ptr;
                    } else {
                        return error.GPUDeviceNotSet;
                    }
                }
                return font.bitmap_atlas.?;
            }
        }
        return error.FontNotFound;
    }

    /// Get or create bitmap rasterizer for the font
    pub fn getBitmapRasterizer(self: *FontManager, font_id: u32) !*bitmap_strategy.rasterizer.RasterizerCore {
        for (self.loaded_fonts.items) |*font| {
            if (font.id == font_id) {
                if (font.bitmap_rasterizer == null) {
                    const rasterizer_ptr = try self.allocator.create(bitmap_strategy.rasterizer.RasterizerCore);
                    // RasterizerCore.init needs: allocator, parser, point_size, dpi
                    const default_point_size = 16.0; // Default size for initialization
                    const default_dpi = 96.0; // Standard DPI
                    rasterizer_ptr.* = bitmap_strategy.rasterizer.RasterizerCore.init(self.allocator, font.parser, default_point_size, default_dpi);
                    font.bitmap_rasterizer = rasterizer_ptr;
                }
                return font.bitmap_rasterizer.?;
            }
        }
        return error.FontNotFound;
    }
};
