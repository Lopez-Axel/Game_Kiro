class_name ExplorationGenerator
extends Node2D

const MAP_WIDTH := 20
const MAP_HEIGHT := 10
const CORRIDOR_HALF_WIDTH := 1

const PLAYER_SCENE := preload("res://grid_movement/pawns/character.tscn")
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

var rng := RandomNumberGenerator.new()
var walkable: Dictionary = {}


func _ready() -> void:
	if not NetworkManager.map_seed:
		NetworkManager.map_seed = randi()
	seed(NetworkManager.map_seed)
	rng.seed = NetworkManager.map_seed
	$Decoration.hide()
	$"Decoration upper level".hide()
	_generate_map()
	_spawn_pawns()
	_clean_templates()


func _generate_map() -> void:
	_fill_ground()
	grid.clear()
	pathways.clear()
	walkable.clear()

	var start := Vector2i(2, rng.randi_range(2, MAP_HEIGHT - 3))
	var item := Vector2i(MAP_WIDTH / 2, rng.randi_range(2, MAP_HEIGHT - 3))
	var enemy := Vector2i(MAP_WIDTH - 3, rng.randi_range(2, MAP_HEIGHT - 3))
	_carve_room(start, 1)
	_carve_room(item, 1)
	_carve_room(enemy, 1)
	_carve_route(start, item)
	_carve_route(item, enemy)
	_add_optional_branches()
	_draw_walkable_terrain()
	_draw_boundaries_and_obstacles()
	key_item.position = grid.map_to_local(item)


func _fill_ground() -> void:
	ground.clear()
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO, rng.randi_range(0, 7))


func _carve_route(from: Vector2i, to: Vector2i) -> void:
	var current := from
	while current.x != to.x:
		_carve_cell(current)
		current.x += 1 if to.x > current.x else -1
		if rng.randf() < 0.28:
			_carve_cell(current + Vector2i(0, rng.randi_range(-1, 1)))
	while current.y != to.y:
		_carve_cell(current)
		current.y += 1 if to.y > current.y else -1
	_carve_cell(to)


func _add_optional_branches() -> void:
	for branch in 3:
		var origin := Vector2i(rng.randi_range(3, MAP_WIDTH - 4), rng.randi_range(2, MAP_HEIGHT - 3))
		if not walkable.has(origin):
			continue
		var end := origin + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-2, 2))
		end.x = clampi(end.x, 1, MAP_WIDTH - 2)
		end.y = clampi(end.y, 1, MAP_HEIGHT - 2)
		_carve_route(origin, end)


func _carve_room(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			_carve_cell(Vector2i(x, y))


func _carve_cell(cell: Vector2i) -> void:
	for y in range(cell.y - CORRIDOR_HALF_WIDTH, cell.y + CORRIDOR_HALF_WIDTH + 1):
		for x in range(cell.x - CORRIDOR_HALF_WIDTH, cell.x + CORRIDOR_HALF_WIDTH + 1):
			if x > 0 and x < MAP_WIDTH - 1 and y > 0 and y < MAP_HEIGHT - 1:
				walkable[Vector2i(x, y)] = true


func _draw_walkable_terrain() -> void:
	for cell in walkable:
		pathways.set_cell(cell, 2, Vector2i.ZERO, rng.randi_range(0, 7))


func _draw_boundaries_and_obstacles() -> void:
	for y in range(-1, MAP_HEIGHT + 1):
		for x in range(-1, MAP_WIDTH + 1):
			var cell := Vector2i(x, y)
			if x == -1 or x == MAP_WIDTH or y == -1 or y == MAP_HEIGHT or not walkable.has(cell):
				# Los tiles de obstáculo no se rotan: se colocan siempre en su alternativa 0.
				grid.set_cell(cell, CellType.Type.OBSTACLE, Vector2i.ZERO, 0)


func _spawn_pawns() -> void:
	var spawn_points := _calculate_spawn_points(4)
	var peer_ids: Array = NetworkManager.players.keys()
	peer_ids.sort()

	for i in range(4):
		var pos: Vector2 = grid.map_to_local(spawn_points[i])
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var is_ai: bool = NetworkManager.players[peer_id].get("is_ai", false)
			if is_ai:
				_spawn_character(pos, peer_id, true)
			else:
				_spawn_character(pos, peer_id, false)
		else:
			_spawn_character(pos, -(i + 1), true)

	key_item.type = CellType.Type.OBJECT
	grid.set_cell(grid.local_to_map(key_item.position), CellType.Type.OBJECT, Vector2i.ZERO)


func _calculate_spawn_points(count: int) -> Array:
	var cells: Array = walkable.keys()
	cells.sort()
	var start_cell: Vector2i = cells[0]
	var result: Array = [start_cell]
	var min_dist := 3

	for cell in cells:
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
		result.append(cells[result.size() % cells.size()])
	return result


func _spawn_character(pos: Vector2, peer_id: int, is_ai: bool) -> void:
	var spawned_pawn: Walker = PLAYER_SCENE.instantiate()
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
		dp.dialogue_file = "res://dialogue/dialogue_data/npc.json"
		spawned_pawn.add_child(dp)

	grid.add_child(spawned_pawn)
	grid.register_pawn(peer_id, spawned_pawn)


func _clean_templates() -> void:
	var player_template: Node = grid.get_node_or_null(^"Player")
	if player_template:
		player_template.queue_free()
	var opponent_template: Node = grid.get_node_or_null(^"Opponent")
	if opponent_template:
		opponent_template.queue_free()
