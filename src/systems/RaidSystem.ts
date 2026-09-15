import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { World } from "../world/World";
import { getWaveConfigForDay } from "../data/enemyConfigs";
import { eventBus } from "../game/EventBus";

export class RaidSystem {
  private world: World;
  private mobCounter = 1;
  public activeWave: number = 0;
  public remainingWaveEnemies: number = 0;

  constructor(world: World) {
    this.world = world;

    eventBus.on("raidStarted", (data: { day: number }) => {
      this.activeWave = data.day;
    });
  }

  public spawnNightWave(
    day: number,
    units: Unit[],
    buildings: Building[],
    onSpawn: (enemy: Unit) => void
  ): void {
    const playerUnits = units.filter((u) => u.faction === "player" && u.isAlive).length;
    const wave = getWaveConfigForDay(day, buildings.length, playerUnits);

    this.remainingWaveEnemies = wave.melee + wave.fast;
    eventBus.emit("toast", {
      message: `⚔️ Night Raid Wave ${day}: ${wave.melee} Brutes & ${wave.fast} Fiends are attacking!`,
      type: "danger"
    });

    // Determine spawn origin: Cave Entrance or map border
    let spawnX = this.world.size - 6;
    let spawnZ = 6;

    for (const poi of this.world.pois.values()) {
      if (poi.type === "cave") {
        spawnX = poi.x;
        spawnZ = poi.z;
        break;
      }
    }

    // Spawn Melee mobs
    for (let i = 0; i < wave.melee; i++) {
      const offsetX = (Math.random() - 0.5) * 4;
      const offsetZ = (Math.random() - 0.5) * 4;
      const sx = Math.max(2, Math.min(this.world.size - 3, spawnX + offsetX));
      const sz = Math.max(2, Math.min(this.world.size - 3, spawnZ + offsetZ));
      const sy = this.world.getHeight(sx, sz);

      const enemy = new Unit(
        `enemy_m_${this.mobCounter++}`,
        "enemy_melee",
        sx,
        sy,
        sz,
        "enemy"
      );
      onSpawn(enemy);
    }

    // Spawn Fast mobs
    for (let i = 0; i < wave.fast; i++) {
      const offsetX = (Math.random() - 0.5) * 5;
      const offsetZ = (Math.random() - 0.5) * 5;
      const sx = Math.max(2, Math.min(this.world.size - 3, spawnX + offsetX));
      const sz = Math.max(2, Math.min(this.world.size - 3, spawnZ + offsetZ));
      const sy = this.world.getHeight(sx, sz);

      const enemy = new Unit(
        `enemy_f_${this.mobCounter++}`,
        "enemy_fast",
        sx,
        sy,
        sz,
        "enemy"
      );
      onSpawn(enemy);
    }
  }

  public onEnemyDefeated(): void {
    this.remainingWaveEnemies = Math.max(0, this.remainingWaveEnemies - 1);
    if (this.remainingWaveEnemies === 0 && this.activeWave > 0) {
      eventBus.emit("toast", {
        message: `🏆 Raid wave ${this.activeWave} repelled! Settlement is victorious!`,
        type: "success"
      });
      eventBus.emit("sound", { soundName: "build_done" });
      this.activeWave = 0;
    }
  }
}
