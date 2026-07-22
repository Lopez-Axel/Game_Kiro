class_name RoomManager
extends Node2D

const TileVisualResolver = preload("res://grid_movement/tile_visual_resolver.gd")

const ROOM_WIDTH := 20
const ROOM_HEIGHT := 10
const ROOM_COUNT := 5

const CHARACTER_SCENE := preload("res://grid_movement/pawns/character.tscn")
const PLAYER_SCRIPT := preload("res://grid_movement/pawns/player.gd")
const AI_SCRIPT := preload("res://grid_movement/pawns/ai_wanderer.gd")
const OPPONENT_SCRIPT := preload("res://grid_movement/pawns/opponent.gd")
const OPPONENT_COMBAT := preload("res://combat/combatants/opponent.tscn")
const PLAYER_COMBAT := preload("res://combat/combatants/player.tscn")
const PLAYER_POSE := preload("res://grid_movement/pawns/anim_player.tres")
const OPPONENT_POSE := preload("res://grid_movement/pawns/anim_opponent.tres")

@onready var ground: TileMapLayer = $Ground
@onready var pathways: TileMapLayer = $Pathways
@onready var grid: Grid = $Grid
@onready var key_item: Node2D = $Grid/Object
@onready var minimap: DungeonMinimap = $DungeonMinimap

var generator := MazeGenerator.new()
var rooms: Dictionary = {}
var room_connections := {
	0: {"east": 1, "south": 2},
	1: {"west": 0, "south": 3},
	2: {"north": 0, "south": 4},
	3: {"north": 1, "east": 4},
	4: {"north": 2, "west": 3},
}
var current_room_id := 0
var rng := RandomNumberGenerator.new()
var changing_room := false

var peer_rooms: Dictionary = {}
var peer_positions: Dictionary = {}
var opponent: Walker = null
var bot_dialogues: Array = [
	"res://dialogue/dialogue_data/npc_bot_1.json",
	"res://dialogue/dialogue_data/npc_bot_2.json",
	"res://dialogue/dialogue_data/npc_bot_3.json",
	"res://dialogue/dialogue_data/npc.json",
]


func _ready() -> void:
	if not NetworkManager.map_seed:
		NetworkManager.map_seed = randi()
	rng.seed = NetworkManager.map_seed
	grid.room_width = ROOM_WIDTH
	grid.room_height = ROOM_HEIGHT
	$Decoration.hide()
	$"Decoration upper level".hide()
	for room_id in ROOM_COUNT:
		rooms[room_id] = generator.generate(ROOM_WIDTH, ROOM_HEIGHT, room_connections[room_id], NetworkManager.map_seed, room_id)
	minimap.configure(room_connections)
	_spawn_all_pawns()
	_spawn_opponent()
	_clean_templates()
	_render_room(0, Vector2i(1, 1))
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	if changing_room:
		return
	if not multiplayer.has_multiplayer_peer():
		return
	var local_pawn := _get_local_pawn()
	if not local_pawn:
		return
	var cell := grid.local_to_map(local_pawn.position)
	for direction: String in rooms[current_room_id].doors:
		if cell == rooms[current_room_id].doors[direction]:
			var next_room: int = room_connections[current_room_id][direction]
			var entered_from: String = _opposite(direction)
			var entry_cell: Vector2i = _interior_cell(rooms[next_room].doors[entered_from])
			if multiplayer.is_server():
				_server_change_room(1, next_room, entry_cell)
			else:
				_change_room_rpc.rpc_id(1, next_room, entry_cell)
			return


func _get_local_pawn() -> Walker:
	if not multiplayer.has_multiplayer_peer():
		return null
	var local_id: int = multiplayer.get_unique_id()
	if grid.peer_pawns.has(local_id):
		return grid.peer_pawns[local_id]
	return null


