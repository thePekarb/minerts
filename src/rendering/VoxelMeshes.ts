import * as THREE from "three";
import { Materials } from "./Materials";
import { UnitType } from "../data/unitConfigs";
import { BuildingType } from "../data/buildingConfigs";

export interface UnitMeshHierarchy {
  root: THREE.Group;
  body: THREE.Mesh;
  head: THREE.Mesh;
  leftArm: THREE.Group;
  rightArm: THREE.Group;
  leftLeg: THREE.Group;
  rightLeg: THREE.Group;
  weaponOrTool?: THREE.Mesh;
  selectionRing: THREE.Mesh;
  healthBar: {
    bg: THREE.Mesh;
    fill: THREE.Mesh;
  };
}

export class VoxelMeshes {
  // Build Unit 3D Model
  public static createUnitMesh(type: UnitType, isPlayer: boolean): UnitMeshHierarchy {
    const root = new THREE.Group();

    // Body / Torso
    let clothesMat = Materials.workerClothes;
    if (type === "scout") clothesMat = Materials.scoutClothes;
    else if (type === "guard") clothesMat = Materials.guardArmor as any;
    else if (type === "archer") clothesMat = Materials.archerClothes;
    else if (type === "enemy_melee") clothesMat = Materials.enemyMelee;
    else if (type === "enemy_fast") clothesMat = Materials.enemyFast;

    const bodyWidth = type === "enemy_melee" ? 0.6 : (type === "enemy_fast" ? 0.45 : 0.45);
    const bodyHeight = type === "enemy_melee" ? 0.7 : (type === "enemy_fast" ? 0.4 : 0.55);
    const bodyDepth = type === "enemy_fast" ? 0.6 : 0.3;

    const bodyGeo = new THREE.BoxGeometry(bodyWidth, bodyHeight, bodyDepth);
    const body = new THREE.Mesh(bodyGeo, clothesMat);
    body.position.y = type === "enemy_fast" ? 0.35 : 0.65;
    body.castShadow = true;
    body.receiveShadow = true;
    root.add(body);

    // Head
    const headSize = type === "enemy_melee" ? 0.38 : 0.32;
    const headGeo = new THREE.BoxGeometry(headSize, headSize, headSize);
    const headMat = isPlayer ? Materials.skin : clothesMat;
    const head = new THREE.Mesh(headGeo, headMat);
    head.position.y = bodyHeight / 2 + headSize / 2 + 0.02;
    head.castShadow = true;
    body.add(head);

    // Eyes / Details
    if (!isPlayer) {
      // Glowing red eyes for enemies
      const eyeGeo = new THREE.BoxGeometry(0.06, 0.04, 0.04);
      const leftEye = new THREE.Mesh(eyeGeo, Materials.enemyEyes);
      leftEye.position.set(-0.09, 0.04, headSize / 2 + 0.01);
      const rightEye = new THREE.Mesh(eyeGeo, Materials.enemyEyes);
      rightEye.position.set(0.09, 0.04, headSize / 2 + 0.01);
      head.add(leftEye);
      head.add(rightEye);
    } else if (type === "guard") {
      // Guard Helmet
      const helmGeo = new THREE.BoxGeometry(headSize + 0.04, 0.15, headSize + 0.04);
      const helm = new THREE.Mesh(helmGeo, Materials.guardArmor);
      helm.position.y = 0.12;
      head.add(helm);
    }

    // Limbs
    const limbGeo = new THREE.BoxGeometry(0.14, 0.4, 0.14);
    limbGeo.translate(0, -0.2, 0); // Pivot at top

    // Left Arm
    const leftArm = new THREE.Group();
    leftArm.position.set(-bodyWidth / 2 - 0.08, bodyHeight / 2 - 0.05, 0);
    const leftArmMesh = new THREE.Mesh(limbGeo, clothesMat);
    leftArmMesh.castShadow = true;
    leftArm.add(leftArmMesh);
    body.add(leftArm);

    // Right Arm
    const rightArm = new THREE.Group();
    rightArm.position.set(bodyWidth / 2 + 0.08, bodyHeight / 2 - 0.05, 0);
    const rightArmMesh = new THREE.Mesh(limbGeo, clothesMat);
    rightArmMesh.castShadow = true;
    rightArm.add(rightArmMesh);
    body.add(rightArm);

    // Legs
    const legGeo = new THREE.BoxGeometry(0.15, 0.4, 0.15);
    legGeo.translate(0, -0.2, 0);

    const leftLeg = new THREE.Group();
    leftLeg.position.set(-bodyWidth / 4, -bodyHeight / 2, 0);
    const leftLegMesh = new THREE.Mesh(legGeo, clothesMat);
    leftLegMesh.castShadow = true;
    leftLeg.add(leftLegMesh);
    body.add(leftLeg);

    const rightLeg = new THREE.Group();
    rightLeg.position.set(bodyWidth / 4, -bodyHeight / 2, 0);
    const rightLegMesh = new THREE.Mesh(legGeo, clothesMat);
    rightLegMesh.castShadow = true;
    rightLeg.add(rightLegMesh);
    body.add(rightLeg);

    // Weapons / Tools
    let weaponOrTool: THREE.Mesh | undefined;
    if (type === "worker") {
      // Pickaxe / Hammer
      const handleGeo = new THREE.BoxGeometry(0.06, 0.45, 0.06);
      const headGeoT = new THREE.BoxGeometry(0.24, 0.08, 0.08);
      const toolMesh = new THREE.Mesh(handleGeo, Materials.wood);
      const headMesh = new THREE.Mesh(headGeoT, Materials.stone);
      headMesh.position.y = -0.2;
      toolMesh.add(headMesh);
      toolMesh.position.set(0, -0.3, 0.12);
      toolMesh.rotation.x = Math.PI / 3;
      rightArm.add(toolMesh);
      weaponOrTool = toolMesh;
    } else if (type === "guard") {
      // Sword in right hand, Shield in left hand
      const swordGeo = new THREE.BoxGeometry(0.06, 0.55, 0.08);
      const swordMesh = new THREE.Mesh(swordGeo, Materials.guardArmor);
      swordMesh.position.set(0, -0.25, 0.15);
      swordMesh.rotation.x = Math.PI / 3;
      rightArm.add(swordMesh);
      weaponOrTool = swordMesh;

      const shieldGeo = new THREE.BoxGeometry(0.3, 0.4, 0.08);
      const shieldMesh = new THREE.Mesh(shieldGeo, Materials.wood);
      shieldMesh.position.set(0, -0.2, 0.12);
      leftArm.add(shieldMesh);
    } else if (type === "archer") {
      // Wooden Bow
      const bowGeo = new THREE.BoxGeometry(0.06, 0.55, 0.06);
      const bowMesh = new THREE.Mesh(bowGeo, Materials.wood);
      bowMesh.position.set(0, -0.25, 0.15);
      leftArm.add(bowMesh);
      weaponOrTool = bowMesh;
    } else if (type === "enemy_melee") {
      // Spiked heavy club
      const clubGeo = new THREE.BoxGeometry(0.12, 0.65, 0.12);
      const clubMesh = new THREE.Mesh(clubGeo, Materials.wood);
      clubMesh.position.set(0, -0.3, 0.15);
      clubMesh.rotation.x = Math.PI / 3;
      rightArm.add(clubMesh);
      weaponOrTool = clubMesh;
    }

    // Selection Ring (under feet)
    const ringGeo = new THREE.RingGeometry(0.4, 0.48, 16);
    ringGeo.rotateX(-Math.PI / 2);
    const ringMat = isPlayer ? Materials.selectionRing : Materials.enemySelectionRing;
    const selectionRing = new THREE.Mesh(ringGeo, ringMat);
    selectionRing.position.y = 0.03;
    selectionRing.visible = false;
    root.add(selectionRing);

    // Floating Healthbar
    const hbBgGeo = new THREE.PlaneGeometry(0.6, 0.08);
    const hbBgMat = new THREE.MeshBasicMaterial({ color: 0x1e293b });
    const hbBg = new THREE.Mesh(hbBgGeo, hbBgMat);
    hbBg.position.y = 1.35;
    hbBg.rotation.x = -Math.PI / 4;

    const hbFillGeo = new THREE.PlaneGeometry(0.56, 0.06);
    hbFillGeo.translate(0.28, 0, 0); // Left anchor
    const hbFillMat = new THREE.MeshBasicMaterial({ color: isPlayer ? 0x22c55e : 0xef4444 });
    const hbFill = new THREE.Mesh(hbFillGeo, hbFillMat);
    hbFill.position.set(-0.28, 0, 0.005);
    hbBg.add(hbFill);
    root.add(hbBg);

    return {
      root,
      body,
      head,
      leftArm,
      rightArm,
      leftLeg,
      rightLeg,
      weaponOrTool,
      selectionRing,
      healthBar: { bg: hbBg, fill: hbFill }
    };
  }

