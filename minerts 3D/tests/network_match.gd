extends Node
var game: Main
var failures: int=0
var host: bool
func check(ok: bool,label: String) -> void:
	if ok:print("PASS: ",label)
	else:failures+=1;push_error(label)
func _ready() -> void:
	SoundManager.is_muted=true
	host=OS.get_cmdline_user_args().has("host")
	GameSettings.night_wave_enabled=false
	GameSettings.player_name="Host" if host else "Guest"
	NetworkManager.network_error.connect(func(message):push_error(message))
	if host:
		check(NetworkManager.host_game(17897,2)==OK,"host opens UDP")
		for i in range(900):
			if NetworkManager.multiplayer.get_peers().size()>0 and GameSettings.get_participant_count()==2:break
			await get_tree().create_timer(.05).timeout
		check(GameSettings.get_participant_count()==2,"client registered in separate seat")
		NetworkManager.in_match=true
	else:
		check(NetworkManager.join_game("127.0.0.1",17897)==OK,"client connects")
		for i in range(400):
			if NetworkManager.connection_deadline==0:break
			await get_tree().create_timer(.05).timeout
		check(NetworkManager.registered(NetworkManager.local_peer_id),"handshake confirms identity")
		NetworkManager.in_match=true
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	if host:
		for i in range(800):
			if game.network_session.started:break
			await get_tree().create_timer(.05).timeout
		check(game.network_session.started,"both worlds ready before simulation")
		for i in range(300):await get_tree().create_timer(.05).timeout
		check(game.network_session.accepted_commands>0,"host processes client commands")
		check(game.network_session.rejected_commands>0,"foreign ownership is rejected")
		var f: String=NetworkManager.faction_for_peer(NetworkManager.multiplayer.get_peers()[0])
		check(FactionEconomy.resources(f).get("wood",-1)==120,"separate remote wallet")
		check(EconomyManager.resources.wood==120,"client does not spend host wallet")
	else:
		for i in range(1000):
			if game.network_session.frames_received>3:break
			await get_tree().create_timer(.05).timeout
		check(game.network_session.frames_received>3,"client receives authoritative snapshots")
		var own: Array=game.all_units.filter(func(u):return u.faction=="player")
		var other: Array=game.all_units.filter(func(u):return u.faction=="peer_1")
		check(own.size()==5 and other.size()==5,"two separately owned colonies replicated")
		check(not game.is_processing() and own.all(func(u):return not u.is_physics_processing()),"client simulation stays disabled")
		if not own.is_empty():
			var u: Unit=own[0];var before: Vector3=u.position
			var point: Vector3=game.grid_manager.find_nearest_walkable_world(before+Vector3(5,0,3)) if game.grid_manager.has_method("find_nearest_walkable_world") else before+Vector3(5,0,3)
			game.selection_system.select_single_unit(u);game.network_session.context(point,null)
			for i in range(80):await get_tree().create_timer(.05).timeout
			check(u.position.distance_to(before)>1,"client order moves authoritative replica")
		if not other.is_empty():game.network_session.send("stop",{"units":[game.network_session.node_id(other[0])]})
		for i in range(180):await get_tree().create_timer(.05).timeout
	print("NETWORK ","HOST" if host else "CLIENT"," FAILURES: ",failures)
	get_tree().quit(failures)
