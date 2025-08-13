const std = @import("std");
const observer = @import("observer.zig");
const tracking = @import("tracking.zig");

/// Re-export core types for compatibility
/// These maintain the original API while using the new modular structure
pub const ReactiveContext = tracking.ReactiveContext;
pub const Observer = observer.Observer;
pub const Dependency = observer.Dependency;

/// Re-export tracking functions for compatibility
/// These maintain the original API while delegating to the tracking module
pub const initContext = tracking.initContext;
pub const deinitContext = tracking.deinitContext;
pub const getContext = tracking.getContext;
pub const trackDependency = tracking.trackDependency;
pub const withTracking = tracking.withTracking;
pub const untrack = tracking.untrack;
pub const createDependency = observer.createDependency;
pub const createObserver = observer.createObserver;

// Tests are now in the tracking module
// This file serves as a compatibility layer