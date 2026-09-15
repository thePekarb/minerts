import * as THREE from "three";
import { Entity } from "./Entity";
import { UnitType, UnitState, UnitOrder, UnitConfig, UNIT_CONFIGS } from "../data/unitConfigs";
import { ResourceType } from "../data/resourceConfigs";
import { Vec3 } from "../game/GameCommand";
import { VoxelMeshes, UnitMeshHierarchy } from "../rendering/VoxelMeshes";

export class Unit extends Entity {
  public type: UnitType;
  public config: UnitConfig;
  public speed: number;
  public attackDamage: number;
  public attackRange: number;
  public attackCooldown: number;
  public currentOrder: UnitOrder = "move";
  public state: UnitState = "idle";
  public target: any = null; // target position, entity, resource, or building
  public inventory: { type: ResourceType; amount: number } | null = null;

  // Path following
  public path: Vec3[] = [];
  public currentWaypointIndex: number = 0;

  // Timers & cooldowns
  public attackTimer: number = 0;
  public gatherTimer: number = 0;
  public buildTimer: number = 0;

  // 3D Rendering
  public meshHierarchy: UnitMeshHierarchy;
  private animTime: number = Math.random() * 10;
  private hurtFlashTimer: number = 0;

  constructor(id: string, type: UnitType, x: number, y: number, z: number, faction: "player" | "enemy") {
    const config = UNIT_CONFIGS[type];
    super(id, x, y, z, config.maxHealth, faction);

    this.type = type;
    this.config = config;
    this.speed = config.speed;
    this.attackDamage = config.attackDamage;
    this.attackRange = config.attackRange;
    this.attackCooldown = config.attackCooldown;

    this.meshHierarchy = VoxelMeshes.createUnitMesh(type, faction === "player");
    this.meshHierarchy.root.position.set(x, y, z);
    this.meshHierarchy.root.userData = { unitId: id };
    this.meshHierarchy.root.traverse((child) => {
      child.userData = { unitId: id };
    });
  }

  public setSelected(selected: boolean): void {
    this.meshHierarchy.selectionRing.visible = selected;
  }

  public override takeDamage(amount: number): boolean {
    const isDead = super.takeDamage(amount);
    this.hurtFlashTimer = 0.15;

    // Update floating healthbar
    const hpPct = Math.max(0, this.health / this.maxHealth);
    this.meshHierarchy.healthBar.fill.scale.x = hpPct;

    if (isDead) {
      this.state = "dead";
      this.meshHierarchy.healthBar.bg.visible = false;
      this.setSelected(false);
    }
    return isDead;
  }

  public updateAnimation(deltaTime: number): void {
    this.meshHierarchy.root.position.set(this.position.x, this.position.y, this.position.z);
    this.meshHierarchy.root.rotation.y = this.rotation;

    // Hurt flash
    if (this.hurtFlashTimer > 0) {
      this.hurtFlashTimer -= deltaTime;
      (this.meshHierarchy.body.material as any).color?.setHex(0xff2222);
    } else {
      // Revert body color
      const isPlayer = this.faction === "player";
      if (!isPlayer) {
        (this.meshHierarchy.body.material as any).color?.setHex(
          this.type === "enemy_fast" ? 0x742a2a : 0x4a154b
        );
      } else {
        if (this.type === "worker") (this.meshHierarchy.body.material as any).color?.setHex(0x3182ce);
        else if (this.type === "scout") (this.meshHierarchy.body.material as any).color?.setHex(0x38a169);
        else if (this.type === "guard") (this.meshHierarchy.body.material as any).color?.setHex(0x718096);
        else if (this.type === "archer") (this.meshHierarchy.body.material as any).color?.setHex(0xd69e2e);
      }
    }

    if (this.state === "dead") {
      // Tumble down into ground
      this.meshHierarchy.root.rotation.x = THREE.MathUtils.lerp(this.meshHierarchy.root.rotation.x, -Math.PI / 2, deltaTime * 8);
      this.meshHierarchy.root.position.y = THREE.MathUtils.lerp(this.meshHierarchy.root.position.y, this.position.y - 0.2, deltaTime * 4);
      return;
    }

    // Walking animation
    if (this.state === "moving" || this.state === "returningToStorage" || this.state === "fleeing") {
      this.animTime += deltaTime * (this.speed * 3.0);
      const swing = Math.sin(this.animTime) * 0.65;

      this.meshHierarchy.leftLeg.rotation.x = swing;
      this.meshHierarchy.rightLeg.rotation.x = -swing;
      this.meshHierarchy.leftArm.rotation.x = -swing * 0.8;
      this.meshHierarchy.rightArm.rotation.x = swing * 0.8;
      this.meshHierarchy.head.rotation.y = Math.sin(this.animTime * 0.5) * 0.1;
    } else if (this.state === "gathering" || this.state === "building") {
      // Chopping / mining / hammering action
      this.animTime += deltaTime * 8.0;
      const chop = Math.sin(this.animTime) * 0.8 - 0.2;
      this.meshHierarchy.rightArm.rotation.x = chop;
      this.meshHierarchy.leftArm.rotation.x = 0;
      this.meshHierarchy.leftLeg.rotation.x = 0;
      this.meshHierarchy.rightLeg.rotation.x = 0;
    } else if (this.state === "attacking") {
      // Attack thrust / slash
      this.animTime += deltaTime * 10.0;
      const attackSwing = Math.sin(this.animTime) * 0.9;
      this.meshHierarchy.rightArm.rotation.x = attackSwing;
      this.meshHierarchy.leftArm.rotation.x = -attackSwing * 0.3;
    } else {
      // Idle breathing / slight sway
      this.animTime += deltaTime * 2.0;
      this.meshHierarchy.leftLeg.rotation.x = 0;
      this.meshHierarchy.rightLeg.rotation.x = 0;
      this.meshHierarchy.leftArm.rotation.x = Math.sin(this.animTime) * 0.08;
      this.meshHierarchy.rightArm.rotation.x = -Math.sin(this.animTime) * 0.08;
      this.meshHierarchy.head.position.y = (this.type === "enemy_fast" ? 0.2 : 0.45) + Math.sin(this.animTime) * 0.02;
    }
  }
}
