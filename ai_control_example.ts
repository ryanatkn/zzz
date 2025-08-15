/**
 * TypeScript AI Controller for Hex Game
 * 
 * This provides a TypeScript interface to control the game via the memory-mapped
 * command buffer. It can be used in Node.js/Deno with file system access,
 * or in the browser with a WebSocket bridge.
 */

import * as fs from 'fs';
import * as path from 'path';

// Vector type
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

// Command structure matching the Zig implementation
export interface InputCommand {
  frame: number;      // Target frame (0 = immediate)
  keys: bigint;       // 64-bit key state
  mouseX: number;     // Mouse X position
  mouseY: number;     // Mouse Y position
  buttons: number;    // Mouse buttons + valid flag
}

/**
 * AI Controller class for game control
 */
export class AIController {
  private static readonly BUFFER_SIZE = 256;
  private static readonly COMMAND_SIZE = 20;
  private static readonly HEADER_SIZE = 20;
  private static readonly TOTAL_SIZE = AIController.HEADER_SIZE + (AIController.BUFFER_SIZE * AIController.COMMAND_SIZE);
  private static readonly MAGIC = 0xA1C0DE42;
  private static readonly VALID_FLAG = 0x80;

  private fd: number | null = null;
  private buffer: Buffer | null = null;
  private readonly path: string;

  constructor(path: string = '.ai_commands') {
    this.path = path;
  }

  /**
   * Connect to the game's command buffer
   */
  async connect(): Promise<void> {
    // Create file if it doesn't exist
    if (!fs.existsSync(this.path)) {
      const emptyBuffer = Buffer.alloc(AIController.TOTAL_SIZE);
      fs.writeFileSync(this.path, emptyBuffer);
    }

    // Open file for read/write
    this.fd = fs.openSync(this.path, 'r+');
    
    // Read the entire buffer
    this.buffer = Buffer.alloc(AIController.TOTAL_SIZE);
    fs.readSync(this.fd, this.buffer, 0, AIController.TOTAL_SIZE, 0);

    // Initialize if needed
    const magic = this.buffer.readUInt32LE(0);
    if (magic !== AIController.MAGIC) {
      this.buffer.writeUInt32LE(AIController.MAGIC, 0);     // magic
      this.buffer.writeUInt32LE(1, 4);                      // version
      this.buffer.writeUInt32LE(0, 8);                      // write_index
      this.buffer.writeUInt32LE(0, 12);                     // read_index
      this.buffer.writeUInt32LE(0, 16);                     // current_frame
      this.flush();
    }
  }

  /**
   * Disconnect from the command buffer
   */
  disconnect(): void {
    if (this.fd !== null) {
      fs.closeSync(this.fd);
      this.fd = null;
      this.buffer = null;
    }
  }

  /**
   * Send a command to the game
   */
  sendCommand(cmd: InputCommand): boolean {
    if (!this.buffer) throw new Error('Not connected');

    // Read indices
    const writeIdx = this.buffer.readUInt32LE(8);
    const readIdx = this.buffer.readUInt32LE(12);

    // Check if buffer is full
    const nextWrite = (writeIdx + 1) % AIController.BUFFER_SIZE;
    if (nextWrite === readIdx) {
      console.warn('Command buffer full');
      return false;
    }

    // Calculate command offset
    const cmdOffset = AIController.HEADER_SIZE + (writeIdx * AIController.COMMAND_SIZE);

    // Pack command with valid flag
    const buttons = cmd.buttons | AIController.VALID_FLAG;

    // Write command data
    this.buffer.writeUInt32LE(cmd.frame, cmdOffset);
    this.buffer.writeBigUInt64LE(cmd.keys, cmdOffset + 4);
    this.buffer.writeFloatLE(cmd.mouseX, cmdOffset + 12);
    this.buffer.writeFloatLE(cmd.mouseY, cmdOffset + 16);
    this.buffer.writeUInt8(buttons, cmdOffset + 20);
    // Padding bytes are already zero

    // Update write index
    this.buffer.writeUInt32LE(nextWrite, 8);

    // Flush to file
    this.flush();
    return true;
  }

  /**
   * Get the current frame number from the game
   */
  getCurrentFrame(): number {
    if (!this.buffer) throw new Error('Not connected');
    this.sync();
    return this.buffer.readUInt32LE(16);
  }

