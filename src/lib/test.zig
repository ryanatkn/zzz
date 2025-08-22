// Library Test Barrel File
//
// This file re-exports all tests from the lib module for clean integration
// with the main test suite. It ensures all lib tests are discoverable
// and runnable through a single import point.
//
// Organization follows capability-based structure with proper test barrels
// for each major subsystem.

const std = @import("std");

// Core library functionality
test {
    _ = @import("core/test.zig");
    _ = @import("math/test.zig");
    _ = @import("physics/test.zig");
}

// Rendering and UI
test {
    _ = @import("rendering/test.zig");
    _ = @import("ui/test.zig");
}

// Text and font systems
test {
    _ = @import("font/test.zig");
    _ = @import("text/test.zig");
}

// Game systems
test {
    _ = @import("game/test.zig");
}

// Reactive system
test {
    _ = @import("reactive/test.zig");
}

// Layout system (already has test.zig)
test {
    _ = @import("layout/test.zig");
}

// Terminal system (already has test.zig)
test {
    _ = @import("terminal/test.zig");
}

// Platform and debug systems
test {
    _ = @import("platform/test.zig");
    _ = @import("debug/test.zig");
}

// Cache and utility systems
test {
    _ = @import("cache/test.zig");
}

// Particles system
test {
    _ = @import("particles/test.zig");
}

// Gannaway system
test {
    _ = @import("gannaway/test.zig");
}
