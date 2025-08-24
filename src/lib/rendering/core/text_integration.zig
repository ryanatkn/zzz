// Buffer-based Text Integration - coordinates between text domain and GPU rendering
// Replaces texture-based text integration with pure buffer approach

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const font_manager = @import("../../font/manager.zig");
const text_renderer = @import("../../text/renderer.zig");
const font_config = @import("../../font/config.zig");
const loggers = @import("../../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const FontManager = font_manager.FontManager;
const TextRenderer = text_renderer.TextRenderer;

/// Buffer-based text integration - bridges text requests with GPU buffer rendering
pub const TextIntegration = struct {
    allocator: std.mem.Allocator,
    font_manager: *FontManager,
    text_renderer: TextRenderer,

    // Simple queue for batched text rendering
    text_queue: std.ArrayList(QueuedText),

    const QueuedText = struct {
        text: []const u8,
        position: Vec2,
        font_category: font_config.FontCategory,
        font_size: f32,
        color: Color,
    };

    pub fn init(allocator: std.mem.Allocator, font_mgr: *FontManager) TextIntegration {
        return TextIntegration{
            .allocator = allocator,
            .font_manager = font_mgr,
            .text_renderer = TextRenderer.init(allocator, font_mgr),
            .text_queue = std.ArrayList(QueuedText).init(allocator),
        };
    }

    pub fn deinit(self: *TextIntegration) void {
        // Clean up queued text strings
        for (self.text_queue.items) |queued| {
            self.allocator.free(queued.text);
        }
        self.text_queue.deinit();
        self.text_renderer.deinit(null); // TODO: Pass GPU device when available
    }

    /// Queue text for persistent rendering (compatible with old API)
    pub fn queuePersistentText(
        self: *TextIntegration,
        text: []const u8,
        position: Vec2,
        font_mgr: *FontManager,
        font_category: font_config.FontCategory,
        font_size: f32,
        color: Color,
    ) !void {
        _ = font_mgr; // We use our own font manager

        const render_log = loggers.getRenderLog();
        render_log.info("text_queue", "Queueing text: '{s}' at ({d}, {d})", .{ text, position.x, position.y });

        // Validate text string
        const MAX_TEXT_LENGTH = 1024; // Max 1KB per text string
        if (text.len == 0) {
            render_log.warn("text_queue", "Ignoring empty text string at ({d}, {d})", .{ position.x, position.y });
            return; // Skip empty strings
        }
        if (text.len > MAX_TEXT_LENGTH) {
            render_log.err("text_queue", "Text string too long ({d} chars): '{s}'", .{ text.len, text });
            return error.TextTooLong;
        }

        // Load font for the given category and size
        render_log.info("text_queue", "Queueing text: '{s}' at size {d:.1}px", .{ text, font_size });

        // Copy the text string (since it might be temporary)
        const owned_text = try self.allocator.dupe(u8, text);

        // Add to queue
        try self.text_queue.append(QueuedText{
            .text = owned_text,
            .position = position,
            .font_category = font_category,
            .font_size = font_size,
            .color = color,
        });
    }

    /// Render all queued text using buffer approach
    pub fn drawQueuedText(
        self: *TextIntegration,
        gpu_renderer: anytype, // Duck typing - any renderer with drawGlyph method
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
    ) !void {
        const render_log = loggers.getRenderLog();
        render_log.info("text_draw_debug", "Drawing {} queued text items", .{self.text_queue.items.len});

        for (self.text_queue.items, 0..) |queued, i| {
            render_log.info("text_draw_item", "Drawing item {}: '{s}' at ({d}, {d})", .{ i, queued.text, queued.position.x, queued.position.y });
            try self.text_renderer.renderText(
                gpu_renderer,
                cmd_buffer,
                render_pass,
                queued.text,
                queued.position,
                queued.font_category,
                queued.font_size,
                queued.color,
            );
        }

        // Clear queue after rendering
        for (self.text_queue.items) |queued| {
            self.allocator.free(queued.text);
        }
        self.text_queue.clearRetainingCapacity();
    }

    /// Render a single string immediately (no queueing)
    pub fn renderStringImmediate(
        self: *TextIntegration,
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        text: []const u8,
        position: Vec2,
        font_category: font_config.FontCategory,
        font_size: f32,
        color: Color,
    ) !void {
        try self.text_renderer.renderText(
            gpu_renderer,
            cmd_buffer,
            render_pass,
            text,
            position,
            font_category,
            font_size,
            color,
        );
    }

    /// Calculate string width for layout purposes
    pub fn getStringWidth(
        self: *TextIntegration,
        text: []const u8,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !f32 {
        // Use text renderer to measure text width
        var total_width: f32 = 0.0;

        // Load font for measurements
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        var prev_char: ?u8 = null;
        for (text) |char| {
            // Skip non-printable characters except space
            if (char < 32 or char > 126) {
                if (char == ' ') {
                    // Handle space by advancing position (typical advance width)
                    total_width += font_size * 0.5; // Rough space width
                    prev_char = char;
                }
                continue;
            }

            // Apply kerning adjustment if we have a previous character
            if (prev_char) |prev| {
                if (prev >= 32 and prev <= 126) { // Only apply kerning between printable chars
                    const parser = self.font_manager.getParser(font_id);
                    const units_per_em = if (parser) |p|
                        if (p.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                    else
                        1000.0;
                    const scale = font_size / units_per_em;
                    const kern_adjustment = self.font_manager.getKerning(font_id, prev, char, scale);
                    total_width += kern_adjustment;
                }
            }

            // Get character advance width
            const char_advance = self.font_manager.getGlyphAdvance(font_id, char, font_size) catch font_size * 0.6;
            total_width += char_advance;
            prev_char = char;
        }

        return total_width;
    }

    /// Get text height for layout purposes
    pub fn getStringHeight(
        self: *TextIntegration,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !f32 {
        // Load font for measurements
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        // Get font metrics
        const metrics = self.font_manager.getFontMetrics(font_id) catch {
            // Fallback to font size if metrics unavailable
            return font_size;
        };

        // Calculate total height from ascent + descent
        const parser = self.font_manager.getParser(font_id);
        const units_per_em = if (parser) |p|
            if (p.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
        else
            1000.0;
        const scale = font_size / units_per_em;

        const ascent = @as(f32, @floatFromInt(metrics.ascender)) * scale;
        const descent = @as(f32, @floatFromInt(-metrics.descender)) * scale; // Descender is negative

        return ascent + descent;
    }
};