  /**
   * Clear all pending commands
   */
  clear(): void {
    if (!this.buffer) throw new Error('Not connected');
    const writeIdx = this.buffer.readUInt32LE(8);
    this.buffer.writeUInt32LE(writeIdx, 12); // read_index = write_index
    this.flush();
  }

  /**
   * Flush buffer to file
   */
  private flush(): void {
    if (this.fd !== null && this.buffer) {
      fs.writeSync(this.fd, this.buffer, 0, AIController.TOTAL_SIZE, 0);
    }
  }

  /**
   * Sync buffer from file
   */
  private sync(): void {
    if (this.fd !== null && this.buffer) {
      fs.readSync(this.fd, this.buffer, 0, AIController.TOTAL_SIZE, 0);
    }
  }

  // High-level command builders

  /**
   * Create a movement command
   */
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

  /**
   * Create a shoot command
   */
  shoot(target: Vec2, hold: boolean = false): InputCommand {
    return {
      frame: 0,
      keys: 0n,
      mouseX: target.x,
      mouseY: target.y,
      buttons: hold ? MouseButtons.LEFT : 0
    };
  }

  /**
   * Create a spell cast command
   */
  castSpell(slot: number, target: Vec2, selfCast: boolean = false): InputCommand {
    let keys = 0n;

    // Select spell slot
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

    // Add Ctrl for self-cast
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

  /**
   * Execute a sequence of commands with delays
   */
  async executeSequence(commands: Array<{ cmd: InputCommand, delayMs: number }>): Promise<void> {
    for (const { cmd, delayMs } of commands) {
      this.sendCommand(cmd);
      await this.sleep(delayMs);
    }
  }

  /**
   * Move to a specific position
   */
  async moveTo(target: Vec2, speedMultiplier: number = 1.0): Promise<void> {
    const steps = 60; // Approximate steps
    const delayMs = 16; // ~60 FPS

    for (let i = 0; i < steps; i++) {
      const cmd: InputCommand = {
        frame: 0,
        keys: 1n << BigInt(Keys.LCTRL), // Ctrl for mouse movement
        mouseX: target.x,
        mouseY: target.y,
        buttons: MouseButtons.LEFT
      };
      
      this.sendCommand(cmd);
      await this.sleep(delayMs / speedMultiplier);
    }

    // Release
    this.sendCommand({
      frame: 0,
      keys: 0n,
      mouseX: target.x,
      mouseY: target.y,
      buttons: 0
    });
  }

  /**
   * Shoot in a pattern
   */
  async shootPattern(pattern: Vec2[], holdTime: number = 150): Promise<void> {
    for (const target of pattern) {
      // Start shooting
      this.sendCommand(this.shoot(target, true));
      await this.sleep(holdTime);
      
      // Stop shooting
      this.sendCommand(this.shoot(target, false));
      await this.sleep(50);
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Example usage functions

/**
 * Demo: Move in a square pattern
 */
export async function demoMovement() {
  const ai = new AIController();
  await ai.connect();

  console.log('Moving in square pattern...');
  
  const movements = [
    { direction: 'right' as const, duration: 1000 },
    { direction: 'down' as const, duration: 1000 },
    { direction: 'left' as const, duration: 1000 },
    { direction: 'up' as const, duration: 1000 },
  ];

  for (const { direction, duration } of movements) {
    console.log(`Moving ${direction}...`);
    const steps = duration / 16; // 60 FPS
    
    for (let i = 0; i < steps; i++) {
      ai.sendCommand(ai.move(direction));
      await new Promise(r => setTimeout(r, 16));
    }
  }

  ai.sendCommand(ai.move('stop'));
  ai.disconnect();
  console.log('Movement demo complete!');
}

/**
 * Demo: Combat patterns
 */
export async function demoCombat() {
  const ai = new AIController();
  await ai.connect();

  console.log('Executing combat patterns...');

  // Shoot in a circle
  const radius = 200;
  const centerX = 400;
  const centerY = 300;
  const points: Vec2[] = [];

  for (let angle = 0; angle < 360; angle += 30) {
    const rad = angle * Math.PI / 180;
    points.push({
      x: centerX + radius * Math.cos(rad),
      y: centerY + radius * Math.sin(rad)
    });
  }

  await ai.shootPattern(points);

  ai.disconnect();
  console.log('Combat demo complete!');
}

// Export for use in other modules
export default AIController;