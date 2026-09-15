import * as THREE from "three";
import { ResourceType } from "../data/resourceConfigs";

interface Particle {
  mesh: THREE.Mesh;
  vx: number;
  vy: number;
  vz: number;
  life: number;
  maxLife: number;
}

export class ParticleEffects {
  private scene: THREE.Scene;
  private particles: Particle[] = [];
  private pool: THREE.Mesh[] = [];
  private particleGeo: THREE.BoxGeometry;

  constructor(scene: THREE.Scene) {
    this.scene = scene;
    this.particleGeo = new THREE.BoxGeometry(0.1, 0.1, 0.1);
  }

  private getParticle(material: THREE.Material): THREE.Mesh {
    let mesh: THREE.Mesh;
    if (this.pool.length > 0) {
      mesh = this.pool.pop()!;
      mesh.material = material;
    } else {
      mesh = new THREE.Mesh(this.particleGeo, material);
    }
    mesh.visible = true;
    this.scene.add(mesh);
    return mesh;
  }

  public spawnBurst(
    x: number,
    y: number,
    z: number,
    colorHex: number,
    count: number = 8,
    speed: number = 2.0
  ): void {
    const mat = new THREE.MeshBasicMaterial({ color: colorHex });

    for (let i = 0; i < count; i++) {
      const mesh = this.getParticle(mat);
      mesh.position.set(x, y, z);

      const angle = Math.random() * Math.PI * 2;
      const elevation = Math.random() * Math.PI * 0.5;

      const p: Particle = {
        mesh,
        vx: Math.cos(angle) * Math.cos(elevation) * speed * (0.5 + Math.random() * 0.5),
        vy: Math.sin(elevation) * speed * (0.8 + Math.random() * 0.4),
        vz: Math.sin(angle) * Math.cos(elevation) * speed * (0.5 + Math.random() * 0.5),
        life: 0,
        maxLife: 0.35 + Math.random() * 0.25
      };

      this.particles.push(p);
    }
  }

  public spawnHarvestEffect(type: ResourceType, x: number, y: number, z: number): void {
    let color = 0x925e36;
    if (type === "stone") color = 0x71717a;
    else if (type === "food") color = 0xe53e3e;
    else if (type === "ore") color = 0xf59e0b;
    else if (type === "loot") color = 0xfacc15;

    this.spawnBurst(x, y + 0.5, z, color, 5, 1.6);
  }

  public spawnHitEffect(x: number, y: number, z: number): void {
    this.spawnBurst(x, y + 0.6, z, 0xef4444, 7, 2.2);
  }

  public spawnBuildEffect(x: number, y: number, z: number): void {
    this.spawnBurst(x, y + 0.4, z, 0xfacc15, 4, 1.4);
  }

  public update(dt: number): void {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life += dt;

      if (p.life >= p.maxLife) {
        p.mesh.visible = false;
        this.scene.remove(p.mesh);
        this.pool.push(p.mesh);
        this.particles.splice(i, 1);
      } else {
        p.mesh.position.x += p.vx * dt;
        p.mesh.position.y += p.vy * dt;
        p.mesh.position.z += p.vz * dt;
        p.vy -= 9.8 * dt; // Gravity

        const scale = 1.0 - (p.life / p.maxLife);
        p.mesh.scale.set(scale, scale, scale);
      }
    }
  }
}
