SKILL: generate_maze_dungeon (Versión Multi-Habitación)
📘 Descripción General
Nombre: generate_maze_dungeon
Propósito: Modificar el archivo exploration.tscn para que, al cargar la escena, genere 5 mapas laberinto independientes (habitaciones) interconectados por puertas. Cada habitación es un laberinto con múltiples caminos, callejones sin salida y áreas abiertas, utilizando los tiles disponibles en grid_movement/grid/tiles.

Contexto: El mapa completo consta de 5 habitaciones generadas aleatoriamente pero conectadas entre sí. El jugador comienza en la habitación 0 y puede moverse entre habitaciones a través de puertas. Cada habitación mantiene las características de un laberinto completo con múltiples rutas, diseñado para exploración y persecución de enemigos (bots).

🎯 Objetivos Específicos
5 habitaciones independientes generadas aleatoriamente al inicio.

Conexiones mediante puertas que permiten transitar entre habitaciones.

Cada habitación es un laberinto completo con múltiples rutas, callejones sin salida y zonas abiertas.

Coherencia visual: Usar correctamente todos los tiles disponibles.

Minimapa integrado que muestra las 5 habitaciones, sus conexiones y la ubicación actual del jugador.

Transiciones suaves al cambiar de habitación.

🗺️ Mapeo de Tiles a Funciones (Manteniendo el original)
Tile	Uso en el mapa
ground_grass	Suelo base transitable
path_center, path_edge, path_corner_noise_1, path_edge_noise_1	Caminos transitables con variaciones estéticas
obstacle	Obstáculo sólido no transitable
obstacle_wall	Pared recta
obstacle_wall_corner	Esquina de pared
obstacle_edge	Borde de obstáculo
obstacle_corner, obstacle_corner_inward, obstacle_corner_outward	Esquinas para bordes de obstáculos
obstacle_grass	Obstáculo con apariencia de hierba
rock	Roca decorativa o bloqueo (no transitable)
⚙️ Algoritmo de Generación (Por Habitación)
Cada una de las 5 habitaciones se genera con el mismo algoritmo:

Fase 1: Estructura base tipo laberinto (DFS)
Se crea una cuadrícula donde todas las celdas son paredes.

Se excavan caminos transitables asegurando múltiples rutas.

Se generan callejones sin salida (dead ends) intencionalmente.

Fase 2: Zonas abiertas
Se seleccionan aleatoriamente 2-3 áreas para agrandarlas (3x3 a 5x5 celdas transitables).

Se añaden caminos adicionales que conecten estas zonas.

Fase 3: Decoración con tiles
Asignación de tiles visuales según tipo de celda.

Añadir rocas y obstáculos estéticos en zonas transitables.

Fase 4: Colocación de puertas
Cada habitación tiene entre 2-4 puertas que la conectan con otras habitaciones.

Las puertas se colocan en los bordes (Norte, Sur, Este, Oeste).

📁 Estructura de Archivos Esperada
text
res://
├── exploration.tscn (escena principal)
├── grid_movement/
│   └── grid/
│       └── tiles/
│           ├── ground_grass.png
│           ├── ground_grass.png.import
│           ├── obstacle_corner_inward.png
│           ├── obstacle_corner_outward.png
│           ├── obstacle_corner.png
│           ├── obstacle_edge.png
│           ├── obstacle_grass.png
│           ├── obstacle_wall_corner.png
│           ├── obstacle_wall.png
│           ├── obstacle.png
│           ├── path_center.png
│           ├── path_corner_noise_1.png
│           ├── path_edge_noise_1.png
│           ├── path_edge.png
│           └── rock.png
└── scripts/
    ├── maze_generator.gd (script base - SIN MODIFICAR)
    ├── room_manager.gd (NUEVO: maneja las 5 habitaciones)
    └── minimap.gd (NUEVO: minimapa interactivo)
💻 Código para el Agente (Godot 4)
1. Script Base: maze_generator.gd (¡SIN CAMBIOS!)
Mantén exactamente el mismo código que ya tenías. Este script genera una sola habitación y se reutilizará para cada una de las 5 habitaciones.

