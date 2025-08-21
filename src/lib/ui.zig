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

// Re-export layout system types for backward compatibility
pub const BoxModel = layout.BoxModel;
pub const TextBaseline = layout.TextBaseline;
pub const TextPositioning = layout.TextPositioning;
pub const Flexbox = layout.Flexbox;
pub const FlexItem = layout.FlexItem;
pub const FlexItemLayout = layout.FlexItemLayout;
pub const SpacingUtils = layout.SpacingUtils;
pub const SizingUtils = layout.SizingUtils;
pub const PositioningUtils = layout.PositioningUtils;

// Re-export layout enums for convenience
pub const JustifyContent = layout.JustifyContent;
pub const AlignItems = layout.AlignItems;
pub const Direction = layout.Direction;
pub const PositionMode = layout.PositionMode;
pub const Alignment = layout.Alignment;
