extends Node
class_name BuildingComponent

var grid_size := 0.1
var ghost_block: Node3D = null
var objects: Array = []
var current_object_index := 0

func _ready():
	# Update these paths to your actual buildable scenes
	objects.append(preload("res://asset/BuildObject/Table.tscn"))
	objects.append(preload("res://asset/BuildObject/wardrobe.tscn"))

func process_building(p, _delta):
	# Toggle Ghost Block
	if Input.is_action_just_pressed("Build"):
		if ghost_block:
			_clear_ghost()
		else:
			_spawn_ghost(p)

	if ghost_block:
		_update_ghost_position(p)
		
		# Cycle Items
		if Input.is_action_just_pressed("next_item"): _cycle_object(p, 1)
		if Input.is_action_just_pressed("previous_item"): _cycle_object(p, -1)
		
		# Rotate
		if Input.is_action_just_pressed("rotate"):
			ghost_block.rotation.y += deg_to_rad(90)
			
		# Place
		if Input.is_action_just_pressed("left_click"):
			if ghost_block.get("can_place") == true: # Assumes ghost has 'can_place' logic
				_place_object(p)

	# Delete Object Logic
	elif p.raycast.is_colliding():
		var target = p.raycast.get_collider()
		if target and target.is_in_group("Object") and Input.is_action_just_pressed("right_click"):
			if target.has_method("destroy"): target.destroy()

func _spawn_ghost(p):
	ghost_block = objects[current_object_index].instantiate()
	get_tree().current_scene.add_child(ghost_block)
	ghost_block.process_mode = PROCESS_MODE_DISABLED # Ghost shouldn't run logic

func _clear_ghost():
	if ghost_block: ghost_block.queue_free()
	ghost_block = null

func _cycle_object(p, dir):
	_clear_ghost()
	current_object_index = posmod(current_object_index + dir, objects.size())
	_spawn_ghost(p)

func _update_ghost_position(p):
	var raw_pos = p.hand_target.global_position
	var snapped_pos = Vector3(
		round(raw_pos.x / grid_size) * grid_size,
		raw_pos.y, # We handle Y separately
		round(raw_pos.z / grid_size) * grid_size
	)
	
	# Floor Snapping
	var space_state = p.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(snapped_pos + Vector3(0, 2, 0), snapped_pos + Vector3(0, -5, 0))
	query.exclude = [p, ghost_block]
	var result = space_state.intersect_ray(query)
	
	if result:
		snapped_pos.y = result.position.y
		# Offset for mesh height
		var mesh = ghost_block.get_node_or_null("Model")
		if mesh:
			snapped_pos.y += 0.05 

	ghost_block.global_position = ghost_block.global_position.lerp(snapped_pos, 0.2)

func _place_object(p):
	var final_obj = objects[current_object_index].instantiate()
	get_tree().current_scene.add_child(final_obj)
	final_obj.global_transform = ghost_block.global_transform
	if final_obj.has_method("place"): final_obj.place()
	p.sfx.pickup.play() # Use pickup sound for placement
