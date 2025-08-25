# key.gd
extends RigidBody3D
@export var item_id: String = ""
@export var key_id: String = ""

func _ready():
	set_meta("item_id", item_id)
	set_meta("key_id", key_id)
