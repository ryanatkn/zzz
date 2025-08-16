/**
 * Node.js AI Controller Implementation
 * Direct file system access to memory-mapped command buffer
 */

import * as fs from 'fs';
import { AIControllerBase } from '../core/base.js';
import type { InputCommand } from '../core/types.js';

export class NodeAIController extends AIControllerBase {
  private static readonly BUFFER_SIZE = 256;
  private static readonly COMMAND_SIZE = 32;  // Zig alignment
  private static readonly HEADER_SIZE = 24;   // Commands array offset
  private static readonly TOTAL_SIZE = NodeAIController.HEADER_SIZE + (NodeAIController.BUFFER_SIZE * NodeAIController.COMMAND_SIZE);
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
      const emptyBuffer = Buffer.alloc(NodeAIController.TOTAL_SIZE);
      fs.writeFileSync(this.path, emptyBuffer);
    }

    // Open file for read/write
    this.fd = fs.openSync(this.path, 'r+');
    
    // Read the entire buffer
    this.buffer = Buffer.alloc(NodeAIController.TOTAL_SIZE);
    fs.readSync(this.fd, this.buffer, 0, NodeAIController.TOTAL_SIZE, 0);

    // Initialize if needed
    const magic = this.buffer.readUInt32LE(0);
    if (magic !== NodeAIController.MAGIC) {
      this.buffer.writeUInt32LE(NodeAIController.MAGIC, 0);     // magic
      this.buffer.writeUInt32LE(1, 4);                          // version
      this.buffer.writeUInt32LE(0, 8);                          // write_index
      this.buffer.writeUInt32LE(0, 12);                         // read_index
      this.buffer.writeUInt32LE(0, 16);                         // current_frame
      this.buffer.writeUInt32LE(0, 20);                         // padding
      this.flush();
      console.log('✨ AI command buffer initialized');
    }
    
    console.log('✅ Connected to AI control system');
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

    // Check if buffer is full
    const nextWrite = (writeIdx + 1) % NodeAIController.BUFFER_SIZE;
    if (nextWrite === readIdx) {
      console.warn('⚠️ Command buffer full');
      return false;
    }

    // Calculate command offset
    const cmdOffset = NodeAIController.HEADER_SIZE + (writeIdx * NodeAIController.COMMAND_SIZE);

    // Pack command with valid flag
    const buttons = cmd.buttons | NodeAIController.VALID_FLAG;

    // Write command data (matching Zig's InputCommand layout)
    this.buffer.writeUInt32LE(cmd.frame, cmdOffset + 0);       // frame
    this.buffer.writeUInt32LE(0, cmdOffset + 4);               // padding
    this.buffer.writeBigUInt64LE(cmd.keys, cmdOffset + 8);     // keys
    this.buffer.writeFloatLE(cmd.mouseX, cmdOffset + 16);      // mouseX
    this.buffer.writeFloatLE(cmd.mouseY, cmdOffset + 20);      // mouseY
    this.buffer.writeUInt8(buttons, cmdOffset + 24);           // buttons
    // Padding bytes 25-31 remain zero

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
    console.log('🧹 Command buffer cleared');
  }

  private flush(): void {
    if (this.fd !== null && this.buffer) {
      fs.writeSync(this.fd, this.buffer, 0, NodeAIController.TOTAL_SIZE, 0);
    }
  }

  private sync(): void {
    if (this.fd !== null && this.buffer) {
      fs.readSync(this.fd, this.buffer, 0, NodeAIController.TOTAL_SIZE, 0);
    }
  }
}