const std = @import("std");
const types = @import("../types.zig");
const reactive = @import("../reactive.zig");
const component = @import("component.zig");
const text_renderer = @import("../text_renderer.zig");
const fonts = @import("../fonts.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;

/// Text alignment options
pub const TextAlign = enum {
    left,
    center,
    right,
};

/// Text styling options
pub const TextStyle = struct {
    font_size: f32 = 14.0,
    font_category: fonts.FontCategory = .sans,
    color: Color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, // White by default
    align: TextAlign = .left,
    
    // Remove debug colors that cause yellow flashing
    const NORMAL_COLOR = Color{ .r = 255, .g = 255, .b = 255, .a = 255 }; // White
    const HOVER_COLOR = Color{ .r = 200, .g = 200, .b = 255, .a = 255 }; // Light blue
    const DISABLED_COLOR = Color{ .r = 128, .g = 128, .b = 128, .a = 255 }; // Gray
    
    pub fn getDisplayColor(self: *const TextStyle, hovered: bool, enabled: bool) Color {
        if (!enabled) return DISABLED_COLOR;
        if (hovered) return HOVER_COLOR;
        return self.color;
    }
};

/// Unified text component that handles all text rendering
pub const Text = struct {
    base: Component,
    
    // Text properties (reactive)
    content: reactive.Signal([]const u8),
    style: reactive.Signal(TextStyle),
    
    // Cached text rendering data
    cached_texture: ?*anyopaque = null, // GPU texture from text_renderer
    cached_content: []const u8 = "",
    cached_style: TextStyle = TextStyle{},
    cache_valid: bool = false,
    
    // Text measurement cache
    measured_size: Vec2 = Vec2{ .x = 0, .y = 0 },
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        const text: *Text = @fieldParentPtr("base", self);
        
        // Initialize text-specific signals
        text.content = try reactive.signal(allocator, []const u8, "");
        text.style = try reactive.signal(allocator, TextStyle, TextStyle{});
        
        // Set up automatic cache invalidation when content or style changes
        const InvalidateCacheContext = struct {
            text_ptr: *Text,
            
            fn invalidate(context: @This()) void {
                context.text_ptr.cache_valid = false;
            }
        };
        
        const cache_context = InvalidateCacheContext{ .text_ptr = text };
        
        // Create effects to invalidate cache when properties change
        _ = try reactive.createEffect(allocator, cache_context.invalidate);
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        const text: *Text = @fieldParentPtr("base", self);
        
        // Cleanup text-specific signals
        text.content.deinit();
        text.style.deinit();
        
        // Cleanup cached texture if it exists
        if (text.cached_texture) |texture| {
            // Note: Texture cleanup handled by text_renderer system
            _ = texture;
        }
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = dt;
        const text: *Text = @fieldParentPtr("base", self);
        
        // Update text cache if needed
        text.updateCache();
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const text: *const Text = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const content = text.content.get();
        if (content.len == 0) return;
        
        const style = text.style.get();
        const position = self.props.position.get();
        const hovered = self.props.hovered.get();
        const enabled = self.props.enabled.get();
        
        // Get appropriate color (no more debug yellow!)
        const display_color = style.getDisplayColor(hovered, enabled);
        
        // Use unified text rendering system
        if (@hasDecl(@TypeOf(renderer), "drawText")) {
            // Modern renderer with unified text system
            try renderer.drawText(content, position, style.font_size, display_color, style.font_category);
        } else if (@hasDecl(@TypeOf(renderer), "queueTextTexture")) {
            // Legacy renderer - queue for text_renderer system
            try text.renderWithTextRenderer(renderer, content, position, display_color, style);
        } else {
            // Fallback to geometric text (should be rare)
            try text.renderGeometric(renderer, content, position, display_color);
        }
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        _ = self;
        _ = event;
        // Text components typically don't handle events directly
        return false;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const text: *Text = @fieldParentPtr("base", self);
        allocator.destroy(text);
    }
    
    /// Update the text cache if content or style has changed
    fn updateCache(self: *Text) void {
        const current_content = self.content.get();
        const current_style = self.style.get();
        
        // Check if cache needs updating
        if (self.cache_valid and 
            std.mem.eql(u8, self.cached_content, current_content) and
            std.meta.eql(self.cached_style, current_style)) {
            return; // Cache is still valid
        }
        
        // Cache is invalid, update it
        self.cached_content = current_content;
        self.cached_style = current_style;
        
        // Estimate text size for layout purposes
        self.measured_size = self.estimateTextSize(current_content, current_style);
        
        // Update component size to match text
        self.base.props.size.set(self.measured_size);
        
        self.cache_valid = true;
    }
    
    /// Estimate text size for layout calculations
    fn estimateTextSize(self: *Text, content: []const u8, style: TextStyle) Vec2 {
        _ = self;
        
        // Simple estimation based on character count and font size
        // In a more sophisticated system, this would query the actual font metrics
        const char_width = style.font_size * 0.6; // Rough approximation
        const char_height = style.font_size * 1.2; // Include line height
        
        return Vec2{
            .x = @as(f32, @floatFromInt(content.len)) * char_width,
            .y = char_height,
        };
    }
    
    /// Render using the text_renderer system (TTF fonts)
    fn renderWithTextRenderer(
        self: *const Text, 
        renderer: anytype, 
        content: []const u8, 
        position: Vec2, 
        color: Color, 
        style: TextStyle
    ) !void {
        // Use the existing text_renderer system
        if (@hasDecl(@TypeOf(renderer), "font_manager")) {
            if (renderer.font_manager) |fm| {
                const text_result = fm.renderTextToTexture(
                    content, 
                    style.font_category, 
                    style.font_size, 
                    color, 
                    renderer.device
                ) catch {
                    // Fallback to geometric if TTF fails
                    try self.renderGeometric(renderer, content, position, color);
                    return;
                };
                
                // Queue the texture for rendering (will be cleaned up by text_renderer)
                renderer.queueTextTexture(
                    text_result.texture,
                    position,
                    text_result.width,
                    text_result.height,
                    color
                );
            }
        }
    }
    
    /// Fallback geometric text rendering  
    fn renderGeometric(
        self: *const Text, 
        renderer: anytype, 
        content: []const u8, 
        position: Vec2, 
        color: Color
    ) !void {
        _ = self;
        
        // Use geometric text rendering as fallback
        if (@hasDecl(@TypeOf(renderer), "drawGeometricText")) {
            try renderer.drawGeometricText(content, position.x, position.y, color);
        }
    }
    
    /// Set the text content
    pub fn setText(self: *Text, new_content: []const u8) void {
        self.content.set(new_content);
    }
    
    /// Set the text style  
    pub fn setStyle(self: *Text, new_style: TextStyle) void {
        self.style.set(new_style);
    }
    
    /// Set font size
    pub fn setFontSize(self: *Text, size: f32) void {
        var current_style = self.style.get();
        current_style.font_size = size;
        self.style.set(current_style);
    }
    
    /// Set text color
    pub fn setColor(self: *Text, new_color: Color) void {
        var current_style = self.style.get();
        current_style.color = new_color;
        self.style.set(current_style);
    }
    
    /// Set text alignment
    pub fn setAlignment(self: *Text, alignment: TextAlign) void {
        var current_style = self.style.get();
        current_style.align = alignment;
        self.style.set(current_style);
    }
    
    /// Get the measured text size for layout calculations
    pub fn getMeasuredSize(self: *const Text) Vec2 {
        return self.measured_size;
    }
};

