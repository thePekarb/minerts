class_name NetworkManagerAutoload
extends Node
signal connection_succeeded
signal connection_failed
signal server_disconnected
signal player_joined(peer_id,info)
signal player_left(peer_id)
signal chat_message_received(sender_name,text,timestamp)
signal lobby_updated
signal match_started
signal server_discovered(server_info)
signal server_expired(server_key)
signal order_received(order_data)
signal game_command(sender_id,command)
signal snapshot_received(kind,data)
signal network_error(message)
const PROTOCOL: int=3
const LAN_DISCOVERY_PORT: int=7778
var peer: ENetMultiplayerPeer
var is_server: bool=false
var server_ip: String="127.0.0.1"
var server_port: int=7777
var local_peer_id: int=1
var in_match: bool=false
var session: Node
var applying_command: bool=false
var ready_peers: Dictionary={}
var rates: Dictionary={}
var last_error: String=""
var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var is_broadcasting: bool=false
var is_listening: bool=false
var broadcast_timer: float=0
var discovered_servers: Dictionary={}
var connection_deadline: int=0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
func is_active() -> bool:return peer!=null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED
func is_host() -> bool:return is_server or peer==null
func local_faction() -> String:return "player" if is_host() else "peer_%d" % local_peer_id
func faction_for_peer(id: int) -> String:return "player" if id==1 else "peer_%d" % id
func registered(id: int) -> bool:
	return GameSettings.lobby_slots.any(func(s):return s.get("type")=="player" and s.get("peer_id",0)==id)
func slot_for_peer(id: int) -> Dictionary:
	for s in GameSettings.lobby_slots:
		if s.get("type")=="player" and s.get("peer_id",0)==id:return s
	return {}
func _error(message: String) -> void:
	last_error=message;network_error.emit(message)
func host_game(port: int=7777,max_clients: int=4) -> Error:
	leave_game()
	if port<1024 or port>65535:return ERR_INVALID_PARAMETER
	server_port=port;GameSettings.max_players=clampi(max_clients,2,6)
	peer=ENetMultiplayerPeer.new()
	var err: Error=peer.create_server(port,GameSettings.max_players-1,3)
	if err!=OK:peer=null;_error("Не удалось открыть UDP-порт %d: %s" % [port,error_string(err)]);return err
	multiplayer.multiplayer_peer=peer;is_server=true;local_peer_id=1;GameSettings.is_multiplayer=true
	GameSettings.lobby_slots[0].merge({"peer_id":1,"type":"player","name":GameSettings.player_name,"faction":GameSettings.player_faction,"is_host":true,"ready":true},true)
	# Keep one AI opponent; leave actual seats for connecting people.
	for i in range(2,GameSettings.lobby_slots.size()):GameSettings.clear_slot(i)
	if GameSettings.max_players==2:GameSettings.clear_slot(1)
	start_broadcasting();lobby_updated.emit();return OK
func join_game(ip: String="127.0.0.1",port: int=7777) -> Error:
	leave_game()
	ip=ip.strip_edges()
	if ip.is_empty() or ip.length()>253 or port<1024 or port>65535:return ERR_INVALID_PARAMETER
	server_ip=ip;server_port=port;peer=ENetMultiplayerPeer.new()
	var err: Error=peer.create_client(ip,port,3)
	if err!=OK:peer=null;_error("Не удалось начать подключение: "+error_string(err));return err
	multiplayer.multiplayer_peer=peer;GameSettings.is_multiplayer=true;connection_deadline=Time.get_ticks_msec()+15000
	return OK
func leave_game() -> void:
	stop_broadcasting();stop_listening()
	if peer:peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();peer=null
	is_server=false;in_match=false;local_peer_id=1;session=null;applying_command=false
	ready_peers.clear();rates.clear();connection_deadline=0;GameSettings.is_multiplayer=false
func _on_connected_to_server() -> void:
	local_peer_id=multiplayer.get_unique_id()
	register_player.rpc_id(1,GameSettings.player_name,GameSettings.player_faction,PROTOCOL)
func _on_connection_failed() -> void:
	leave_game();_error("Сервер не отвечает. Проверьте адрес, UDP-порт и сеть ZeroTier/LAN.");connection_failed.emit()
func _on_server_disconnected() -> void:
	var was_playing: bool=in_match
	leave_game();_error("Создатель вышел: сервер отключён.");server_disconnected.emit()
	if was_playing and get_tree().current_scene is Main:get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
func _on_peer_disconnected(id: int) -> void:
	ready_peers.erase(id);rates.erase(id)
	if is_server and not in_match:
		for i in range(1,GameSettings.lobby_slots.size()):
			if GameSettings.lobby_slots[i].get("peer_id",0)==id:GameSettings.clear_slot(i)
		sync_lobby_to_all()
	player_left.emit(id)