gdscript
extends Node2D

@export var map_width: int = 30  # Reducido para habitaciones
@export var map_height: int = 30
@export var tile_size: int = 16

# Referencias a los tiles
@export var ground_tile: Texture2D
@export var wall_tile: Texture2D
@export var corner_tile: Texture2D
@export var edge_tile: Texture2D
@export var rock_tile: Texture2D
@export var path_center_tile: Texture2D
@export var path_edge_tile: Texture2D
@export var path_corner_tile: Texture2D
@export var obstacle_grass_tile: Texture2D

var tile_map: TileMapLayer
var grid: Array = []
var room_id: int = 0
var doors: Dictionary = {}  # { "north": Vector2, "south": Vector2, "east": Vector2, "west": Vector2 }

# NUEVO: Método para generar habitación con ID y conexiones
func generate_room(room_id: int, connections: Dictionary) -> Node2D:
	self.room_id = room_id
	var room_node = Node2D.new()
	room_node.name = "Room_" + str(room_id)
	
	# Crear TileMapLayer
	tile_map = TileMapLayer.new()
	tile_map.name = "TileMapLayer"
	room_node.add_child(tile_map)
	
	# Generar el mapa (mismo algoritmo)
	generate_map()
	
	# Colocar puertas según conexiones
	place_doors(connections)
	
	# Aplicar tiles
	apply_tiles()
	
	return room_node

# EL RESTO DEL CÓDIGO ES EXACTAMENTE IGUAL
func generate_map():
	initialize_grid()
	generate_maze()
	create_open_areas()
	apply_tiles()

func initialize_grid():
	grid = []
	for y in range(map_height):
		var row = []
		for x in range(map_width):
			row.append(1)
		grid.append(row)

func generate_maze():
	var stack = []
	var start_x = randi() % (map_width - 2) + 1
	var start_y = randi() % (map_height - 2) + 1
	grid[start_y][start_x] = 0
	stack.push_back(Vector2(start_x, start_y))

	while stack.size() > 0:
		var current = stack[-1]
		var neighbors = get_unvisited_neighbors(current)
		if neighbors.size() > 0:
			var next = neighbors[randi() % neighbors.size()]
			var wall_x = (current.x + next.x) / 2
			var wall_y = (current.y + next.y) / 2
			grid[wall_y][wall_x] = 0
			grid[next.y][next.x] = 0
			stack.push_back(next)
		else:
			stack.pop_back()

func get_unvisited_neighbors(pos: Vector2) -> Array:
	var neighbors = []
	var directions = [Vector2(0, -2), Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0)]
	for dir in directions:
		var nx = pos.x + dir.x
		var ny = pos.y + dir.y
		if nx > 0 and nx < map_width - 1 and ny > 0 and ny < map_height - 1:
			if grid[ny][nx] == 1:
				neighbors.append(Vector2(nx, ny))
	return neighbors

func create_open_areas():
	for i in range(2 + randi() % 2):  # 2-3 áreas abiertas
		var cx = randi() % (map_width - 6) + 3
		var cy = randi() % (map_height - 6) + 3
		var size = 3 + randi() % 3
		for dy in range(size):
			for dx in range(size):
				if cx + dx < map_width and cy + dy < map_height:
					grid[cy + dy][cx + dx] = 0

# NUEVO: Colocar puertas en los bordes
func place_doors(connections: Dictionary):
	if connections.has("north"):
		var x = randi() % (map_width - 4) + 2
		var y = 0
		grid[y][x] = 0
		grid[y+1][x] = 0
		doors["north"] = Vector2(x, y)
	
	if connections.has("south"):
		var x = randi() % (map_width - 4) + 2
		var y = map_height - 1
		grid[y][x] = 0
		grid[y-1][x] = 0
		doors["south"] = Vector2(x, y)
	
	if connections.has("east"):
		var x = map_width - 1
		var y = randi() % (map_height - 4) + 2
		grid[y][x] = 0
		grid[y][x-1] = 0
		doors["east"] = Vector2(x, y)
	
	if connections.has("west"):
		var x = 0
		var y = randi() % (map_height - 4) + 2
		grid[y][x] = 0
		grid[y][x+1] = 0
		doors["west"] = Vector2(x, y)

