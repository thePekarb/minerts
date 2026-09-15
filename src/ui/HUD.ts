import { eventBus } from "../game/EventBus";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { BuildingType } from "../data/buildingConfigs";
import { TimeOfDay } from "../systems/TimeOfDaySystem";

export class HUD {
  // Top bar elements
  private resWood: HTMLElement;
  private resStone: HTMLElement;
  private resFood: HTMLElement;
  private resOre: HTMLElement;
  private resPop: HTMLElement;

  private timeBadge: HTMLElement;
  private timeClock: HTMLElement;
  private dayCounter: HTMLElement;
  private waveWarning: HTMLElement;
  private waveTimer: HTMLElement;

  // Selection panels
  private selectionPanel: HTMLElement;
  private selIcon: HTMLElement;
  private selTitle: HTMLElement;
  private selSubtitle: HTMLElement;
  private selHpBar: HTMLElement;
  private selHpText: HTMLElement;
  private statDmg: HTMLElement;
  private statArm: HTMLElement;
  private statSpd: HTMLElement;
  private selInventory: HTMLElement;
  private invDetails: HTMLElement;

  // Action buttons
  private actTrainWorker: HTMLElement;
  private actTrainGuard: HTMLElement;
  private actTrainArcher: HTMLElement;
  private actRepair: HTMLElement;

  // Multi-unit selection
  private multiPanel: HTMLElement;
  private multiCount: HTMLElement;
  private multiList: HTMLElement;

  // Event Log
  private eventLog: HTMLElement;

  // Build menu
  private buildButtons: NodeListOf<HTMLButtonElement>;
  private btnLumberZone: HTMLElement | null = null;
  private actUpgradeMine: HTMLElement | null = null;
  private actToggleGate: HTMLElement | null = null;

  // Callbacks
  public onBuildSelect?: (type: BuildingType) => void;
  public onLumberZoneToggle?: () => void;
  public onUpgradeBuilding?: (building: Building) => void;
  public onToggleGate?: (building: Building) => void;
  public onTrainUnit?: (type: "worker" | "guard" | "archer", building: Building) => void;
  public onUnitAction?: (action: "stop" | "hold" | "retreat") => void;

  public currentInspectedBuilding: Building | null = null;

  constructor() {
    this.resWood = document.getElementById("res-wood")!;
    this.resStone = document.getElementById("res-stone")!;
    this.resFood = document.getElementById("res-food")!;
    this.resOre = document.getElementById("res-ore")!;
    this.resPop = document.getElementById("res-pop")!;

    this.timeBadge = document.getElementById("time-phase-badge")!;
    this.timeClock = document.getElementById("time-clock")!;
    this.dayCounter = document.getElementById("day-counter")!;
    this.waveWarning = document.getElementById("wave-warning")!;
    this.waveTimer = document.getElementById("wave-timer")!;

    this.selectionPanel = document.getElementById("selection-panel")!;
    this.selIcon = document.getElementById("sel-icon")!;
    this.selTitle = document.getElementById("sel-title")!;
    this.selSubtitle = document.getElementById("sel-subtitle")!;
    this.selHpBar = document.getElementById("sel-hp-bar")!;
    this.selHpText = document.getElementById("sel-hp-text")!;
    this.statDmg = document.getElementById("stat-dmg")!;
    this.statArm = document.getElementById("stat-arm")!;
    this.statSpd = document.getElementById("stat-spd")!;
    this.selInventory = document.getElementById("sel-inventory")!;
    this.invDetails = document.getElementById("inv-details")!;

    this.actTrainWorker = document.getElementById("act-train-worker")!;
    this.actTrainGuard = document.getElementById("act-train-guard")!;
    this.actTrainArcher = document.getElementById("act-train-archer")!;
    this.actRepair = document.getElementById("act-repair")!;
    this.actUpgradeMine = document.getElementById("act-upgrade-mine");
    this.actToggleGate = document.getElementById("act-toggle-gate");

    this.multiPanel = document.getElementById("multi-selection-panel")!;
    this.multiCount = document.getElementById("multi-count")!;
    this.multiList = document.getElementById("multi-unit-list")!;

    this.eventLog = document.getElementById("event-log")!;
    this.buildButtons = document.querySelectorAll(".btn-build");
    this.btnLumberZone = document.getElementById("btn-lumber-zone");

    this.setupEventListeners();
    this.setupEventBusSubscribers();
  }

