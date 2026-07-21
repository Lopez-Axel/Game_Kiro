extends Walker


func _process(_delta: float) -> void:
	if owner_peer_id == -1:
		return
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.get_unique_id() != owner_peer_id:
		return

	var input_direction := get_input_direction()
	input_direction = input_direction.round()

	if input_direction.is_zero_approx():
		return

	update_look_direction(input_direction)

	grid.rpc("request_move", input_direction)


func get_input_direction() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
