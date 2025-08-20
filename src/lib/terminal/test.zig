// Terminal Test Barrel File
//
// This file re-exports all tests from the terminal module for clean integration
// with the main test suite. It ensures all terminal tests are discoverable
// and runnable through a single import point.

// Kernel tests (micro-kernel architecture)
test {
    _ = @import("kernel/test_kernel.zig");
}

// Core capability tests (Phase 2)
test {
    _ = @import("capabilities/test_capabilities.zig");
}

// State capability tests (Phase 3)
test {
    _ = @import("capabilities/state/history.zig");
}

test {
    _ = @import("capabilities/state/screen_buffer.zig");
}

test {
    _ = @import("capabilities/state/scrollback.zig");
}

test {
    _ = @import("capabilities/state/persistence.zig");
}

// Command capability tests (Phase 4)
test {
    _ = @import("capabilities/commands/parser.zig");
}

test {
    _ = @import("capabilities/commands/registry.zig");
}

test {
    _ = @import("capabilities/commands/executor.zig");
}

test {
    _ = @import("capabilities/commands/builtin.zig");
}

test {
    _ = @import("capabilities/commands/pipeline.zig");
}

// Output capability tests (Phase 4)
test {
    _ = @import("capabilities/output/ansi_writer.zig");
}

// Preset tests
test {
    _ = @import("presets/standard.zig");
}

test {
    _ = @import("presets/command.zig");
}
