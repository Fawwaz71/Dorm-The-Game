extends StaticBody3D

@onready var anim: AnimationPlayer = $AnimationPlayer

@export var door_id: String = ""
@export var is_locked: bool = true

var is_open = false

func _ready():
	anim.play("normal")
	set_meta("locked", is_locked)
	set_meta("key_id", door_id)  # Only for reference

func open():
	if !is_open:
		anim.play("open")
		is_open = true

func close():
	if is_open:
		anim.play("close")
		is_open = false

func toggle():
	if is_locked:
		print("This door is locked.")
		return
	if is_open:
		close()
	else:
		open()

func try_unlock_with_keys(player_keys: Array[String]):
	if door_id in player_keys or "ALL" in player_keys:
		is_locked = false
		set_meta("locked", false)
		print("Unlocked door with key ID:", door_id)
	else:
		print("You need the correct key to open this door.")


#extends StaticBody3D
#
#@onready var anim: AnimationPlayer = $AnimationPlayer
#
#var is_open = false
#
#func _ready():
	#anim.play("normal")  # Set initial pose
#
#func open():
	#if !is_open:
		#anim.play("open")
		#is_open = true
#
#func close():
	#if is_open:
		#anim.play("close")
		#is_open = false
#
#func toggle():
	#if is_open:
		#close()
	#else:
		#open()
