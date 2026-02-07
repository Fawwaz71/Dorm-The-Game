extends StaticBody3D

@onready var anim: AnimationPlayer = $AnimationPlayer

@export var door_id: String = ""
@export var is_locked: bool = true

var is_open = false

func _ready():
	anim.play("normal")
	# Sync variable to metadata for the InteractionComponent to read
	set_meta("locked", is_locked)
	set_meta("key_id", door_id)

func toggle():
	# If the InteractionComponent hasn't flipped this variable to false, 
	# the door will stay shut.
	if is_locked:
		print("This door is locked.")
		return
		
	if is_open:
		anim.play("close")
		is_open = false
	else:
		anim.play("open")
		is_open = true

# This is a helper if you want to call it from elsewhere
func try_unlock_with_keys(player_keys: Array[String]):
	if door_id in player_keys or "ALL" in player_keys:
		is_locked = false
		set_meta("locked", false)
