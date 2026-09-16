class_name EquipmentConfigs
extends RefCounted
const ITEMS: Dictionary = {
	"sword":{"name":"Меч","cost":{"wood":8,"ore":3},"time":12.0,"role":"Рыцари и воины"},
	"bow":{"name":"Лук","cost":{"wood":12,"stone":2},"time":10.0,"role":"Лучники и паучьи всадники"},
	"spear":{"name":"Копьё","cost":{"wood":10,"ore":2},"time":10.0,"role":"Копейщики и тролли"},
	"pitchfork":{"name":"Вилы","cost":{"wood":8,"stone":3},"time":8.0,"role":"Оснащение фермы"},
	"pickaxe":{"name":"Кирка","cost":{"wood":8,"stone":6},"time":9.0,"role":"Оснащение шахтёра"},
	"axe":{"name":"Топор","cost":{"wood":8,"stone":4},"time":8.0,"role":"Найм рабочего"}
}
static func required(type: UnitConfigs.UnitType) -> Dictionary:
	match type:
		UnitConfigs.UnitType.WORKER,UnitConfigs.UnitType.GOBLIN_WORKER:return {"axe":1}
		UnitConfigs.UnitType.WARRIOR,UnitConfigs.UnitType.GOBLIN_WARRIOR:return {"sword":1}
		UnitConfigs.UnitType.ARCHER,UnitConfigs.UnitType.GOBLIN_ARCHER,UnitConfigs.UnitType.SPIDER_RIDER:return {"bow":1}
		UnitConfigs.UnitType.GOBLIN_SPEARMAN,UnitConfigs.UnitType.TROLL:return {"spear":1}
	return {}
static func resource_name(key: String) -> String:
	return ITEMS[key].name if ITEMS.has(key) else {"wood":"дерево","stone":"камень","ore":"железо","food":"еда","water":"вода"}.get(key,key)
static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String]=[]
	for key in cost:
		if cost[key]>0:parts.append("%d %s" % [cost[key],resource_name(key)])
	return " · ".join(parts)