  private setupEventListeners(): void {
    // Build buttons
    this.buildButtons.forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const type = btn.getAttribute("data-type") as BuildingType;
        if (!type) return; // e.g. special tool button
        this.clearBuildActive();
        btn.classList.add("active");
        if (this.onBuildSelect) this.onBuildSelect(type);
      });
    });

    // Lumber Zone tool button
    this.btnLumberZone?.addEventListener("click", (e) => {
      e.stopPropagation();
      this.clearBuildActive();
      if (this.onLumberZoneToggle) this.onLumberZoneToggle();
    });

    // Building upgrade button
    this.actUpgradeMine?.addEventListener("click", () => {
      if (this.currentInspectedBuilding) {
        this.onUpgradeBuilding?.(this.currentInspectedBuilding);
      }
    });

    // Gate toggle button
    this.actToggleGate?.addEventListener("click", () => {
      if (this.currentInspectedBuilding && this.currentInspectedBuilding.type === "gate") {
        this.onToggleGate?.(this.currentInspectedBuilding);
      }
    });

    // Action buttons
    document.getElementById("act-stop")?.addEventListener("click", () => this.onUnitAction?.("stop"));
    document.getElementById("act-hold")?.addEventListener("click", () => this.onUnitAction?.("hold"));
    document.getElementById("act-retreat")?.addEventListener("click", () => this.onUnitAction?.("retreat"));

    // Help Modal
    const helpModal = document.getElementById("help-modal");
    document.getElementById("btn-help")?.addEventListener("click", () => {
      helpModal?.classList.remove("hidden");
    });
    document.getElementById("btn-close-help")?.addEventListener("click", () => {
      helpModal?.classList.add("hidden");
    });
  }

  public clearBuildActive(): void {
    this.buildButtons.forEach((btn) => btn.classList.remove("active"));
    this.btnLumberZone?.classList.remove("active");
  }

  public setLumberZoneActive(active: boolean): void {
    if (active) {
      this.btnLumberZone?.classList.add("active");
    } else {
      this.btnLumberZone?.classList.remove("active");
    }
  }

  private setupEventBusSubscribers(): void {
    // Resources
    eventBus.on("resourceChanged", (data) => {
      this.resWood.textContent = data.wood;
      this.resStone.textContent = data.stone;
      this.resFood.textContent = data.food;
      this.resOre.textContent = data.ore;
      this.resPop.textContent = `${data.pop}/${data.maxPop}`;
    });

    // Time
    eventBus.on("timeChanged", (data) => {
      this.timeClock.textContent = data.timeString;
      this.dayCounter.textContent = `Day ${data.day}`;

      this.timeBadge.className = "";
      if (data.timeOfDay === TimeOfDay.Dawn) {
        this.timeBadge.className = "badge-dawn";
        this.timeBadge.textContent = "🌅 Dawn";
      } else if (data.timeOfDay === TimeOfDay.Day) {
        this.timeBadge.className = "badge-day";
        this.timeBadge.textContent = "☀️ Day";
      } else if (data.timeOfDay === TimeOfDay.Dusk) {
        this.timeBadge.className = "badge-dusk";
        this.timeBadge.textContent = "🌆 Dusk";
      } else {
        this.timeBadge.className = "badge-night";
        this.timeBadge.textContent = "🌙 Night";
      }
    });

    // Raid warning
    eventBus.on("raidWarning", (data) => {
      this.waveWarning.classList.remove("hidden");
      this.waveTimer.textContent = `${data.secondsLeft}s`;
    });

    eventBus.on("raidStarted", () => {
      this.waveWarning.classList.add("hidden");
    });

    // Toasts
    eventBus.on("toast", (data: { message: string; type?: "info" | "warn" | "danger" | "success" }) => {
      this.addToast(data.message, data.type || "info");
    });

    // Unit selection inspect
    eventBus.on("unitSelected", (unit: Unit | null) => {
      if (unit) {
        this.showUnitInspect(unit);
      } else {
        this.selectionPanel.classList.add("hidden");
      }
    });

    // Multi-unit selection
    eventBus.on("multiUnitSelected", (units: Unit[]) => {
      if (units.length > 1) {
        this.showMultiInspect(units);
      } else {
        this.multiPanel.classList.add("hidden");
      }
    });

    // Building selection inspect
    eventBus.on("buildingSelected", (building: Building | null) => {
      if (building) {
        this.showBuildingInspect(building);
      } else if (!this.selectionPanel.classList.contains("hidden")) {
        this.selectionPanel.classList.add("hidden");
      }
    });
  }

  private showUnitInspect(unit: Unit): void {
    this.selectionPanel.classList.remove("hidden");
    this.multiPanel.classList.add("hidden");

    let icon = "🧑‍🌾";
    if (unit.type === "scout") icon = "🏃";
    else if (unit.type === "guard") icon = "⚔️";
    else if (unit.type === "archer") icon = "🏹";
    else if (unit.type === "enemy_melee") icon = "👹";
    else if (unit.type === "enemy_fast") icon = "🐺";

    this.selIcon.textContent = icon;
    this.selTitle.textContent = unit.config.name;
    this.selSubtitle.textContent = `State: ${unit.state.toUpperCase()}`;

    const hpPct = Math.max(0, (unit.health / unit.maxHealth) * 100);
    this.selHpBar.style.width = `${hpPct}%`;
    this.selHpText.textContent = `${Math.ceil(unit.health)} / ${unit.maxHealth} HP`;

    this.statDmg.textContent = unit.attackDamage.toString();
    this.statArm.textContent = unit.type === "guard" ? "4" : "0";
    this.statSpd.textContent = unit.speed.toString();

    // Inventory
    if (unit.inventory && unit.inventory.amount > 0) {
      this.selInventory.classList.remove("hidden");
      this.invDetails.textContent = `${unit.inventory.amount} ${unit.inventory.type.toUpperCase()}`;
    } else {
      this.selInventory.classList.add("hidden");
    }

    // Hide recruitment buttons
    this.actTrainWorker.classList.add("hidden");
    this.actTrainGuard.classList.add("hidden");
    this.actTrainArcher.classList.add("hidden");
    this.actRepair.classList.add("hidden");
    this.actUpgradeMine?.classList.add("hidden");
    this.actToggleGate?.classList.add("hidden");
  }

  public refreshSelectedUnit(unit?: Unit): void {
    if (!unit || !unit.isAlive || this.selectionPanel.classList.contains("hidden")) return;
    this.selSubtitle.textContent = `State: ${unit.state.toUpperCase()}`;
    const hpPct = Math.max(0, (unit.health / unit.maxHealth) * 100);
    this.selHpBar.style.width = `${hpPct}%`;
    this.selHpText.textContent = `${Math.ceil(unit.health)} / ${unit.maxHealth} HP`;

    if (unit.inventory && unit.inventory.amount > 0) {
      this.selInventory.classList.remove("hidden");
      this.invDetails.textContent = `${unit.inventory.amount}/${unit.config.inventoryCapacity} ${unit.inventory.type.toUpperCase()}`;
    } else {
      this.selInventory.classList.add("hidden");
    }
  }

  public updateGateButtonText(building: Building): void {
    if (building.type !== "gate") return;
    if (this.actToggleGate) {
      this.actToggleGate.textContent = building.isOpen ? "🔒 Close Gate [O]" : "🚪 Open Gate [O]";
      this.actToggleGate.title = building.isOpen ? "Click to close and lock the gate [O]" : "Click to open the gate [O]";
    }
    if (this.currentInspectedBuilding === building) {
      this.selSubtitle.textContent = building.isOpen ? "Status: Open (Passable)" : "Status: Closed (Locked)";
    }
  }

  public showBuildingInspect(building: Building): void {
    this.currentInspectedBuilding = building;
    this.selectionPanel.classList.remove("hidden");
    this.multiPanel.classList.add("hidden");

    let icon = "🛖";
    if (building.type === "campfire") icon = "🔥";
    else if (building.type === "storage") icon = "📦";
    else if (building.type === "tower") icon = "🗼";
    else if (building.type === "workshop") icon = "🔨";
    else if (building.type === "wall") icon = "🧱";
    else if (building.type === "gate") icon = "🚪";
    else if (building.type === "mine") icon = "⛏️";

    this.selIcon.textContent = icon;
    this.selTitle.textContent = building.config.name;
    this.selSubtitle.textContent = building.isConstructed
      ? (building.type === "mine"
          ? (building.level >= 2 ? "Deep Mine (Stone + Ore)" : "Quarry (Stone)")
          : (building.type === "gate" ? (building.isOpen ? "Status: Open (Passable)" : "Status: Closed (Locked)") : "Status: Active"))
      : `Building: ${Math.floor(building.constructionProgress)}%`;

    const hpPct = Math.max(0, (building.health / building.maxHealth) * 100);
    this.selHpBar.style.width = `${hpPct}%`;
    this.selHpText.textContent = `${Math.ceil(building.health)} / ${building.maxHealth} HP`;

    this.statDmg.textContent = (building.config.attackDamage || 0).toString();
    this.statArm.textContent = "5";
    this.statSpd.textContent = "0";
    this.selInventory.classList.add("hidden");

    // Show recruitment actions based on building
    if (building.type === "campfire" && building.isConstructed) {
      this.actTrainWorker.classList.remove("hidden");
      this.actTrainWorker.onclick = () => this.onTrainUnit?.("worker", building);
    } else {
      this.actTrainWorker.classList.add("hidden");
    }

    if (building.type === "workshop" && building.isConstructed) {
      this.actTrainGuard.classList.remove("hidden");
      this.actTrainGuard.onclick = () => this.onTrainUnit?.("guard", building);

      this.actTrainArcher.classList.remove("hidden");
      this.actTrainArcher.onclick = () => this.onTrainUnit?.("archer", building);
    } else {
      this.actTrainGuard.classList.add("hidden");
      this.actTrainArcher.classList.add("hidden");
    }

    // Upgrade Mine button
    if (building.type === "mine" && building.isConstructed && building.level === 1) {
      this.actUpgradeMine?.classList.remove("hidden");
      if (this.actUpgradeMine) {
        this.actUpgradeMine.textContent = "⬆️ Deep Mine (40🪵 30🪨)";
      }
    } else {
      this.actUpgradeMine?.classList.add("hidden");
    }

    // Gate toggle button
    if (building.type === "gate" && building.isConstructed) {
      this.actToggleGate?.classList.remove("hidden");
      this.updateGateButtonText(building);
    } else {
      this.actToggleGate?.classList.add("hidden");
    }

    // Repair button
    if (building.health < building.maxHealth) {
      this.actRepair.classList.remove("hidden");
    } else {
      this.actRepair.classList.add("hidden");
    }
  }

  private showMultiInspect(units: Unit[]): void {
    this.selectionPanel.classList.add("hidden");
    this.multiPanel.classList.remove("hidden");
    this.multiCount.textContent = units.length.toString();

    this.multiList.innerHTML = "";
    units.slice(0, 12).forEach((u) => {
      const card = document.createElement("div");
      card.className = "multi-unit-card";
      let ic = "🧑‍🌾";
      if (u.type === "scout") ic = "🏃";
      else if (u.type === "guard") ic = "⚔️";
      else if (u.type === "archer") ic = "🏹";
      card.innerHTML = `${ic}<br><small>${Math.ceil(u.health)}HP</small>`;
      this.multiList.appendChild(card);
    });
  }

  public addToast(message: string, type: "info" | "warn" | "danger" | "success" = "info"): void {
    const entry = document.createElement("div");
    entry.className = `log-entry ${type}`;
    entry.textContent = message;

    this.eventLog.appendChild(entry);
    setTimeout(() => {
      entry.style.opacity = "0";
      entry.style.transition = "opacity 0.4s";
      setTimeout(() => entry.remove(), 400);
    }, 4500);

    // Keep log max size 5
    while (this.eventLog.children.length > 5) {
      this.eventLog.firstElementChild?.remove();
    }
  }

  public updateDebug(
    fps: number,
    drawCalls: number,
    triangles: number,
    units: number,
    enemies: number,
    simMs: number,
    camX: number,
    camZ: number
  ): void {
    document.getElementById("dbg-fps")!.textContent = Math.round(fps).toString();
    document.getElementById("dbg-draws")!.textContent = drawCalls.toString();
    document.getElementById("dbg-tris")!.textContent = triangles.toString();
    document.getElementById("dbg-units")!.textContent = units.toString();
    document.getElementById("dbg-enemies")!.textContent = enemies.toString();
    document.getElementById("dbg-tick")!.textContent = `${simMs.toFixed(1)}ms`;
    document.getElementById("dbg-cam")!.textContent = `${Math.round(camX)}, ${Math.round(camZ)}`;
  }
}
