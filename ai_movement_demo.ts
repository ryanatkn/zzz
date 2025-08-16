#!/usr/bin/env npx tsx

/**
 * AI Movement Demo - Shows working AI control
 * 
 * Make sure to press G in the game to enable AI control mode first!
 */

import { AIController } from './ai_control_node.ts';

async function demonstrateMovement() {
  console.log('🎮 AI Movement Demo');
  console.log('📋 Make sure to press G in the game first to enable AI control!');
  console.log('');
  
  const ai = new AIController();
  await ai.connect();
  
  console.log('🏃 Starting movement sequence...');
  
  // Move in a square pattern using helper methods
  const movements = [
    { direction: 'right' as const, emoji: '➡️', duration: 1500 },
    { direction: 'up' as const, emoji: '⬆️', duration: 1500 },
    { direction: 'left' as const, emoji: '⬅️', duration: 1500 },
    { direction: 'down' as const, emoji: '⬇️', duration: 1500 },
  ];
  
  for (const { direction, emoji, duration } of movements) {
    console.log(`${emoji} Moving ${direction}...`);
    const steps = Math.floor(duration / 16); // 60 FPS
    
    for (let i = 0; i < steps; i++) {
      ai.sendCommand(ai.move(direction));
      await new Promise(r => setTimeout(r, 16));
    }
  }
  
  // Stop moving
  console.log('🛑 Stopping...');
  ai.sendCommand(ai.move('stop'));
  
  ai.disconnect();
  console.log('✅ Movement demo complete!');
}

demonstrateMovement().catch(console.error);