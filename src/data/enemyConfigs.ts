import { UnitType } from "./unitConfigs";

export interface WaveConfig {
  day: number;
  meleeCount: number;
  fastCount: number;
  bossCount?: number;
}

export function getWaveConfigForDay(day: number, buildingCount: number, unitCount: number): { melee: number; fast: number } {
  // Raid difficulty scales with day number, building count, and unit count
  const baseDifficulty = Math.max(1, day);
  const settlementFactor = Math.floor(buildingCount / 4) + Math.floor(unitCount / 3);
  
  const melee = Math.max(2, Math.floor(baseDifficulty * 2 + settlementFactor * 0.8));
  const fast = Math.max(1, Math.floor(baseDifficulty * 1.5 + settlementFactor * 0.6));

  return { melee, fast };
}
