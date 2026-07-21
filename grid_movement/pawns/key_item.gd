extends Pawn

@export var speed_boost := 1.5

@onready var dialogue_player: Node = $DialoguePlayer


func _ready() -> void:
	dialogue_player.dialogue_finished.connect(_on_dialogue_finished)


func _on_dialogue_finished() -> void:
	if multiplayer.is_server():
		_apply_pickup_server()
	else:
		rpc_id(1, "request_pickup_rpc", name)


func _apply_pickup_server() -> void:
	var grid_node := _get_grid()
	if grid_node:
		grid_node.clear_cell(grid_node.local_to_map(position))
	remove_item_rpc.rpc(name)
	apply_speed_boost.rpc()


func _get_grid() -> Grid:
	var p := get_parent()
	if p is Grid:
		return p
	return null


@rpc("any_peer", "call_remote", "reliable")
func request_pickup_rpc(_item_name: String) -> void:
	if not multiplayer.is_server():
		return
	if not is_inside_tree():
		return
	_apply_pickup_server()


@rpc("authority", "call_local", "reliable")
func remove_item_rpc(_item_name: String) -> void:
	var grid_node := _get_grid()
	if grid_node:
		grid_node.clear_cell(grid_node.local_to_map(position))
	queue_free()


@rpc("authority", "call_local", "reliable")
func apply_speed_boost() -> void:
	var grid_node: Grid = null
	var scene := get_tree().current_scene
	if scene:
		grid_node = scene.get_node_or_null(^"Grid")
	if not grid_node:
		return
	for child in grid_node.get_children():
		if child is Walker:
			child.speed_multiplier = speed_boost
