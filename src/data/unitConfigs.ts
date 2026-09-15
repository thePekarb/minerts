export type UnitType =
  | "worker"
  | "scout"
  | "guard"
  | "archer"
  | "enemy_melee"
  | "enemy_fast";

export type UnitState =
  | "idle"
  | "moving"
  | "gathering"
  | "building"
  | "attacking"
  | "fleeing"
  | "defending"
  | "dead"
  | "returningToStorage"
  | "mining_inside";

export type UnitOrder =
  | "move"
  | "attack"
  | "gather"
  | "build"
  | "patrol"
  | "defend"
  | "interact"
  | "retreat";

export interface UnitCost {
  wood?: number;
  stone?: number;
  food?: number;
  ore?: number;
}

export interface UnitConfig {
  type: UnitType;
  name: string;
  maxHealth: number;
  speed: number;
  attackDamage: number;
  attackRange: number;
  attackCooldown: number; // in seconds
  visionRange: number;   // in grid tiles
  inventoryCapacity: number;
  cost: UnitCost;
  trainingTime: number;  // in seconds
  description: string;
}

export const UNIT_CONFIGS: Record<UnitType, UnitConfig> = {
  worker: {
    type: "worker",
    name: "Worker",
    maxHealth: 50,
    speed: 3.5,
    attackDamage: 4,
    attackRange: 1.2,
    attackCooldown: 1.2,
    visionRange: 6,
    inventoryCapacity: 10,
    cost: { food: 20 },
    trainingTime: 8,
    description: "Harvests resources and constructs buildings. Basic self-defense."
  },
  scout: {
    type: "scout",
    name: "Scout",
    maxHealth: 45,
    speed: 5.5,
    attackDamage: 5,
    attackRange: 1.2,
    attackCooldown: 0.9,
    visionRange: 12,
    inventoryCapacity: 5,
    cost: { food: 25, wood: 10 },
    trainingTime: 10,
    description: "Rapid reconnaissance unit. Reveals large areas of fog of war."
  },
  guard: {
    type: "guard",
    name: "Guard",
    maxHealth: 130,
    speed: 3.0,
    attackDamage: 14,
    attackRange: 1.3,
    attackCooldown: 1.0,
    visionRange: 7,
    inventoryCapacity: 0,
    cost: { food: 30, wood: 15, stone: 5 },
    trainingTime: 12,
    description: "Armored melee fighter with sword and shield. Protects the settlement."
  },
  archer: {
    type: "archer",
    name: "Archer",
    maxHealth: 55,
    speed: 3.8,
    attackDamage: 11,
    attackRange: 7.0,
    attackCooldown: 1.4,
    visionRange: 9,
    inventoryCapacity: 0,
    cost: { food: 25, wood: 25 },
    trainingTime: 12,
    description: "Ranged defender. Shoots arrows from distance."
  },
  enemy_melee: {
    type: "enemy_melee",
    name: "Shadow Brute",
    maxHealth: 85,
    speed: 2.6,
    attackDamage: 12,
    attackRange: 1.4,
    attackCooldown: 1.2,
    visionRange: 8,
    inventoryCapacity: 0,
    cost: {},
    trainingTime: 0,
    description: "Slow, resilient night raider targeting structures and defenders."
  },
  enemy_fast: {
    type: "enemy_fast",
    name: "Night Fiend",
    maxHealth: 38,
    speed: 4.8,
    attackDamage: 7,
    attackRange: 1.1,
    attackCooldown: 0.8,
    visionRange: 9,
    inventoryCapacity: 0,
    cost: {},
    trainingTime: 0,
    description: "Fast pack predator. Flanks perimeter to harass workers."
  }
};
