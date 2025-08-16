/**
 * Browser AI Controller Example for Hex Game
 * 
 * This is pure frontend code that demonstrates using the AI control system
 * from the browser. It uses the browser-compatible AIController from 
 * ai_control_client.ts which sends commands via Vite HMR.
 */

import AIController, { type Vec2 } from './ai_control_client.ts';

// High-level game control examples

/**
 * Example: Run to the portal on the right and shoot the first enemy
 */
export async function runToPortalAndShoot() {
  const ai = new AIController();
  await ai.connect();

  console.log('Running to portal and shooting first enemy...');

  // Run right to the portal
  await ai.executeSequence([
    { type: 'move', data: { direction: 'right' }, duration: 2000 },
    { type: 'wait', duration: 500 },
    // Shoot at typical enemy position
    { type: 'shoot', data: { target: { x: 600, y: 300 } } },
    { type: 'wait', duration: 200 },
    { type: 'shoot', data: { target: { x: 600, y: 300 } } },
  ]);

  ai.disconnect();
  console.log('Portal rush complete!');
}

/**
 * Example: Clear a room of enemies
 */
export async function clearRoom() {
  const ai = new AIController();
  await ai.connect();

  console.log('Clearing room...');

  // Common enemy positions in a room
  const enemyPositions: Vec2[] = [
    { x: 200, y: 200 },
    { x: 600, y: 200 },
    { x: 200, y: 400 },
    { x: 600, y: 400 },
    { x: 400, y: 300 },
  ];

  // Shoot at each position
  await ai.shootPattern(enemyPositions, 200);

  // Cast AoE spell for cleanup
  await ai.executeSequence([
    { type: 'spell', data: { slot: 0, target: { x: 400, y: 300 }, selfCast: false } },
    { type: 'wait', duration: 1000 },
  ]);

  ai.disconnect();
  console.log('Room cleared!');
}

/**
 * Example: Kite enemies in a circle
 */
export async function kiteEnemies() {
  const ai = new AIController();
  await ai.connect();

  console.log('Kiting enemies...');

  const centerX = 400;
  const centerY = 300;
  const radius = 150;

  // Move in a circle while shooting at center
  for (let angle = 0; angle < 360; angle += 10) {
    const rad = angle * Math.PI / 180;
    const x = centerX + radius * Math.cos(rad);
    const y = centerY + radius * Math.sin(rad);

    // Move to position
    ai.sendCommand({
      frame: 0,
      keys: 0n,
      mouseX: x,
      mouseY: y,
      buttons: 0
    });

    // Shoot at center every 30 degrees
    if (angle % 30 === 0) {
      await ai.executeSequence([
        { type: 'shoot', data: { target: { x: centerX, y: centerY } } },
      ]);
    }

    await new Promise(r => setTimeout(r, 50));
  }

  ai.disconnect();
  console.log('Kiting complete!');
}

/**
 * Example: Speed run to boss
 */
export async function speedRunToBoss() {
  const ai = new AIController();
  await ai.connect();

  console.log('Speed running to boss...');

  await ai.executeSequence([
    // Sprint right through first area
    { type: 'move', data: { direction: 'right', walk: false }, duration: 3000 },
    // Enter portal
    { type: 'wait', duration: 500 },
    // Sprint up in new zone
    { type: 'move', data: { direction: 'up', walk: false }, duration: 2000 },
    // Enter boss portal
    { type: 'wait', duration: 500 },
    // Cast buff spell
    { type: 'spell', data: { slot: 1, target: { x: 400, y: 300 }, selfCast: true } },
    { type: 'wait', duration: 1000 },
  ]);

  ai.disconnect();
  console.log('Reached boss room!');
}

/**
 * Example: Farm experience in safe zone
 */
