class_name Pawn
extends Node2D

@export var type := CellType.Type.ACTOR

var active: bool = true: set = set_active
var owner_peer_id: int = 0

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	set_process_input(value)
