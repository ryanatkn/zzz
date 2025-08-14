const std = @import("std");
const types = @import("../lib/core/types.zig");
const reactive = @import("../lib/reactive.zig");
const ui = @import("../lib/ui.zig");
const simple_gpu_renderer = @import("../lib/rendering/gpu.zig");
const page = @import("page.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;

/// Modern reactive HUD renderer that uses the new UI component system
/// Replaces the old renderer.zig with its debug yellow text colors
pub const ModernHUDRenderer = struct {
    allocator: std.mem.Allocator,
    base_renderer: *SimpleGPURenderer,
    
    // Reactive screen size management
    screen_width: reactive.Signal(f32),
    screen_height: reactive.Signal(f32),
    screen_units: ui.ScreenUnits,
    
    // UI root container
    root_container: ?*ui.Component = null,
    
    // Theme system
    theme: ui.Theme,
    
    // Page components (reactive replacement for static links)
    current_page_component: ?*ui.Component = null,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, base_renderer: *SimpleGPURenderer) !Self {
        // Initialize reactive system if not already done
        reactive.init(allocator) catch |err| {
            if (err != error.AlreadyInitialized) return err;
        };
        
        // Get current screen dimensions
        const current_width = base_renderer.screen_width;
        const current_height = base_renderer.screen_height;
        
        var screen_width = try reactive.signal(allocator, f32, current_width);
        var screen_height = try reactive.signal(allocator, f32, current_height);
        
        const screen_units = ui.ScreenUnits.init(&screen_width, &screen_height);
        
        // Create root container that fills the screen
        var root_props = try ui.ComponentProps.init(
            allocator, 
            Vec2{ .x = 0, .y = 0 }, 
            Vec2{ .x = current_width, .y = current_height }
        );
        
        const root_container = try ui.createLayout(allocator, root_props);
        const root_layout: *ui.Layout = @fieldParentPtr("base", root_container);
        root_layout.setDirection(.column);
        root_layout.setJustifyContent(.flex_start);
        root_layout.setAlignItems(.stretch);
        
        return Self{
            .allocator = allocator,
            .base_renderer = base_renderer,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .screen_units = screen_units,
            .root_container = root_container,
            .theme = ui.default_theme,
        };
    }
    
    pub fn deinit(self: *Self) void {
        // Cleanup UI components
        if (self.root_container) |root| {
            root.destroy(self.allocator);
        }
        
        if (self.current_page_component) |page_comp| {
            page_comp.destroy(self.allocator);
        }
        
        // Cleanup reactive signals
        self.screen_width.deinit();
        self.screen_height.deinit();
    }
    
    /// Update screen size and trigger responsive updates
    pub fn updateScreenSize(self: *Self, width: f32, height: f32) void {
        // Update reactive signals - this will automatically trigger layout updates
        reactive.batchUpdates(struct {
            fn update() void {
                self.screen_width.set(width);
                self.screen_height.set(height);
                
                // Update root container size
                if (self.root_container) |root| {
                    root.props.size.set(Vec2{ .x = width, .y = height });
                }
            }
        }.update);
    }
    
    /// Convert old page links to modern UI components
    pub fn renderPageWithComponents(
        self: *Self,
        current_page: *const page.Page,
        cmd_buffer: *anyopaque,
        render_pass: *anyopaque
    ) !void {
        // Clear previous page component
        if (self.current_page_component) |old_comp| {
            if (self.root_container) |root| {
                root.removeChild(old_comp);
                old_comp.destroy(self.allocator);
            }
        }
        
        // Create new page component
        self.current_page_component = try self.createPageComponent(current_page);
        
        // Add to root container
        if (self.root_container) |root| {
            try root.addChild(self.current_page_component.?);
        }
        
        // Update all components
        if (self.root_container) |root| {
            root.update(0.0); // dt not needed for layout updates
        }
        
        // Render all components using the modern renderer
        try self.renderComponents(cmd_buffer, render_pass);
    }
    
    /// Create modern UI components from old page link system
    fn createPageComponent(self: *Self, current_page: *const page.Page) !*ui.Component {
        // Create a container for this page's content
        const page_size = Vec2{ 
            .x = self.screen_width.get(), 
            .y = self.screen_height.get() 
        };
        var page_props = try ui.ComponentProps.init(
            self.allocator, 
            Vec2{ .x = 0, .y = 0 }, 
            page_size
        );
        
        const page_container = try ui.createLayout(self.allocator, page_props);
        const page_layout: *ui.Layout = @fieldParentPtr("base", page_container);
        page_layout.setDirection(.column);
        page_layout.setJustifyContent(.flex_start);
        page_layout.setAlignItems(.stretch);
        page_layout.setPadding(self.theme.spacing_large);
        
        // Get links from the old page system
        var links = std.ArrayList(page.Link).init(self.allocator);
        defer links.deinit();
        
        try current_page.render(&links);
        
        // Convert each link to a modern button component
        for (links.items) |link| {
            const button_component = try self.createButtonFromLink(link);
            try page_container.addChild(button_component);
        }
        
        return page_container;
    }
    
    /// Convert an old page.Link to a modern Button component
    fn createButtonFromLink(self: *Self, link: page.Link) !*ui.Component {
        // Create click handler that navigates to the link's path
        const NavigationContext = struct {
            path: []const u8,
            
            fn onClick(context: @This()) void {
                // TODO: Integrate with router system to navigate to context.path
                std.log.info("Navigate to: {s}", .{context.path});
            }
        };
        
        const nav_context = NavigationContext{ .path = link.path };
        
        // Create button with modern styling (no more debug colors!)
        const button_style = self.theme.getButtonStyle();
        const text_style = self.theme.getTextStyle(.normal);
        
        const button = try ui.createButton(
            self.allocator,
            link.text,
            link.bounds.position,
            link.bounds.size,
            button_style,
            nav_context.onClick // TODO: This needs proper closure handling
        );
        
        // Update text style to use theme colors
        const button_impl: *ui.Button = @fieldParentPtr("base", button);
        button_impl.setTextStyle(text_style);
        
        return button;
    }
    
    /// Render all UI components using the base renderer
    fn renderComponents(self: *Self, cmd_buffer: *anyopaque, render_pass: *anyopaque) !void {
        if (self.root_container) |root| {
            // Create a renderer adapter that implements the expected interface
            const RendererAdapter = struct {
                base: *SimpleGPURenderer,
                cmd_buffer: *anyopaque,
                render_pass: *anyopaque,
                
                pub fn drawRect(self: @This(), bounds: types.Rectangle, color: Color) !void {
                    // Convert to base renderer call
                    try self.base.drawRect(
                        @ptrCast(self.cmd_buffer),
                        @ptrCast(self.render_pass),
                        bounds.position,
                        bounds.size,
                        color
                    );
                }
                
                pub fn drawRoundedRect(self: @This(), bounds: types.Rectangle, color: Color, radius: f32) !void {
                    // For now, fall back to regular rect (can be enhanced later)
                    _ = radius;
                    try self.drawRect(bounds, color);
                }
                
                pub fn drawText(
                    self: @This(), 
                    text_content: []const u8, 
                    position: Vec2, 
                    font_size: f32, 
                    color: Color, 
                    font_category: @import("../lib/font/config.zig").FontCategory
                ) !void {
                    // Use the unified text system (no more yellow debug colors!)
                    if (self.base.font_manager) |fm| {
                        const text_result = fm.renderTextToTexture(
                            text_content,
                            font_category,
                            font_size,
                            color,
                            self.base.device
                        ) catch {
                            // Fallback to geometric text if TTF fails
                            try self.drawGeometricText(text_content, position.x, position.y, color);
                            return;
                        };
                        
                        // Queue for rendering (texture will be cleaned up automatically)
                        self.base.queueTextTexture(
                            text_result.texture,
                            position,
                            text_result.width,
                            text_result.height,
                            color
                        );
                    } else {
                        // Fallback to geometric text
                        try self.drawGeometricText(text_content, position.x, position.y, color);
                    }
                }
                
                pub fn drawGeometricText(
                    self: @This(), 
                    text_content: []const u8, 
                    x: f32, 
                    y: f32, 
                    color: Color
                ) !void {
                    // Use base renderer's geometric text system as fallback
                    try self.base.drawGeometricText(
                        @ptrCast(self.cmd_buffer),
                        @ptrCast(self.render_pass),
                        text_content,
                        x,
                        y,
                        color
                    );
                }
                
                // Properties for compatibility
                pub const font_manager = null; // Will be set properly
                pub const device = null; // Will be set properly
                
                pub fn queueTextTexture(
                    self: @This(),
                    texture: *anyopaque,
                    position: Vec2,
                    width: u32,
                    height: u32,
                    color: Color
                ) void {
                    self.base.queueTextTexture(texture, position, width, height, color);
                }
            };
            
            const adapter = RendererAdapter{
                .base = self.base_renderer,
                .cmd_buffer = cmd_buffer,
                .render_pass = render_pass,
            };
            
            try root.render(adapter);
        }
    }
    
    /// Handle input events with the modern UI system
    pub fn handleEvent(self: *Self, event: anytype) bool {
        if (self.root_container) |root| {
            return root.handleEvent(event);
        }
        return false;
    }
    
    /// Update the theme and trigger re-styling
    pub fn setTheme(self: *Self, new_theme: ui.Theme) void {
        self.theme = new_theme;
        // TODO: Trigger reactive update to re-style all components
    }
    
    /// Get current screen dimensions
    pub fn getScreenSize(self: *const Self) Vec2 {
        return Vec2{
            .x = self.screen_width.get(),
            .y = self.screen_height.get(),
        };
    }
};