export async function farmExperience() {
  const ai = new AIController();
  await ai.connect();

  console.log('Farming experience...');

  // Patrol pattern hitting spawn points
  const patrolPath: Vec2[] = [
    { x: 200, y: 200 },
    { x: 600, y: 200 },
    { x: 600, y: 400 },
    { x: 200, y: 400 },
  ];

  for (let round = 0; round < 5; round++) {
    console.log(`Farm round ${round + 1}/5`);
    
    for (const point of patrolPath) {
      // Move to spawn point
      await ai.moveTo(point, 1);
      
      // Clear any spawns
      await ai.shootPattern([
        point,
        { x: point.x + 50, y: point.y },
        { x: point.x - 50, y: point.y },
        { x: point.x, y: point.y + 50 },
        { x: point.x, y: point.y - 50 },
      ], 100);
      
      await new Promise(r => setTimeout(r, 500));
    }
  }

  ai.disconnect();
  console.log('Farming complete!');
}

/**
 * Interactive AI Controller
 * Can be instantiated and used directly in the browser console
 */
export class InteractiveAI {
  private ai: AIController;
  private connected: boolean = false;

  constructor() {
    this.ai = new AIController();
  }

  async connect(): Promise<void> {
    await this.ai.connect();
    this.connected = true;
    console.log('AI Controller connected - use commands like ai.moveRight(), ai.shoot(), etc.');
  }

  disconnect(): void {
    this.ai.disconnect();
    this.connected = false;
    console.log('AI Controller disconnected');
  }

  // Movement commands
  moveUp(duration: number = 1000): void {
    this.executeMove('up', duration);
  }

  moveDown(duration: number = 1000): void {
    this.executeMove('down', duration);
  }

  moveLeft(duration: number = 1000): void {
    this.executeMove('left', duration);
  }

  moveRight(duration: number = 1000): void {
    this.executeMove('right', duration);
  }

  walk(): void {
    this.ai.sendCommand(this.ai.move('stop', true));
  }

  stop(): void {
    this.ai.sendCommand(this.ai.move('stop'));
  }

  private async executeMove(direction: 'up' | 'down' | 'left' | 'right', duration: number) {
    if (!this.connected) {
      console.error('Not connected! Call ai.connect() first');
      return;
    }

    const steps = duration / 16;
    for (let i = 0; i < steps; i++) {
      this.ai.sendCommand(this.ai.move(direction));
      await new Promise(r => setTimeout(r, 16));
    }
    this.stop();
  }

  // Combat commands
  async shoot(x: number = 400, y: number = 300): Promise<void> {
    if (!this.connected) {
      console.error('Not connected! Call ai.connect() first');
      return;
    }

    this.ai.sendCommand(this.ai.shoot({ x, y }, true));
    await new Promise(r => setTimeout(r, 50));
    this.ai.sendCommand(this.ai.shoot({ x, y }, false));
  }

  castSpell(slot: number, x: number = 400, y: number = 300, selfCast: boolean = false): void {
    if (!this.connected) {
      console.error('Not connected! Call ai.connect() first');
      return;
    }

    this.ai.sendCommand(this.ai.castSpell(slot, { x, y }, selfCast));
  }

  // Utility
  clear(): void {
    this.ai.clear();
    console.log('Command buffer cleared');
  }

  getFrame(): number {
    return this.ai.getCurrentFrame();
  }
}

// Export for browser console usage
if (typeof window !== 'undefined') {
  (window as any).AIExamples = {
    runToPortalAndShoot,
    clearRoom,
    kiteEnemies,
    speedRunToBoss,
    farmExperience,
    InteractiveAI,
  };
  
  console.log(`
AI Control Examples loaded! Try these in the console:

Quick examples:
- AIExamples.runToPortalAndShoot()
- AIExamples.clearRoom()
- AIExamples.kiteEnemies()
- AIExamples.speedRunToBoss()
- AIExamples.farmExperience()

Interactive control:
const ai = new AIExamples.InteractiveAI();
await ai.connect();
ai.moveRight();
ai.shoot(600, 300);
ai.castSpell(0, 400, 300);
ai.disconnect();
  `);
}

export default InteractiveAI;