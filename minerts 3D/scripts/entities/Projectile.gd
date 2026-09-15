class_name Projectile
extends Node3D

var target_entity: Node3D = null
var target_pos: Vector3 = Vector3.ZERO
var source_faction: String = "player"
var damage: float = 12.0
var arcane: bool = false
var speed: float = 16.0
var arc_height: float = 1.2
var start_pos: Vector3 = Vector3.ZERO
var total_distance: float = 1.0
var elapsed: float = 0.0
var duration: float = 1.0

func init_projectile(from_pos: Vector3, target: Node3D, dmg: float = 12.0) -> void:
	start_pos = from_pos
	global_position = from_pos
	target_entity = target
	damage = dmg
	target_pos = target.global_position + Vector3(0, 0.5, 0)
	total_distance = start_pos.distance_to(target_pos)
	duration = maxf(0.1, total_distance / speed)

	_build_mesh()

func _build_mesh() -> void:
	if arcane:
		var orb: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new();sphere.radius=0.14;sphere.height=0.28;sphere.radial_segments=12;sphere.rings=6;orb.mesh=sphere
		var material: StandardMaterial3D = StandardMaterial3D.new();material.albedo_color=Color("8bdcff");material.emission_enabled=true;material.emission=Color("58baff");material.emission_energy_multiplier=2.0;orb.material_override=material
		add_child(orb);arc_height=0.2;return
	# Shaft
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var shaft_box: BoxMesh = BoxMesh.new()
	shaft_box.size = Vector3(0.06, 0.06, 0.4)
	shaft.mesh = shaft_box
	var m_wood: StandardMaterial3D = StandardMaterial3D.new()
	m_wood.albedo_color = Color("8B5A2B")
	shaft.material_override = m_wood
	add_child(shaft)

	# Tip
	var tip: MeshInstance3D = MeshInstance3D.new()
	var tip_box: BoxMesh = BoxMesh.new()
	tip_box.size = Vector3(0.1, 0.1, 0.1)
	tip.mesh = tip_box
	tip.position = Vector3(0, 0, -0.22)
	var m_iron: StandardMaterial3D = StandardMaterial3D.new()
	m_iron.albedo_color = Color("cccccc")
	tip.material_override = m_iron
	add_child(tip)

func _process(delta: float) -> void:
	if is_instance_valid(target_entity) and (target_entity.position.y < -1.0) != (start_pos.y < -1.0):
		queue_free()
		return
	elapsed += delta
	var t: float = clampf(elapsed / duration, 0.0, 1.0)

	if is_instance_valid(target_entity) and target_entity.is_alive:
		target_pos = target_entity.global_position + Vector3(0, 0.5, 0)

	var current_p: Vector3 = start_pos.lerp(target_pos, t)
	# Parabolic arc
	var arc: float = sin(t * PI) * arc_height
	current_p.y += arc
	global_position = current_p

	# Face movement direction
	var next_t: float = minf(1.0, t + 0.02)
	var next_p: Vector3 = start_pos.lerp(target_pos, next_t)
	next_p.y += sin(next_t * PI) * arc_height
	if next_p.distance_to(current_p) > 0.001:
		look_at(next_p, Vector3.UP)

	if t >= 1.0:
		_on_hit()

func _on_hit() -> void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(target_entity) and target_entity.is_alive:
		target_entity.set_meta("last_hit_faction",source_faction)
		target_entity.take_damage(damage)
	queue_free()
