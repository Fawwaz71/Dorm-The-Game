extends Node3D

@onready var anim: AnimationPlayer = $AnimationPlayer
var sweeping := false

func try_clean(target: Node) -> bool:
	if sweeping:
		return false
	if target and target.is_in_group("stain"):
		sweeping = true
		anim.play("sweep")
		anim.animation_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
		return true
	return false

func _on_anim_done(anim_name: String) -> void:
	if anim_name == "sweep":
		sweeping = false
