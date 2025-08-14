const std = @import("std");

/// Centralized font configuration for consistent scaling across the UI
/// This solves the issue where different UI components had hardcoded font sizes
/// that didn't work well together (e.g., 48pt FPS text vs 16pt button text)
pub const FontConfig = struct {
    /// Base font size that other sizes are derived from
    /// Users can adjust this for their preference/display
    base_size: f32 = 16.0,  // Changed to match original button size
    
    /// Scaling factors for different UI elements (relative to base_size)
    /// Test various font sizes with bitmap rendering (SDF disabled)
    button_text: f32 = 1.0,      // 16pt - test standard button text
    header_text: f32 = 1.5,      // 24pt - test larger headers
    navigation_text: f32 = 0.875,  // 14pt - test smaller navigation
    fps_counter: f32 = 1.25,     // 20pt - test readable performance metrics
    debug_text: f32 = 0.75,      // 12pt - test smallest readable text
    
    /// Calculate actual font size for buttons
    pub fn buttonFontSize(self: FontConfig) f32 {
        return self.base_size * self.button_text;
    }
    
    /// Calculate actual font size for headers
    pub fn headerFontSize(self: FontConfig) f32 {
        return self.base_size * self.header_text;
    }
    
    /// Calculate actual font size for navigation
    pub fn navigationFontSize(self: FontConfig) f32 {
        return self.base_size * self.navigation_text;
    }
    
    /// Calculate actual font size for FPS counter
    pub fn fpsFontSize(self: FontConfig) f32 {
        return self.base_size * self.fps_counter;
    }
    
    /// Calculate actual font size for debug text
    pub fn debugFontSize(self: FontConfig) f32 {
        return self.base_size * self.debug_text;
    }
    
    /// Calculate button height based on font size
    /// Ensures text fits comfortably with padding
    pub fn buttonHeight(self: FontConfig) f32 {
        const font_size = self.buttonFontSize();
        // Height = font size * line height multiplier + vertical padding
        // Increased multiplier for 48pt text debugging
        return font_size * 1.8 + self.buttonPadding() * 2;
    }
    
    /// Calculate button padding based on font size
    pub fn buttonPadding(self: FontConfig) f32 {
        return self.base_size * 0.4;
    }
    
    /// Estimate character width for a given font size
    /// This is approximate - actual width varies by font and character
    pub fn estimateCharWidth(_: FontConfig, font_size: f32) f32 {
        // Approximate: character width is about 0.6x the font size for proportional fonts
        return font_size * 0.6;
    }
    
    /// Get character width for button text
    pub fn buttonCharWidth(self: FontConfig) f32 {
        return self.estimateCharWidth(self.buttonFontSize());
    }
    
    /// Get character width for header text
    pub fn headerCharWidth(self: FontConfig) f32 {
        return self.estimateCharWidth(self.headerFontSize());
    }
    
    /// Get character width for navigation text
    pub fn navigationCharWidth(self: FontConfig) f32 {
        return self.estimateCharWidth(self.navigationFontSize());
    }
};

/// Preset configurations for different use cases
pub const FontPresets = struct {
    /// Small preset - good for high-density displays
    pub const small = FontConfig{
        .base_size = 12.0,
    };
    
    /// Medium preset - balanced default (matches original design)
    pub const medium = FontConfig{
        .base_size = 16.0,
    };
    
    /// Large preset - better readability
    pub const large = FontConfig{
        .base_size = 20.0,
    };
    
    /// Extra large preset - accessibility
    pub const extra_large = FontConfig{
        .base_size = 24.0,
    };
};

/// Global font configuration instance
/// This should be initialized at startup and used throughout the application
pub var global_config: FontConfig = FontPresets.medium;

/// Set the global font configuration
pub fn setGlobalConfig(config: FontConfig) void {
    global_config = config;
}

/// Get the current global font configuration
pub fn getGlobalConfig() FontConfig {
    return global_config;
}

/// Set the global configuration from a preset
pub fn setPreset(preset: enum { small, medium, large, extra_large }) void {
    global_config = switch (preset) {
        .small => FontPresets.small,
        .medium => FontPresets.medium,
        .large => FontPresets.large,
        .extra_large => FontPresets.extra_large,
    };
}