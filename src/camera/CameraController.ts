import * as THREE from "three";

export class CameraController {
  public camera: THREE.PerspectiveCamera;
  public target: THREE.Vector3 = new THREE.Vector3(32, 0, 32);

  // Spherical coordinates
  public distance: number = 32;
  public minDistance: number = 10;
  public maxDistance: number = 65;

  public elevationAngle: number = Math.PI / 3.2; // ~56 degrees
  public azimuthAngle: number = Math.PI / 4; // 45 degrees isometric

  // Movement speed
  public panSpeed: number = 28;
  public rotateSpeed: number = 2.0;
  public zoomSpeed: number = 0.08;

  // Bounds
  public mapBounds: { minX: number; maxX: number; minZ: number; maxZ: number } = {
    minX: 4,
    maxX: 60,
    minZ: 4,
    maxZ: 60
  };

  // Input states
  private keysPressed: Set<string> = new Set();
  private isRotatingWithMouse: boolean = false;
  private previousMousePosition: { x: number; y: number } = { x: 0, y: 0 };

  constructor(camera: THREE.PerspectiveCamera, domElement: HTMLElement, mapSize: number) {
    this.camera = camera;
    this.target.set(mapSize / 2, 0, mapSize / 2);
    this.mapBounds = { minX: 4, maxX: mapSize - 4, minZ: 4, maxZ: mapSize - 4 };

    this.setupInputs(domElement);
    this.updateCameraPosition();
  }

  private setupInputs(domElement: HTMLElement): void {
    window.addEventListener("keydown", (e) => {
      this.keysPressed.add(e.code);
    });

    window.addEventListener("keyup", (e) => {
      this.keysPressed.delete(e.code);
    });

    domElement.addEventListener("wheel", (e) => {
      e.preventDefault();
      const zoomDelta = e.deltaY * 0.03;
      this.distance = THREE.MathUtils.clamp(
        this.distance + zoomDelta,
        this.minDistance,
        this.maxDistance
      );
    }, { passive: false });

    domElement.addEventListener("mousedown", (e) => {
      // Middle mouse or Right mouse while Alt pressed to rotate
      if (e.button === 1 || (e.button === 2 && e.altKey)) {
        this.isRotatingWithMouse = true;
        this.previousMousePosition = { x: e.clientX, y: e.clientY };
      }
    });

    window.addEventListener("mousemove", (e) => {
      if (this.isRotatingWithMouse) {
        const deltaX = e.clientX - this.previousMousePosition.x;
        this.azimuthAngle += deltaX * 0.006;
        this.previousMousePosition = { x: e.clientX, y: e.clientY };
      }
    });

    window.addEventListener("mouseup", (e) => {
      if (e.button === 1 || e.button === 2) {
        this.isRotatingWithMouse = false;
      }
    });
  }

  public update(deltaTime: number, terrainHeightGetter?: (x: number, z: number) => number): void {
    const moveVector = new THREE.Vector3();

    // WASD / Arrow keys
    if (this.keysPressed.has("KeyW") || this.keysPressed.has("ArrowUp")) moveVector.z -= 1;
    if (this.keysPressed.has("KeyS") || this.keysPressed.has("ArrowDown")) moveVector.z += 1;
    if (this.keysPressed.has("KeyA") || this.keysPressed.has("ArrowLeft")) moveVector.x -= 1;
    if (this.keysPressed.has("KeyD") || this.keysPressed.has("ArrowRight")) moveVector.x += 1;

    // Q / E for camera rotation
    if (this.keysPressed.has("KeyQ")) {
      this.azimuthAngle += this.rotateSpeed * deltaTime;
    }
    if (this.keysPressed.has("KeyE")) {
      this.azimuthAngle -= this.rotateSpeed * deltaTime;
    }

    if (moveVector.lengthSq() > 0) {
      moveVector.normalize();

      // Transform move vector according to camera azimuth rotation
      const forward = new THREE.Vector3(-Math.sin(this.azimuthAngle), 0, -Math.cos(this.azimuthAngle));
      const right = new THREE.Vector3(Math.cos(this.azimuthAngle), 0, -Math.sin(this.azimuthAngle));

      const displacement = new THREE.Vector3()
        .addScaledVector(right, moveVector.x)
        .addScaledVector(forward, -moveVector.z)
        .multiplyScalar(this.panSpeed * deltaTime);

      this.target.add(displacement);

      // Clamp within map bounds
      this.target.x = THREE.MathUtils.clamp(this.target.x, this.mapBounds.minX, this.mapBounds.maxX);
      this.target.z = THREE.MathUtils.clamp(this.target.z, this.mapBounds.minZ, this.mapBounds.maxZ);
    }

    // Keep target height aligned with terrain
    if (terrainHeightGetter) {
      this.target.y = terrainHeightGetter(this.target.x, this.target.z);
    }

    this.updateCameraPosition();
  }

  public focusOn(x: number, z: number): void {
    this.target.x = THREE.MathUtils.clamp(x, this.mapBounds.minX, this.mapBounds.maxX);
    this.target.z = THREE.MathUtils.clamp(z, this.mapBounds.minZ, this.mapBounds.maxZ);
    this.updateCameraPosition();
  }

  private updateCameraPosition(): void {
    const horizontalDistance = this.distance * Math.cos(this.elevationAngle);
    const verticalHeight = this.distance * Math.sin(this.elevationAngle);

    const camX = this.target.x + horizontalDistance * Math.sin(this.azimuthAngle);
    const camZ = this.target.z + horizontalDistance * Math.cos(this.azimuthAngle);
    const camY = this.target.y + verticalHeight;

    this.camera.position.set(camX, camY, camZ);
    this.camera.lookAt(this.target);
  }
}