func apply_tiles():
	if not has_node("TileMapLayer"):
		var tile_map_layer = TileMapLayer.new()
		tile_map_layer.name = "TileMapLayer"
		add_child(tile_map_layer)
		tile_map = tile_map_layer
	else:
		tile_map = $TileMapLayer

	tile_map.clear()
	tile_map.tile_set = create_tile_set()

	for y in range(map_height):
		for x in range(map_width):
			var cell_type = grid[y][x]
			var atlas_coords = Vector2i(-1, -1)
			match cell_type:
				0:
					atlas_coords = get_ground_tile(x, y)
				1:
					atlas_coords = get_wall_tile(x, y)
				2:
					atlas_coords = get_path_tile(x, y)
				3:
					atlas_coords = Vector2i(4, 0)
			if atlas_coords != Vector2i(-1, -1):
				tile_map.set_cell(Vector2i(x, y), 0, atlas_coords)

func get_ground_tile(x: int, y: int) -> Vector2i:
	var r = randi() % 4
	match r:
		0: return Vector2i(0, 0)
		1: return Vector2i(1, 0)
		2: return Vector2i(2, 0)
		3: return Vector2i(3, 0)
	return Vector2i(0, 0)

func get_wall_tile(x: int, y: int) -> Vector2i:
	var is_wall_up = y == 0 or grid[y-1][x] == 1
	var is_wall_down = y == map_height-1 or grid[y+1][x] == 1
	var is_wall_left = x == 0 or grid[y][x-1] == 1
	var is_wall_right = x == map_width-1 or grid[y][x+1] == 1

	if is_wall_up and is_wall_left: return Vector2i(2, 1)
	if is_wall_up and is_wall_right: return Vector2i(3, 1)
	if is_wall_down and is_wall_left: return Vector2i(0, 2)
	if is_wall_down and is_wall_right: return Vector2i(1, 2)
	if is_wall_up and not is_wall_down: return Vector2i(4, 1)
	if is_wall_down and not is_wall_up: return Vector2i(4, 2)
	if is_wall_left and not is_wall_right: return Vector2i(3, 0)
	if is_wall_right and not is_wall_left: return Vector2i(5, 0)
	return Vector2i(0, 1)

func get_path_tile(x: int, y: int) -> Vector2i:
	var r = randi() % 3
	match r:
		0: return Vector2i(1, 0)
		1: return Vector2i(2, 0)
		2: return Vector2i(3, 0)
	return Vector2i(1, 0)

func create_tile_set() -> TileSet:
	var tile_set = TileSet.new()
	return tile_set
2. Script NUEVO: room_manager.gd (Maneja las 5 habitaciones)
gdscript
extends Node2D
class_name RoomManager

@export var num_rooms: int = 5
@export var room_size: int = 30
@export var player_start_room: int = 0

# Referencias
@export var player: CharacterBody2D
@export var minimap: Minimap

var rooms: Dictionary = {}
var room_connections: Dictionary = {}
var current_room_id: int = 0
var current_room_node: Node2D
var room_generator: MazeGenerator

func _ready():
	# Instanciar el generador de habitaciones
	room_generator = MazeGenerator.new()
	add_child(room_generator)
	
	# Configurar el generador con los tiles
	setup_generator()
	
	# Generar todas las habitaciones
	generate_all_rooms()
	
	# Entrar a la habitación inicial
	enter_room(player_start_room)

func setup_generator():
	# Asignar texturas desde el inspector del RoomManager
	room_generator.ground_tile = ground_tile
	room_generator.wall_tile = wall_tile
	room_generator.corner_tile = corner_tile
	room_generator.edge_tile = edge_tile
	room_generator.rock_tile = rock_tile
	room_generator.path_center_tile = path_center_tile
	room_generator.path_edge_tile = path_edge_tile
	room_generator.path_corner_tile = path_corner_tile
	room_generator.obstacle_grass_tile = obstacle_grass_tile
	room_generator.map_width = room_size
	room_generator.map_height = room_size

