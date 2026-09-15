class_name GuardianSystem
extends Node
var game: Main
var lairs: Array[Dictionary] = []
var elapsed: float = 0.0
func setup(main: Main) -> void:
	game=main
	for entry in [[UnitConfigs.UnitType.ANCIENT_GOLEM,Vector3(282.5,0,270.5)],[UnitConfigs.UnitType.STORM_WARDEN,Vector3(322.5,0,296.5)]]:
		var home: Vector3 = game.grid_manager.find_free_position(entry[1])
		var lair: Dictionary = {"type":entry[0],"home":home,"unit":null,"respawn":0.0,"cooldown":6.0,"charge":0.0,"impact":Vector3.ZERO,"warning":null}
		lairs.append(lair);_spawn(lair)
func _spawn(lair: Dictionary) -> void:
	var guardian: Unit = game.spawn_unit(lair.type,"enemy",lair.home)
	guardian.set_meta("guardian",true);lair.unit=weakref(guardian);lair.cooldown=6.0
func _process(delta: float) -> void:
	for lair in lairs:
		var u: Unit = lair.unit.get_ref()
		if not is_instance_valid(u) or not u.is_alive:
			if is_instance_valid(lair.warning):lair.warning.queue_free();lair.warning=null
			lair.charge=0.0;lair.respawn+=delta
			if lair.respawn>=120 and game.combat_system.find_colonist(lair.home,game.all_units,12)==null:lair.respawn=0.0;_spawn(lair)
			continue
		if is_instance_valid(lair.warning):lair.warning.visible=u.visible
		lair.cooldown=maxf(0,lair.cooldown-delta)
		if lair.charge>0:
			u.stop();u.state=UnitConfigs.UnitState.ATTACKING;lair.charge-=delta
			if lair.charge<=0:_impact(lair)
			continue
		var target: Unit = game.combat_system.find_colonist(u.position,game.all_units,18)
		if target and target.position.distance_to(lair.home)<=24 and u.position.distance_to(lair.home)<26:
			u.target=target;u.current_order=UnitConfigs.UnitOrder.ATTACK
			u.repath_timer=maxf(0,u.repath_timer-delta)
			if lair.cooldown<=0 and u.position.distance_to(target.position)<(4.5 if lair.type==UnitConfigs.UnitType.ANCIENT_GOLEM else 10.0):_charge(lair,target)
			else:game.combat_system._attack_or_chase(u,target,delta)
		else:
			u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE
			if u.position.distance_to(lair.home)>1.0 and u.path.is_empty():u.set_path(game.grid_manager.find_unit_path(u,lair.home,true));u.state=UnitConfigs.UnitState.MOVING
			elif u.path.is_empty():u.heal(delta*4)
func _charge(lair: Dictionary,target: Unit) -> void:
	var u: Unit = lair.unit.get_ref()
	lair.impact=u.position if lair.type==UnitConfigs.UnitType.ANCIENT_GOLEM else target.position
	lair.charge=1.3;lair.cooldown=8.0
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new();mesh.inner_radius=2.6;mesh.outer_radius=2.8;mesh.rings=32;mesh.ring_segments=6;ring.mesh=mesh
	var material: StandardMaterial3D = StandardMaterial3D.new();material.albedo_color=Color("ffb15c") if lair.type==UnitConfigs.UnitType.ANCIENT_GOLEM else Color("80d9ff");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=material
	game.add_child(ring);ring.position=lair.impact+Vector3.UP*.12;lair.warning=ring
func _impact(lair: Dictionary) -> void:
	for victim in game.all_units.duplicate():
		if is_instance_valid(victim) and victim.is_alive and victim.faction in ["player","goblin"] and not victim.underground_unit and not is_instance_valid(victim.embarked_in) and victim.position.distance_to(lair.impact)<2.8:victim.take_damage(55 if lair.type==UnitConfigs.UnitType.ANCIENT_GOLEM else 42)
	if is_instance_valid(lair.warning):lair.warning.queue_free();lair.warning=null
	SoundManager.play_hit()
