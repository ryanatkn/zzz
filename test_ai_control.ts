#!/usr/bin/env node

/**
 * Direct test of AI control system
 * Run this while the game is running with AI control enabled (press G in game)
 */

import { AIController } from './ai_control_node.js';

async function testMovement() {
  const ai = new AIController();
  await ai.connect();
  
  console.log('🎮 Testing AI control - make sure to press G in game to enable AI mode!');
  console.log('📍 Moving in a square pattern...');
  
  // Move right
  console.log('➡️ Moving right...');
  for (let i = 0; i < 60; i++) {
    ai.sendCommand(ai.move('right'));
    await new Promise(r => setTimeout(r, 16));
  }
  
  // Move down
  console.log('⬇️ Moving down...');
  for (let i = 0; i < 60; i++) {
    ai.sendCommand(ai.move('down'));
    await new Promise(r => setTimeout(r, 16));
  }
  
  // Move left
  console.log('⬅️ Moving left...');
  for (let i = 0; i < 60; i++) {
    ai.sendCommand(ai.move('left'));
    await new Promise(r => setTimeout(r, 16));
  }
  
  // Move up
  console.log('⬆️ Moving up...');
  for (let i = 0; i < 60; i++) {
    ai.sendCommand(ai.move('up'));
    await new Promise(r => setTimeout(r, 16));
  }
  
  // Stop
  ai.sendCommand(ai.move('stop'));
  
  console.log('✅ Test complete!');
  console.log('📊 Final frame:', ai.getCurrentFrame());
  
  ai.disconnect();
}

testMovement().catch(console.error);