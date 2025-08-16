/**
 * Vite plugin for AI control system
 * Handles communication between browser and game via file system
 * Uses the Node.js AI Controller for file operations
 */

import { Plugin, ViteDevServer } from 'vite';
import { AIController } from './ai_control_node.ts';
import type { InputCommand } from './ai_control_core.ts';

interface SerializedCommand {
  frame: number;
  keys: string; // bigint serialized as string
  mouseX: number;
  mouseY: number;
  buttons: number;
}

export function aiControlPlugin(): Plugin {
  let server: ViteDevServer;
  let controller: AIController | null = null;
  let commandCount = 0;
  let lastLogTime = Date.now();
  let lastFrameLogTime = Date.now();
  let frameQueryCount = 0;

  return {
    name: 'vite-plugin-ai-control',
    
    async configureServer(devServer) {
      server = devServer;
      
      // Initialize controller when server starts
      try {
        controller = new AIController();
        await controller.connect();
        console.log('🎮 AI Control plugin: Controller connected to .ai_commands file');
        console.log('📍 Command buffer initialized with magic: 0xA1C0DE42');
      } catch (error) {
        console.error('❌ AI Control plugin: Failed to connect controller:', error);
      }

      // Listen for commands from client
      server.ws.on('ai:command', (data: SerializedCommand, client) => {
        if (!controller) {
          console.error('❌ Command rejected: Controller not connected');
          client.send('ai:command-result', { success: false, error: 'Controller not connected' });
          return;
        }

        commandCount++;
        
        // Convert serialized command to InputCommand
        // Validate and clamp the keys value to 64-bit range
        let keys: bigint;
        let keysInfo = '';
        try {
          keys = BigInt(data.keys);
          
          // Log which keys are pressed and map to SDL scancode names
          const pressedKeys: string[] = [];
          const keyNames: { [key: number]: string } = {
            4: 'A', 5: 'B', 6: 'C', 7: 'D', 8: 'E', 9: 'F', 10: 'G', 11: 'H',
            12: 'I', 13: 'J', 14: 'K', 15: 'L', 16: 'M', 17: 'N', 18: 'O', 19: 'P',
            20: 'Q', 21: 'R', 22: 'S', 23: 'T', 24: 'U', 25: 'V', 26: 'W', 27: 'X',
            28: 'Y', 29: 'Z', 30: '1', 31: '2', 32: '3', 33: '4', 34: '5', 35: '6',
            36: '7', 37: '8', 38: '9', 39: '0', 44: 'SPACE'
          };
          
          if (keys > 0n) {
            for (let i = 0; i < 64; i++) {
              if (keys & (1n << BigInt(i))) {
                const keyName = keyNames[i] || `bit${i}`;
                pressedKeys.push(keyName);
              }
            }
            keysInfo = pressedKeys.length > 0 ? ` Keys: [${pressedKeys.join(', ')}]` : '';
          }
          
          // Ensure it's within valid u64 range
          if (keys < 0n) {
            console.warn('⚠️ Negative keys value, clamping to 0');
            keys = 0n;
          }
          if (keys >= (1n << 64n)) {
            console.warn(`⚠️ Keys value out of range: ${keys.toString()}, clamping to max u64`);
            keys = (1n << 64n) - 1n;
          }
        } catch (e) {
          console.error('❌ Invalid keys value:', data.keys);
          keys = 0n;
        }

        const cmd: InputCommand = {
          frame: data.frame,
          keys: keys,
          mouseX: data.mouseX,
          mouseY: data.mouseY,
          buttons: data.buttons
        };

        const success = controller.sendCommand(cmd);
        
        // Log command details
        const now = Date.now();
        if (now - lastLogTime > 100) { // Throttle logging to every 100ms
          console.log(`📤 Command #${commandCount}: Frame=${cmd.frame} Mouse=(${cmd.mouseX.toFixed(0)},${cmd.mouseY.toFixed(0)}) Buttons=${cmd.buttons}${keysInfo}`);
          lastLogTime = now;
        }
        
        client.send('ai:command-result', { success });
      });

      server.ws.on('ai:get-frame', (_, client) => {
        if (!controller) {
          client.send('ai:frame', { frame: 0 });
          return;
        }
        
        const frame = controller.getCurrentFrame();
        frameQueryCount++;
        
        // Only log frame queries every second to reduce spam
        const now = Date.now();
        if (now - lastFrameLogTime > 1000) {
          console.log(`🔍 Frame queries: ${frameQueryCount} in last second, current frame = ${frame}`);
          frameQueryCount = 0;
          lastFrameLogTime = now;
        }
        
        client.send('ai:frame', { frame });
      });

      server.ws.on('ai:clear', (_, client) => {
        if (!controller) {
          console.error('❌ Clear rejected: Controller not connected');
          client.send('ai:clear-result', { success: false });
          return;
        }

        controller.clear();
        console.log('🧹 Command buffer cleared');
        commandCount = 0;
        client.send('ai:clear-result', { success: true });
      });

      // Send connection confirmation
      server.ws.on('connection', () => {
        const connected = controller !== null;
        console.log(`🔌 WebSocket client connected. AI Control status: ${connected ? '✅ Ready' : '❌ Not ready'}`);
        server.ws.send('ai:connected', { connected });
      });
    },

    closeBundle() {
      // Clean up controller
      if (controller) {
        controller.disconnect();
        controller = null;
      }
    }
  };
}

export default aiControlPlugin;