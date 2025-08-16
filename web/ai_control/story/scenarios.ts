/**
 * Predefined Story Scenarios
 * Different narrative playthroughs for the AI
 */

export type ScenarioType = 'hero' | 'speedrun' | 'pacifist' | 'warrior' | 'explorer';

export class Scenarios {
  static readonly descriptions: Record<ScenarioType, string> = {
    hero: "A classic hero's journey from humble beginnings to defeating the final boss",
    speedrun: "Optimized path to reach and defeat the boss as quickly as possible",
    pacifist: "Complete the game without harming any enemies, using stealth and spells",
    warrior: "Aggressive combat-focused playthrough, defeating every enemy",
    explorer: "Methodical exploration of every zone and secret in the game"
  };

  static getDescription(scenario: ScenarioType): string {
    return this.descriptions[scenario] || this.descriptions.hero;
  }

  static getAllScenarios(): ScenarioType[] {
    return Object.keys(this.descriptions) as ScenarioType[];
  }
}