  // Build Building 3D Mesh
  public static createBuildingMesh(type: BuildingType, ghost: boolean = false, valid: boolean = true): THREE.Group {
    const group = new THREE.Group();

    const getMat = (origMat: THREE.Material) => {
      if (!ghost) return origMat;
      return valid ? Materials.ghostValid : Materials.ghostInvalid;
    };

    switch (type) {
      case "campfire": {
        // Stone fire circle + logs + fire
        const stones = 8;
        for (let i = 0; i < stones; i++) {
          const a = (i / stones) * Math.PI * 2;
          const sMesh = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.25, 0.35), getMat(Materials.stone));
          sMesh.position.set(Math.cos(a) * 0.9, 0.125, Math.sin(a) * 0.9);
          sMesh.castShadow = !ghost;
          group.add(sMesh);
        }
        // Logs
        const log1 = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.15, 0.2), getMat(Materials.wood));
        log1.position.set(0, 0.1, 0);
        log1.rotation.y = Math.PI / 4;
        const log2 = log1.clone();
        log2.rotation.y = -Math.PI / 4;
        group.add(log1);
        group.add(log2);

        // Fire ember cube
        const fire = new THREE.Mesh(
          new THREE.BoxGeometry(0.3, 0.35, 0.3),
          ghost ? getMat(Materials.wood) : new THREE.MeshBasicMaterial({ color: 0xf97316 })
        );
        fire.position.set(0, 0.25, 0);
        group.add(fire);

        // Tent / shelter next to campfire
        const tentGeo = new THREE.ConeGeometry(1.0, 1.4, 4);
        tentGeo.rotateY(Math.PI / 4);
        const tent = new THREE.Mesh(tentGeo, getMat(Materials.wood));
        tent.position.set(0.9, 0.7, -0.9);
        tent.castShadow = !ghost;
        group.add(tent);
        break;
      }

      case "hut": {
        // Base foundation
        const fMesh = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.3, 1.8), getMat(Materials.stone));
        fMesh.position.y = 0.15;
        fMesh.castShadow = !ghost;
        group.add(fMesh);

        // Wooden log walls
        const wallMesh = new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.1, 1.6), getMat(Materials.wood));
        wallMesh.position.y = 0.85;
        wallMesh.castShadow = !ghost;
        group.add(wallMesh);

        // Roof (pyramid / pitch)
        const roofGeo = new THREE.ConeGeometry(1.4, 0.8, 4);
        roofGeo.rotateY(Math.PI / 4);
        const roof = new THREE.Mesh(roofGeo, getMat(Materials.foliagePine));
        roof.position.y = 1.8;
        roof.castShadow = !ghost;
        group.add(roof);
        break;
      }

      case "storage": {
        // Platform
        const floor = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.2, 1.9), getMat(Materials.wood));
        floor.position.y = 0.1;
        group.add(floor);

        // 4 corner posts
        const postGeo = new THREE.BoxGeometry(0.15, 1.4, 0.15);
        [-0.8, 0.8].forEach((x) => {
          [-0.8, 0.8].forEach((z) => {
            const post = new THREE.Mesh(postGeo, getMat(Materials.wood));
            post.position.set(x, 0.7, z);
            group.add(post);
          });
        });

        // Crates and barrels inside
        const crateGeo = new THREE.BoxGeometry(0.5, 0.5, 0.5);
        const crate1 = new THREE.Mesh(crateGeo, getMat(Materials.wood));
        crate1.position.set(-0.3, 0.45, -0.3);
        const crate2 = new THREE.Mesh(crateGeo, getMat(Materials.stone));
        crate2.position.set(0.3, 0.45, -0.2);
        group.add(crate1);
        group.add(crate2);

        // Roof awning
        const roof = new THREE.Mesh(new THREE.BoxGeometry(2.1, 0.1, 2.1), getMat(Materials.wood));
        roof.position.y = 1.45;
        group.add(roof);
        break;
      }

      case "wall": {
        // Sturdy palisade log wall
        const wall = new THREE.Mesh(new THREE.BoxGeometry(0.95, 1.5, 0.95), getMat(Materials.wood));
        wall.position.y = 0.75;
        wall.castShadow = !ghost;
        group.add(wall);

        // Pointed spikes on top
        const spike = new THREE.Mesh(new THREE.ConeGeometry(0.4, 0.5, 4), getMat(Materials.wood));
        spike.position.y = 1.75;
        spike.rotation.y = Math.PI / 4;
        group.add(spike);
        break;
      }

      case "gate": {
        // 2 side pillars
        const postGeo = new THREE.BoxGeometry(0.3, 1.7, 0.6);
        const leftPost = new THREE.Mesh(postGeo, getMat(Materials.wood));
        leftPost.position.set(-0.85, 0.85, 0);
        const rightPost = new THREE.Mesh(postGeo, getMat(Materials.wood));
        rightPost.position.set(0.85, 0.85, 0);
        group.add(leftPost);
        group.add(rightPost);

        // Top arch
        const topBar = new THREE.Mesh(new THREE.BoxGeometry(2.0, 0.3, 0.4), getMat(Materials.wood));
        topBar.position.set(0, 1.75, 0);
        group.add(topBar);

        // Center door panel
        const door = new THREE.Mesh(new THREE.BoxGeometry(1.4, 1.3, 0.15), getMat(Materials.wood));
        door.name = "gate_door";
        door.position.set(0, 0.75, 0);
        group.add(door);
        break;
      }

      case "tower": {
        // Stone base
        const base = new THREE.Mesh(new THREE.BoxGeometry(1.5, 1.8, 1.5), getMat(Materials.stone));
        base.position.y = 0.9;
        base.castShadow = !ghost;
        group.add(base);

        // Wooden guard platform
        const platform = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.3, 1.9), getMat(Materials.wood));
        platform.position.y = 1.95;
        group.add(platform);

        // Battlements
        const fenceGeo = new THREE.BoxGeometry(0.15, 0.4, 1.9);
        const f1 = new THREE.Mesh(fenceGeo, getMat(Materials.wood));
        f1.position.set(-0.87, 2.3, 0);
        const f2 = f1.clone();
        f2.position.set(0.87, 2.3, 0);
        group.add(f1);
        group.add(f2);

        // Roof
        const roof = new THREE.Mesh(new THREE.ConeGeometry(1.5, 0.9, 4), getMat(Materials.foliagePine));
        roof.position.y = 3.1;
        roof.rotation.y = Math.PI / 4;
        roof.castShadow = !ghost;
        group.add(roof);
        break;
      }

      case "workshop": {
        // Foundation
        const base = new THREE.Mesh(new THREE.BoxGeometry(2.6, 0.3, 1.8), getMat(Materials.stone));
        base.position.y = 0.15;
        group.add(base);

        const house = new THREE.Mesh(new THREE.BoxGeometry(2.4, 1.2, 1.6), getMat(Materials.wood));
        house.position.y = 0.9;
        group.add(house);

        // Stone chimney
        const chimney = new THREE.Mesh(new THREE.BoxGeometry(0.5, 2.2, 0.5), getMat(Materials.stone));
        chimney.position.set(1.0, 1.1, -0.5);
        group.add(chimney);
        break;
      }

      case "castle": {
        // Keep
        const keep = new THREE.Mesh(new THREE.BoxGeometry(3.6, 2.5, 3.6), getMat(Materials.stone));
        keep.position.y = 1.25;
        group.add(keep);

        // 4 Corner Towers
        const cTowerGeo = new THREE.BoxGeometry(1.0, 3.8, 1.0);
        [-1.6, 1.6].forEach((x) => {
          [-1.6, 1.6].forEach((z) => {
            const ct = new THREE.Mesh(cTowerGeo, getMat(Materials.stone));
            ct.position.set(x, 1.9, z);
            group.add(ct);
          });
        });
        break;
      }

      case "mine": {
        // Stone foundation / pit rim
        const pitRim = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.4, 1.9), getMat(Materials.stone));
        pitRim.position.y = 0.2;
        pitRim.castShadow = !ghost;
        group.add(pitRim);

        // Dark underground pit
        const pitInterior = new THREE.Mesh(
          new THREE.BoxGeometry(1.2, 0.2, 1.2),
          new THREE.MeshBasicMaterial({ color: 0x09090b })
        );
        pitInterior.position.y = 0.35;
        group.add(pitInterior);

        // Wooden mine headframe (4 vertical posts + crossbeam)
        const postGeo = new THREE.BoxGeometry(0.12, 1.8, 0.12);
        [-0.6, 0.6].forEach((x) => {
          [-0.6, 0.6].forEach((z) => {
            const p = new THREE.Mesh(postGeo, getMat(Materials.wood));
            p.position.set(x, 0.9, z);
            p.castShadow = !ghost;
            group.add(p);
          });
        });

        // Top crossbeam
        const beam1 = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.12, 0.12), getMat(Materials.wood));
        beam1.position.set(0, 1.75, 0.6);
        const beam2 = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.12, 0.12), getMat(Materials.wood));
        beam2.position.set(0, 1.75, -0.6);
        const beam3 = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.12, 1.4), getMat(Materials.wood));
        beam3.position.set(0, 1.75, 0);
        group.add(beam1);
        group.add(beam2);
        group.add(beam3);

        // Pulley / wheel
        const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.08, 8), getMat(Materials.stone));
        wheel.rotation.z = Math.PI / 2;
        wheel.position.set(0, 1.6, 0);
        group.add(wheel);

        // Piles of excavated stone boulders next to mine
        const stonePile = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.35, 0.45), getMat(Materials.stone));
        stonePile.position.set(0.8, 0.2, -0.6);
        stonePile.rotation.y = 0.4;
        group.add(stonePile);

        // Ore indicator on side (becomes visible when upgraded)
        const oreCube = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.35, 0.35), getMat(Materials.ore));
        oreCube.position.set(-0.7, 0.2, 0.7);
        oreCube.name = "mine_ore_cube";
        oreCube.visible = false;
        group.add(oreCube);
        break;
      }
    }

    return group;
  }

  // Build Resource Prop Meshes
  public static createTreeMesh(): THREE.Group {
    const group = new THREE.Group();
    // Trunk
    const trunk = new THREE.Mesh(new THREE.BoxGeometry(0.35, 1.5, 0.35), Materials.wood);
    trunk.position.y = 0.75;
    trunk.castShadow = true;
    group.add(trunk);

    // Leaves / foliage layers
    const foliageMat = Math.random() > 0.5 ? Materials.foliage : Materials.foliagePine;
    const leafGeo1 = new THREE.BoxGeometry(1.3, 0.8, 1.3);
    const leaf1 = new THREE.Mesh(leafGeo1, foliageMat);
    leaf1.position.y = 1.8;
    leaf1.castShadow = true;
    group.add(leaf1);

    const leafGeo2 = new THREE.BoxGeometry(0.9, 0.7, 0.9);
    const leaf2 = new THREE.Mesh(leafGeo2, foliageMat);
    leaf2.position.y = 2.4;
    leaf2.castShadow = true;
    group.add(leaf2);

    return group;
  }

  public static createRockMesh(isOre: boolean = false): THREE.Group {
    const group = new THREE.Group();
    const mat = isOre ? Materials.ore : Materials.stone;

    // Main boulder
    const base = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.9, 1.2), mat);
    base.position.y = 0.45;
    base.castShadow = true;
    base.rotation.y = Math.random() * Math.PI;
    group.add(base);

    // Top crag
    const top = new THREE.Mesh(new THREE.BoxGeometry(0.85, 0.75, 0.85), mat);
    top.position.set(0.15, 0.95, -0.1);
    top.castShadow = true;
    top.rotation.y = 0.5;
    group.add(top);

    // Side boulder
    const side = new THREE.Mesh(new THREE.BoxGeometry(0.65, 0.5, 0.65), mat);
    side.position.set(-0.45, 0.25, 0.35);
    side.castShadow = true;
    group.add(side);

    return group;
  }

  public static createBushMesh(): THREE.Group {
    const group = new THREE.Group();
    const bush = new THREE.Mesh(new THREE.BoxGeometry(0.75, 0.6, 0.75), Materials.foliage);
    bush.position.y = 0.3;
    bush.castShadow = true;
    group.add(bush);

    // Red berries
    for (let i = 0; i < 6; i++) {
      const b = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.1, 0.1), Materials.berry);
      b.position.set(
        (Math.random() - 0.5) * 0.7,
        0.3 + (Math.random() - 0.5) * 0.3,
        (Math.random() - 0.5) * 0.7
      );
      group.add(b);
    }

    return group;
  }

  public static createChestMesh(): THREE.Group {
    const group = new THREE.Group();
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.65, 0.35, 0.45), Materials.wood);
    body.position.y = 0.175;
    body.castShadow = true;
    group.add(body);

    const lid = new THREE.Mesh(new THREE.BoxGeometry(0.67, 0.15, 0.47), Materials.wood);
    lid.position.set(0, 0.42, 0);
    lid.castShadow = true;
    group.add(lid);

    // Golden lock
    const lock = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.12, 0.08), Materials.sand);
    lock.position.set(0, 0.3, 0.25);
    group.add(lock);

    return group;
  }

  public static createCaveMesh(): THREE.Group {
    const group = new THREE.Group();
    // Heavy rocky archway
    const arch = new THREE.Mesh(new THREE.BoxGeometry(2.4, 2.2, 1.6), Materials.stone);
    arch.position.y = 1.1;
    arch.castShadow = true;
    group.add(arch);

    // Deep black mouth
    const mouth = new THREE.Mesh(
      new THREE.BoxGeometry(1.2, 1.4, 0.8),
      new THREE.MeshBasicMaterial({ color: 0x020617 })
    );
    mouth.position.set(0, 0.8, 0.45);
    group.add(mouth);

    return group;
  }
}
