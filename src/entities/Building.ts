import * as THREE from "three";
import { Entity } from "./Entity";
import { BuildingType, BuildingConfig, BUILDING_CONFIGS } from "../data/buildingConfigs";
import { VoxelMeshes } from "../rendering/VoxelMeshes";

export class Building extends Entity {
  public type: BuildingType;
  public config: BuildingConfig;
  public gridX: number;
  public gridZ: number;
  public constructionProgress: number = 0; // 0 to 100
  public isConstructed: boolean = false;
  public attackTimer: number = 0;
  public mesh: THREE.Group;

  // Floating UI
  private hpBarFill: THREE.Mesh;
  private hpBarGroup: THREE.Group;

  constructor(id: string, type: BuildingType, gridX: number, y: number, gridZ: number, instant: boolean = false) {
    const config = BUILDING_CONFIGS[type];
    super(
      id,
      gridX + config.size.x / 2,
      y,
      gridZ + config.size.z / 2,
      config.maxHealth,
      "player"
    );

    this.type = type;
    this.isGate = (type === "gate");
    this.config = config;
    this.gridX = gridX;
    this.gridZ = gridZ;
    this.isConstructed = instant || config.buildTime === 0;
    this.constructionProgress = this.isConstructed ? 100 : 0;

    this.mesh = VoxelMeshes.createBuildingMesh(type);
    this.mesh.position.set(this.position.x, this.position.y, this.position.z);
    this.mesh.userData = { buildingId: id };
    this.mesh.traverse((child) => {
      child.userData = { buildingId: id };
    });

    // Initial scale if under construction
    if (!this.isConstructed) {
      this.mesh.scale.set(1.0, 0.25, 1.0);
    }

    // Health / Progress bar
    this.hpBarGroup = new THREE.Group();
    const bgGeo = new THREE.PlaneGeometry(1.2, 0.12);
    const bgMat = new THREE.MeshBasicMaterial({ color: 0x0f172a });
    const bgMesh = new THREE.Mesh(bgGeo, bgMat);

    const fillGeo = new THREE.PlaneGeometry(1.14, 0.09);
    fillGeo.translate(0.57, 0, 0); // Left anchor
    const fillMat = new THREE.MeshBasicMaterial({ color: 0x22c55e });
    this.hpBarFill = new THREE.Mesh(fillGeo, fillMat);
    this.hpBarFill.position.set(-0.57, 0, 0.01);

    this.hpBarGroup.add(bgMesh);
    this.hpBarGroup.add(this.hpBarFill);
    this.hpBarGroup.position.set(0, (config.size.x > 2 ? 2.5 : 1.8), 0);
    this.hpBarGroup.rotation.x = -Math.PI / 4;
    this.hpBarGroup.visible = false;
    this.mesh.add(this.hpBarGroup);
  }

  public advanceConstruction(amount: number): boolean {
    if (this.isConstructed) return true;

    this.constructionProgress = Math.min(100, this.constructionProgress + amount);
    const progressFactor = this.constructionProgress / 100;
    this.mesh.scale.set(1.0, 0.25 + progressFactor * 0.75, 1.0);

    this.hpBarGroup.visible = true;
    this.hpBarFill.scale.x = progressFactor;
    (this.hpBarFill.material as THREE.MeshBasicMaterial).color.setHex(0xf59e0b); // Amber for building

    if (this.constructionProgress >= 100) {
      this.isConstructed = true;
      this.mesh.scale.set(1.0, 1.0, 1.0);
      (this.hpBarFill.material as THREE.MeshBasicMaterial).color.setHex(0x22c55e);
      this.hpBarGroup.visible = false;
      return true;
    }
    return false;
  }

  public override takeDamage(amount: number): boolean {
    const isDead = super.takeDamage(amount);
    this.hpBarGroup.visible = true;
    this.hpBarFill.scale.x = Math.max(0, this.health / this.maxHealth);
    (this.hpBarFill.material as THREE.MeshBasicMaterial).color.setHex(0xef4444);

    return isDead;
  }

  public level: number = 1;
  public isGate: boolean = false;
  public isOpen: boolean = false;
  public isGateLocked: boolean = false;

  // Mine garrison & production
  public assignedMinerIds: Set<string> = new Set();
  public maxMiners: number = 4;
  public mineCycleTimer: number = 0;
  public domBadge?: HTMLElement;
  public domCountNum?: HTMLElement;
  public domLabel?: HTMLElement;

  public toggleGate(world?: any): boolean {
    if (!this.isGate) return false;
    if (this.isOpen) {
      // Close and lock the gate
      this.isGateLocked = true;
      this.setGateOpen(false, world);
      return false;
    } else {
      // Open the gate (unlocked)
      this.isGateLocked = false;
      this.setGateOpen(true, world);
      return true;
    }
  }

  public setGateOpen(open: boolean, world?: any): void {
    if (!this.isGate || this.isOpen === open) return;
    this.isOpen = open;

    const door = this.mesh.getObjectByName("gate_door");
    if (door) {
      door.rotation.y = open ? -Math.PI / 2 : 0;
      door.position.set(open ? -0.7 : 0, 0.75, open ? 0.7 : 0);
    }

    if (world) {
      const tile = world.getTile(this.gridX, this.gridZ);
      if (tile) {
        tile.isGateOpen = open;
        tile.isGateLocked = this.isGateLocked;
      }
    }
  }

  public upgradeMine(): void {
    if (this.type !== "mine" || this.level >= 2) return;
    this.level = 2;
    this.config.name = "Deep Ore Mine";
    const oreCube = this.mesh.getObjectByName("mine_ore_cube");
    if (oreCube) oreCube.visible = true;
    if (this.domLabel) {
      this.domLabel.textContent = "DEEP MINE";
    }
  }

  public ejectAllMiners(units: any[], world: any): void {
    if (this.assignedMinerIds.size === 0) return;
    for (const uid of this.assignedMinerIds) {
      const u = units.find((x) => x.id === uid);
      if (u) {
        u.meshHierarchy.root.visible = true;
        const outX = this.position.x + 1.5;
        const outZ = this.position.z + 1.5;
        u.position = { x: outX, y: world.getHeight(outX, outZ), z: outZ };
        u.meshHierarchy.root.position.set(outX, u.position.y, outZ);
        u.state = "idle";
        u.currentOrder = "move";
        u.target = null;
        u.path = [];
        delete (u as any).miningBuildingId;
      }
    }
    this.assignedMinerIds.clear();
    if (this.domCountNum) {
      this.domCountNum.textContent = "0";
    }
  }

  public setSelected(selected: boolean): void {
    this.hpBarGroup.visible = selected;
  }
}
