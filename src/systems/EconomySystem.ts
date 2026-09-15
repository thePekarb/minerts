import { eventBus } from "../game/EventBus";
import { ResourceType } from "../data/resourceConfigs";
import { ResourceCost } from "../data/buildingConfigs";
import { UnitType, UNIT_CONFIGS } from "../data/unitConfigs";

export interface Stockpile {
  wood: number;
  stone: number;
  food: number;
  ore: number;
}

export class EconomySystem {
  public resources: Stockpile = {
    wood: 60,
    stone: 40,
    food: 50,
    ore: 0
  };

  public currentPopulation: number = 4;
  public maxPopulation: number = 6;

  constructor() {
    this.notifyChange();
  }

  public canAfford(cost: ResourceCost): boolean {
    if (cost.wood && this.resources.wood < cost.wood) return false;
    if (cost.stone && this.resources.stone < cost.stone) return false;
    if (cost.food && this.resources.food < cost.food) return false;
    if (cost.ore && this.resources.ore < cost.ore) return false;
    return true;
  }

  public deductCost(cost: ResourceCost): boolean {
    if (!this.canAfford(cost)) return false;

    if (cost.wood) this.resources.wood -= cost.wood;
    if (cost.stone) this.resources.stone -= cost.stone;
    if (cost.food) this.resources.food -= cost.food;
    if (cost.ore) this.resources.ore -= cost.ore;

    this.notifyChange();
    return true;
  }

  public refundCost(cost: ResourceCost, factor: number = 0.8): void {
    if (cost.wood) this.resources.wood += Math.floor(cost.wood * factor);
    if (cost.stone) this.resources.stone += Math.floor(cost.stone * factor);
    if (cost.food) this.resources.food += Math.floor(cost.food * factor);
    if (cost.ore) this.resources.ore += Math.floor(cost.ore * factor);

    this.notifyChange();
  }

  public addResource(type: ResourceType, amount: number): void {
    if (type === "loot") return;
    this.resources[type] += amount;
    this.notifyChange();
  }

  public updatePopulation(current: number, max: number): void {
    this.currentPopulation = current;
    this.maxPopulation = max;
    this.notifyChange();
  }

  public canTrainUnit(type: UnitType): { ok: boolean; reason?: string } {
    if (this.currentPopulation >= this.maxPopulation) {
      return { ok: false, reason: "Population cap reached! Build more huts." };
    }
    const cost = UNIT_CONFIGS[type].cost;
    if (!this.canAfford(cost)) {
      return { ok: false, reason: "Insufficient resources to train unit." };
    }
    return { ok: true };
  }

  private notifyChange(): void {
    eventBus.emit("resourceChanged", {
      wood: this.resources.wood,
      stone: this.resources.stone,
      food: this.resources.food,
      ore: this.resources.ore,
      pop: this.currentPopulation,
      maxPop: this.maxPopulation
    });
  }
}
