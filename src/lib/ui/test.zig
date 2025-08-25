// UI Library Test Barrel File
//
// This file re-exports all tests from UI modules for clean integration
// with the main test suite.

const std = @import("std");

// Working UI modules
test {
    _ = @import("animated_borders.zig");
    _ = @import("component.zig");

    // Fixed test modules (re-enabled after fixing issues)
    _ = @import("primitives.zig"); // Fixed const qualifier mismatches

    // Re-enabled test modules
    _ = @import("focus_manager.zig"); // Re-enabled - focus management tests

    // New unified style system tests
    _ = @import("styles/text_style.zig"); // Text styling with presets
    _ = @import("text_display.zig"); // TextDisplay component integration tests
    _ = @import("text_display_style.zig"); // TextDisplayStyle tests

    // Working button component (renamed from simple_button.zig)
    _ = @import("button.zig");
}

// The following modules are excluded:
// - fps_counter.zig: SDL dependencies (uses text/renderer.zig which requires SDL GPU API)
// - terminal_layout_renderer.zig: SDL text rendering dependencies (legitimate exclusion)
//
// Recently cleaned up:
// - ✅ Removed broken text.zig (comptime vtable issues - superseded by text_display.zig)
// - ✅ Removed broken debug_overlay.zig (comptime format string issues)
// - ✅ Renamed simple_button.zig → button.zig (working component)
//
// Successfully working:
// - focus_manager.zig: ✅ Re-enabled successfully (focus management tests)
// - primitives.zig: ✅ Re-enabled after fixing const qualifier mismatches
// - button.zig: ✅ Working button component with unified styles
