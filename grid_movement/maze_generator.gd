class_name MazeGenerator
extends RefCounted

var rng := RandomNumberGenerator.new()


func generate(width: int, height: int, directions: Dictionary, seed_value: int = -1, room_index: int = 0) -> Dictionary:
	if seed_value >= 0:
		rng.seed = seed_value + room_index * 7919
	else:
		rng.randomize()
	var cells := _make_walls(width, height)
	_carve_depth_first_maze(cells, width, height)
	_add_open_areas(cells, width, height)
	_add_extra_routes(cells, width, height)
	var doors := _place_doors(cells, width, height, directions)
	return {"cells": cells, "doors": doors}


func _make_walls(width: int, height: int) -> Array:
	var cells: Array = []
	for y in height:
		var row: Array = []
		for x in width:
			row.append(1)
		cells.append(row)
	return cells


func _carve_depth_first_maze(cells: Array, width: int, height: int) -> void:
	var start := Vector2i(1, 1)
	cells[start.y][start.x] = 0
	var stack: Array[Vector2i] = [start]
	var directions: Array[Vector2i] = [Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var candidates: Array[Vector2i] = []
		for direction: Vector2i in directions:
			var next: Vector2i = current + direction
			if next.x > 0 and next.x < width - 1 and next.y > 0 and next.y < height - 1 and cells[next.y][next.x] == 1:
				candidates.append(next)
		if candidates.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var wall: Vector2i = current + (next - current) / 2
		cells[wall.y][wall.x] = 0
		cells[next.y][next.x] = 0
		stack.append(next)


func _add_open_areas(cells: Array, width: int, height: int) -> void:
	for area in rng.randi_range(2, 3):
		var size := rng.randi_range(3, 5)
		var origin := Vector2i(rng.randi_range(2, width - size - 1), rng.randi_range(2, height - size - 1))
		for y in range(origin.y, origin.y + size):
			for x in range(origin.x, origin.x + size):
				cells[y][x] = 0


func _add_extra_routes(cells: Array, width: int, height: int) -> void:
	# Abrir algunos muros evita un laberinto de ruta Ãºnica y mantiene callejones.
	for opening in rng.randi_range(5, 8):
		var cell := Vector2i(rng.randi_range(2, width - 3), rng.randi_range(2, height - 3))
		if cells[cell.y][cell.x] == 1:
			cells[cell.y][cell.x] = 0


func _place_doors(cells: Array, width: int, height: int, directions: Dictionary) -> Dictionary:
	var doors := {}
	for direction: String in directions:
		var door := Vector2i.ZERO
		match direction:
			"north": door = Vector2i(_odd_between(1, width - 2), 0)
			"south": door = Vector2i(_odd_between(1, width - 2), height - 1)
			"east": door = Vector2i(width - 1, _odd_between(1, height - 2))
			"west": door = Vector2i(0, _odd_between(1, height - 2))
		var inner := _inside_cell(door, width, height)
		cells[door.y][door.x] = 0
		cells[inner.y][inner.x] = 0
		_connect_to_maze(cells, inner, width, height)
		doors[direction] = door
	return doors


func _inside_cell(door: Vector2i, width: int, height: int) -> Vector2i:
	if door.x == 0:
		return door + Vector2i.RIGHT
	if door.x == width - 1:
		return door + Vector2i.LEFT
	if door.y == 0:
		return door + Vector2i.DOWN
	return door + Vector2i.UP


func _connect_to_maze(cells: Array, from: Vector2i, width: int, height: int) -> void:
	var closest := from
	var best_distance := 9999
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if cells[y][x] == 0:
				var candidate := Vector2i(x, y)
				var distance := absi(candidate.x - from.x) + absi(candidate.y - from.y)
				if distance < best_distance:
					closest = candidate
					best_distance = distance
	while from.x != closest.x:
		cells[from.y][from.x] = 0
		from.x += 1 if closest.x > from.x else -1
	while from.y != closest.y:
		cells[from.y][from.x] = 0
		from.y += 1 if closest.y > from.y else -1
	cells[closest.y][closest.x] = 0


func _odd_between(minimum: int, maximum: int) -> int:
	var value := rng.randi_range(minimum, maximum)
	if value % 2 == 0:
		value = value + 1 if value < maximum else value - 1
	return value
