/**
 * Story-Driven Autonomous AI Controller
 * Plays through the game with narrative and purpose
 */

import { NodeAIController } from '../node/controller.js';
import type { Vec2, ActionSequence } from '../core/types.js';
import { Keys } from '../core/types.js';
import { ZONES, STORY_CHECKPOINTS, SCREEN } from '../core/constants.js';
import { Behaviors } from './behaviors.js';
import { Scenarios, type ScenarioType } from './scenarios.js';

export interface StoryState {
  currentZone: string;
  visitedZones: Set<string>;
  defeatedEnemies: number;
  checkpoints: Set<string>;
  health: number;
  bullets: number;
  spellCooldowns: Map<number, number>;
}

export class StoryController {
  private controller: NodeAIController;
  private state: StoryState;
  private scenario: ScenarioType;
  private narrativeEnabled: boolean = true;
  private startTime: number = 0;

  constructor() {
    this.controller = new NodeAIController();
    this.state = this.initializeState();
    this.scenario = 'hero';
  }

  /**
   * Initialize story state
   */
  private initializeState(): StoryState {
    return {
      currentZone: 'OVERWORLD',
      visitedZones: new Set(['OVERWORLD']),
      defeatedEnemies: 0,
      checkpoints: new Set([STORY_CHECKPOINTS.START]),
      health: 100,
      bullets: 6,
      spellCooldowns: new Map()
    };
  }

  /**
   * Main story playthrough
   */
  async play(scenario: ScenarioType = 'hero', narrative: boolean = true): Promise<void> {
    this.scenario = scenario;
    this.narrativeEnabled = narrative;
    this.startTime = Date.now();
    
    try {
      await this.controller.connect();
      
      this.narrate(`🎮 Starting ${scenario} playthrough...`);
      this.narrate(`📖 ${Scenarios.getDescription(scenario)}`);
      
      // Enable AI control mode
      await this.enableAIControl();
      
      // Execute the chosen scenario
      await this.executeScenario(scenario);
      
      // Show completion stats
      this.showCompletionStats();
      
    } catch (error) {
      console.error('❌ Story playthrough failed:', error);
    } finally {
      this.controller.disconnect();
    }
  }

  /**
   * Execute a specific scenario
   */
  private async executeScenario(scenario: ScenarioType): Promise<void> {
    switch (scenario) {
      case 'hero':
        await this.playHeroJourney();
        break;
      case 'speedrun':
        await this.playSpeedrun();
        break;
      case 'pacifist':
        await this.playPacifist();
        break;
      case 'warrior':
        await this.playWarrior();
        break;
      case 'explorer':
        await this.playExplorer();
        break;
      default:
        await this.playHeroJourney();
    }
  }

  /**
   * The Hero's Journey - Complete story arc
   */
  private async playHeroJourney(): Promise<void> {
    this.narrate("Chapter 1: The Awakening");
    this.narrate("Our hero awakens in the overworld, sensing danger nearby...");
    
    // Initial exploration
    await this.exploreCurrentZone();
    
    this.narrate("Chapter 2: First Blood");
    this.narrate("Enemies approach! Time to learn combat...");
    
    // Learn combat
    await this.engageCombat(ZONES.OVERWORLD.spawns.slice(0, 2));
    this.addCheckpoint(STORY_CHECKPOINTS.FIRST_COMBAT);
    
    this.narrate("Chapter 3: The Dungeon Calls");
    this.narrate("A portal beckons to the east. Darkness awaits within...");
    
    // Enter dungeon
    await this.travelToZone('DUNGEON_1');
    this.addCheckpoint(STORY_CHECKPOINTS.ENTERED_DUNGEON);
    
    this.narrate("Chapter 4: Trials of the Deep");
    this.narrate("The dungeon tests our hero's skills...");
    
    // Clear dungeon
    await this.clearZone();
    
    this.narrate("Chapter 5: The Final Confrontation");
    this.narrate("The boss chamber lies ahead. This is it...");
    
    // Boss fight
    await this.travelToZone('DUNGEON_2');
    this.addCheckpoint(STORY_CHECKPOINTS.BOSS_ENCOUNTERED);
    await this.defeatBoss();
    this.addCheckpoint(STORY_CHECKPOINTS.BOSS_DEFEATED);
    
    this.narrate("Epilogue: Victory!");
    this.narrate("The realm is saved. Our hero's journey is complete.");
  }

  /**
   * Speedrun - Optimal path to boss
   */
  private async playSpeedrun(): Promise<void> {
    this.narrate("SPEEDRUN: Any% Boss Kill");
    this.narrate("Frame-perfect movement engaged...");
    
    // Rush to first portal
    const portal = ZONES.OVERWORLD.portals[0];
    await this.controller.executeSequence([
      {
        type: 'move',
        data: { direction: 'right' },
        duration: 2000
      }
    ]);
    
    // Enter dungeon
    await this.controller.executeSequence(Behaviors.enterPortal(portal.position));
    await this.wait(1000); // Zone transition
    
    // Skip enemies, rush to boss portal
    await this.controller.executeSequence([
      {
        type: 'move',
        data: { direction: 'up' },
        duration: 1500
      }
    ]);
    
    // Enter boss room
    const bossPortal = ZONES.DUNGEON_1.portals[1];
    await this.controller.executeSequence(Behaviors.enterPortal(bossPortal.position));
    await this.wait(1000);
    
    // Quick boss kill with optimal strategy
    await this.controller.executeSequence(Behaviors.bossFight(ZONES.DUNGEON_2.spawns[0]));
    
    const time = (Date.now() - this.startTime) / 1000;
    this.narrate(`SPEEDRUN COMPLETE! Time: ${time.toFixed(2)}s`);
  }

