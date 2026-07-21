extends Walker

const DIRECTIONS := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
const WANDER_INTERVAL := 1.5

var wander_timer: float = 0.0


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if owner_peer_id >= 0:
		return
	wander_timer -= delta
	if wander_timer > 0.0:
		return
	wander_timer = WANDER_INTERVAL + randf() * 1.0
	_try_move()


func _try_move() -> void:
	var dir: Vector2 = DIRECTIONS[randi() % DIRECTIONS.size()]
	grid._apply_move(self, dir, owner_peer_id)
