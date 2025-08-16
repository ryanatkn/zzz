/**
 * Core AI Controller Types
 * Shared type definitions for all AI controller implementations
 */

export interface Vec2 {
  x: number;
  y: number;
}

// SDL Scancodes for keyboard mapping (0-63 range supported)
export enum Keys {
  A = 4,
  B = 5,
  C = 6,
  D = 7,
  E = 8,
  F = 9,
  G = 10,
  H = 11,
  I = 12,
  J = 13,
  K = 14,
  L = 15,
  M = 16,
  N = 17,
  O = 18,
  P = 19,
  Q = 20,
  R = 21,
  S = 22,
  T = 23,
  U = 24,
  V = 25,
  W = 26,
  X = 27,
  Y = 28,
  Z = 29,
  KEY_1 = 30,
  KEY_2 = 31,
  KEY_3 = 32,
  KEY_4 = 33,
  KEY_5 = 34,
  KEY_6 = 35,
  KEY_7 = 36,
  KEY_8 = 37,
  KEY_9 = 38,
  KEY_0 = 39,
  RETURN = 40,
  ESCAPE = 41,
  BACKSPACE = 42,
  TAB = 43,
  SPACE = 44,
  MINUS = 45,
  EQUALS = 46,
  LEFTBRACKET = 47,
  RIGHTBRACKET = 48,
  BACKSLASH = 49,
  NONUSHASH = 50,
  SEMICOLON = 51,
  APOSTROPHE = 52,
  GRAVE = 53,
  COMMA = 54,
  PERIOD = 55,
  SLASH = 56,
  CAPSLOCK = 57,
  F1 = 58,
  F2 = 59,
  F3 = 60,
  F4 = 61,
  F5 = 62,
  F6 = 63,
  // Keys beyond 63 are not supported in the 64-bit bitfield
  // F7-F12, arrow keys, modifiers are out of range
}

// Mouse button flags
export enum MouseButtons {
  LEFT = 0x01,
  RIGHT = 0x02,
  MIDDLE = 0x04,
}

// Command structure matching Zig's InputCommand
export interface InputCommand {
  frame: number;      // Target frame (0 = immediate)
  keys: bigint;       // 64-bit keyboard state
  mouseX: number;     // Mouse X position
  mouseY: number;     // Mouse Y position
  buttons: number;    // Mouse button state
}

// High-level action types for sequences
export interface Action {
  type: 'move' | 'shoot' | 'spell' | 'wait' | 'interact';
  data?: any;
  duration?: number;
}

// Movement action data
export interface MoveAction extends Action {
  type: 'move';
  data: {
    direction?: 'up' | 'down' | 'left' | 'right' | 'stop';
    position?: Vec2;
    speed?: number;
    walk?: boolean;
  };
}

// Shooting action data
export interface ShootAction extends Action {
  type: 'shoot';
  data: {
    target: Vec2;
    burst?: boolean;
  };
}

// Spell casting action data
export interface SpellAction extends Action {
  type: 'spell';
  data: {
    slot: number;
    target: Vec2;
    selfCast?: boolean;
  };
}

// Wait action data
export interface WaitAction extends Action {
  type: 'wait';
  duration: number;
}

// Interaction action data
export interface InteractAction extends Action {
  type: 'interact';
  data: {
    key: Keys;
  };
}

export type ActionSequence = Array<MoveAction | ShootAction | SpellAction | WaitAction | InteractAction>;