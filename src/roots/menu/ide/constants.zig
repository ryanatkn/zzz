/// IDE File Explorer Constants
/// Centralized configuration for the file explorer interface
const colors = @import("../../../lib/core/colors.zig");
const color_math = @import("../../../lib/math/color.zig");
const ColorBuilder = color_math.ColorBuilder;
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
    pub const HEADER_BG = ColorBuilder.rgb(25, 30, 40);
    pub const PANEL_BG = ColorBuilder.rgb(35, 40, 50);
    pub const PANEL_BORDER = ColorBuilder.rgb(60, 65, 75);

    /// Text colors
    pub const TEXT_NORMAL = ColorBuilder.rgb(200, 200, 200);
    pub const TEXT_LINE_NUMBERS = ColorBuilder.gray(120);
    pub const TEXT_TRUNCATION = ColorBuilder.rgb(150, 150, 50);

    /// Selection and interaction colors
    pub const SELECTION_BG = ColorBuilder.rgba(70, 130, 180, 100);
    pub const HOVER_BG = ColorBuilder.rgba(55, 60, 70, 150);
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
    pub const ENABLE_HIGHLIGHTING: bool = true;

    /// Maximum line length to highlight (performance limit)
    pub const MAX_HIGHLIGHT_LINE_LENGTH: u32 = 500;

    /// Maximum tokens per line (performance limit)
    pub const MAX_TOKENS_PER_LINE: u32 = 100;

    /// Maximum file size to highlight (10KB limit for safety)
    pub const MAX_FILE_SIZE_BYTES: u32 = 10 * 1024;

    /// Timeout for syntax highlighting per file (100ms)
    pub const HIGHLIGHT_TIMEOUT_MS: u32 = 100;
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
    pub const INPUT_BG_NORMAL = ColorBuilder.rgb(35, 40, 50);
    pub const INPUT_BG_FOCUSED = ColorBuilder.rgba(55, 60, 70, 150);
    pub const INPUT_BORDER_FOCUSED = ColorBuilder.rgb(70, 130, 180);
};
