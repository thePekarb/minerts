import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { EconomySystem } from "../systems/EconomySystem";
import { TimeOfDaySystem } from "../systems/TimeOfDaySystem";
import { World } from "../world/World";
import { eventBus } from "./EventBus";

export interface SerializedGameState {
  day: number;
  elapsedSeconds: number;
  resources: { wood: number; stone: number; food: number; ore: number };
  units: {
    id: string;
    type: string;
    faction: "player" | "enemy" | "neutral";
    x: number;
    y: number;
    z: number;
    health: number;
  }[];
  buildings: {
    id: string;
    type: string;
    gridX: number;
    gridZ: number;
    health: number;
    constructionProgress: number;
    isConstructed: boolean;
  }[];
  openedChests: string[];
}

export class SaveManager {
  private static STORAGE_KEY = "frontier_blocks_save";

  public static saveGame(
    economy: EconomySystem,
    timeSystem: TimeOfDaySystem,
    units: Unit[],
    buildings: Building[],
    world: World
  ): void {
    const openedChests: string[] = [];
    for (const poi of world.pois.values()) {
      if (poi.isOpened) openedChests.push(poi.id);
    }

    const state: SerializedGameState = {
      day: timeSystem.day,
      elapsedSeconds: timeSystem.elapsedSeconds,
      resources: { ...economy.resources },
      units: units.filter(u => u.isAlive).map(u => ({
        id: u.id,
        type: u.type,
        faction: u.faction,
        x: u.position.x,
        y: u.position.y,
        z: u.position.z,
        health: u.health
      })),
      buildings: buildings.filter(b => b.isAlive).map(b => ({
        id: b.id,
        type: b.type,
        gridX: b.gridX,
        gridZ: b.gridZ,
        health: b.health,
        constructionProgress: b.constructionProgress,
        isConstructed: b.isConstructed
      })),
      openedChests
    };

    try {
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify(state));
      eventBus.emit("toast", { message: "💾 Game saved successfully!", type: "success" });
    } catch (e) {
      console.error("Failed to save to localStorage:", e);
      eventBus.emit("toast", { message: "Failed to save game.", type: "danger" });
    }
  }

  public static loadGame(): SerializedGameState | null {
    try {
      const data = localStorage.getItem(this.STORAGE_KEY);
      if (!data) {
        eventBus.emit("toast", { message: "No saved game found.", type: "warn" });
        return null;
      }
      return JSON.parse(data) as SerializedGameState;
    } catch (e) {
      console.error("Failed to load game:", e);
      eventBus.emit("toast", { message: "Failed to parse save game.", type: "danger" });
      return null;
    }
  }
}
