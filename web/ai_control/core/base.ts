/**
 * Abstract Base AI Controller
 * Provides common functionality for all controller implementations
 */

import { Keys, MouseButtons, type Vec2, type InputCommand, type ActionSequence } from './types.js';

export abstract class AIControllerBase {
  protected frameCounter: number = 0;

  // Abstract methods that must be implemented by subclasses
  abstract connect(): Promise<void>;
  abstract disconnect(): void;
  abstract sendCommand(cmd: InputCommand): boolean;
  abstract getCurrentFrame(): number;
  abstract clear(): void;

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
    
    // Note: Modifier keys like Shift are beyond the 64-bit range
    // Would need protocol extension to support walk modifier
    
    return {
      frame: 0,
      keys,
      mouseX: 400,
      mouseY: 300,
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
    
    return {
      frame: 0,
      keys,
      mouseX: target.x,
      mouseY: target.y,
      buttons: MouseButtons.RIGHT
    };
  }

  /**
   * Press a specific key
   */
  pressKey(key: Keys): InputCommand {
    return {
      frame: 0,
      keys: 1n << BigInt(key),
      mouseX: 400,
      mouseY: 300,
      buttons: 0
    };
  }

  /**
   * Navigate to a position using simple interpolation
   */
  async moveTo(position: Vec2, speed: number = 1): Promise<void> {
    const steps = Math.floor(60 / speed); // Adjust steps based on speed
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
      
      this.sendCommand({
        frame: 0,
        keys,
        mouseX: position.x,
        mouseY: position.y,
        buttons: 0
      });
      
      await this.wait(16);
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
      await this.wait(50);
      this.sendCommand(this.shoot(target, false));
      await this.wait(interval - 50);
    }
  }

  /**
   * Execute a burst fire at target
   */
  async burstFire(target: Vec2, shots: number = 3, interval: number = 100): Promise<void> {
    for (let i = 0; i < shots; i++) {
      this.sendCommand(this.shoot(target, true));
      await this.wait(50);
      this.sendCommand(this.shoot(target, false));
      if (i < shots - 1) {
        await this.wait(interval - 50);
      }
    }
  }

  /**
   * Execute a complex action sequence
   */
  async executeSequence(actions: ActionSequence): Promise<void> {
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
              await this.wait(16);
            }
            this.sendCommand(this.move('stop'));
          }
          break;
          
        case 'shoot':
          if (action.data.burst) {
            await this.burstFire(action.data.target);
          } else {
            this.sendCommand(this.shoot(action.data.target, true));
            await this.wait(50);
            this.sendCommand(this.shoot(action.data.target, false));
          }
          break;
          
        case 'spell':
          // Select spell slot
          this.sendCommand(this.pressKey(this.getSpellKey(action.data.slot)));
          await this.wait(100);
          // Cast spell
          this.sendCommand(this.castSpell(
            action.data.slot,
            action.data.target,
            action.data.selfCast
          ));
          break;
          
        case 'wait':
          await this.wait(action.duration);
          break;
          
        case 'interact':
          this.sendCommand(this.pressKey(action.data.key));
          await this.wait(100);
          break;
      }
    }
  }

  /**
   * Helper to get spell key for slot
   */
  private getSpellKey(slot: number): Keys {
    const slotKeys = [
      Keys.KEY_1, Keys.KEY_2, Keys.KEY_3, Keys.KEY_4,
      Keys.Q, Keys.E, Keys.R, Keys.F
    ];
    return slotKeys[slot] || Keys.KEY_1;
  }

  /**
   * Wait for specified milliseconds
   */
  protected wait(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}