class_name Grid
extends TileMapLayer

@export var dialogue_ui: Node

var peer_pawns: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is Pawn and child.type >= 0:
			set_cell(local_to_map(child.position), child.type, Vector2i.ZERO)
			if child.owner_peer_id > 0:
				peer_pawns[child.owner_peer_id] = child


func get_cell_pawn(cell: Vector2i, type: CellType.Type = CellType.Type.ACTOR) -> Node2D:
	for node in get_children():
		if not node is Pawn:
			continue
		if node.type != type:
			continue
		if local_to_map(node.position) == cell:
			return node
	return null


func clear_cell(cell: Vector2i) -> void:
	set_cell(cell, -1, Vector2i.ZERO)


func register_pawn(peer_id: int, pawn: Pawn) -> void:
	peer_pawns[peer_id] = pawn


func unregister_pawn(peer_id: int) -> void:
	peer_pawns.erase(peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_move(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not peer_pawns.has(sender_id):
		return
	_apply_move(peer_pawns[sender_id], direction, sender_id)


func _apply_move(pawn: Pawn, direction: Vector2, peer_id: int) -> void:
	var cell_start := local_to_map(pawn.position)
	var dir_i := Vector2i(direction)
	var cell_target := cell_start + dir_i
	var target_pos := pawn.position

	var cell_tile_id := get_cell_source_id(cell_target)
	match cell_tile_id:
		-1:
			set_cell(cell_target, CellType.Type.ACTOR, Vector2i.ZERO)
			set_cell(cell_start, -1, Vector2i.ZERO)
			target_pos = map_to_local(cell_target)
		CellType.Type.OBJECT:
			var target_pawn := get_cell_pawn(cell_target, cell_tile_id)
			if target_pawn and target_pawn.has_node(^"DialoguePlayer"):
				if peer_id == 1:
					_show_object_interaction(peer_id, target_pawn.get_path())
				else:
					rpc_id(peer_id, "show_object_interaction_rpc", peer_id, target_pawn.get_path())
			target_pos = pawn.position
		CellType.Type.ACTOR:
			var target_pawn := get_cell_pawn(cell_target, cell_tile_id)
			if target_pawn and target_pawn.has_node(^"DialoguePlayer"):
				if peer_id == 1:
					var dp: Node = target_pawn.get_node(^"DialoguePlayer")
					_show_npc_dialogue(peer_id, dp.dialogue_file)
				else:
					var dp: Node = target_pawn.get_node(^"DialoguePlayer")
					rpc_id(peer_id, "show_dialogue_rpc", peer_id, dp.dialogue_file)
			target_pos = pawn.position

	move_confirmed.rpc(peer_id, target_pos, direction)


func _show_npc_dialogue(peer_id: int, dialogue_file_path: String) -> void:
	if not dialogue_ui:
		return
	var dp_scene := preload("res://dialogue/dialogue_player/dialogue_player.tscn")
	var dp: Node = dp_scene.instantiate()
	dp.dialogue_file = dialogue_file_path
	add_child(dp)
	var player_pawn: Pawn = peer_pawns.get(peer_id)
	if player_pawn:
		dialogue_ui.show_dialogue(player_pawn, dp)


func _show_object_interaction(peer_id: int, object_path: NodePath) -> void:
	if not dialogue_ui:
		return
	var obj := get_node_or_null(object_path)
	if not obj:
		return
	var dp: Node = obj.get_node(^"DialoguePlayer")
	if not dp:
		return
	var player_pawn: Pawn = peer_pawns.get(peer_id)
	if player_pawn:
		dialogue_ui.show_dialogue(player_pawn, dp)


@rpc("authority", "call_local", "reliable")
func move_confirmed(peer_id: int, target_pos: Vector2, _direction: Vector2) -> void:
	if not peer_pawns.has(peer_id):
		return
	var pawn: Walker = peer_pawns[peer_id]
	if pawn.grid:
		var current_cell := pawn.grid.local_to_map(pawn.position)
		var target_cell := pawn.grid.local_to_map(target_pos)
		if current_cell != target_cell:
			pawn.grid.set_cell(target_cell, CellType.Type.ACTOR, Vector2i.ZERO)
			pawn.grid.set_cell(current_cell, -1, Vector2i.ZERO)
	if target_pos != pawn.position:
		pawn.move_to(target_pos)
	else:
		pawn.bump()


@rpc("authority", "call_remote", "reliable")
func show_dialogue_rpc(peer_id: int, dialogue_file_path: String) -> void:
	_show_npc_dialogue(peer_id, dialogue_file_path)


@rpc("authority", "call_remote", "reliable")
func show_object_interaction_rpc(peer_id: int, object_path: NodePath) -> void:
	_show_object_interaction(peer_id, object_path)
