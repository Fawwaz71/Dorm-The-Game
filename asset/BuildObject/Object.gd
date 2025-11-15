extends StaticBody3D

@onready var model: MeshInstance3D = $Model
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var clipping_hitbox: Area3D = $ClippingHitbox
@onready var floating_hitbox: Area3D = $FloatingHitbox

var red_material: Material = load("res://asset/BuildObject/Red.tres")
var green_material: Material = load("res://asset/BuildObject/Green.tres")

var can_place: bool = true

func _process(_delta: float) -> void:
	if clipping_hitbox:
		# Ignore the floor in collisions
		var overlaps = clipping_hitbox.get_overlapping_bodies()
		var filtered = overlaps.filter(func(b): return not b.is_in_group("ground"))
		can_place = filtered.is_empty()
		model.transparency = 0.6
		_update_material(can_place)



func _update_material(placeable: bool) -> void:
	var mat = green_material if placeable else red_material

	# Apply to all MeshInstance3D children safely
	for child in get_children():
		_apply_material_recursive(child, mat)


func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
		node.transparency = 0.6

	for sub in node.get_children():
		_apply_material_recursive(sub, mat)


func place() -> void:
	clipping_hitbox.queue_free()
	floating_hitbox.queue_free()
	restore_original_materials(self)
	collision_shape_3d.disabled = false


func restore_original_materials(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = null
			child.transparency = 0.0
		else:
			restore_original_materials(child)


func destroy():
	queue_free()
