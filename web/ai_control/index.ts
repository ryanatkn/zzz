/**
 * AI Control System - Main Entry Point
 * Unified exports for the AI control system
 */

// Core types and constants
export * from './core/types.js';
export * from './core/constants.js';
export { AIControllerBase } from './core/base.js';

// Node.js implementation
export { NodeAIController } from './node/controller.js';

// Story system
export { StoryController } from './story/story_controller.js';
export { Behaviors } from './story/behaviors.js';
export { Scenarios, type ScenarioType } from './story/scenarios.js';

// Default export for convenience
export { StoryController as default } from './story/story_controller.js';