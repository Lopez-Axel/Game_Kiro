extends Node

signal player_list_changed(players: Dictionary)
signal game_ready()

var players: Dictionary = {}
var map_seed: int = 0


func host_game(port: int = 7000) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(port, 4)
	multiplayer.multiplayer_peer = peer
	players[1] = {"name": "Host", "is_ai": false}
	map_seed = randi()
	player_list_changed.emit(players)


func join_game(ip: String, port: int = 7000) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer


func start_game() -> void:
	if not multiplayer.is_server():
		return
	for id in players:
		if id == 1:
			continue
		players[id]["is_ai"] = false
	var ai_slots := 4 - players.size()
	for i in range(ai_slots):
		players[-(i + 1)] = {"name": "AI %d" % (i + 1), "is_ai": true}
	sync_player_list.rpc(players)
	start_game_rpc.rpc()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		players[id] = {"name": "Player %d" % id, "is_ai": false}
		rpc("set_map_seed", map_seed)
		player_list_changed.emit(players)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		player_list_changed.emit(players)


@rpc("authority", "call_local", "reliable")
func start_game_rpc() -> void:
	game_ready.emit()


@rpc("authority", "call_local", "reliable")
func set_map_seed(seed_value: int) -> void:
	map_seed = seed_value


@rpc("authority", "call_local", "reliable")
func sync_player_list(new_players: Dictionary) -> void:
	players = new_players
	player_list_changed.emit(players)


@rpc("authority", "call_local", "reliable")
func apply_speed_boost() -> void:
	pass
