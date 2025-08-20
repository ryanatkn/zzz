//! Terminal UI support for Zzz Game Engine
//!
//! Provides unified terminal layout rendering capabilities.
//! This module has been cleaned up to remove unused re-exports.

pub const terminal_layout_renderer = @import("ui/terminal_layout_renderer.zig");

// Re-export terminal layout types (only ones actually used)
pub const TerminalLayoutRenderer = terminal_layout_renderer.TerminalLayoutRenderer;
pub const TerminalLayoutConfig = terminal_layout_renderer.TerminalLayoutConfig;
pub const TerminalContent = terminal_layout_renderer.TerminalContent;