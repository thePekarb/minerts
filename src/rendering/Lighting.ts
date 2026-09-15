import * as THREE from "three";
import { TimeOfDay } from "../systems/TimeOfDaySystem";

export class Lighting {
  public sunLight: THREE.DirectionalLight;
  public ambientLight: THREE.AmbientLight;
  public hemiLight: THREE.HemisphereLight;
  public pointLights: THREE.PointLight[] = [];

  constructor(scene: THREE.Scene, mapSize: number) {
    // Ambient light
    this.ambientLight = new THREE.AmbientLight(0xffffff, 0.4);
    scene.add(this.ambientLight);

    // Hemisphere light (Sky vs Ground bounce)
    this.hemiLight = new THREE.HemisphereLight(0x93c5fd, 0x334155, 0.5);
    scene.add(this.hemiLight);

    // Directional Sun / Moon
    this.sunLight = new THREE.DirectionalLight(0xfff7ed, 1.2);
    this.sunLight.position.set(mapSize * 0.5, 40, mapSize * 0.5);
    this.sunLight.castShadow = true;

    // High quality shadow configuration
    this.sunLight.shadow.mapSize.width = 2048;
    this.sunLight.shadow.mapSize.height = 2048;
    this.sunLight.shadow.camera.near = 0.5;
    this.sunLight.shadow.camera.far = 150;

    const shadowDistance = mapSize * 0.75;
    this.sunLight.shadow.camera.left = -shadowDistance;
    this.sunLight.shadow.camera.right = shadowDistance;
    this.sunLight.shadow.camera.top = shadowDistance;
    this.sunLight.shadow.camera.bottom = -shadowDistance;
    this.sunLight.shadow.bias = -0.0005;

    scene.add(this.sunLight);
    scene.add(this.sunLight.target);
  }

  public updateTime(phase: TimeOfDay, cycleProgress: number, mapSize: number): void {
    // Orbital rotation around the map center
    const centerX = mapSize / 2;
    const centerZ = mapSize / 2;
    const angle = cycleProgress * Math.PI * 2 - Math.PI / 2;

    const radius = mapSize * 0.8;
    const height = Math.sin(angle) * 45;
    const posX = centerX + Math.cos(angle) * radius;
    const posZ = centerZ + Math.sin(angle) * (radius * 0.5);

    this.sunLight.position.set(posX, Math.max(10, Math.abs(height)), posZ);
    this.sunLight.target.position.set(centerX, 0, centerZ);

    switch (phase) {
      case TimeOfDay.Dawn:
        this.sunLight.color.setHex(0xfdba74); // Warm golden amber
        this.sunLight.intensity = 0.8;
        this.ambientLight.color.setHex(0xfbcfe8);
        this.ambientLight.intensity = 0.35;
        this.hemiLight.color.setHex(0xfdba74);
        this.hemiLight.groundColor.setHex(0x1e293b);
        break;

      case TimeOfDay.Day:
        this.sunLight.color.setHex(0xfffbeb); // Crisp daylight
        this.sunLight.intensity = 1.3;
        this.ambientLight.color.setHex(0xffffff);
        this.ambientLight.intensity = 0.5;
        this.hemiLight.color.setHex(0xbae6fd);
        this.hemiLight.groundColor.setHex(0x334155);
        break;

      case TimeOfDay.Dusk:
        this.sunLight.color.setHex(0xf97316); // Deep sunset orange
        this.sunLight.intensity = 0.7;
        this.ambientLight.color.setHex(0xa855f7);
        this.ambientLight.intensity = 0.3;
        this.hemiLight.color.setHex(0xf97316);
        this.hemiLight.groundColor.setHex(0x0f172a);
        break;

      case TimeOfDay.Night:
        this.sunLight.color.setHex(0x60a5fa); // Cool moonlight
        this.sunLight.intensity = 0.35;
        this.ambientLight.color.setHex(0x1e1b4b); // Deep indigo
        this.ambientLight.intensity = 0.2;
        this.hemiLight.color.setHex(0x312e81);
        this.hemiLight.groundColor.setHex(0x020617);
        break;
    }
  }

  public addCampfireLight(scene: THREE.Scene, x: number, y: number, z: number): THREE.PointLight {
    const light = new THREE.PointLight(0xf97316, 2.0, 12, 1.5);
    light.position.set(x, y + 1.2, z);
    scene.add(light);
    this.pointLights.push(light);
    return light;
  }
}
