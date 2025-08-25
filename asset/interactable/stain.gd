extends StaticBody3D

var is_cleaned = false

func try_clean(item_id: String):
	if is_cleaned:
		return
	if item_id == "broom":
		is_cleaned = true
		print("Cleaning stain:", name)
		fade_and_remove()

func fade_and_remove():
	var mesh = $MeshInstance3D
	if not mesh:
		print("Mesh node not found")
		return

	var material = mesh.get_active_material(0)
	if material == null:
		print("No material found on mesh")
		return

	material = material.duplicate()
	mesh.set_surface_override_material(0, material)

	if material is StandardMaterial3D:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.flags_transparent = true

		for i in range(10):
			await get_tree().create_timer(0.1).timeout
			material.albedo_color.a = clamp(material.albedo_color.a - 0.1, 0.0, 1.0)
	else:
		print("Material is not a StandardMaterial3D, cannot fade.")

	queue_free()
