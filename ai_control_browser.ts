/**
 * Browser-compatible AI Controller for Hex Game
 * Uses Vite dev server as a proxy to send commands to the game
 */

export interface Vec2 {
  x: number;
  y: number;
}

// Key mappings (SDL scancodes)
export const Keys = {
  W: 26,
  A: 4,
  S: 22,
  D: 7,
  SPACE: 44,
  LSHIFT: 225,
  LCTRL: 224,
  '1': 30,
  '2': 31,
  '3': 32,
  '4': 33,
  Q: 20,
  E: 8,
  R: 21,
  F: 9,
} as const;

// Mouse button flags
export const MouseButtons = {
  LEFT: 0x01,
  RIGHT: 0x02,
  MIDDLE: 0x04,
} as const;

export interface InputCommand {
  frame: number;
  keys: bigint;
  mouseX: number;
  mouseY: number;
  buttons: number;
}

/**
 * Browser-based AI Controller using WebSocket or fetch
 */
export class AIController {
  private ws: WebSocket | null = null;
  private connected = false;
  
  async connect(): Promise<void> {
    // In dev, we'll use Vite's server to proxy commands
    // For now, we'll just simulate connection
    this.connected = true;
    console.log('AI Controller connected (simulated)');
  }
  
  disconnect(): void {
    this.connected = false;
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
  
  sendCommand(cmd: InputCommand): boolean {
    if (!this.connected) return false;
    
    // In a real implementation, we'd send this to a backend service
    // For now, we'll use console.log to show the command
    console.log('Command:', {
      frame: cmd.frame,
      keys: cmd.keys.toString(16),
      mouse: `(${cmd.mouseX}, ${cmd.mouseY})`,
      buttons: cmd.buttons
    });
    
    // You could also use fetch to send to a local server:
    // fetch('/api/command', {
    //   method: 'POST',
    //   body: JSON.stringify(cmd)
    // });
    
    return true;
  }
  
  getCurrentFrame(): number {
    // Simulated frame counter
    return Math.floor(performance.now() / 16.67);
  }
  
  clear(): void {
    console.log('Clearing command buffer');
  }
  
  // Command builders
  move(direction: 'up' | 'down' | 'left' | 'right' | 'stop', walk: boolean = false): InputCommand {
    let keys = 0n;
    
    switch (direction) {
      case 'up': keys |= 1n << BigInt(Keys.W); break;
      case 'down': keys |= 1n << BigInt(Keys.S); break;
      case 'left': keys |= 1n << BigInt(Keys.A); break;
      case 'right': keys |= 1n << BigInt(Keys.D); break;
    }
    
    if (walk) {
      keys |= 1n << BigInt(Keys.LSHIFT);
    }
    
    return {
      frame: 0,
      keys,
      mouseX: 400,
      mouseY: 300,
      buttons: 0
    };
  }
  
  shoot(target: Vec2, hold: boolean = false): InputCommand {
    return {
      frame: 0,
      keys: 0n,
      mouseX: target.x,
      mouseY: target.y,
      buttons: hold ? MouseButtons.LEFT : 0
    };
  }
  
  castSpell(slot: number, target: Vec2, selfCast: boolean = false): InputCommand {
    let keys = 0n;
    
    if (slot >= 0 && slot < 4) {
      keys |= 1n << BigInt(Keys['1'] + slot);
    } else if (slot === 4) {
      keys |= 1n << BigInt(Keys.Q);
    } else if (slot === 5) {
      keys |= 1n << BigInt(Keys.E);
    } else if (slot === 6) {
      keys |= 1n << BigInt(Keys.R);
    } else if (slot === 7) {
      keys |= 1n << BigInt(Keys.F);
    }
    
    if (selfCast) {
      keys |= 1n << BigInt(Keys.LCTRL);
    }
    
    return {
      frame: 0,
      keys,
      mouseX: target.x,
      mouseY: target.y,
      buttons: MouseButtons.RIGHT
    };
  }
  
  async executeSequence(commands: Array<{ cmd: InputCommand, delayMs: number }>): Promise<void> {
    for (const { cmd, delayMs } of commands) {
      this.sendCommand(cmd);
      await new Promise(r => setTimeout(r, delayMs));
    }
  }
  
  async moveTo(target: Vec2, speedMultiplier: number = 1.0): Promise<void> {
    const steps = 60;
    const delayMs = 16;
    
    for (let i = 0; i < steps; i++) {
      const cmd: InputCommand = {
        frame: 0,
        keys: 1n << BigInt(Keys.LCTRL),
        mouseX: target.x,
        mouseY: target.y,
        buttons: MouseButtons.LEFT
      };
      
      this.sendCommand(cmd);
      await new Promise(r => setTimeout(r, delayMs / speedMultiplier));
    }
    
    this.sendCommand({
      frame: 0,
      keys: 0n,
      mouseX: target.x,
      mouseY: target.y,
      buttons: 0
    });
  }
  
  async shootPattern(pattern: Vec2[], holdTime: number = 150): Promise<void> {
    for (const target of pattern) {
      this.sendCommand(this.shoot(target, true));
      await new Promise(r => setTimeout(r, holdTime));
      this.sendCommand(this.shoot(target, false));
      await new Promise(r => setTimeout(r, 50));
    }
  }
}

export default AIController;