  /**
   * Pacifist - Avoid all combat
   */
  private async playPacifist(): Promise<void> {
    this.narrate("The Path of Peace");
    this.narrate("Violence is never the answer...");
    
    // Explore carefully
    await this.exploreCurrentZone();
    
    // Use Lull spell when encountering enemies
    const enemies = ZONES.OVERWORLD.spawns;
    for (const enemy of enemies) {
      this.narrate("Calming hostile presence...");
      await this.controller.executeSequence([
        {
          type: 'spell',
          data: { slot: 0, target: enemy, selfCast: false }
        },
        {
          type: 'wait',
          duration: 1000
        }
      ]);
    }
    
    // Stealth through dungeon
    this.narrate("Sneaking through the dungeon...");
    await this.travelToZone('DUNGEON_1');
    
    const dungeonEnemies = ZONES.DUNGEON_1.spawns;
    await this.controller.executeSequence(
      Behaviors.stealth(SCREEN.CENTER, ZONES.DUNGEON_1.portals[1].position, dungeonEnemies)
    );
    
    this.narrate("Peace prevails. The journey ends without bloodshed.");
  }

  /**
   * Warrior - Maximum aggression
   */
  private async playWarrior(): Promise<void> {
    this.narrate("BLOOD FOR THE BLOOD GOD!");
    this.narrate("Every enemy must fall!");
    
    // Systematically eliminate all enemies in each zone
    for (const zoneName of Object.keys(ZONES)) {
      if (zoneName !== this.state.currentZone) {
        await this.travelToZone(zoneName);
      }
      
      this.narrate(`Purging ${zoneName} of all hostiles...`);
      await this.clearZone();
      
      // Extra aggression - patrol for respawns
      const zone = ZONES[zoneName as keyof typeof ZONES];
      if (zone.spawns) {
        await this.controller.executeSequence(Behaviors.patrol(zone.spawns));
        await this.engageCombat(zone.spawns);
      }
    }
    
    this.narrate(`TOTAL KILLS: ${this.state.defeatedEnemies}`);
    this.narrate("The warrior's thirst is quenched... for now.");
  }

  /**
   * Explorer - Visit every location
   */
  private async playExplorer(): Promise<void> {
    this.narrate("The Cartographer's Dream");
    this.narrate("Every corner must be mapped...");
    
    // Visit all zones
    for (const zoneName of Object.keys(ZONES)) {
      this.narrate(`Exploring ${zoneName}...`);
      
      if (zoneName !== this.state.currentZone) {
        await this.travelToZone(zoneName);
      }
      
      // Thorough exploration
      await this.exploreCurrentZone();
      
      // Document findings
      const zone = ZONES[zoneName as keyof typeof ZONES];
      this.narrate(`Found ${zone.spawns?.length || 0} enemy spawns`);
      this.narrate(`Found ${zone.portals?.length || 0} portals`);
      
      await this.wait(2000);
    }
    
    this.addCheckpoint(STORY_CHECKPOINTS.ALL_ZONES_VISITED);
    this.narrate(`Exploration complete! Visited ${this.state.visitedZones.size} zones`);
  }

  // Helper methods

  private async enableAIControl(): Promise<void> {
    this.narrate("Enabling AI control mode...");
    this.controller.sendCommand(this.controller.pressKey(Keys.G));
    await this.wait(500);
  }

  private async exploreCurrentZone(): Promise<void> {
    const zone = ZONES[this.state.currentZone as keyof typeof ZONES];
    await this.controller.executeSequence(Behaviors.explore(SCREEN.CENTER, 250));
  }

  private async engageCombat(enemies: Vec2[]): Promise<void> {
    await this.controller.executeSequence(Behaviors.combat(enemies, SCREEN.CENTER));
    this.state.defeatedEnemies += enemies.length;
  }

  private async clearZone(): Promise<void> {
    const zone = ZONES[this.state.currentZone as keyof typeof ZONES];
    if (zone.spawns) {
      await this.engageCombat(zone.spawns);
    }
  }

  private async travelToZone(zoneName: string): Promise<void> {
    const currentZone = ZONES[this.state.currentZone as keyof typeof ZONES];
    const portal = currentZone.portals?.find(p => p.leadsTo === zoneName);
    
    if (portal) {
      this.narrate(`Traveling to ${zoneName}...`);
      await this.controller.executeSequence(Behaviors.enterPortal(portal.position));
      this.state.currentZone = zoneName;
      this.state.visitedZones.add(zoneName);
      await this.wait(1000); // Zone transition time
    }
  }

  private async defeatBoss(): Promise<void> {
    const bossPos = ZONES.DUNGEON_2.spawns[0];
    this.narrate("BOSS FIGHT!");
    await this.controller.executeSequence(Behaviors.bossFight(bossPos));
    this.state.defeatedEnemies++;
  }

  private addCheckpoint(checkpoint: string): void {
    this.state.checkpoints.add(checkpoint);
  }

  private narrate(message: string): void {
    if (this.narrativeEnabled) {
      const time = ((Date.now() - this.startTime) / 1000).toFixed(1);
      console.log(`[${time}s] ${message}`);
    }
  }

  private showCompletionStats(): void {
    const duration = (Date.now() - this.startTime) / 1000;
    console.log('\n📊 === Playthrough Statistics ===');
    console.log(`⏱️  Duration: ${duration.toFixed(1)}s`);
    console.log(`🗺️  Zones Visited: ${this.state.visitedZones.size}`);
    console.log(`⚔️  Enemies Defeated: ${this.state.defeatedEnemies}`);
    console.log(`🏆 Checkpoints: ${this.state.checkpoints.size}`);
    console.log(`📖 Scenario: ${this.scenario}`);
  }

  private wait(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}