/// IDE File Explorer Constants
/// Centralized configuration for the file explorer interface
/// File content reading limits
pub const FILE_LIMITS = struct {
    /// Maximum file size to read (1MB)
    pub const MAX_FILE_SIZE: u64 = 1024 * 1024;

    /// Maximum directory depth for scanning
    pub const MAX_DIRECTORY_DEPTH: u32 = 10;
};

/// Dashboard layout configuration
pub const LAYOUT = struct {
    /// Header panel height
    pub const HEADER_HEIGHT: f32 = 60;

    /// Gap between panels
    pub const PANEL_GAP: f32 = 8;

    /// File explorer panel width (left)
    pub const EXPLORER_WIDTH: f32 = 300;

    /// Maximum content area width (center)
    pub const MAX_CONTENT_WIDTH: f32 = 800;

    /// Preview panel width (right) - 2x wider
    pub const PREVIEW_WIDTH: f32 = 800;
};

/// Text rendering configuration
pub const TEXT = struct {
    /// Standard font size for file content - using same size as buttons (16pt)
    pub const CONTENT_FONT_SIZE: f32 = 16.0;

    /// Line height for file content display
    pub const LINE_HEIGHT: f32 = 16;

    /// Character width approximation
    pub const CHAR_WIDTH: f32 = 8;

    /// Offset for line numbers in content area
    pub const LINE_NUMBER_OFFSET: f32 = 50;
};

/// Color scheme for the file explorer
pub const COLORS = struct {
    /// Panel background colors
    pub const HEADER_BG = @import("../../lib/core/colors.zig").Color{ .r = 25, .g = 30, .b = 40, .a = 255 };
    pub const PANEL_BG = @import("../../lib/core/colors.zig").Color{ .r = 35, .g = 40, .b = 50, .a = 255 };
    pub const PANEL_BORDER = @import("../../lib/core/colors.zig").Color{ .r = 60, .g = 65, .b = 75, .a = 255 };

    /// Text colors
    pub const TEXT_NORMAL = @import("../../lib/core/colors.zig").Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
    pub const TEXT_LINE_NUMBERS = @import("../../lib/core/colors.zig").Color{ .r = 120, .g = 120, .b = 120, .a = 255 };
    pub const TEXT_TRUNCATION = @import("../../lib/core/colors.zig").Color{ .r = 150, .g = 150, .b = 50, .a = 255 };

    /// Selection and interaction colors
    pub const SELECTION_BG = @import("../../lib/core/colors.zig").Color{ .r = 70, .g = 130, .b = 180, .a = 100 };
    pub const HOVER_BG = @import("../../lib/core/colors.zig").Color{ .r = 55, .g = 60, .b = 70, .a = 150 };
};

/// File tree interaction configuration
pub const FILE_TREE = struct {
    /// Item height in the file tree
    pub const ITEM_HEIGHT: f32 = 24.0;

    /// Width of file tree items
    pub const ITEM_WIDTH: f32 = 280.0;

    /// Spacing between items
    pub const ITEM_SPACING: f32 = 26.0;

    /// Icon size for file types
    pub const ICON_SIZE: f32 = 12.0;

    /// Indentation per directory level
    pub const INDENT_PER_LEVEL: f32 = 20.0;
};

/// Syntax highlighting configuration
pub const SYNTAX = struct {
    /// Enable syntax highlighting for supported file types
    pub const ENABLE_HIGHLIGHTING: bool = false; // Temporarily disabled to test freeze issue

    /// Maximum line length to highlight (performance limit)
    pub const MAX_HIGHLIGHT_LINE_LENGTH: u32 = 500;

    /// Maximum tokens per line (performance limit)
    pub const MAX_TOKENS_PER_LINE: u32 = 100;
};

/// Terminal styling configuration
pub const TERMINAL = struct {
    /// Terminal line spacing multiplier (1.2 = 20% more space)
    pub const LINE_SPACING_MULTIPLIER: f32 = 1.3;
    
    /// Bottom margin for terminal content
    pub const BOTTOM_MARGIN: f32 = 15;
    
    /// Side margin for terminal content
    pub const SIDE_MARGIN: f32 = 10;
    
    /// Input padding inside the input field
    pub const INPUT_PADDING: f32 = 6;
    
    /// Input field colors
    pub const INPUT_BG_NORMAL = @import("../../lib/core/colors.zig").Color{ .r = 35, .g = 40, .b = 50, .a = 255 };
    pub const INPUT_BG_FOCUSED = @import("../../lib/core/colors.zig").Color{ .r = 55, .g = 60, .b = 70, .a = 150 };
    pub const INPUT_BORDER_FOCUSED = @import("../../lib/core/colors.zig").Color{ .r = 70, .g = 130, .b = 180, .a = 255 };
};
