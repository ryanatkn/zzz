/**
 * Core AI Controller Types and Base Class
 * 
 * Shared between Node.js and browser implementations.
 * Contains all type definitions and abstract base class.
 */

// Export types
export interface Vec2 {
  x: number;
  y: number;
}

// SDL Scancodes for keyboard mapping
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
  SPACE = 44,
  LCTRL = 224,
  LSHIFT = 225,
  LALT = 226,
  RCTRL = 228,
  RSHIFT = 229,
  RALT = 230,
  ESCAPE = 41,
  RETURN = 40,
  TAB = 43,
  BACKSPACE = 42,
  UP = 82,
  DOWN = 81,
  LEFT = 80,
  RIGHT = 79,
  F1 = 58,
  F2 = 59,
  F3 = 60,
  F4 = 61,
  F5 = 62,
  F6 = 63,
  F7 = 64,
  F8 = 65,
  F9 = 66,
  F10 = 67,
  F11 = 68,
  F12 = 69,
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
  keys: bigint;        // 64-bit keyboard state
  mouseX: number;      // Mouse X position
  mouseY: number;      // Mouse Y position
  buttons: number;     // Mouse button state
}

/**
 * Abstract base class for AI Controllers
 * Provides common functionality for both Node.js and browser implementations
 */
export abstract class AIControllerCore {
  protected frameCounter: number = 0;

  // Abstract methods that must be implemented by subclasses
  abstract connect(): Promise<void>;
  abstract disconnect(): void;
  abstract sendCommand(cmd: InputCommand): boolean;
  abstract getCurrentFrame(): number;
  abstract clear(): void;

  // Common helper methods

  /**
   * Create a movement command
   */
  move(direction: 'up' | 'down' | 'left' | 'right' | 'stop', walk: boolean = false): InputCommand {
    let keys = 0n;
    
    switch (direction) {
      case 'up':
        keys |= 1n << BigInt(Keys.W);
        break;
      case 'down':
        keys |= 1n << BigInt(Keys.S);
        break;
      case 'left':
        keys |= 1n << BigInt(Keys.A);
        break;
      case 'right':
        keys |= 1n << BigInt(Keys.D);
        break;
    }
    
    // Note: LSHIFT (225) is beyond 64-bit range, so we can't use it in the bitfield
    // The direct input system only supports scancodes 0-63
    // We would need to use a different key or extend the system
    if (walk) {
      // Use a different key that's within range, or handle separately
      // For now, we'll skip this as it's out of range
    }
    
    return {
      frame: 0,
      keys,
      mouseX: 0,
      mouseY: 0,
      buttons: 0
    };
  }

  /**
   * Create a shooting command
   */
  shoot(target: Vec2, pressed: boolean): InputCommand {
    return {
      frame: 0,
      keys: 0n,
      mouseX: target.x,
      mouseY: target.y,
      buttons: pressed ? MouseButtons.LEFT : 0
    };
  }

  /**
   * Create a spell casting command
   */
  castSpell(slot: number, target: Vec2, selfCast: boolean = false): InputCommand {
    let keys = 0n;
    
    // Map slot to key
    const slotKeys = [
      Keys.KEY_1, Keys.KEY_2, Keys.KEY_3, Keys.KEY_4,
      Keys.Q, Keys.E, Keys.R, Keys.F
    ];
    
    if (slot >= 0 && slot < slotKeys.length) {
      keys |= 1n << BigInt(slotKeys[slot]);
    }
    
    // Note: LCTRL (224) is beyond 64-bit range, so we can't use it in the bitfield
    // The direct input system only supports scancodes 0-63
    // We would need to use a different key or extend the system
    if (selfCast) {
      // Use a different key that's within range, or handle separately
      // For now, we'll skip this as it's out of range
    }
    
    return {
      frame: 0,
      keys,
      mouseX: target.x,
      mouseY: target.y,
      buttons: MouseButtons.RIGHT
    };
  }

  /**
   * Navigate to a position using pathfinding
   */
  async moveTo(position: Vec2, speed: number = 1): Promise<void> {
    // Simplified movement - real implementation would use pathfinding
    const steps = 60; // 1 second at 60 FPS
    const currentPos = { x: 400, y: 300 }; // Assume center start
    
    for (let i = 0; i < steps; i++) {
      const t = i / steps;
      const x = currentPos.x + (position.x - currentPos.x) * t;
      const y = currentPos.y + (position.y - currentPos.y) * t;
      
      // Determine movement direction
      const dx = position.x - x;
      const dy = position.y - y;
      
      let keys = 0n;
      if (Math.abs(dx) > 5) {
        keys |= 1n << BigInt(dx > 0 ? Keys.D : Keys.A);
      }
      if (Math.abs(dy) > 5) {
        keys |= 1n << BigInt(dy > 0 ? Keys.S : Keys.W);
      }
      
      // Walk if moving slowly
      // Note: LSHIFT is beyond 64-bit range, skipping
      
      this.sendCommand({
        frame: 0,
        keys,
        mouseX: position.x,
        mouseY: position.y,
        buttons: 0
      });
      
      await new Promise(r => setTimeout(r, 16));
    }
    
    // Stop at destination
    this.sendCommand(this.move('stop'));
  }

  /**
   * Execute a shooting pattern
   */
  async shootPattern(targets: Vec2[], interval: number = 150): Promise<void> {
    for (const target of targets) {
      this.sendCommand(this.shoot(target, true));
      await new Promise(r => setTimeout(r, 50));
      this.sendCommand(this.shoot(target, false));
      await new Promise(r => setTimeout(r, interval - 50));
    }
  }

  /**
   * Execute a complex action sequence
   */
  async executeSequence(actions: Array<{
    type: 'move' | 'shoot' | 'spell' | 'wait';
    data?: any;
    duration?: number;
  }>): Promise<void> {
    for (const action of actions) {
      switch (action.type) {
        case 'move':
          if (action.data?.position) {
            await this.moveTo(action.data.position, action.data.speed || 1);
          } else if (action.data?.direction) {
            const duration = action.duration || 1000;
            const steps = duration / 16;
            for (let i = 0; i < steps; i++) {
              this.sendCommand(this.move(action.data.direction, action.data.walk));
              await new Promise(r => setTimeout(r, 16));
            }
          }
          break;
          
        case 'shoot':
          this.sendCommand(this.shoot(action.data.target, true));
          await new Promise(r => setTimeout(r, 50));
          this.sendCommand(this.shoot(action.data.target, false));
          break;
          
        case 'spell':
          this.sendCommand(this.castSpell(
            action.data.slot,
            action.data.target,
            action.data.selfCast
          ));
          break;
          
        case 'wait':
          await new Promise(r => setTimeout(r, action.duration || 1000));
          break;
      }
    }
  }
}