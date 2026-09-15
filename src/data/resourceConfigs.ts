export type ResourceType = "wood" | "stone" | "food" | "ore" | "loot";

export interface ResourceConfig {
  type: ResourceType;
  name: string;
  maxAmount: number;
  harvestTimePerUnit: number; // seconds per resource unit gathered
  yieldPerCycle: number;
  description: string;
}

export const RESOURCE_CONFIGS: Record<ResourceType, ResourceConfig> = {
  wood: {
    type: "wood",
    name: "Wood Tree",
    maxAmount: 60,
    harvestTimePerUnit: 1.2,
    yieldPerCycle: 5,
    description: "Timber harvested from forest trees. Fundamental for construction."
  },
  stone: {
    type: "stone",
    name: "Rock Deposit",
    maxAmount: 80,
    harvestTimePerUnit: 1.5,
    yieldPerCycle: 4,
    description: "Quarried stone for fortifications and durable structures."
  },
  food: {
    type: "food",
    name: "Berry Bush",
    maxAmount: 50,
    harvestTimePerUnit: 1.0,
    yieldPerCycle: 5,
    description: "Sweet wild berries. Vital for feeding and training new villagers."
  },
  ore: {
    type: "ore",
    name: "Iron Vein",
    maxAmount: 50,
    harvestTimePerUnit: 2.0,
    yieldPerCycle: 3,
    description: "Metallic ore found in craggy plateaus. Used for weapons and armor."
  },
  loot: {
    type: "loot",
    name: "Treasure Chest",
    maxAmount: 1,
    harvestTimePerUnit: 0.5,
    yieldPerCycle: 1,
    description: "Mysterious container left in ruins containing valuable caches."
  }
};