/// Create a new text component
pub fn createText(
    allocator: std.mem.Allocator, 
    content: []const u8, 
    position: Vec2, 
    style: TextStyle
) !*Component {
    const text = try allocator.create(Text);
    
    // Estimate initial size based on content and style
    const estimated_size = Vec2{
        .x = @as(f32, @floatFromInt(content.len)) * style.font_size * 0.6,
        .y = style.font_size * 1.2,
    };
    
    var props = try ComponentProps.init(allocator, position, estimated_size);
    
    text.* = Text{
        .base = Component{
            .vtable = Component.VTable{
                .init = Text.init,
                .deinit = Text.deinit,
                .update = Text.update,
                .render = Text.render,
                .handle_event = Text.handleEvent,
                .destroy = Text.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .content = undefined, // Will be initialized in init()
        .style = undefined,
    };
    
    try text.base.init(allocator, props);
    
    // Set initial content and style
    text.setText(content);
    text.setStyle(style);
    
    return &text.base;
}

/// Create a simple text label with default styling
pub fn createLabel(
    allocator: std.mem.Allocator,
    content: []const u8,
    position: Vec2,
    font_size: f32
) !*Component {
    const style = TextStyle{
        .font_size = font_size,
        .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, // White
        .align = .left,
    };
    
    return try createText(allocator, content, position, style);
}

/// Create a centered title text
pub fn createTitle(
    allocator: std.mem.Allocator,
    content: []const u8,
    position: Vec2,
    font_size: f32
) !*Component {
    const style = TextStyle{
        .font_size = font_size,
        .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, // White
        .align = .center,
    };
    
    return try createText(allocator, content, position, style);
}

// Tests
test "text component creation and basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    const style = TextStyle{
        .font_size = 16.0,
        .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    };
    
    var text = try createText(allocator, "Hello, World!", Vec2{ .x = 10, .y = 20 }, style);
    defer text.destroy(allocator);
    
    const text_impl: *Text = @fieldParentPtr("base", text);
    
    // Test initial content
    try std.testing.expect(std.mem.eql(u8, text_impl.content.get(), "Hello, World!"));
    
    // Test style modification
    text_impl.setFontSize(20.0);
    try std.testing.expect(text_impl.style.get().font_size == 20.0);
    
    // Test content modification
    text_impl.setText("New content");
    try std.testing.expect(std.mem.eql(u8, text_impl.content.get(), "New content"));
}

test "text color handling (no debug colors)" {
    const style = TextStyle{
        .color = Color{ .r = 100, .g = 150, .b = 200, .a = 255 },
    };
    
    // Test normal state
    const normal_color = style.getDisplayColor(false, true);
    try std.testing.expect(std.mem.eql(u8, std.mem.asBytes(&normal_color), std.mem.asBytes(&style.color)));
    
    // Test hover state (should be light blue, not yellow)
    const hover_color = style.getDisplayColor(true, true);
    try std.testing.expect(hover_color.r == 200);
    try std.testing.expect(hover_color.g == 200);
    try std.testing.expect(hover_color.b == 255); // Blue, not yellow
    
    // Test disabled state (should be gray, not yellow)
    const disabled_color = style.getDisplayColor(false, false);
    try std.testing.expect(disabled_color.r == 128);
    try std.testing.expect(disabled_color.g == 128);
    try std.testing.expect(disabled_color.b == 128); // Gray, not yellow
}

test "text size estimation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    const style = TextStyle{ .font_size = 20.0 };
    var text = try createText(allocator, "Test", Vec2{ .x = 0, .y = 0 }, style);
    defer text.destroy(allocator);
    
    const text_impl: *Text = @fieldParentPtr("base", text);
    const size = text_impl.getMeasuredSize();
    
    // Should have reasonable dimensions based on font size and content
    try std.testing.expect(size.x > 0);
    try std.testing.expect(size.y > 0);
    try std.testing.expect(size.y >= style.font_size); // Height should be at least font size
}