import { World } from "../world/World";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { CameraController } from "../camera/CameraController";

export class Minimap {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private world: World;
  private cameraCtrl: CameraController;

  constructor(canvasId: string, world: World, cameraCtrl: CameraController) {
    this.canvas = document.getElementById(canvasId) as HTMLCanvasElement;
    this.ctx = this.canvas.getContext("2d")!;
    this.world = world;
    this.cameraCtrl = cameraCtrl;

    this.setupInteraction();
  }

  private setupInteraction(): void {
    const handleMinimapClick = (e: MouseEvent) => {
      const rect = this.canvas.getBoundingClientRect();
      const clickX = (e.clientX - rect.left) / rect.width;
      const clickY = (e.clientY - rect.top) / rect.height;

      const targetWorldX = clickX * this.world.size;
      const targetWorldZ = clickY * this.world.size;

      this.cameraCtrl.focusOn(targetWorldX, targetWorldZ);
    };

    this.canvas.addEventListener("click", handleMinimapClick);

    let isMouseDown = false;
    this.canvas.addEventListener("mousedown", (e) => {
      isMouseDown = true;
      handleMinimapClick(e);
    });
    window.addEventListener("mousemove", (e) => {
      if (isMouseDown) handleMinimapClick(e);
    });
    window.addEventListener("mouseup", () => {
      isMouseDown = false;
    });
  }

  public render(units: Unit[], buildings: Building[]): void {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const size = this.world.size;
    const scaleX = w / size;
    const scaleY = h / size;

    this.ctx.clearRect(0, 0, w, h);

    // 1. Draw Terrain Tiles with Fog of War
    for (let x = 0; x < size; x++) {
      for (let z = 0; z < size; z++) {
        const tile = this.world.tiles[x][z];

        if (!tile.explored) {
          // Hidden
          this.ctx.fillStyle = "#020617";
          this.ctx.fillRect(x * scaleX, z * scaleY, scaleX + 0.5, scaleY + 0.5);
          continue;
        }

        // Explored base colors
        let color = "#3b7329"; // Plains
        if (tile.biome === "forest") color = "#1e4d1f";
        else if (tile.biome === "rock") color = "#52525b";
        else if (tile.biome === "sand") color = "#ca8a04";
        else if (tile.biome === "water") color = "#1d4ed8";

        this.ctx.fillStyle = color;
        this.ctx.fillRect(x * scaleX, z * scaleY, scaleX + 0.5, scaleY + 0.5);

        // Darken if explored but not currently visible
        if (!tile.visible) {
          this.ctx.fillStyle = "rgba(0, 0, 0, 0.45)";
          this.ctx.fillRect(x * scaleX, z * scaleY, scaleX + 0.5, scaleY + 0.5);
        }
      }
    }

    // 2. POIs (Chests, Cave, Camp)
    for (const poi of this.world.pois.values()) {
      const tile = this.world.getTile(poi.x, poi.z);
      if (tile && tile.explored) {
        this.ctx.fillStyle = poi.type === "cave" ? "#a855f7" : "#eab308";
        this.ctx.fillRect(poi.x * scaleX - 1, poi.z * scaleY - 1, 4, 4);
      }
    }

    // 3. Buildings
    for (const b of buildings) {
      if (!b.isAlive) continue;
      this.ctx.fillStyle = b.type === "campfire" ? "#f97316" : "#38bdf8";
      this.ctx.fillRect(
        b.gridX * scaleX,
        b.gridZ * scaleY,
        b.config.size.x * scaleX,
        b.config.size.z * scaleY
      );
    }

    // 4. Units
    for (const u of units) {
      if (!u.isAlive) continue;
      const tile = this.world.getTile(u.position.x, u.position.z);
      if (u.faction === "enemy" && (!tile || !tile.visible)) {
        // Hide enemy in fog of war
        continue;
      }

      this.ctx.fillStyle = u.faction === "player" ? "#22c55e" : "#ef4444";
      this.ctx.beginPath();
      this.ctx.arc(u.position.x * scaleX, u.position.z * scaleY, 2.5, 0, Math.PI * 2);
      this.ctx.fill();
    }

    // 5. Camera View Box
    const camTarget = this.cameraCtrl.target;
    const boxSize = 18 * scaleX;
    this.ctx.strokeStyle = "rgba(255, 255, 255, 0.85)";
    this.ctx.lineWidth = 1.5;
    this.ctx.strokeRect(
      camTarget.x * scaleX - boxSize / 2,
      camTarget.z * scaleY - boxSize / 2,
      boxSize,
      boxSize
    );
  }
}
