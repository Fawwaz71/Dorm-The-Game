extends Node
class_name InteractionComponent

# === State ===
var trash_counter := 0
var big_trash_counter := 0
const TRASH_LIMIT := 5

var viewing_image := false
var label_default_pos := Vector2()

func handle_interaction(p, _delta):
	# 1. If we are viewing an image, ONLY allow the escape logic to run
	if viewing_image:
		_handle_viewing(p, null) 
		return # Exit early so we don't try to interact with things behind the image

	# 2. Normal safety checks
	if !p.can_move or p.input_locked:
		p.interact_label.visible = false
		return
	
	# Reset UI states for this frame
	p.interact_label.visible = false
	p.crosshair_ui.visible = true
	
	
	# 1. SPECIAL CASE: While in Bed
	if p.in_bed_camera:
		p.interact_label.text = "Press Q to Get Up"
		p.interact_label.visible = true
		p.crosshair_ui.visible = false
		
		if Input.is_action_just_pressed("Drop"): # Ensure Q is mapped to "Drop"
			_wake_up(p)
		return # Stop other interactions while in bed

	# 2. SPECIAL CASE: While viewing image
	if viewing_image:
		_handle_viewing(p, null)
		return

	# 3. Normal Safety Gate
	if !p.can_move or p.input_locked:
		p.interact_label.visible = false
		return
	# Store the UI's original position once
	if label_default_pos == Vector2.ZERO: 
		label_default_pos = p.interact_label.position

	# 2. Raycast Collision Logic
	if p.raycast.is_colliding():
		var target = p.raycast.get_collider()

		if not is_instance_valid(target): 
			return

		# A. Pickup System (Only if hand is empty)
		if p.inventory.held_visual == null and target.is_in_group("pickable"):
			_show_label(p, "Press E to Pick Up", false)
			if Input.is_action_just_pressed("interact"):
				p.inventory.pick_up_weapon(p, target)
				p.sfx.pickup.play()

		# B. Doors & Toggles
		elif target.has_method("toggle"):
			_handle_door(p, target)

		# C. Cleaning Logic (Requires Broom)
		elif target.has_method("try_clean"):
			if p.inventory.held_visual and p.inventory.held_visual.has_method("try_clean"):
				_show_label(p, "Press E to Clean", false)
				if Input.is_action_just_pressed("interact"):
					# Use await if the cleaning animation/logic is an async process
					target.try_clean("broom")
					p.sfx.sweep.play()

		# D. Image Viewing System
		elif target.has_method("view"):
			_handle_viewing(p, target)

		# E. Trash Can Systems
		elif target.is_in_group("trash_can") or target.is_in_group("big_trash_can"):
			_handle_trash(p, target)

		# F. Light Equipment
		elif target.name == "light":
			_show_label(p, "Press E to Equip Light", true)
			if Input.is_action_just_pressed("interact"):
				target.queue_free()
				p.sfx.pickup.play()
				p.light.visible = true

		# G. Bed & PC
		elif not p.in_bed_camera:
			if target.is_in_group("sleepable") or target.name == "Bed":
				_show_label(p, "Press E to Sleep", true)
				if Input.is_action_just_pressed("interact"):
					_go_to_sleep(p, target)
			else:
				_check_pc(p, target)

	# 3. Handle Active Bed State (Get Up Logic)
	if p.in_bed_camera:
		_show_label(p, "Press Q to Get Up", false)
		if Input.is_action_just_pressed("Drop"): # Ensure "Drop" is mapped to Q
			_wake_up(p)

	# 4. Short-Range Border Check (Small Raycast)
	if p.small_target.is_colliding():
		var target_short = p.small_target.get_collider()
		if is_instance_valid(target_short) and target_short.is_in_group("border"):
			_show_label(p, "Can't Enter", false)

# --- Internal Helper Methods ---

func _show_label(p, text: String, show_crosshair: bool):
	p.interact_label.text = text
	p.interact_label.visible = true
	p.crosshair_ui.visible = show_crosshair

