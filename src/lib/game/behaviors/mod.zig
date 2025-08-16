/// Behavior system module exports
/// 
/// This module provides reusable AI behavior patterns that can be used
/// across different game implementations without depending on specific
/// entity or component systems.

pub const chase_behavior = @import("chase_behavior.zig");
pub const return_home_behavior = @import("return_home_behavior.zig");

// Re-export main types and functions for convenience
pub const ChaseConfig = chase_behavior.ChaseConfig;
pub const ChaseState = chase_behavior.ChaseState;
pub const ChaseResult = chase_behavior.ChaseResult;
pub const evaluateChase = chase_behavior.evaluateChase;
pub const simpleChase = chase_behavior.simpleChase;

pub const ReturnHomeConfig = return_home_behavior.ReturnHomeConfig;
pub const ReturnHomeResult = return_home_behavior.ReturnHomeResult;
pub const PatrolState = return_home_behavior.PatrolState;
pub const calculateReturnHomeVelocity = return_home_behavior.calculateReturnHomeVelocity;
pub const simpleReturnHome = return_home_behavior.simpleReturnHome;
pub const isAtHome = return_home_behavior.isAtHome;
pub const calculatePatrolVelocity = return_home_behavior.calculatePatrolVelocity;