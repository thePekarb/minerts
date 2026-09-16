class_name WorkshopSystem
extends Node
var game: Main
func setup(main: Main) -> void:game=main
func enqueue(b: Building,item: String) -> String:
	if NetworkManager.route_building("craft",b,{"item":item}):return ""
	if not is_instance_valid(b) or not b.is_alive or not b.is_constructed or b.building_type!=BuildingConfigs.BuildingType.WORKSHOP:return "Нужна готовая мастерская."
	if not EquipmentConfigs.ITEMS.has(item):return "Неизвестный предмет."
	if b.crafting_queue.size()>=6:return "Очередь заполнена (6 мест)."
	var recipe: Dictionary=EquipmentConfigs.ITEMS[item]
	if not FactionEconomy.spend(b.faction,recipe.cost):return "Не хватает: "+EquipmentConfigs.cost_text(recipe.cost)
	b.crafting_queue.append({"item":item,"cost":recipe.cost.duplicate(),"duration":recipe.time,"progress":0.0})
	return ""
func cancel(b: Building,index: int) -> void:
	if NetworkManager.route_building("cancel",b,{"index":index}):return
	if not is_instance_valid(b) or index<0 or index>=b.crafting_queue.size():return
	var job: Dictionary=b.crafting_queue[index];b.crafting_queue.remove_at(index)
	for key in job.cost:FactionEconomy.add(b.faction,key,job.cost[key])
func queued(faction: String,item: String) -> int:
	var count: int=0
	for b in game.all_buildings:
		if not is_instance_valid(b) or not b.is_alive or b.faction!=faction:continue
		for job in b.crafting_queue:
			if job.item==item:count+=1
	return count
func tick(delta: float) -> void:
	for b in game.all_buildings:
		if not is_instance_valid(b) or not b.is_alive or not b.is_constructed or b.crafting_queue.is_empty():continue
		var job: Dictionary=b.crafting_queue[0]
		job.progress=minf(job.duration,job.progress+delta)
		if job.progress<job.duration:continue
		if game.storage_system.deposit_any(b.faction,job.item,1)==0:
			b.production_status="Готово · нет места на складе";continue
		b.crafting_queue.pop_front();b.production_status="Предмет отправлен в запас"
