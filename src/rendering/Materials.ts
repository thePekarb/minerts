import * as THREE from "three";
import { TextureFactory } from "./TextureFactory";

export class Materials {
  public static grass: THREE.MeshLambertMaterial;
  public static dirt: THREE.MeshLambertMaterial;
  public static stone: THREE.MeshLambertMaterial;
  public static wood: THREE.MeshLambertMaterial;
  public static sand: THREE.MeshLambertMaterial;
  public static water: THREE.MeshLambertMaterial;
  public static ore: THREE.MeshLambertMaterial;
  public static foliage: THREE.MeshLambertMaterial;
  public static foliagePine: THREE.MeshLambertMaterial;
  public static berry: THREE.MeshLambertMaterial;

  // Unit materials
  public static skin: THREE.MeshLambertMaterial;
  public static workerClothes: THREE.MeshLambertMaterial;
  public static scoutClothes: THREE.MeshLambertMaterial;
  public static guardArmor: THREE.MeshStandardMaterial;
  public static archerClothes: THREE.MeshLambertMaterial;
  public static enemyMelee: THREE.MeshLambertMaterial;
  public static enemyFast: THREE.MeshLambertMaterial;
  public static enemyEyes: THREE.MeshBasicMaterial;

  // Ghost placement materials
  public static ghostValid: THREE.MeshBasicMaterial;
  public static ghostInvalid: THREE.MeshBasicMaterial;

  // Indicators
  public static selectionRing: THREE.MeshBasicMaterial;
  public static enemySelectionRing: THREE.MeshBasicMaterial;

  public static init(): void {
    this.grass = new THREE.MeshLambertMaterial({
      map: TextureFactory.getGrassTexture(),
      roughness: 0.8
    } as any);

    this.dirt = new THREE.MeshLambertMaterial({
      map: TextureFactory.getDirtTexture(),
      roughness: 0.9
    } as any);

    this.stone = new THREE.MeshLambertMaterial({
      map: TextureFactory.getStoneTexture(),
      roughness: 0.7
    } as any);

    this.wood = new THREE.MeshLambertMaterial({
      map: TextureFactory.getWoodTexture(),
      roughness: 0.75
    } as any);

    this.sand = new THREE.MeshLambertMaterial({
      map: TextureFactory.getSandTexture(),
      roughness: 0.9
    } as any);

    this.water = new THREE.MeshLambertMaterial({
      map: TextureFactory.getWaterTexture(),
      transparent: true,
      opacity: 0.75
    } as any);

    this.ore = new THREE.MeshLambertMaterial({
      map: TextureFactory.getOreTexture(),
      roughness: 0.6
    } as any);

    this.foliage = new THREE.MeshLambertMaterial({
      color: 0x38a169,
      roughness: 0.8
    } as any);

    this.foliagePine = new THREE.MeshLambertMaterial({
      color: 0x22543d,
      roughness: 0.8
    } as any);

    this.berry = new THREE.MeshLambertMaterial({
      color: 0xe53e3e,
      roughness: 0.5
    } as any);

    // Units
    this.skin = new THREE.MeshLambertMaterial({ color: 0xfbd38d });
    this.workerClothes = new THREE.MeshLambertMaterial({ color: 0x3182ce }); // Blue
    this.scoutClothes = new THREE.MeshLambertMaterial({ color: 0x38a169 }); // Green
    this.guardArmor = new THREE.MeshStandardMaterial({
      color: 0x718096,
      metalness: 0.6,
      roughness: 0.3
    });
    this.archerClothes = new THREE.MeshLambertMaterial({ color: 0xd69e2e }); // Gold/Leather
    this.enemyMelee = new THREE.MeshLambertMaterial({ color: 0x4a154b }); // Dark purple/charcoal
    this.enemyFast = new THREE.MeshLambertMaterial({ color: 0x742a2a }); // Crimson/Rust
    this.enemyEyes = new THREE.MeshBasicMaterial({ color: 0xff3333 });

    // Ghost materials
    this.ghostValid = new THREE.MeshBasicMaterial({
      color: 0x22c55e,
      transparent: true,
      opacity: 0.5,
      wireframe: false
    });

    this.ghostInvalid = new THREE.MeshBasicMaterial({
      color: 0xef4444,
      transparent: true,
      opacity: 0.5,
      wireframe: false
    });

    this.selectionRing = new THREE.MeshBasicMaterial({
      color: 0x22c55e,
      wireframe: true
    });

    this.enemySelectionRing = new THREE.MeshBasicMaterial({
      color: 0xef4444,
      wireframe: true
    });
  }
}
