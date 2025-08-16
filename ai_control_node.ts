/**
 * Node.js AI Controller for Hex Game
 * 
 * This is the Node.js-specific implementation that directly accesses
 * the memory-mapped command buffer file system.
 */

import * as fs from 'fs';

// Import types from the core module
import { AIControllerCore, Keys, MouseButtons } from './ai_control_core.ts';
import type { Vec2, InputCommand } from './ai_control_core.ts';

// Re-export for convenience
export { Keys, MouseButtons };
export type { Vec2, InputCommand };

/**
 * Node.js implementation of AI Controller
 */
export class AIController extends AIControllerCore {
  private static readonly BUFFER_SIZE = 256;
  private static readonly COMMAND_SIZE = 32;  // Zig reports 32 bytes due to alignment
  private static readonly HEADER_SIZE = 24;   // Zig reports commands array offset at 24, not 20
  private static readonly TOTAL_SIZE = AIController.HEADER_SIZE + (AIController.BUFFER_SIZE * AIController.COMMAND_SIZE);
  private static readonly MAGIC = 0xA1C0DE42;
  private static readonly VALID_FLAG = 0x80;

  private fd: number | null = null;
  private buffer: Buffer | null = null;
  private readonly path: string;

  constructor(path: string = '.ai_commands') {
    super();
    this.path = path;
  }

  async connect(): Promise<void> {
    console.log(`🔗 Connecting to AI command buffer: ${this.path}`);
    
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
      this.buffer.writeUInt32LE(0, 8);                      // write_index (atomic)
      this.buffer.writeUInt32LE(0, 12);                     // read_index
      this.buffer.writeUInt32LE(0, 16);                     // current_frame (atomic)
      this.buffer.writeUInt32LE(0, 20);                     // padding to align commands array
      this.flush();
      console.log('✨ AI command buffer initialized');
    }
  }

  disconnect(): void {
    if (this.fd !== null) {
      console.log('🔌 Disconnecting from command buffer...');
      fs.closeSync(this.fd);
      this.fd = null;
      this.buffer = null;
      console.log('👋 Disconnected');
    }
  }

  sendCommand(cmd: InputCommand): boolean {
    if (!this.buffer) throw new Error('Not connected');

    // Read indices
    const writeIdx = this.buffer.readUInt32LE(8);
    const readIdx = this.buffer.readUInt32LE(12);
    
    console.log(`📝 Writing command: Write=${writeIdx}, Read=${readIdx}`);

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

    // Write command data (matching Zig's exact InputCommand layout)
    // Zig layout: frame@0, keys@8, mouse_x@16, mouse_y@20, buttons@24, padding@25
    this.buffer.writeUInt32LE(cmd.frame, cmdOffset + 0);       // frame at offset 0
    // 4 bytes padding for alignment (bytes 4-7) - filled with zeros
    this.buffer.writeUInt32LE(0, cmdOffset + 4);               // clear padding
    this.buffer.writeBigUInt64LE(cmd.keys, cmdOffset + 8);     // keys at offset 8
    this.buffer.writeFloatLE(cmd.mouseX, cmdOffset + 16);      // mouseX at offset 16  
    this.buffer.writeFloatLE(cmd.mouseY, cmdOffset + 20);      // mouseY at offset 20
    this.buffer.writeUInt8(buttons, cmdOffset + 24);           // buttons at offset 24
    // Padding bytes 25-27 are already zero
    
    // Optional: Log for debugging (comment out for cleaner output)
    // const cmdBytes = this.buffer.subarray(cmdOffset, cmdOffset + AIController.COMMAND_SIZE);
    // console.log(`📝 Written command bytes: ${cmdBytes.toString('hex')}`);
    // console.log(`📊 Command: frame=${cmd.frame}, keys=0x${cmd.keys.toString(16)}, mouse=(${cmd.mouseX},${cmd.mouseY}), buttons=0x${buttons.toString(16)}`);

    // Update write index
    this.buffer.writeUInt32LE(nextWrite, 8);

    // Flush to file
    this.flush();
    return true;
  }

  getCurrentFrame(): number {
    if (!this.buffer) throw new Error('Not connected');
    this.sync();
    return this.buffer.readUInt32LE(16);
  }

  clear(): void {
    if (!this.buffer) throw new Error('Not connected');
    const writeIdx = this.buffer.readUInt32LE(8);
    this.buffer.writeUInt32LE(writeIdx, 12); // read_index = write_index
    this.flush();
  }

  private flush(): void {
    if (this.fd !== null && this.buffer) {
      fs.writeSync(this.fd, this.buffer, 0, AIController.TOTAL_SIZE, 0);
    }
  }

  private sync(): void {
    if (this.fd !== null && this.buffer) {
      fs.readSync(this.fd, this.buffer, 0, AIController.TOTAL_SIZE, 0);
    }
  }
}

// Demo functions for Node.js
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

export default AIController;