class_name Entity
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died(entity: Entity)

@export var max_health: float = 100.0
@export var faction: String = "player" # "player", "enemy", "neutral"

var armor: float = 0.0
var health: float = 100.0
var entity_id: String = ""
var is_alive: bool = true

func _ready() -> void:
	health = max_health

func take_damage(amount: float) -> bool:
	if not is_alive:
		return true
	if amount <= 0.0:
		return false
	SoundManager.play_hit()
	health = maxf(0.0, health - maxf(1.0, amount - armor))
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_alive = false
		died.emit(self)
		EventBus.entity_died.emit(self)
		return true
	return false

func heal(amount: float) -> void:
	if not is_alive:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)