func _on_peer_disconnected(peer_id: int) -> void:
	if grid.peer_pawns.has(peer_id):
		var pawn: Node = grid.peer_pawns[peer_id]
		grid.unregister_pawn(peer_id)
		if is_instance_valid(pawn):
			var cell := grid.local_to_map(pawn.position)
			grid.clear_cell(cell)
			pawn.queue_free()
	peer_rooms.erase(peer_id)
	peer_positions.erase(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _change_room_rpc(next_room_id: int, entry_cell: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_server_change_room(sender_id, next_room_id, entry_cell)


func _server_change_room(sender_id: int, next_room_id: int, entry_cell: Vector2i) -> void:
	if not peer_rooms.has(sender_id):
		return
	for pid: int in peer_rooms.keys():
		peer_rooms[pid] = next_room_id
		if pid == sender_id:
			peer_positions[pid] = entry_cell
		else:
			var remote_cell := _first_open_cell(next_room_id, Vector2i(ROOM_WIDTH >> 1, ROOM_HEIGHT >> 1))
			peer_positions[pid] = remote_cell
	_sync_room_state_rpc.rpc(peer_rooms, peer_positions)


@rpc("authority", "call_local", "reliable")
func _sync_room_state_rpc(new_peer_rooms: Dictionary, new_peer_positions: Dictionary) -> void:
	peer_rooms = new_peer_rooms
	peer_positions = new_peer_positions
	var local_id: int = multiplayer.get_unique_id()
	if not peer_rooms.has(local_id):
		return
	var my_room: int = peer_rooms[local_id]
	var my_pos: Vector2i = peer_positions[local_id]
	if my_room != current_room_id:
		_change_room_local(my_room, my_pos)
	else:
		_reposition_remote_pawns()


func _reposition_remote_pawns() -> void:
	for child in grid.get_children():
		if child is Walker and child.owner_peer_id != multiplayer.get_unique_id() and child.owner_peer_id != 0:
			var pid: int = child.owner_peer_id
			if peer_rooms.has(pid) and peer_rooms[pid] == current_room_id:
				child.visible = true
				if peer_positions.has(pid):
					var cell: Vector2i = peer_positions[pid]
					child.position = grid.map_to_local(cell)
					grid.set_cell(cell, CellType.Type.ACTOR, Vector2i.ZERO)
			else:
				child.visible = false


func _change_room_local(next_room_id: int, entry_cell: Vector2i) -> void:
	changing_room = true
	var local_pawn := _get_local_pawn()
	if local_pawn:
		local_pawn.set_process(false)
	await _fade(Color(0.02, 0.03, 0.06, 1.0), 0.18)
	_render_room(next_room_id, entry_cell)
	await _fade(Color(0.02, 0.03, 0.06, 0.0), 0.18)
	if local_pawn:
		local_pawn.set_process(true)
	changing_room = false


func _render_room(room_id: int, player_cell: Vector2i) -> void:
	current_room_id = room_id
	ground.clear()
	pathways.clear()
	grid.clear()
	var cells: Array = rooms[room_id].cells
	for y in ROOM_HEIGHT:
		for x in ROOM_WIDTH:
			var cell := Vector2i(x, y)
			var ground_tile: Dictionary = TileVisualResolver.resolve_ground(rng)
			ground.set_cell(cell, ground_tile.source, Vector2i.ZERO, ground_tile.alternative)
			if cells[y][x] == 0:
				var path_tile: Dictionary = TileVisualResolver.resolve_path(cell, cells, ROOM_WIDTH, ROOM_HEIGHT, rng)
				pathways.set_cell(cell, path_tile.source, Vector2i.ZERO, path_tile.alternative)
			else:
				var obstacle_tile: Dictionary = TileVisualResolver.resolve_obstacle(cell, cells, ROOM_WIDTH, ROOM_HEIGHT, rng)
				grid.set_cell(cell, obstacle_tile.source, Vector2i.ZERO, obstacle_tile.alternative)
	_place_room_entities(room_id)
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var local_pawn: Walker = grid.peer_pawns.get(local_id) as Walker
	if local_pawn:
		local_pawn.position = grid.map_to_local(player_cell)
		grid.set_cell(player_cell, CellType.Type.ACTOR, Vector2i.ZERO)
		local_pawn.visible = true
	for child in grid.get_children():
		if child is Walker and child.owner_peer_id != local_id and child.owner_peer_id != 0:
			var pid: int = child.owner_peer_id
			if peer_rooms.has(pid) and peer_rooms[pid] == room_id:
				child.visible = true
				if peer_positions.has(pid):
					var cell: Vector2i = peer_positions[pid]
					child.position = grid.map_to_local(cell)
					grid.set_cell(cell, CellType.Type.ACTOR, Vector2i.ZERO)
			else:
				child.visible = false
	minimap.set_current_room(room_id)
	grid.set_current_room(cells)


func _place_room_entities(room_id: int) -> void:
	if is_instance_valid(key_item):
		key_item.visible = room_id == 2
		if key_item.visible:
			var item_cell := _first_open_cell(room_id, Vector2i(ROOM_WIDTH >> 1, ROOM_HEIGHT >> 1))
			key_item.position = grid.map_to_local(item_cell)
			grid.set_cell(item_cell, CellType.Type.OBJECT, Vector2i.ZERO)
	if is_instance_valid(opponent):
		opponent.visible = room_id == 4
		opponent.set_process(room_id == 4)
		if room_id == 4:
			var enemy_cell := _first_open_cell(room_id, Vector2i(ROOM_WIDTH - 3, ROOM_HEIGHT - 3))
			opponent.position = grid.map_to_local(enemy_cell)
			grid.set_cell(enemy_cell, CellType.Type.ACTOR, Vector2i.ZERO)


var _bot_index := 0


func _spawn_all_pawns() -> void:
	_bot_index = 0
	var spawn_points := _calculate_spawn_points(4)
	var peer_ids: Array = NetworkManager.players.keys()
	peer_ids.sort()
	for i in range(4):
		var cell: Vector2i = spawn_points[i]
		var pos: Vector2 = grid.map_to_local(cell)
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var is_ai: bool = NetworkManager.players[peer_id].get("is_ai", false)
			_spawn_character(pos, peer_id, is_ai)
			peer_rooms[peer_id] = 0
			peer_positions[peer_id] = cell
		else:
			var fake_id: int = -(i + 1)
			_spawn_character(pos, fake_id, true)
			peer_rooms[fake_id] = 0
			peer_positions[fake_id] = cell


func _calculate_spawn_points(count: int) -> Array:
	var cells: Array = rooms[0].cells
	var open_cells: Array = []
	for y in range(1, ROOM_HEIGHT - 1):
		for x in range(1, ROOM_WIDTH - 1):
			if cells[y][x] == 0:
				open_cells.append(Vector2i(x, y))
	open_cells.sort()
	if open_cells.is_empty():
		return [Vector2i(1, 1)]
	var result: Array = [open_cells[0]]
	var min_dist := 3
	for cell in open_cells:
		if result.size() >= count:
			break
		var valid := true
		for existing in result:
			var diff: Vector2i = (cell - Vector2i(existing)).abs()
			if maxi(diff.x, diff.y) < min_dist:
				valid = false
				break
		if valid:
			result.append(cell)
	while result.size() < count:
		result.append(open_cells[result.size() % open_cells.size()])
	return result


func _spawn_character(pos: Vector2, peer_id: int, is_ai: bool) -> void:
	var spawned_pawn: Walker = CHARACTER_SCENE.instantiate()
	if is_ai:
		spawned_pawn.set_script(AI_SCRIPT)
		spawned_pawn.pose_anims = OPPONENT_POSE
		spawned_pawn.combat_actor = OPPONENT_COMBAT
	else:
		spawned_pawn.set_script(PLAYER_SCRIPT)
		spawned_pawn.pose_anims = PLAYER_POSE
		spawned_pawn.combat_actor = PLAYER_COMBAT
	spawned_pawn.owner_peer_id = peer_id
	spawned_pawn.position = pos
	spawned_pawn.add_to_group("players")
	var anim_tree: AnimationTree = spawned_pawn.get_node_or_null(^"AnimationTree")
	if anim_tree:
		anim_tree.active = true
	spawned_pawn.get_node(^"Pivot/Slime").sprite_frames = spawned_pawn.pose_anims
	if is_ai:
		var dp_scene := preload("res://dialogue/dialogue_player/dialogue_player.tscn")
		var dp: Node = dp_scene.instantiate()
		dp.name = &"DialoguePlayer"
		var dialogue_path: String = bot_dialogues[_bot_index % bot_dialogues.size()]
		dp.dialogue_file = dialogue_path
		_bot_index += 1
		spawned_pawn.add_child(dp)
	grid.add_child(spawned_pawn)
	grid.register_pawn(peer_id, spawned_pawn)


func _clean_templates() -> void:
	var player_template: Node = grid.get_node_or_null(^"Player")
	if player_template:
		player_template.queue_free()


func _spawn_opponent() -> void:
	opponent = CHARACTER_SCENE.instantiate() as Walker
	opponent.set_script(OPPONENT_SCRIPT)
	opponent.pose_anims = OPPONENT_POSE
	opponent.combat_actor = OPPONENT_COMBAT
	opponent.owner_peer_id = 0
	var anim_tree: AnimationTree = opponent.get_node_or_null(^"AnimationTree")
	if anim_tree:
		anim_tree.active = true
	opponent.get_node(^"Pivot/Slime").sprite_frames = OPPONENT_POSE
	opponent.visible = false
	opponent.set_process(false)
	var dp_scene := preload("res://dialogue/dialogue_player/dialogue_player.tscn")
	var dp: Node = dp_scene.instantiate()
	dp.name = &"DialoguePlayer"
	dp.dialogue_file = "res://dialogue/dialogue_data/npc_opponent.json"
	opponent.add_child(dp)
	grid.add_child(opponent)


func _first_open_cell(room_id: int, preferred: Vector2i) -> Vector2i:
	var cells: Array = rooms[room_id].cells
	for radius in range(0, max(ROOM_WIDTH, ROOM_HEIGHT)):
		for y in range(maxi(1, preferred.y - radius), mini(ROOM_HEIGHT - 1, preferred.y + radius + 1)):
			for x in range(maxi(1, preferred.x - radius), mini(ROOM_WIDTH - 1, preferred.x + radius + 1)):
				if cells[y][x] == 0:
					return Vector2i(x, y)
	return Vector2i(1, 1)


func _interior_cell(door: Vector2i) -> Vector2i:
	if door.x == 0:
		return door + Vector2i.RIGHT
	if door.x == ROOM_WIDTH - 1:
		return door + Vector2i.LEFT
	if door.y == 0:
		return door + Vector2i.DOWN
	return door + Vector2i.UP


func _opposite(direction: String) -> String:
	return {"north": "south", "south": "north", "east": "west", "west": "east"}[direction]


func _fade(color: Color, duration: float) -> void:
	var overlay: ColorRect = $RoomTransition
	var tween := create_tween()
	tween.tween_property(overlay, "color", color, duration)
	await tween.finished
