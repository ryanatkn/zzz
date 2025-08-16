#!/usr/bin/env npx tsx
/**
 * Basic Movement Demo
 * Simple movement patterns for testing
 */

import { NodeAIController } from '../node/controller.js';
import { PATTERNS, SCREEN } from '../core/constants.js';

async function demonstrateMovement() {
  console.log('🎮 AI Movement Demo');
  console.log('==================');
  console.log('');
  console.log('📋 Make sure to press G in the game first to enable AI control!');
  console.log('');
  
  const ai = new NodeAIController();
  await ai.connect();
  
  console.log('🏃 Starting movement sequence...');
  console.log('');
  
  // Square pattern
  console.log('1️⃣ Square Pattern');
  const movements = [
    { direction: 'right' as const, emoji: '➡️', duration: 1500 },
    { direction: 'up' as const, emoji: '⬆️', duration: 1500 },
    { direction: 'left' as const, emoji: '⬅️', duration: 1500 },
    { direction: 'down' as const, emoji: '⬇️', duration: 1500 },
  ];
  
  for (const { direction, emoji, duration } of movements) {
    console.log(`${emoji} Moving ${direction}...`);
    const steps = Math.floor(duration / 16);
    
    for (let i = 0; i < steps; i++) {
      ai.sendCommand(ai.move(direction));
      await new Promise(r => setTimeout(r, 16));
    }
  }
  
  ai.sendCommand(ai.move('stop'));
  console.log('✅ Square complete');
  console.log('');
  
  await new Promise(r => setTimeout(r, 1000));
  
  // Circle strafe
  console.log('2️⃣ Circle Strafe Pattern');
  const circlePoints = PATTERNS.CIRCLE_STRAFE(SCREEN.CENTER, 150, 16);
  
  for (let i = 0; i < circlePoints.length; i++) {
    await ai.moveTo(circlePoints[i], 2);
    
    if (i % 4 === 0) {
      const progress = Math.floor((i / circlePoints.length) * 100);
      console.log(`   ${progress}% complete`);
    }
  }
  
  console.log('✅ Circle strafe complete');
  console.log('');
  
  await new Promise(r => setTimeout(r, 1000));
  
  // Zigzag pattern
  console.log('3️⃣ Zigzag Evasion');
  const zigzagPath = PATTERNS.ZIGZAG(
    { x: 200, y: 300 },
    { x: 600, y: 300 },
    75
  );
  
  for (const point of zigzagPath) {
    await ai.moveTo(point, 3);
  }
  
  console.log('✅ Zigzag complete');
  console.log('');
  
  ai.disconnect();
  console.log('🎉 Movement demo complete!');
}

demonstrateMovement().catch(console.error);