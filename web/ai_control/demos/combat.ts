#!/usr/bin/env npx tsx
/**
 * Combat Patterns Demo
 * Demonstrates shooting and spell casting
 */

import { NodeAIController } from '../node/controller.js';
import { ZONES, PATTERNS, SCREEN } from '../core/constants.js';
import { Behaviors } from '../story/behaviors.js';

async function demonstrateCombat() {
  console.log('⚔️ AI Combat Demo');
  console.log('=================');
  console.log('');
  console.log('📋 Make sure to press G in the game first to enable AI control!');
  console.log('');
  
  const ai = new NodeAIController();
  await ai.connect();
  
  console.log('🎯 Starting combat sequence...');
  console.log('');
  
  // Pattern 1: Burst fire at common enemy positions
  console.log('1️⃣ Burst Fire Pattern');
  const enemyPositions = ZONES.OVERWORLD.spawns.slice(0, 3);
  
  for (let i = 0; i < enemyPositions.length; i++) {
    const pos = enemyPositions[i];
    console.log(`   Targeting enemy ${i + 1} at (${pos.x}, ${pos.y})`);
    await ai.burstFire(pos, 3, 150);
    await new Promise(r => setTimeout(r, 500));
  }
  
  console.log('✅ Burst fire complete');
  console.log('');
  
  await new Promise(r => setTimeout(r, 1000));
  
  // Pattern 2: Circle strafe with shooting
  console.log('2️⃣ Kiting Pattern (move + shoot)');
  const kiteCenter = SCREEN.CENTER;
  const kitePoints = PATTERNS.CIRCLE_STRAFE(kiteCenter, 200, 8);
  
  for (let i = 0; i < kitePoints.length; i++) {
    // Move to position
    await ai.moveTo(kitePoints[i], 2);
    
    // Shoot at center
    console.log(`   Position ${i + 1}/8 - Firing!`);
    await ai.shootPattern([kiteCenter], 100);
  }
  
  console.log('✅ Kiting complete');
  console.log('');
  
  await new Promise(r => setTimeout(r, 1000));
  
  // Pattern 3: Spell casting
  console.log('3️⃣ Spell Casting Sequence');
  const spells = [
    { slot: 0, name: 'Lull', target: { x: 500, y: 300 } },
    { slot: 3, name: 'Burst', target: { x: 400, y: 400 } },
    { slot: 7, name: 'Lightning', target: { x: 300, y: 300 } },
  ];
  
  for (const spell of spells) {
    console.log(`   Casting ${spell.name} at (${spell.target.x}, ${spell.target.y})`);
    
    // Select spell
    ai.sendCommand(ai.pressKey(ai['getSpellKey'](spell.slot)));
    await new Promise(r => setTimeout(r, 100));
    
    // Cast it
    ai.sendCommand(ai.castSpell(spell.slot, spell.target, false));
    await new Promise(r => setTimeout(r, 1500));
  }
  
  console.log('✅ Spells cast');
  console.log('');
  
  await new Promise(r => setTimeout(r, 1000));
  
  // Pattern 4: Complex combat behavior
  console.log('4️⃣ Advanced Combat Behavior');
  const combatSequence = Behaviors.combat(
    ZONES.OVERWORLD.spawns.slice(0, 2),
    SCREEN.CENTER
  );
  
  console.log('   Executing tactical combat...');
  await ai.executeSequence(combatSequence);
  
  console.log('✅ Advanced combat complete');
  console.log('');
  
  ai.disconnect();
  console.log('🎉 Combat demo complete!');
}

demonstrateCombat().catch(console.error);