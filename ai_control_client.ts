/**
 * Browser-side AI Controller using Vite HMR WebSocket
 * 
 * This is the browser implementation that communicates with the game
 * via Vite's HMR WebSocket, which then writes to the memory-mapped file.
 */

import { AIControllerCore, type Vec2, type InputCommand } from './ai_control_core.ts';

// Re-export everything from core for convenience
export * from './ai_control_core.ts';

/**
 * Browser AI Controller using Vite HMR
 */
export class AIController extends AIControllerCore {
  private connected = false;
  private currentFrame = 0;

  constructor() {
    super();
    
    // Set up HMR listeners if available
    if (import.meta.hot) {
      import.meta.hot.on('ai:connected', () => {
        this.connected = true;
        console.log('AI Controller connected via Vite HMR');
      });

      import.meta.hot.on('ai:frame', (data: { frame: number }) => {
        this.currentFrame = data.frame;
      });

      import.meta.hot.on('ai:command-result', (data: { success: boolean }) => {
        if (!data.success) {
          console.warn('Command failed to send');
        }
      });
    }
  }

  async connect(): Promise<void> {
    // Connection is automatic via HMR
    this.connected = true;
    return Promise.resolve();
  }

  disconnect(): void {
    this.connected = false;
  }

  sendCommand(cmd: InputCommand): boolean {
    if (!this.connected || !import.meta.hot) return false;

    // Convert bigint to string for serialization
    const serialized = {
      frame: cmd.frame,
      keys: cmd.keys.toString(),
      mouseX: cmd.mouseX,
      mouseY: cmd.mouseY,
      buttons: cmd.buttons
    };

    import.meta.hot.send('ai:command', serialized);
    return true;
  }

  getCurrentFrame(): number {
    if (import.meta.hot) {
      import.meta.hot.send('ai:get-frame', {});
    }
    return this.currentFrame;
  }

  clear(): void {
    if (import.meta.hot) {
      import.meta.hot.send('ai:clear', {});
    }
  }
}

// Demo functions for browser usage
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
    const steps = duration / 16;
    
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