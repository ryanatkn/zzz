// UI Library Test Barrel File
//
// This file re-exports all tests from UI modules for clean integration
// with the main test suite.

const std = @import("std");

// Working UI modules
test {
    _ = @import("animated_borders.zig");
    _ = @import("component.zig");
    _ = @import("geometric_text.zig");

    // TODO: Fix broken test modules - these have compilation issues
    // _ = @import("button.zig"); // Const qualifier mismatches, reactive issues
    // _ = @import("debug_overlay.zig"); // Comptime value issues
    // _ = @import("focus_manager.zig"); // Derived pointer issues
    // _ = @import("fps_counter.zig"); // SDL dependencies + reactive issues - has 'reactive' undefined
    // _ = @import("primitives.zig"); // Const qualifier mismatches
    // _ = @import("reactive_label.zig"); // FormatArg API changes
    // _ = @import("text.zig"); // Runtime segfault in reactive system
}

// TODO: The following modules are excluded:
// - button.zig: Const qualifier mismatches, reactive issues (needs fixing)
// - primitives.zig: Const qualifier mismatches (needs fixing)
// - text.zig: Runtime segfault in reactive system (needs fixing)
// - fps_counter.zig: SDL dependencies + reactive issues (legitimate exclusion + needs fixing)
// - debug_overlay.zig: Comptime value issues (needs fixing)
// - reactive_label.zig: FormatArg API changes (needs fixing)
// - focus_manager.zig: Derived pointer issues (needs fixing)
// - terminal_layout_renderer.zig: SDL text rendering dependencies (legitimate exclusion)