// Helper functions for migration

/// Migrate from old renderer to new modern renderer
pub fn migrateRenderer(
    allocator: std.mem.Allocator, 
    old_renderer: *anytype,
    base_renderer: *SimpleGPURenderer
) !ModernHUDRenderer {
    _ = old_renderer; // Will be replaced
    return try ModernHUDRenderer.init(allocator, base_renderer);
}

/// Convert old hardcoded layout to responsive layout
pub fn makeResponsive(
    screen_units: *const ui.ScreenUnits,
    hardcoded_x: f32,
    hardcoded_y: f32,
    hardcoded_width: f32,
    hardcoded_height: f32
) struct { position: Vec2, size: Vec2 } {
    // Convert hardcoded 1920x1080 coordinates to responsive
    const screen_width_1920 = 1920.0;
    const screen_height_1080 = 1080.0;
    
    const relative_x = hardcoded_x / screen_width_1920;
    const relative_y = hardcoded_y / screen_height_1080;
    const relative_width = hardcoded_width / screen_width_1920;
    const relative_height = hardcoded_height / screen_height_1080;
    
    return .{
        .position = Vec2{
            .x = screen_units.vw(relative_x),
            .y = screen_units.vh(relative_y),
        },
        .size = Vec2{
            .x = screen_units.vw(relative_width),
            .y = screen_units.vh(relative_height),
        },
    };
}