func _handle_door(p, target):
	var is_locked = target.get_meta("locked") if target.has_meta("locked") else false
	
	if is_locked:
		var door_key_id = str(target.get_meta("key_id")) if target.has_meta("key_id") else "NONE"
		var held_item = p.inventory.held_visual
		var player_key_id = str(held_item.get_meta("key_id")) if held_item and held_item.has_meta("key_id") else "EMPTY"

		if player_key_id == door_key_id:
			_show_label(p, "Press E to Unlock", false)
			if Input.is_action_just_pressed("interact"):
				target.set_meta("locked", false)
				if target.has_method("toggle"):
					target.toggle()
				p.sfx.door.play()
				p.inventory.clear_held(p)
		else:
			_show_label(p, "Locked (Requires Key)", false)
			if Input.is_action_just_pressed("interact"):
				p.sfx.locked.play()
	else:
		_show_label(p, "Press E to Open", true)
		if Input.is_action_just_pressed("interact"):
			target.toggle()
			p.sfx.door.play()

func _handle_viewing(p, target):
	if viewing_image:
		# Exit Viewing
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			viewing_image = false
			p.input_locked = false
			p.texture_rect.visible = false
			p.color_rect.visible = false
			p.interact_label.position = label_default_pos
			p.sfx.paper.play()
	else:
		# Enter Viewing
		_show_label(p, "Press E to View", false)
		if Input.is_action_just_pressed("interact"):
			viewing_image = true
			p.input_locked = true
			p.texture_rect.visible = true
			p.color_rect.visible = true
			p.texture_rect.texture = target.view()
			p.interact_label.text = "[E] to Escape"
			p.interact_label.position = label_default_pos + Vector2(0, 200)
			p.sfx.paper.play()
			p.sfx.walk.stop()

func _handle_trash(p, target):
	var is_big = target.is_in_group("big_trash_can")
	var required_group = "final_trash" if is_big else "trash"
	
	if p.inventory.held_visual and p.inventory.held_visual.is_in_group(required_group):
		_show_label(p, "Press E to Throw Away", true)
		if Input.is_action_just_pressed("interact"):
			p.inventory.clear_held(p)
			p.sfx.trash.play()
			
			if not is_big:
				trash_counter += 1
				if trash_counter >= TRASH_LIMIT:
					trash_counter = 0
					spawn_recyclable(p, target.global_transform.origin)
			else:
				big_trash_counter += 1

func _go_to_sleep(p, target):
	var bed_camera = target.get_node_or_null("SleepView")
	if bed_camera and bed_camera is Camera3D:
		p.previous_camera = p.camera
		p.sfx.bed.play()
		fade_and_switch_camera(p, bed_camera, true)

func _wake_up(p):
	if p.previous_camera:
		p.sfx.bed.play()
		fade_and_switch_camera(p, p.previous_camera, false)

func fade_and_switch_camera(p, to_camera: Camera3D, is_sleeping: bool):
	p.fade_anim.play("fade_out")
	await p.fade_anim.animation_finished

	to_camera.current = true
	p.in_bed_camera = is_sleeping
	p.input_locked = is_sleeping
	p.color_rect.visible = is_sleeping
	
	if p.inventory.held_visual:
		p.inventory.held_visual.visible = !is_sleeping

	p.fade_anim.play("fade_in")

func _check_pc(p, target):
	var hit = target
	while hit != null:
		if hit.is_in_group("PC"):
			_show_label(p, "Press E to Use PC", true)
			if Input.is_action_just_pressed("interact") and hit.has_method("interact"):
				hit.interact(p)
			return
		hit = hit.get_parent()

func spawn_recyclable(_p, spawn_pos: Vector3):
	var path = "res://asset/interactable/trash object/rigid_trash.tscn"
	if ResourceLoader.exists(path):
		var new_object = load(path).instantiate()
		get_tree().current_scene.add_child(new_object)
		new_object.global_transform.origin = spawn_pos + Vector3(0, 1.5, 0)
