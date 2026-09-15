extends Node

# Economy & Resources
signal resource_changed(type_name: String, amount: int)
signal population_changed(current: int, maximum: int)

# Selection
signal selection_changed(units: Array, building: Variant)
signal unit_selected(unit: Node)
signal multi_unit_selected(units: Array)
signal building_selected(building: Node)
signal selection_cleared()

# Units & Spawning
signal unit_spawned(unit: Node)
signal entity_died(entity: Node)

# Construction & Upgrades
signal building_placed(building: Node)
signal building_constructed(building: Node)
signal building_upgraded(building: Node)

# Lumber Zones
signal lumber_zone_placed(zone: Variant)
signal lumber_zone_selected(zone: Variant)
signal lumber_zone_cleared(zone_id: String)
signal lumber_zone_workers_changed(zone: Variant, count: int)
signal lumber_zone_worker_count_changed(zone_id: String, count: int)

# Mine Garrison
signal mine_miner_count_changed(mine: Node, count: int)

# Combat, Raids & Waves
signal raid_warning(message: String)
signal raid_spawned(wave: int, count: int)
signal raid_started(day: int)
signal raid_ended(day: int)

# Time of Day
signal time_of_day_changed(time_norm: float)
signal day_passed(day: int)
signal time_phase_changed(phase_name: String, progress: float)
signal day_advanced(day_number: int)

# Feedback & Audio
signal toast(message: String, type: String)
signal sound_requested(sound_name: String)
