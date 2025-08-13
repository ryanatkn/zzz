const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const log = std.log.scoped(.fonts);

pub const FontCategory = enum {
    mono,          // Monospace fonts for code
    sans,          // Sans-serif for UI
    serif_display, // Serif for titles/headers
    serif_text,    // Serif for body text
};

pub const FontVariant = struct {
    path: []const u8,
    weight: i32,      // 100-900 (100=Thin, 400=Regular, 700=Bold, 900=Black)
    italic: bool,
    condensed: enum { normal, semi, condensed, extra } = .normal,
    optical_size: ?i32 = null,  // For fonts with optical size variants
};

pub const FontFamily = struct {
    name: []const u8,
    category: FontCategory,
    variants: []const FontVariant,
};

// Available font families with all their variants
pub const available_fonts = [_]FontFamily{
    .{
        .name = "DM Mono",
        .category = .mono,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Mono/DMMono-Light.ttf", .weight = 300, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-LightItalic.ttf", .weight = 300, .italic = true },
            .{ .path = "static/fonts/DM_Mono/DMMono-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-Italic.ttf", .weight = 400, .italic = true },
            .{ .path = "static/fonts/DM_Mono/DMMono-Medium.ttf", .weight = 500, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-MediumItalic.ttf", .weight = 500, .italic = true },
        },
    },
    .{
        .name = "DM Sans",
        .category = .sans,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Thin.ttf", .weight = 100, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ThinItalic.ttf", .weight = 100, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraLight.ttf", .weight = 200, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraLightItalic.ttf", .weight = 200, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Light.ttf", .weight = 300, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-LightItalic.ttf", .weight = 300, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Italic.ttf", .weight = 400, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Medium.ttf", .weight = 500, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-MediumItalic.ttf", .weight = 500, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-SemiBold.ttf", .weight = 600, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-SemiBoldItalic.ttf", .weight = 600, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Bold.ttf", .weight = 700, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-BoldItalic.ttf", .weight = 700, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraBold.ttf", .weight = 800, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraBoldItalic.ttf", .weight = 800, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Black.ttf", .weight = 900, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-BlackItalic.ttf", .weight = 900, .italic = true },
        },
    },
    .{
        .name = "DM Serif Display",
        .category = .serif_display,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Serif_Display/DMSerifDisplay-Italic.ttf", .weight = 400, .italic = true },
        },
    },
    .{
        .name = "DM Serif Text",
        .category = .serif_text,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Serif_Text/DMSerifText-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Serif_Text/DMSerifText-Italic.ttf", .weight = 400, .italic = true },
        },
    },
};

pub const FontSettings = struct {
    mono_family: []const u8 = "DM Mono",
    mono_weight: i32 = 400,
    mono_italic: bool = false,
    
    sans_family: []const u8 = "DM Sans",
    sans_weight: i32 = 400,
    sans_italic: bool = false,
    
    serif_display_family: []const u8 = "DM Serif Display",
    serif_display_weight: i32 = 400,
    serif_display_italic: bool = false,
    
    serif_text_family: []const u8 = "DM Serif Text",
    serif_text_weight: i32 = 400,
    serif_text_italic: bool = false,
    
    default_size: f32 = 16.0,
    ui_size: f32 = 14.0,
    code_size: f32 = 13.0,
    heading_size: f32 = 24.0,
    body_size: f32 = 16.0,
};

pub const FontHandle = struct {
    font: *c.ttf.TTF_Font,
    family: []const u8,
    variant: FontVariant,
    size: f32,
};

