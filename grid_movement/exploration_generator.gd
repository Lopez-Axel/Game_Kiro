class_name ExplorationGenerator
extends Node2D

## El mapa se crea al cargar la escena. Cada recorrido conecta el inicio,
## el objeto y el rival, por lo que nunca se generan objetivos aislados.
const MAP_WIDTH := 20
const MAP_HEIGHT := 10
const CORRIDOR_HALF_WIDTH := 1

@onready var ground: TileMapLayer = $Ground
@onready var pathways: TileMapLayer = $Pathways
@onready var grid: Grid = $Grid
@onready var player: Node2D = $Grid/Player
@onready var opponent: Node2D = $Grid/Opponent
@onready var key_item: Node2D = $Grid/Object

var rng := RandomNumberGenerator.new()
var walkable: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	$Decoration.hide()
	$"Decoration upper level".hide()
	_generate_map()


func _generate_map() -> void:
	_fill_ground()
	grid.clear()
	pathways.clear()
	walkable.clear()

	# La secuencia de puntos convierte el mapa en una pequeña aventura:
	# aparecer -> conseguir objeto -> enfrentarse al rival.
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
	_place_pawns(start, item, enemy)


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
				grid.set_cell(cell, CellType.Type.OBSTACLE, Vector2i.ZERO, rng.randi_range(0, 7))


func _place_pawns(start: Vector2i, item: Vector2i, enemy: Vector2i) -> void:
	player.position = grid.map_to_local(start)
	key_item.position = grid.map_to_local(item)
	opponent.position = grid.map_to_local(enemy)
	grid.set_cell(start, CellType.Type.ACTOR, Vector2i.ZERO)
	grid.set_cell(item, CellType.Type.OBJECT, Vector2i.ZERO)
	grid.set_cell(enemy, CellType.Type.ACTOR, Vector2i.ZERO)