func generate_all_rooms():
	# Generar conexiones entre habitaciones
	generate_room_connections()
	
	for room_id in range(num_rooms):
		var connections = room_connections[room_id]
		var room_node = room_generator.generate_room(room_id, connections)
		
		# Posicionar habitación en una cuadrícula
		var cols = 3
		var row = room_id / cols
		var col = room_id % cols
		var spacing = room_size * 16 + 50
		room_node.position = Vector2(col * spacing, row * spacing)
		
		# Configurar detección de puertas
		setup_doors(room_node, room_id)
		
		# Inicialmente ocultar todas las habitaciones
		room_node.visible = false
		room_node.process_mode = PROCESS_MODE_DISABLED
		
		add_child(room_node)
		rooms[room_id] = room_node

func generate_room_connections():
	# Grafo de conexiones (asegurar que todas estén conectadas)
	room_connections = {}
	for i in range(num_rooms):
		room_connections[i] = {}
	
	# Conexiones en forma de estrella + conexiones extra
	var connections = [
		[0, 1], [0, 2], [1, 3], [2, 4], [3, 4], [1, 4]
	]
	
	for conn in connections:
		var room_a = conn[0]
		var room_b = conn[1]
		
		# Asignar direcciones opuestas
		var dirs = ["north", "south", "east", "west"]
		var dir_a = dirs[randi() % dirs.size()]
		var dir_b = get_opposite_direction(dir_a)
		
		room_connections[room_a][dir_a] = room_b
		room_connections[room_b][dir_b] = room_a

