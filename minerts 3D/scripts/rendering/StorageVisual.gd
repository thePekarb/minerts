class_name StorageVisual
extends Node3D
# Open-front depot: three partitioned bays with stock-dependent cargo, all inside footprint.
var piles: Dictionary = {}
func box(size: Vector3,pos: Vector3,color: Color,parent: Node3D=self) -> MeshInstance3D:
	var mesh: MeshInstance3D=VoxelMeshFactory.create_box_mesh(size,color);parent.add_child(mesh);mesh.position=pos;return mesh
func setup(faction: String) -> void:
	var asset: String="res://assets/frontier/storage_depot_%s.glb" % ("goblin" if FactionRules.race(faction)=="goblin" else "player")
	if ResourceLoader.exists(asset):
		var model: Node3D=(load(asset) as PackedScene).instantiate();add_child(model);model.rotation.y=PI
		for key in ["food","wood","stone"]:
			var bucket:=Node3D.new();model.add_child(bucket);piles[key]=bucket
			for i in range(9):
				var part: Node3D=model.find_child("Stock_%s_%d" % [key,i],true,false)
				if part:
					part.owner=null
					for child in part.find_children("*","",true,false):child.owner=null
					part.reparent(bucket,false);part.visible=false
		return
	var wood := Color("72503b") if faction=="player" else Color("4f4931")
	box(Vector3(1.9,.16,1.9),Vector3(0,.08,0),wood)
	for x in [-.9,-.3,.3,.9]:
		box(Vector3(.08,.85,1.8),Vector3(x,.53,0),wood)
	for z in [-.88,.88]:
		for x in [-.88,.88]:box(Vector3(.12,1.55,.12),Vector3(x,.84,z),wood.lightened(.12))
	box(Vector3(1.9,1.05,.09),Vector3(0,.67,-.88),wood)
	for y in [.4,.85]:box(Vector3(1.9,.08,.08),Vector3(0,y,.9),wood.lightened(.2))
	# Short rear awning leaves all three cargo bays visible from the RTS camera.
	box(Vector3(2.0,.12,.65),Vector3(0,1.62,-.65),Color("47778a") if faction=="player" else Color("695442"))
	for i in range(3):
		var key: String=["food","wood","stone"][i]
		var root := Node3D.new();add_child(root);piles[key]=root
		for n in range(9):
			var x: float=-.6+i*.6+(n%2)*.22-.11
			var y: float=.3+int(n/4)*.24
			var z: float=-.35+int(n%4/2)*.55
			var color: Color=[Color("bc934b"),Color("9b6436"),Color("969fa5")][i]
			var cargo: MeshInstance3D=box(Vector3(.2,.2,.4) if key=="wood" else Vector3(.22,.21,.24),Vector3(x,y,z),color,root)
			cargo.visible=false
		var sign := Label3D.new();sign.text=["ЕДА","ЛЕС","КАМЕНЬ"][i];sign.font_size=20;sign.pixel_size=.004
		sign.position=Vector3(-.6+i*.6,1.22,.8);sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(sign)
func set_stock(stock: Dictionary) -> void:
	for key in piles:
		var count: int=stock.get(key,0)
		if key=="stone":count+=stock.get("ore",0)
		if key=="wood":
			for item in EquipmentConfigs.ITEMS:count+=stock.get(item,0)*3
		var shown: int=mini(9,ceili(float(count)/22))
		var root: Node3D=piles[key]
		for i in range(root.get_child_count()):root.get_child(i).visible=i<shown
