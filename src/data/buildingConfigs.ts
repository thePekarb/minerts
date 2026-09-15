export type BuildingType =
  | "campfire"
  | "hut"
  | "storage"
  | "workshop"
  | "wall"
  | "gate"
  | "tower"
  | "castle"
  | "mine";

export interface ResourceCost {
  wood?: number;
  stone?: number;
  food?: number;
  ore?: number;
}

export interface BuildingConfig {
  type: BuildingType;
  name: string;
  cost: ResourceCost;
  size: { x: number; z: number }; // footprint in tiles
  buildTime: number; // in seconds
  maxHealth: number;
  populationCapacity?: number;
  attackRange?: number;
  attackDamage?: number;
  attackCooldown?: number;
  visionRadius: number;
  description: string;
  upgradeCost?: ResourceCost;
  upgradeName?: string;
}

export const BUILDING_CONFIGS: Record<BuildingType, BuildingConfig> = {
  campfire: {
    type: "campfire",
    name: "Central Camp",
    cost: { wood: 0, stone: 0 },
    size: { x: 3, z: 3 },
    buildTime: 0,
    maxHealth: 500,
    populationCapacity: 6,
    visionRadius: 10,
    description: "Heart of the settlement. Emits light, drops off resources, and trains workers. Defend at all costs!"
  },
  hut: {
    type: "hut",
    name: "Hut",
    cost: { wood: 30, stone: 0 },
    size: { x: 2, z: 2 },
    buildTime: 8,
    maxHealth: 250,
    populationCapacity: 4,
    visionRadius: 6,
    description: "Residential shelter. Increases maximum population capacity by 4."
  },
  storage: {
    type: "storage",
    name: "Storage Depot",
    cost: { wood: 35, stone: 20 },
    size: { x: 2, z: 2 },
    buildTime: 10,
    maxHealth: 350,
    visionRadius: 6,
    description: "Central resource collection hub. Workers drop gathered wood, stone, and food here."
  },
  wall: {
    type: "wall",
    name: "Wooden Wall",
    cost: { wood: 10, stone: 0 },
    size: { x: 1, z: 1 },
    buildTime: 4,
    maxHealth: 220,
    visionRadius: 3,
    description: "Defensive palisade blocking enemy movement."
  },
  gate: {
    type: "gate",
    name: "Wooden Gate",
    cost: { wood: 15, stone: 5 },
    size: { x: 2, z: 1 },
    buildTime: 6,
    maxHealth: 280,
    visionRadius: 4,
    description: "Fortified entryway that opens for friendly units and closes against night raiders."
  },
  tower: {
    type: "tower",
    name: "Defense Tower",
    cost: { wood: 40, stone: 25 },
    size: { x: 2, z: 2 },
    buildTime: 12,
    maxHealth: 400,
    attackRange: 8.5,
    attackDamage: 16,
    attackCooldown: 1.1,
    visionRadius: 11,
    description: "Automated watchtower. Fires precision arrows at incoming hostile raiders."
  },
  workshop: {
    type: "workshop",
    name: "Workshop",
    cost: { wood: 50, stone: 30, ore: 10 },
    size: { x: 3, z: 2 },
    buildTime: 15,
    maxHealth: 400,
    visionRadius: 7,
    description: "Crafting workshop. Trains guards and archers, and crafts upgrades."
  },
  castle: {
    type: "castle",
    name: "Castle Keep",
    cost: { wood: 120, stone: 100, ore: 40 },
    size: { x: 4, z: 4 },
    buildTime: 30,
    maxHealth: 1200,
    populationCapacity: 12,
    visionRadius: 14,
    attackRange: 9.0,
    attackDamage: 22,
    attackCooldown: 0.9,
    description: "Grand fortress citadel representing the apex of settlement power."
  },
  mine: {
    type: "mine",
    name: "Stone Quarry",
    cost: { wood: 30, stone: 0 },
    size: { x: 2, z: 2 },
    buildTime: 8,
    maxHealth: 350,
    visionRadius: 6,
    description: "Dug stone quarry. Workers extract stone here. Upgrade to Deep Mine to extract precious iron ore!",
    upgradeCost: { wood: 40, stone: 30 },
    upgradeName: "Deep Ore Mine"
  }
};