pub const FontManager = struct {
    allocator: std.mem.Allocator,
    settings: FontSettings,
    loaded_fonts: std.StringHashMap(FontHandle),
    text_engine: ?*c.ttf.TTF_TextEngine,
    gpu_device: *c.sdl.SDL_GPUDevice,
    
    pub fn init(allocator: std.mem.Allocator, gpu_device: *c.sdl.SDL_GPUDevice) !FontManager {
        log.info("Initializing FontManager...", .{});
        
        // Initialize SDL_ttf
        const ttf_result = c.ttf.TTF_Init();
        log.info("TTF_Init result: {}", .{ttf_result});
        
        if (!ttf_result) {
            log.err("Failed to initialize SDL_ttf: {s}", .{c.sdl.SDL_GetError()});
            return error.TTFInitFailed;
        }
        
        log.info("SDL_ttf initialized successfully", .{});
        
        return FontManager{
            .allocator = allocator,
            .settings = FontSettings{},
            .loaded_fonts = std.StringHashMap(FontHandle).init(allocator),
            .text_engine = null,
            .gpu_device = gpu_device,
        };
    }
    
    pub fn deinit(self: *FontManager) void {
        // Clean up loaded fonts
        var iter = self.loaded_fonts.iterator();
        while (iter.next()) |entry| {
            c.ttf.TTF_CloseFont(entry.value_ptr.font);
            // Free the duplicated key string
            self.allocator.free(entry.key_ptr.*);
        }
        self.loaded_fonts.deinit();
        
        // Destroy text engine
        if (self.text_engine) |engine| {
            c.ttf.TTF_DestroyGPUTextEngine(engine);
        }
        
        // Quit SDL_ttf
        c.ttf.TTF_Quit();
    }
    
    pub fn createTextEngine(self: *FontManager) !void {
        log.info("Creating GPU text engine...", .{});
        self.text_engine = c.ttf.TTF_CreateGPUTextEngine(self.gpu_device);
        if (self.text_engine == null) {
            log.err("Failed to create GPU text engine: {s}", .{c.sdl.SDL_GetError()});
            return error.TextEngineCreationFailed;
        }
        log.info("GPU text engine created successfully: {*}", .{self.text_engine});
    }
    
    pub fn loadFont(self: *FontManager, category: FontCategory, size: f32) !FontHandle {
        const family_name = switch (category) {
            .mono => self.settings.mono_family,
            .sans => self.settings.sans_family,
            .serif_display => self.settings.serif_display_family,
            .serif_text => self.settings.serif_text_family,
        };
        
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
        
        // Find the font family
        var font_family: ?FontFamily = null;
        for (available_fonts) |family| {
            if (std.mem.eql(u8, family.name, family_name)) {
                font_family = family;
                break;
            }
        }
        
        if (font_family == null) {
            log.err("Font family not found: {s}", .{family_name});
            return error.FontFamilyNotFound;
        }
        
        // Find the best matching variant
        var best_variant: ?FontVariant = null;
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
            log.err("No suitable variant found for font", .{});
            return error.FontVariantNotFound;
        }
        
        // Create cache key
        var key_buf: [256]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "{s}_{d}_{d}", .{ best_variant.?.path, @as(i32, @intFromFloat(size)), @intFromBool(italic) });
        
        // Check if already loaded
        if (self.loaded_fonts.get(key)) |handle| {
            return handle;
        }
        
        // Load the font (SDL3_ttf uses float for size)
        log.info("=== FONT LOADING ===", .{});
        log.info("  Path: {s}", .{best_variant.?.path});
        log.info("  Size: {d}", .{size});
        log.info("  Weight: {d}, Italic: {}", .{ best_variant.?.weight, best_variant.?.italic });
        
        const font = c.ttf.TTF_OpenFont(best_variant.?.path.ptr, size);
        log.info("  TTF_OpenFont returned: {*}", .{font});
        
        if (font == null) {
            const err = c.sdl.SDL_GetError();
            log.err("  Failed to load font: {s}", .{err});
            // Try with absolute path as fallback
            var abs_path_buf: [256]u8 = undefined;
            const abs_path = std.fmt.bufPrintZ(&abs_path_buf, "/home/desk/dev/hex/{s}", .{best_variant.?.path}) catch {
                return error.FontLoadFailed;
            };
            log.info("  Trying absolute path: {s}", .{abs_path});
            const font_abs = c.ttf.TTF_OpenFont(abs_path.ptr, size);
            log.info("  Absolute path result: {*}", .{font_abs});
            
            if (font_abs == null) {
                log.err("  Failed with absolute path too: {s}", .{c.sdl.SDL_GetError()});
                return error.FontLoadFailed;
            }
            const handle_abs = FontHandle{
                .font = font_abs.?,
                .family = family_name,
                .variant = best_variant.?,
                .size = size,
            };
            try self.loaded_fonts.put(try self.allocator.dupe(u8, key), handle_abs);
            log.info("  ✓ Font loaded successfully with absolute path", .{});
            return handle_abs;
        }
        
        log.info("  ✓ Font loaded successfully with relative path", .{});
        
        const handle = FontHandle{
            .font = font.?,
            .family = family_name,
            .variant = best_variant.?,
            .size = size,
        };
        
        try self.loaded_fonts.put(try self.allocator.dupe(u8, key), handle);
        return handle;
    }
    
    pub fn renderText(
        self: *FontManager,
        text: []const u8,
        category: FontCategory,
        size: f32,
        color: types.Color,
    ) !*c.ttf.TTF_Text {
        log.info("=== RENDER TEXT ===", .{});
        log.info("  Text: '{s}'", .{text});
        log.info("  Category: {}, Size: {d}", .{ category, size });
        
        const font_handle = try self.loadFont(category, size);
        log.info("  Font handle obtained: {*}", .{font_handle.font});
        
        if (self.text_engine == null) {
            log.info("  Text engine is null, creating...", .{});
            try self.createTextEngine();
        } else {
            log.info("  Using existing text engine: {*}", .{self.text_engine});
        }
        
        // Create text with the loaded font
        log.info("  Creating text object...", .{});
        const text_obj = c.ttf.TTF_CreateText(self.text_engine, font_handle.font, text.ptr, @intCast(text.len));
        log.info("  TTF_CreateText returned: {*}", .{text_obj});
        
        if (text_obj == null) {
            log.err("  Failed to create text: {s}", .{c.sdl.SDL_GetError()});
            return error.TextCreationFailed;
        }
        
        log.info("  ✓ Text object created successfully", .{});
        
        // Set text color (convert u8 to float 0-1 range)
        const r = @as(f32, @floatFromInt(color.r)) / 255.0;
        const g = @as(f32, @floatFromInt(color.g)) / 255.0;
        const b = @as(f32, @floatFromInt(color.b)) / 255.0;
        const a = @as(f32, @floatFromInt(color.a)) / 255.0;
        _ = c.ttf.TTF_SetTextColorFloat(text_obj, r, g, b, a);
        
        return text_obj.?;
    }
    
    pub fn getFontFamilies(self: *const FontManager, category: FontCategory) []const FontFamily {
        var families = std.ArrayList(FontFamily).init(self.allocator);
        defer families.deinit();
        
        for (available_fonts) |family| {
            if (family.category == category) {
                families.append(family) catch continue;
            }
        }
        
        return families.toOwnedSlice() catch &[_]FontFamily{};
    }
    
    pub fn getVariants(self: *const FontManager, family_name: []const u8) []const FontVariant {
        _ = self;
        for (available_fonts) |family| {
            if (std.mem.eql(u8, family.name, family_name)) {
                return family.variants;
            }
        }
        return &[_]FontVariant{};
    }
    
    pub fn updateSettings(self: *FontManager, settings: FontSettings) void {
        self.settings = settings;
        // Clear font cache to reload with new settings
        var iter = self.loaded_fonts.iterator();
        while (iter.next()) |entry| {
            c.ttf.TTF_CloseFont(entry.value_ptr.font);
        }
        self.loaded_fonts.clearAndFree();
    }
};