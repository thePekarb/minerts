import * as THREE from "three";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { eventBus } from "../game/EventBus";

export class SelectionSystem {
  public selectedUnits: Unit[] = [];
  public selectedBuilding: Building | null = null;
  public controlGroups: Map<number, Unit[]> = new Map();

  // Marquee drag selection
  public isDragging: boolean = false;
  private dragStart: { x: number; y: number } = { x: 0, y: 0 };
  private marqueeElement: HTMLElement | null = null;

  constructor() {
    this.marqueeElement = document.getElementById("selection-box");
    this.setupControlGroupShortcuts();
  }

  private setupControlGroupShortcuts(): void {
    window.addEventListener("keydown", (e) => {
      // 1-5 keys for control groups
      const num = parseInt(e.key);
      if (!isNaN(num) && num >= 1 && num <= 5) {
        if (e.ctrlKey) {
          // Save group
          e.preventDefault();
          this.saveControlGroup(num);
        } else if (!e.shiftKey && !e.altKey) {
          // If not in build mode, recall group
          // (Handled conditionally if no active build ghost)
        }
      }
    });
  }

  public saveControlGroup(index: number): void {
    const units = [...this.selectedUnits];
    this.controlGroups.set(index, units);
    eventBus.emit("toast", { message: `Squad ${index} assigned (${units.length} units)`, type: "info" });
  }

  public recallControlGroup(index: number): void {
    const units = this.controlGroups.get(index);
    if (units && units.length > 0) {
      // Filter out dead units
      const living = units.filter((u) => u.isAlive);
      this.controlGroups.set(index, living);
      this.selectUnits(living);
      eventBus.emit("sound", { soundName: "select_unit" });
    }
  }

  public clearSelection(): void {
    for (const u of this.selectedUnits) {
      u.setSelected(false);
    }
    this.selectedUnits = [];

    if (this.selectedBuilding) {
      this.selectedBuilding.setSelected(false);
      this.selectedBuilding = null;
    }

    eventBus.emit("unitSelected", null);
    eventBus.emit("multiUnitSelected", []);
    eventBus.emit("buildingSelected", null);
  }

  public selectUnit(unit: Unit, addToSelection: boolean = false): void {
    if (unit.state === "mining_inside" || !unit.meshHierarchy.root.visible) return;

    if (this.selectedBuilding) {
      this.selectedBuilding.setSelected(false);
      this.selectedBuilding = null;
      eventBus.emit("buildingSelected", null);
    }

    if (!addToSelection) {
      for (const u of this.selectedUnits) {
        u.setSelected(false);
      }
      this.selectedUnits = [];
    }

    if (!this.selectedUnits.includes(unit)) {
      this.selectedUnits.push(unit);
      unit.setSelected(true);
    }

    eventBus.emit("sound", { soundName: "select_unit" });

    if (this.selectedUnits.length === 1) {
      eventBus.emit("unitSelected", this.selectedUnits[0]);
      eventBus.emit("multiUnitSelected", []);
    } else {
      eventBus.emit("unitSelected", null);
      eventBus.emit("multiUnitSelected", this.selectedUnits);
    }
  }

  public selectUnits(units: Unit[]): void {
    this.clearSelection();
    for (const u of units) {
      if (u.isAlive && u.state !== "mining_inside" && u.meshHierarchy.root.visible) {
        this.selectedUnits.push(u);
        u.setSelected(true);
      }
    }

    if (this.selectedUnits.length > 0) {
      eventBus.emit("sound", { soundName: "select_unit" });
      if (this.selectedUnits.length === 1) {
        eventBus.emit("unitSelected", this.selectedUnits[0]);
      } else {
        eventBus.emit("multiUnitSelected", this.selectedUnits);
      }
    }
  }

  public selectBuilding(building: Building): void {
    this.clearSelection();
    this.selectedBuilding = building;
    building.setSelected(true);
    eventBus.emit("buildingSelected", building);
    eventBus.emit("sound", { soundName: "click" });
  }

  public startDrag(screenX: number, screenY: number): void {
    this.isDragging = true;
    this.dragStart = { x: screenX, y: screenY };

    if (this.marqueeElement) {
      this.marqueeElement.style.left = `${screenX}px`;
      this.marqueeElement.style.top = `${screenY}px`;
      this.marqueeElement.style.width = "0px";
      this.marqueeElement.style.height = "0px";
      this.marqueeElement.classList.remove("hidden");
    }
  }

  public updateDrag(screenX: number, screenY: number): void {
    if (!this.isDragging || !this.marqueeElement) return;

    const left = Math.min(this.dragStart.x, screenX);
    const top = Math.min(this.dragStart.y, screenY);
    const width = Math.abs(screenX - this.dragStart.x);
    const height = Math.abs(screenY - this.dragStart.y);

    this.marqueeElement.style.left = `${left}px`;
    this.marqueeElement.style.top = `${top}px`;
    this.marqueeElement.style.width = `${width}px`;
    this.marqueeElement.style.height = `${height}px`;
  }

  public endDrag(
    screenX: number,
    screenY: number,
    camera: THREE.Camera,
    canvasWidth: number,
    canvasHeight: number,
    allUnits: Unit[],
    shiftKey: boolean
  ): boolean {
    if (!this.isDragging) return false;
    this.isDragging = false;

    if (this.marqueeElement) {
      this.marqueeElement.classList.add("hidden");
    }

    const minX = Math.min(this.dragStart.x, screenX);
    const maxX = Math.max(this.dragStart.x, screenX);
    const minY = Math.min(this.dragStart.y, screenY);
    const maxY = Math.max(this.dragStart.y, screenY);

    const dragDistance = Math.hypot(maxX - minX, maxY - minY);
    if (dragDistance < 8) {
      // It was a click, not a drag
      return false;
    }

    const foundUnits: Unit[] = [];
    const tempVec = new THREE.Vector3();

    for (const u of allUnits) {
      if (u.faction !== "player" || !u.isAlive || u.state === "mining_inside" || !u.meshHierarchy.root.visible) continue;

      tempVec.set(u.position.x, u.position.y + 0.5, u.position.z);
      tempVec.project(camera);

      // Convert NDC to screen coordinates
      const sx = ((tempVec.x + 1) * canvasWidth) / 2;
      const sy = ((-tempVec.y + 1) * canvasHeight) / 2;

      if (tempVec.z > 0 && tempVec.z < 1 && sx >= minX && sx <= maxX && sy >= minY && sy <= maxY) {
        foundUnits.push(u);
      }
    }

    if (foundUnits.length > 0) {
      if (shiftKey) {
        for (const u of foundUnits) {
          if (!this.selectedUnits.includes(u)) {
            this.selectedUnits.push(u);
            u.setSelected(true);
          }
        }
        eventBus.emit("multiUnitSelected", this.selectedUnits);
      } else {
        this.selectUnits(foundUnits);
      }
      return true;
    }

    return false;
  }
}
