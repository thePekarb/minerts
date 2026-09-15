import { eventBus } from "../game/EventBus";

export enum TimeOfDay {
  Dawn = "Dawn",
  Day = "Day",
  Dusk = "Dusk",
  Night = "Night"
}

export interface TimeState {
  day: number;
  timeOfDay: TimeOfDay;
  gameTimeHours: number; // 0..24
  cycleProgress: number; // 0..1
  timeString: string;
  isNight: boolean;
}

export class TimeOfDaySystem {
  public day = 1;
  public timeOfDay: TimeOfDay = TimeOfDay.Day;
  public gameTimeHours = 8.0; // Start at 8:00 AM
  public cycleSeconds = 120; // 2 real minutes per full 24h in-game cycle
  public elapsedSeconds = 40; // 8:00 AM is 8/24 = 1/3 of day (40s into 120s)
  public timeScale = 1.0;
  public isPaused = false;

  private raidWarningIssued = false;
  private raidStartedIssued = false;

  update(deltaSeconds: number): void {
    if (this.isPaused) return;

    const scaledDelta = deltaSeconds * this.timeScale;
    this.elapsedSeconds += scaledDelta;

    if (this.elapsedSeconds >= this.cycleSeconds) {
      this.elapsedSeconds -= this.cycleSeconds;
      this.day++;
      this.raidWarningIssued = false;
      this.raidStartedIssued = false;
      eventBus.emit("toast", { message: `🌅 Dawn of Day ${this.day}. A new day begins!`, type: "success" });
      eventBus.emit("sound", { soundName: "dawn" });
    }

    const cycleProgress = this.elapsedSeconds / this.cycleSeconds;
    this.gameTimeHours = cycleProgress * 24.0;

    // Determine phase
    let newPhase: TimeOfDay;
    if (this.gameTimeHours >= 5 && this.gameTimeHours < 8) {
      newPhase = TimeOfDay.Dawn;
    } else if (this.gameTimeHours >= 8 && this.gameTimeHours < 18) {
      newPhase = TimeOfDay.Day;
    } else if (this.gameTimeHours >= 18 && this.gameTimeHours < 21) {
      newPhase = TimeOfDay.Dusk;
    } else {
      newPhase = TimeOfDay.Night;
    }

    if (newPhase !== this.timeOfDay) {
      this.timeOfDay = newPhase;
      eventBus.emit("phaseChanged", { phase: this.timeOfDay, day: this.day });

      if (this.timeOfDay === TimeOfDay.Dusk) {
        eventBus.emit("toast", { message: "⚠️ Dusk is falling. Prepare your defenses!", type: "warn" });
        eventBus.emit("sound", { soundName: "horn_warn" });
      } else if (this.timeOfDay === TimeOfDay.Night) {
        eventBus.emit("toast", { message: "🌙 Night has arrived! Raid is starting!", type: "danger" });
        eventBus.emit("sound", { soundName: "horn_raid" });
      }
    }

    // Warnings and triggers
    if (this.timeOfDay === TimeOfDay.Dusk && !this.raidWarningIssued) {
      const secondsUntilNight = Math.max(0, (21 / 24) * this.cycleSeconds - this.elapsedSeconds);
      eventBus.emit("raidWarning", { secondsLeft: Math.ceil(secondsUntilNight) });
      this.raidWarningIssued = true;
    }

    if (this.timeOfDay === TimeOfDay.Night && !this.raidStartedIssued) {
      eventBus.emit("raidStarted", { day: this.day });
      this.raidStartedIssued = true;
    }

    // Format HH:MM
    const hours = Math.floor(this.gameTimeHours);
    const minutes = Math.floor((this.gameTimeHours - hours) * 60);
    const timeString = `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}`;

    eventBus.emit("timeChanged", {
      day: this.day,
      timeOfDay: this.timeOfDay,
      gameTimeHours: this.gameTimeHours,
      cycleProgress,
      timeString,
      isNight: this.timeOfDay === TimeOfDay.Night
    });
  }

  getTimeState(): TimeState {
    const hours = Math.floor(this.gameTimeHours);
    const minutes = Math.floor((this.gameTimeHours - hours) * 60);
    return {
      day: this.day,
      timeOfDay: this.timeOfDay,
      gameTimeHours: this.gameTimeHours,
      cycleProgress: this.elapsedSeconds / this.cycleSeconds,
      timeString: `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}`,
      isNight: this.timeOfDay === TimeOfDay.Night
    };
  }
}