@rpc("any_peer","call_remote","reliable",0)
func register_player(p_name: String,p_faction: String,protocol: int=0) -> void:
	if not is_server:return
	var sender: int=multiplayer.get_remote_sender_id()
	if registered(sender):return
	if protocol!=PROTOCOL or in_match:
		reject_join.rpc_id(sender,"Версия игры отличается" if protocol!=PROTOCOL else "Матч уже начался. Подключитесь к новой партии.");return
	var assigned: int=-1
	for i in range(1,mini(GameSettings.max_players,GameSettings.lobby_slots.size())):
		if GameSettings.lobby_slots[i].get("type")=="open":assigned=i;break
	if assigned<0:reject_join.rpc_id(sender,"Комната заполнена.");return
	GameSettings.lobby_slots[assigned]={"type":"player","name":p_name.strip_edges().substr(0,32),"faction":p_faction if p_faction in ["player","goblin"] else "player","team":GameSettings.lobby_slots[0].team if GameSettings.room_mode=="coop" else "Игрок %d" % assigned,"ready":false,"peer_id":sender,"ping":0,"is_host":false}
	sync_lobby_to_all();player_joined.emit(sender,GameSettings.lobby_slots[assigned])
@rpc("authority","call_remote","reliable",0)
func reject_join(reason: String) -> void:
	leave_game();_error(reason);connection_failed.emit()
func sync_lobby_to_all() -> void:
	if not is_server or in_match:return
	var settings: Dictionary={}
	for key in ["map_name","map_size","seed_val","biome","difficulty","night_wave_enabled","fog_enabled","day_night_enabled","resources_richness","enemy_count","starting_resources","room_name","room_mode","max_players"]:settings[key]=GameSettings.get(key)
	rpc_sync_lobby.rpc(GameSettings.lobby_slots,settings)
@rpc("authority","call_local","reliable",0)
func rpc_sync_lobby(slots_data: Array,settings: Dictionary) -> void:
	GameSettings.lobby_slots.assign(slots_data.duplicate(true))
	for key in ["map_name","map_size","seed_val","biome","difficulty","night_wave_enabled","fog_enabled","day_night_enabled","resources_richness","enemy_count","starting_resources","room_name","room_mode","max_players"]:
		if settings.has(key):GameSettings.set(key,settings[key])
	if not is_server and registered(local_peer_id) and connection_deadline>0:
		connection_deadline=0;connection_succeeded.emit()
	lobby_updated.emit()
func set_ready(value: bool) -> void:
	if is_server:_set_ready(1,value)
	elif is_active():rpc_set_ready.rpc_id(1,value)
func _set_ready(id: int,value: bool) -> void:
	if in_match:return
	for slot in GameSettings.lobby_slots:
		if slot.get("peer_id",0)==id:slot.ready=value
	sync_lobby_to_all()
@rpc("any_peer","call_remote","reliable",0)
func rpc_set_ready(value: bool) -> void:
	if is_server:_set_ready(multiplayer.get_remote_sender_id(),value)
func start_match() -> void:
	if not is_active():_launch_match_scene();return
	if not is_server:return
	if GameSettings.lobby_slots.any(func(s):return s.get("type")=="player" and not s.get("ready",false)):_error("Дождитесь готовности всех игроков.");return
	sync_lobby_to_all();rpc_start_match.rpc()
@rpc("authority","call_local","reliable",0)
func rpc_start_match() -> void:
	in_match=true;ready_peers.clear();stop_broadcasting();_launch_match_scene()
func _launch_match_scene() -> void:
	match_started.emit();get_tree().change_scene_to_file("res://scenes/Main.tscn")
func mark_loaded() -> void:
	if is_server:ready_peers[1]=true
	else:client_loaded.rpc_id(1)
@rpc("any_peer","call_remote","reliable",0)
func client_loaded() -> void:
	var id: int=multiplayer.get_remote_sender_id()
	if is_server and in_match and registered(id):ready_peers[id]=true
func all_loaded() -> bool:
	if not ready_peers.has(1):return false
	for id in multiplayer.get_peers():
		if registered(id) and not ready_peers.has(id):return false
	return true
func submit(command: Dictionary) -> bool:
	if not is_active() or not in_match or applying_command:return false
	if is_server:game_command.emit(1,command)
	else:rpc_dispatch_order.rpc_id(1,command)
	return true
func dispatch_order(command: Dictionary) -> void:submit(command)
func _rate_allowed(id: int) -> bool:
	var second: int=Time.get_ticks_msec()/1000
	if not rates.has(id) or rates[id][0]!=second:rates[id]=[second,0]
	rates[id][1]+=1;return rates[id][1]<=40
