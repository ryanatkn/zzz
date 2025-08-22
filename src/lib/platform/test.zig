// Platform Library Test Barrel File
//
// This file re-exports all tests from platform modules for clean integration
// with the main test suite.

const std = @import("std");

// Currently no platform modules have tests that can run without SDL dependencies
// Most platform modules provide SDL3 integration and require runtime SDL environment

// TODO: Future platform modules with testable pure Zig logic can be added here
