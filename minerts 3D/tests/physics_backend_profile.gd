extends Node3D

var checks: int = 0
var failures: int = 0
var samples: Array[Dictionary] = []
var shape: CapsuleShape3D
var positions: Array[Vector3] = []

func check(ok: bool,title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)

func _ready() -> void:
	SoundManager.is_muted=true
	shape=CapsuleShape3D.new();shape.radius=.3;shape.height=1.3
	var wall := StaticBody3D.new();wall.collision_layer=4;wall.position=Vector3(60,0,48);add_child(wall)
	var collision := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(1,3,120);collision.shape=box;wall.add_child(collision)
	for count in [200,1000]:
		var reference: Array[Vector3] = []
		for backend in ["nodes","server"]:
			var nodes: Array[CharacterBody3D] = []
			var bodies: Array[RID] = []
			positions.clear()
			for i in range(count):
				var column: int = i%32
				var position := Vector3(column*3+(2 if column>=20 else 0),0,(i/32)*3)
				positions.append(position)
				if backend=="nodes":
					var body := CharacterBody3D.new();body.position=position;body.collision_layer=2;body.collision_mask=2|4;add_child(body)
					var child := CollisionShape3D.new();child.shape=shape;body.add_child(child);nodes.append(body)
				else:
					var body: RID = PhysicsServer3D.body_create();bodies.append(body)
					PhysicsServer3D.body_set_mode(body,PhysicsServer3D.BODY_MODE_KINEMATIC)
					PhysicsServer3D.body_add_shape(body,shape.get_rid())
					PhysicsServer3D.body_set_collision_layer(body,2);PhysicsServer3D.body_set_collision_mask(body,2|4)
					PhysicsServer3D.body_set_state(body,PhysicsServer3D.BODY_STATE_TRANSFORM,Transform3D(Basis.IDENTITY,position))
					PhysicsServer3D.body_set_space(body,get_world_3d().space)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var times: Array[float] = []
			var params := PhysicsTestMotionParameters3D.new();params.margin=.01
			var result := PhysicsTestMotionResult3D.new()
			for tick in range(180):
				await get_tree().physics_frame
				var begin: int = Time.get_ticks_usec()
				for i in range(count):
					var motion := Vector3(.035,0,0)
					if backend=="nodes":
						nodes[i].move_and_collide(motion,false,.01)
						positions[i]=nodes[i].position
					else:
						params.from=Transform3D(Basis.IDENTITY,positions[i]);params.motion=motion
						positions[i]+=result.get_travel() if PhysicsServer3D.body_test_motion(bodies[i],params,result) else motion
						PhysicsServer3D.body_set_state(bodies[i],PhysicsServer3D.BODY_STATE_TRANSFORM,Transform3D(Basis.IDENTITY,positions[i]))
				times.append((Time.get_ticks_usec()-begin)/1000.0)
			times.sort()
			var sample: Dictionary = {"actors":count,"backend":backend,"p50_motion_ms":times[90],"p95_motion_ms":times[171],"p99_motion_ms":times[178]}
			print("PHYSICS PROFILE ",JSON.stringify(sample));samples.append(sample)
			if backend=="nodes":reference=positions.duplicate()
			else:
				var error: float = 0
				for i in range(count):error=maxf(error,reference[i].distance_to(positions[i]))
				print("BACKEND MAX POSITION DIFFERENCE: ",error)
				check(error<.08,"node and direct-server collision results agree for %d moving bodies" % count)
			for body in nodes:body.queue_free()
			for body in bodies:PhysicsServer3D.free_rid(body)
			await get_tree().physics_frame
	var file := FileAccess.open("res://art/test-results/physics_backend_profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"));file.close()
	print("PHYSICS BACKEND CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