@rpc("any_peer","call_remote","reliable",0)
func rpc_dispatch_order(command: Dictionary) -> void:
	var id: int=multiplayer.get_remote_sender_id()
	if not is_server or not in_match or not registered(id) or not ready_peers.has(id) or not _rate_allowed(id):return
	if var_to_bytes(command).size()>16384:return
	game_command.emit(id,command)
func send_snapshot(id: int,kind: String,data: Variant,reliable: bool=true) -> void:
	if reliable:receive_state.rpc_id(id,kind,data)
	else:receive_motion.rpc_id(id,kind,data)
@rpc("authority","call_remote","reliable",1)
func receive_state(kind: String,data: Variant) -> void:snapshot_received.emit(kind,data)
@rpc("authority","call_remote","unreliable_ordered",2)
func receive_motion(kind: String,data: Variant) -> void:snapshot_received.emit(kind,data)
func send_chat(text: String) -> void:
	text=text.strip_edges().substr(0,512)
	if text.is_empty():return
	if not is_active():chat_message_received.emit(GameSettings.player_name,text,_current_time_str())
	elif is_server:_relay_chat(1,text)
	else:request_chat.rpc_id(1,text)
@rpc("any_peer","call_remote","reliable",0)
func request_chat(text: String) -> void:
	var id: int=multiplayer.get_remote_sender_id()
	if is_server and registered(id) and _rate_allowed(id):_relay_chat(id,text.strip_edges().substr(0,512))
func _relay_chat(id: int,text: String) -> void:
	rpc_send_chat.rpc(slot_for_peer(id).get("name","Игрок"),text,_current_time_str())
@rpc("authority","call_local","reliable",0)
func rpc_send_chat(sender: String,message: String,time_str: String) -> void:chat_message_received.emit(sender,message,time_str)
func _current_time_str() -> String:
	var dt:=Time.get_time_dict_from_system();return "%02d:%02d" % [dt.hour,dt.minute]
func start_broadcasting() -> void:
	is_broadcasting=true;udp_broadcaster=PacketPeerUDP.new();udp_broadcaster.set_broadcast_enabled(true);udp_broadcaster.set_dest_address("255.255.255.255",LAN_DISCOVERY_PORT)
func stop_broadcasting() -> void:
	is_broadcasting=false
	if udp_broadcaster:udp_broadcaster.close();udp_broadcaster=null
func start_listening() -> void:
	if is_listening:return
	discovered_servers.clear();udp_listener=PacketPeerUDP.new()
	is_listening=udp_listener.bind(LAN_DISCOVERY_PORT)==OK
	if not is_listening:udp_listener=null
func stop_listening() -> void:
	is_listening=false
	if udp_listener:udp_listener.close();udp_listener=null
func get_discovered_servers_list() -> Array:return discovered_servers.values()
func _process(delta: float) -> void:
	if connection_deadline>0 and Time.get_ticks_msec()>connection_deadline:_on_connection_failed()
	if is_broadcasting and udp_broadcaster:
		broadcast_timer+=delta
		if broadcast_timer>=1.2:
			broadcast_timer=0
			udp_broadcaster.put_packet(JSON.stringify({"protocol":PROTOCOL,"room_name":GameSettings.room_name,"host_name":GameSettings.player_name,"port":server_port,"players":GameSettings.get_participant_count(),"max_players":GameSettings.max_players,"map":GameSettings.map_name}).to_utf8_buffer())
	if is_listening and udp_listener:
		for i in range(mini(8,udp_listener.get_available_packet_count())):
			var packet: PackedByteArray=udp_listener.get_packet()
			if packet.size()>2048:continue
			var value=JSON.parse_string(packet.get_string_from_utf8())
			if not value is Dictionary or value.get("protocol")!=PROTOCOL:continue
			value.ip=udp_listener.get_packet_ip();value.key="%s:%d" % [value.ip,int(value.get("port",7777))];value.last_seen=Time.get_ticks_msec()
			if discovered_servers.size()<64 or discovered_servers.has(value.key):discovered_servers[value.key]=value;server_discovered.emit(value)
		for key in discovered_servers.keys():
			if Time.get_ticks_msec()-discovered_servers[key].last_seen>4500:discovered_servers.erase(key);server_expired.emit(key)

func route_building(action: String,b: Building,extra: Dictionary={}) -> bool:
	if not in_match or applying_command or not is_instance_valid(session) or not is_instance_valid(b) or b.faction!="player":return false
	extra=extra.duplicate();extra.building=session.node_id(b)
	return session.send(action,extra)
func route_units(action: String,units: Array) -> bool:
	if not in_match or applying_command or not is_instance_valid(session):return false
	var ids: Array=[]
	for u in units:
		if is_instance_valid(u) and u.faction=="player":ids.append(session.node_id(u))
	if ids.is_empty():return false
	return session.send(action,{"units":ids})
