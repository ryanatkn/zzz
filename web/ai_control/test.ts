#!/usr/bin/env node --experimental-strip-types
/**
 * AI Control System Test
 * Quick test to verify the system works
 */

import { NodeAIController } from './node/controller.js';
import { Keys } from './core/types.js';

async function testAIControl() {
  console.log('🧪 AI Control System Test');
  console.log('========================');
  console.log('');
  
  const ai = new NodeAIController();
  
  try {
    console.log('1. Testing connection...');
    await ai.connect();
    console.log('   ✅ Connected successfully');
    
    console.log('2. Testing frame counter...');
    const frame = ai.getCurrentFrame();
    console.log(`   ✅ Current frame: ${frame}`);
    
    console.log('3. Testing command sending...');
    
    // Test movement
    const moveCmd = ai.move('right');
    const moveSent = ai.sendCommand(moveCmd);
    console.log(`   ✅ Movement command sent: ${moveSent}`);
    
    // Test shooting
    const shootCmd = ai.shoot({ x: 400, y: 300 }, true);
    const shootSent = ai.sendCommand(shootCmd);
    console.log(`   ✅ Shoot command sent: ${shootSent}`);
    
    // Test key press
    const keyCmd = ai.pressKey(Keys.SPACE);
    const keySent = ai.sendCommand(keyCmd);
    console.log(`   ✅ Key press command sent: ${keySent}`);
    
    console.log('4. Testing buffer clear...');
    ai.clear();
    console.log('   ✅ Buffer cleared');
    
    console.log('5. Testing disconnection...');
    ai.disconnect();
    console.log('   ✅ Disconnected successfully');
    
    console.log('');
    console.log('🎉 All tests passed!');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    ai.disconnect();
    process.exit(1);
  }
}

testAIControl().catch(console.error);