func get_opposite_direction(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return dir

func setup_doors(room_node: Node2D, room_id: int):
	# Obtener las puertas del generador
	var doors = room_generator.doors
	
	# Crear áreas de detección para cada puerta
	for direction in doors.keys():
		var door_pos = doors[direction]
		var door_area = Area2D.new()
		door_area.name = "Door_" + direction
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(32, 32)
		collision.shape = shape
		door_area.add_child(collision)
		
		# Posicionar en el tile correspondiente
		door_area.position = Vector2(
			door_pos.x * room_generator.tile_size,
			door_pos.y * room_generator.tile_size
		)
		
		# Guardar metadata
		door_area.set_meta("direction", direction)
		door_area.set_meta("room_id", room_id)
		
		# Conectar señal
		door_area.body_entered.connect(_on_door_entered.bind(room_id, direction))
		
		room_node.add_child(door_area)

func _on_door_entered(body: Node2D, room_id: int, direction: String):
	if body == player:
		var target_room = room_connections[room_id][direction]
		change_room(target_room)

func change_room(room_id: int):
	if room_id == current_room_id:
		return
	
	# Desactivar habitación actual
	if current_room_node:
		current_room_node.visible = false
		current_room_node.process_mode = PROCESS_MODE_DISABLED
	
	# Activar nueva habitación
	current_room_id = room_id
	current_room_node = rooms[room_id]
	current_room_node.visible = true
	current_room_node.process_mode = PROCESS_MODE_INHERIT
	
	# Posicionar jugador en el centro de la nueva habitación
	var center = Vector2(room_size * 16 / 2, room_size * 16 / 2)
	player.global_position = current_room_node.global_position + center
	
	# Actualizar minimapa
	if minimap:
		minimap.update_player_position(room_id)

func enter_room(room_id: int):
	current_room_id = room_id
	current_room_node = rooms[room_id]
	current_room_node.visible = true
	current_room_node.process_mode = PROCESS_MODE_INHERIT
	
	# Posicionar jugador
	var center = Vector2(room_size * 16 / 2, room_size * 16 / 2)
	player.global_position = current_room_node.global_position + center
	
	if minimap:
		minimap.update_player_position(room_id)
3. Script NUEVO: minimap.gd (Minimapa)
gdscript
extends CanvasLayer
class_name Minimap

@export var minimap_size: Vector2 = Vector2(200, 200)
@export var room_size_in_minimap: Vector2 = Vector2(30, 30)
@export var player_dot_color: Color = Color.RED
@export var room_color: Color = Color(0.2, 0.2, 0.3)
@export var connection_color: Color = Color(0.5, 0.5, 0.6)
@export var current_room_color: Color = Color(0.3, 0.6, 0.9)

var room_manager: RoomManager
var current_room: int = 0
var draw_node: Node2D

func _ready():
	setup_ui()
	# Esperar a que el RoomManager esté listo
	await get_tree().process_frame
	room_manager = get_parent().get_node("RoomManager")

func setup_ui():
	var panel = Panel.new()
	panel.position = Vector2(20, 20)
	panel.size = minimap_size
	panel.modulate = Color(0, 0, 0, 0.7)
	add_child(panel)
	
	draw_node = Node2D.new()
	draw_node.position = Vector2(20, 20)
	add_child(draw_node)

func _process(delta):
	if draw_node:
		draw_node.queue_redraw()

func _draw():
	if not room_manager:
		return
	
	# Dibujar conexiones
	for room_id in room_manager.room_connections.keys():
		var pos_a = get_room_position(room_id)
		var connections = room_manager.room_connections[room_id]
		
		for dir in connections.keys():
			var target_id = connections[dir]
			if target_id > room_id:
				var pos_b = get_room_position(target_id)
				draw_line(pos_a, pos_b, connection_color, 2.0)
	
	# Dibujar habitaciones
	for room_id in room_manager.rooms.keys():
		var pos = get_room_position(room_id)
		var color = current_room_color if room_id == current_room else room_color
		draw_rect(Rect2(pos - room_size_in_minimap/2, room_size_in_minimap), color)
		
		# Número de habitación
		var font = ThemeDB.fallback_font
		draw_string(font, pos - Vector2(5, 5), str(room_id + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 12)

func get_room_position(room_id: int) -> Vector2:
	# Posicionar en forma de pentágono
	var angle = (room_id / 5.0) * TAU - PI/2
	var radius = 60.0
	var center = minimap_size / 2
	return center + Vector2(cos(angle), sin(angle)) * radius

func update_player_position(room_id: int):
	current_room = room_id
	update_minimap()

func update_minimap():
	if draw_node:
		draw_node.queue_redraw()
🏗️ Estructura de exploration.tscn
text
exploration.tscn
├── RoomManager (Node2D)
│   ├── script: room_manager.gd
│   ├── [export] player: Player
│   ├── [export] minimap: Minimap
│   ├── [export] num_rooms: 5
│   ├── [export] room_size: 30
│   └── [export] TODAS LAS TEXTURAS DE TILES
├── Player (CharacterBody2D)
│   └── [posición inicial en (0,0) - se ajustará automáticamente]
├── Minimap (CanvasLayer)
│   └── script: minimap.gd
└── Camera2D
    └── [Current: true, seguir al jugador]
📋 Checklist para el Agente
□ Mantener maze_generator.gd sin cambios (solo añadir método generate_room()).
□ Crear room_manager.gd con la lógica de 5 habitaciones.
□ Crear minimap.gd para el minimapa interactivo.
□ Modificar exploration.tscn con la nueva estructura.
□ Configurar el RoomManager con todas las texturas de tiles.
□ Probar que se generen 5 habitaciones diferentes.
□ Verificar que las puertas conecten correctamente entre habitaciones.
□ Validar que el minimapa muestre todas las habitaciones y conexiones.
□ Comprobar que la transición entre habitaciones sea suave.
🧪 Pruebas de Validación
Generación: Cada partida genera 5 laberintos diferentes.

Conexiones: Todas las habitaciones son accesibles desde cualquier punto.

Minimapa: Muestra correctamente estructura y posición actual.

Tiles: Todos los tiles se asignan correctamente en cada habitación.

Rendimiento: Sin caídas de FPS al cambiar de habitación.

🔮 Mejoras para el Agente
Exportar variables adicionales:

gdscript
@export var min_open_areas: int = 2
@export var max_open_areas: int = 4
@export var door_density: float = 0.5
Conexiones más complejas:

gdscript
func generate_complex_connections():
	# Asegurar que todas las habitaciones tengan al menos 2 conexiones
Semilla de aleatoriedad:

gdscript
@export var seed_value: int = 0
func _ready():
	if seed_value != 0:
		seed(seed_value)