// Tests
const std = @import("std");

test "modern renderer creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Mock base renderer for testing
    const MockRenderer = struct {
        screen_width: f32 = 1920,
        screen_height: f32 = 1080,
        device: ?*anyopaque = null,
        font_manager: ?*anyopaque = null,
        
        pub fn queueTextTexture(self: @This(), texture: *anyopaque, position: Vec2, width: u32, height: u32, color: Color) void {
            _ = self; _ = texture; _ = position; _ = width; _ = height; _ = color;
        }
        
        pub fn drawRect(self: @This(), cmd_buffer: *anyopaque, render_pass: *anyopaque, position: Vec2, size: Vec2, color: Color) !void {
            _ = self; _ = cmd_buffer; _ = render_pass; _ = position; _ = size; _ = color;
        }
        
        pub fn drawGeometricText(self: @This(), cmd_buffer: *anyopaque, render_pass: *anyopaque, text_content: []const u8, x: f32, y: f32, color: Color) !void {
            _ = self; _ = cmd_buffer; _ = render_pass; _ = text_content; _ = x; _ = y; _ = color;
        }
    };
    
    var mock_renderer = MockRenderer{};
    var modern_renderer = try ModernHUDRenderer.init(allocator, @ptrCast(&mock_renderer));
    defer modern_renderer.deinit();
    
    // Test initial state
    try std.testing.expect(modern_renderer.screen_width.get() == 1920);
    try std.testing.expect(modern_renderer.screen_height.get() == 1080);
    try std.testing.expect(modern_renderer.root_container != null);
}

test "responsive coordinate conversion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var screen_width = try reactive.signal(allocator, f32, 1600); // Different from 1920
    defer screen_width.deinit();
    
    var screen_height = try reactive.signal(allocator, f32, 900); // Different from 1080
    defer screen_height.deinit();
    
    const screen_units = ui.ScreenUnits.init(&screen_width, &screen_height);
    
    // Convert center of 1920x1080 screen to new dimensions
    const result = makeResponsive(&screen_units, 960, 540, 200, 100);
    
    // Should be center of new screen (800, 450) with proportional size
    try std.testing.expect(@abs(result.position.x - 800) < 1.0);
    try std.testing.expect(@abs(result.position.y - 450) < 1.0);
}

test "theme color verification (no debug colors)" {
    const theme = ui.default_theme;
    const button_style = theme.getButtonStyle();
    const text_style = theme.getTextStyle(.normal);
    
    // Ensure no bright yellow debug colors
    try std.testing.expect(!(button_style.hover_color.r == 255 and button_style.hover_color.g == 255 and button_style.hover_color.b == 0));
    try std.testing.expect(!(text_style.color.r == 255 and text_style.color.g == 255 and text_style.color.b == 0));
    
    // Ensure colors are reasonable (not debug colors)
    try std.testing.expect(text_style.color.r == 255 and text_style.color.g == 255 and text_style.color.b == 255); // White
}