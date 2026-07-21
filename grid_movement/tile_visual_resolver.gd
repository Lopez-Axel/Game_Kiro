class_name TileVisualResolver
extends RefCounted

const PATH_EDGE := 0
const PATH_EDGE_NOISE := 1
const PATH_CENTER := 2
const PATH_CORNER := 3

const OBS_OBSTACLE := 1
const OBS_GRASS := 3
const OBS_CORNER := 4
const OBS_CORNER_INWARD := 5
const OBS_EDGE := 6
const OBS_WALL := 7
const OBS_WALL_CORNER := 8
const OBS_CORNER_OUTWARD := 9
const OBS_ROCK := 10

const ROCK_CHANCE := 0.1


static func is_walkable(cells: Array, x: int, y: int, width: int, height: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	return cells[y][x] == 0


static func is_wall(cells: Array, x: int, y: int, width: int, height: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return true
	return cells[y][x] == 1


static func resolve_ground(rng: RandomNumberGenerator) -> Dictionary:
	return {"source": 0, "alternative": random_rotation(rng)}


static func resolve_path(cell: Vector2i, cells: Array, width: int, height: int, rng: RandomNumberGenerator) -> Dictionary:
	var n := is_walkable(cells, cell.x, cell.y - 1, width, height)
	var s := is_walkable(cells, cell.x, cell.y + 1, width, height)
	var e := is_walkable(cells, cell.x + 1, cell.y, width, height)
	var w := is_walkable(cells, cell.x - 1, cell.y, width, height)
	var walk_count := int(n) + int(s) + int(e) + int(w)

	if walk_count == 4:
		return {"source": PATH_CENTER, "alternative": random_rotation(rng)}

	if walk_count == 3:
		var source := _path_edge_source(rng)
		return {
			"source": source,
			"alternative": rotate_from_left(_wall_direction(not n, not s, not e, not w)),
		}

	if walk_count == 2:
		if (n and s) or (e and w):
			var use_center := rng.randf() < 0.85
			return {
				"source": PATH_CENTER if use_center else _path_edge_source(rng),
				"alternative": corridor_rotation(n, s, e, w, rng),
			}
		return {"source": PATH_CORNER, "alternative": rotate_opening(n, s, e, w)}

	if walk_count == 1:
		return {
			"source": _path_edge_source(rng),
			"alternative": rotate_from_left(opposite_direction(_opening_direction(n, s, e, w))),
		}

	return {"source": PATH_CENTER, "alternative": 0}


static func resolve_obstacle(cell: Vector2i, cells: Array, width: int, height: int, rng: RandomNumberGenerator) -> Dictionary:
	var x := cell.x
	var y := cell.y
	var n_wall := is_wall(cells, x, y - 1, width, height)
	var s_wall := is_wall(cells, x, y + 1, width, height)
	var e_wall := is_wall(cells, x + 1, y, width, height)
	var w_wall := is_wall(cells, x - 1, y, width, height)
	var n_walk := not n_wall
	var s_walk := not s_wall
	var e_walk := not e_wall
	var w_walk := not w_wall
	var walk_count := int(n_walk) + int(s_walk) + int(e_walk) + int(w_walk)

	if _is_inward_corner(cells, x, y, width, height, n_walk, s_walk, e_walk, w_walk):
		return {
			"source": OBS_CORNER_INWARD,
			"alternative": rotate_opening(n_walk, s_walk, e_walk, w_walk),
		}

	if _is_outward_corner(n_walk, s_walk, e_walk, w_walk):
		var use_outward := rng.randf() < 0.35
		return {
			"source": OBS_CORNER_OUTWARD if use_outward else OBS_CORNER,
			"alternative": rotate_grass_corner(n_walk, s_walk, e_walk, w_walk),
		}

	if walk_count == 1:
		if _touches_border(x, y, width, height):
			return {"source": OBS_GRASS, "alternative": random_rotation(rng)}
		return {
			"source": OBS_EDGE,
			"alternative": rotate_from_up(_opening_direction(n_walk, s_walk, e_walk, w_walk)),
		}

	if walk_count == 2:
		if (n_walk and s_walk) or (e_walk and w_walk):
			return {
				"source": OBS_WALL,
				"alternative": wall_rotation(cells, x, y, width, height, n_walk, s_walk, e_walk, w_walk),
			}
		return {
			"source": OBS_CORNER,
			"alternative": rotate_grass_corner(n_walk, s_walk, e_walk, w_walk),
		}

	if walk_count >= 3:
		return _maybe_rock(rng, OBS_OBSTACLE)

	return _resolve_solid_wall(cell, cells, width, height, n_wall, s_wall, e_wall, w_wall, rng)


static func random_rotation(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 7)


static func rotate_from_left(direction: Vector2i) -> int:
	# Base: borde del camino apunta hacia la izquierda.
	match direction:
		Vector2i.LEFT:
			return 0
		Vector2i.RIGHT:
			return 1
		Vector2i.UP:
			return 4
		Vector2i.DOWN:
			return 6
		_:
			return 0


static func rotate_from_up(direction: Vector2i) -> int:
	# Base: borde de obstáculo con hierba hacia arriba.
	match direction:
		Vector2i.UP:
			return 0
		Vector2i.DOWN:
			return 2
		Vector2i.RIGHT:
			return 5
		Vector2i.LEFT:
			return 6
		_:
			return 0


static func rotate_opening(n: bool, s: bool, e: bool, w: bool) -> int:
	# Base: apertura hacia el sureste (camino abajo + derecha).
	if s and e:
		return 0
	if s and w:
		return 1
	if n and e:
		return 2
	if n and w:
		return 3
	return 0


static func rotate_grass_corner(n: bool, s: bool, e: bool, w: bool) -> int:
	# Base: hierba en abajo e izquierda (caminable sur + oeste).
	if s and w:
		return 0
	if s and e:
		return 1
	if n and w:
		return 2
	if n and e:
		return 3
	return 0


static func corridor_rotation(n: bool, s: bool, e: bool, w: bool, rng: RandomNumberGenerator) -> int:
	# Alinea el tile con el eje del pasillo; añade variación leve en pasillos rectos.
	if n and s:
		return 0 if rng.randf() < 0.5 else 2
	if e and w:
		return 4 if rng.randf() < 0.5 else 6
	return random_rotation(rng)


static func wall_rotation(cells: Array, x: int, y: int, width: int, height: int, n_walk: bool, s_walk: bool, e_walk: bool, w_walk: bool) -> int:
	# Base: muro horizontal con hierba arriba (extiende este-oeste).
	if n_walk and s_walk:
		return 4 if _wall_extends_vertical(cells, x, y, width, height) else 0
	if e_walk and w_walk:
		return 0 if _wall_extends_horizontal(cells, x, y, width, height) else 4
	return 0


static func _wall_extends_horizontal(cells: Array, x: int, y: int, width: int, height: int) -> bool:
	return is_wall(cells, x - 1, y, width, height) or is_wall(cells, x + 1, y, width, height)


static func _wall_extends_vertical(cells: Array, x: int, y: int, width: int, height: int) -> bool:
	return is_wall(cells, x, y - 1, width, height) or is_wall(cells, x, y + 1, width, height)


static func _wall_direction(n_wall: bool, s_wall: bool, e_wall: bool, w_wall: bool) -> Vector2i:
	if n_wall:
		return Vector2i.UP
	if s_wall:
		return Vector2i.DOWN
	if e_wall:
		return Vector2i.RIGHT
	if w_wall:
		return Vector2i.LEFT
	return Vector2i.LEFT


static func opposite_direction(direction: Vector2i) -> Vector2i:
	return direction * -1


static func _opening_direction(n: bool, s: bool, e: bool, w: bool) -> Vector2i:
	if n:
		return Vector2i.UP
	if s:
		return Vector2i.DOWN
	if e:
		return Vector2i.RIGHT
	if w:
		return Vector2i.LEFT
	return Vector2i.UP


static func _resolve_solid_wall(cell: Vector2i, cells: Array, width: int, height: int, n_wall: bool, s_wall: bool, e_wall: bool, w_wall: bool, rng: RandomNumberGenerator) -> Dictionary:
	var wall_count := int(n_wall) + int(s_wall) + int(e_wall) + int(w_wall)

	if wall_count == 4:
		return _maybe_rock(rng, OBS_OBSTACLE)

	if wall_count == 3:
		return {
			"source": OBS_WALL_CORNER,
			"alternative": rotate_wall_corner_opening(not n_wall, not s_wall, not e_wall, not w_wall),
		}

	if wall_count == 2:
		if (n_wall and s_wall) or (e_wall and w_wall):
			return {
				"source": OBS_WALL,
				"alternative": solid_wall_rotation(cell, cells, width, height, n_wall, s_wall, e_wall, w_wall),
			}
		return {
			"source": OBS_WALL_CORNER,
			"alternative": rotate_wall_mass_corner(n_wall, s_wall, e_wall, w_wall),
		}

	return _maybe_rock(rng, OBS_OBSTACLE)


static func solid_wall_rotation(cell: Vector2i, cells: Array, width: int, height: int, n_wall: bool, s_wall: bool, e_wall: bool, w_wall: bool) -> int:
	# Segmento recto de muro: alterna horizontal / vertical según continuidad.
	if n_wall and s_wall:
		return 4 if _wall_extends_vertical(cells, cell.x, cell.y, width, height) else 0
	if e_wall and w_wall:
		return 0 if _wall_extends_horizontal(cells, cell.x, cell.y, width, height) else 4
	return 0


static func rotate_wall_corner_opening(n_open: bool, s_open: bool, e_open: bool, w_open: bool) -> int:
	# Base: esquina de muro con apertura hacia el sur.
	if s_open:
		return 0
	if n_open:
		return 2
	if e_open:
		return 3
	if w_open:
		return 1
	return 0


static func rotate_wall_mass_corner(n_wall: bool, s_wall: bool, e_wall: bool, w_wall: bool) -> int:
	# Base: esquina interior de masa rocosa (muros arriba + izquierda).
	if n_wall and w_wall:
		return 0
	if n_wall and e_wall:
		return 1
	if s_wall and w_wall:
		return 2
	if s_wall and e_wall:
		return 3
	return 0


static func _maybe_rock(rng: RandomNumberGenerator, fallback_source: int) -> Dictionary:
	if rng.randf() < ROCK_CHANCE:
		return {"source": OBS_ROCK, "alternative": random_rotation(rng)}
	return {"source": fallback_source, "alternative": random_rotation(rng)}


static func _is_inward_corner(cells: Array, x: int, y: int, width: int, height: int, n_walk: bool, s_walk: bool, e_walk: bool, w_walk: bool) -> bool:
	if n_walk and e_walk:
		return is_walkable(cells, x + 1, y - 1, width, height)
	if n_walk and w_walk:
		return is_walkable(cells, x - 1, y - 1, width, height)
	if s_walk and e_walk:
		return is_walkable(cells, x + 1, y + 1, width, height)
	if s_walk and w_walk:
		return is_walkable(cells, x - 1, y + 1, width, height)
	return false


static func _is_outward_corner(n_walk: bool, s_walk: bool, e_walk: bool, w_walk: bool) -> bool:
	var walk_count := int(n_walk) + int(s_walk) + int(e_walk) + int(w_walk)
	if walk_count != 2:
		return false
	return not ((n_walk and s_walk) or (e_walk and w_walk))


static func _touches_border(x: int, y: int, width: int, height: int) -> bool:
	return x == 0 or y == 0 or x == width - 1 or y == height - 1


static func _path_edge_source(rng: RandomNumberGenerator) -> int:
	return PATH_EDGE if rng.randf() < 0.7 else PATH_EDGE_NOISE
