import * as THREE from "three";
import { Entity } from "./Entity";

export class Projectile {
  public mesh: THREE.Mesh;
  public target: Entity;
  public damage: number;
  public speed: number = 18.0;
  public isDead: boolean = false;
  private scene: THREE.Scene;

  constructor(scene: THREE.Scene, startPos: THREE.Vector3, target: Entity, damage: number) {
    this.scene = scene;
    this.target = target;
    this.damage = damage;

    const geo = new THREE.BoxGeometry(0.1, 0.1, 0.4);
    const mat = new THREE.MeshBasicMaterial({ color: 0xfef08a });
    this.mesh = new THREE.Mesh(geo, mat);
    this.mesh.position.copy(startPos);
    this.scene.add(this.mesh);
  }

  public update(dt: number): boolean {
    if (this.isDead || !this.target.isAlive) {
      this.destroy();
      return true;
    }

    const targetPos = new THREE.Vector3(
      this.target.position.x,
      this.target.position.y + 0.5,
      this.target.position.z
    );

    const dir = new THREE.Vector3().subVectors(targetPos, this.mesh.position);
    const dist = dir.length();
    const moveDist = this.speed * dt;

    if (dist <= moveDist) {
      // Hit target
      this.target.takeDamage(this.damage);
      this.destroy();
      return true;
    }

    dir.normalize();
    this.mesh.position.addScaledVector(dir, moveDist);
    this.mesh.lookAt(targetPos);
    return false;
  }

  public destroy(): void {
    if (!this.isDead) {
      this.isDead = true;
      this.scene.remove(this.mesh);
    }
  }
}
