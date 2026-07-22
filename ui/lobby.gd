extends Control

@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var ip_input: LineEdit = %IPInput
@onready var player_list: ItemList = %PlayerList
@onready var start_btn: Button = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var player_count: Label = %PlayerCount


func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	start_btn.visible = false
	NetworkManager.player_list_changed.connect(_on_player_list_changed)
	NetworkManager.game_ready.connect(_on_game_ready)
	status_label.text = ""
	player_count.text = "0 / 4"


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	start_btn.visible = true
	status_label.text = "Room created. Waiting for players..."
	host_btn.disabled = true


func _on_join_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	NetworkManager.join_game(ip)
	status_label.text = "Connecting to " + ip + "..."
	join_btn.disabled = true
	host_btn.disabled = true
	ip_input.editable = false


func _on_start_pressed() -> void:
	if NetworkManager.players.size() < 1:
		status_label.text = "Need at least 1 player to start"
		return
	NetworkManager.start_game()


func _on_player_list_changed(new_players: Dictionary) -> void:
	player_list.clear()
	for id in new_players:
		var p: Dictionary = new_players[id]
		var label: String = p["name"]
		if p.get("is_ai", false):
			label += "  [AI]"
		elif id == 1:
			label += "  [HOST]"
		elif id == multiplayer.get_unique_id():
			label += "  [YOU]"
		player_list.add_item(label)
	player_count.text = "%d / 4" % new_players.size()
	if multiplayer.is_server():
		status_label.text = "%d player(s) in room" % new_players.size()


func _on_game_ready() -> void:
	get_tree().change_scene_to_file("res://grid_movement/exploration.tscn")
