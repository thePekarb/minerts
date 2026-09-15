extends Node
func _ready() -> void:
	var grid := GridManager.new()
	var hierarchy := HierarchicalNavigation.new(grid)
	var valid: bool = hierarchy.region_of(-1)==-1 and hierarchy.region_of(512000)==-1 and hierarchy.region_of(999)==-1 and hierarchy.region_of(511511)==-1
	hierarchy.dirty.clear()
	valid=valid and hierarchy.component_route(-1,512000).is_empty()
	grid.free()
	if valid:print("PASS: outside-map and unbuilt cells have no hierarchical region or route")
	else:push_error("invalid hierarchical boundary lookup")
	print("NAVIGATION BOUNDS CHECKS: 1 | FAILURES: ",0 if valid else 1)
	get_tree().quit(0 if valid else 1)
