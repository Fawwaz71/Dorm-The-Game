# Pickable.gd
extends RigidBody3D
@export var item_id: String = ""

func _ready():
	set_meta("item_id", item_id)
