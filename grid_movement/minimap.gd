class_name DungeonMinimap
extends Control

var connections: Dictionary = {}
var current_room := 0


func configure(new_connections: Dictionary) -> void:
	connections = new_connections
	queue_redraw()


func set_current_room(room_id: int) -> void:
	current_room = room_id
	queue_redraw()


func _draw() -> void:
	var positions := _positions()
	for room_id in connections:
		for target in connections[room_id].values():
			if target > room_id:
				draw_line(positions[room_id], positions[target], Color("8396a8"), 2.0)
	for room_id in positions:
		var color := Color("4f9de0") if room_id == current_room else Color("27384a")
		draw_circle(positions[room_id], 16.0, color)
		draw_arc(positions[room_id], 16.0, 0.0, TAU, 20, Color("d9e8f4"), 1.5)
		draw_string(ThemeDB.fallback_font, positions[room_id] + Vector2(-4, 5), str(room_id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _positions() -> Dictionary:
	return {
		0: Vector2(62, 34), 1: Vector2(120, 58), 2: Vector2(34, 96),
		3: Vector2(116, 124), 4: Vector2(62, 154),
	}
