extends RigidBody3D
@export var item_id = ""

# Called manually by player when interact key is pressed
func try_clean(target):
	if target and target.is_in_group("stain"):
		target.queue_free()
		return true
	return false
