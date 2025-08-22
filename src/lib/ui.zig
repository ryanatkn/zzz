//! UI support for Zzz Game Engine
//!
//! Provides unified terminal layout rendering, focus management, and core UI primitives.
//! This module exports the most commonly used UI components for retained mode rendering.

pub const terminal_layout_renderer = @import("ui/terminal_layout_renderer.zig");
pub const focus_manager = @import("ui/focus_manager.zig");
pub const primitives = @import("ui/primitives.zig");

// Unified layout system (dedicated barrel module)
pub const layout = @import("layout/mod.zig");

// Re-export terminal layout types (only ones actually used)
pub const TerminalLayoutRenderer = terminal_layout_renderer.TerminalLayoutRenderer;
pub const TerminalLayoutConfig = terminal_layout_renderer.TerminalLayoutConfig;
pub const TerminalContent = terminal_layout_renderer.TerminalContent;

// Re-export focus management types
pub const FocusManager = focus_manager.FocusManager;
pub const PanelFocus = focus_manager.PanelFocus;
pub const PanelFocusManager = focus_manager.PanelFocusManager;

// Re-export core UI primitives
pub const UIComponent = primitives.UIComponent;
pub const Panel = primitives.Panel;
pub const PanelConfig = primitives.PanelConfig;
pub const InputField = primitives.InputField;
pub const InputFieldConfig = primitives.InputFieldConfig;
pub const Button = primitives.Button;
pub const ButtonConfig = primitives.ButtonConfig;

// Re-export core layout types that actually exist
pub const LayoutEngine = layout.LayoutEngine;
pub const LayoutResult = layout.LayoutResult;
pub const LayoutElement = layout.LayoutElement;
pub const LayoutContext = layout.LayoutContext;
pub const Vec2 = layout.Vec2;
pub const Rectangle = layout.Rectangle;
pub const Spacing = layout.Spacing;
pub const Constraints = layout.Constraints;

// Re-export layout enums that actually exist
pub const LayoutMode = layout.LayoutMode;
pub const Alignment = layout.Alignment;
pub const Direction = layout.Direction;
