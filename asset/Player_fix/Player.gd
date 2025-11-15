extends CharacterBody3D

# === Movement constants ===
var speed: float
const WALK_SPEED := 2.7
const SPRINT_SPEED := 6.0
const JUMP_VELOCITY := 3.0
const SENSITIVITY := 0.0035

# === Head bobbing ===
const BOB_FREQ := 3.4
const BOB_AMP := 0.04
var t_bob := 0.0

# === FOV ===
const BASE_FOV := 65.0
const FOV_CHANGE := 1.5

# === Gravity ===
var gravity := 9.8

# === Stamina ===
var stamina := 5.0
const MAX_STAMINA := 5.0
const STAMINA_DRAIN_RATE := 1.4
const STAMINA_RECOVERY_RATE := 0.85
var is_exhausted := false

var in_bed_camera := false
var previous_camera: Camera3D = null
var sleep_label_shown := false

var was_walking = false
var can_move: bool = true

var grid_size = 0.1
var ghost_block : Node3D = null
var objects = []
var current_object_index = 0

# === Nodes ===
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var sprint_bar: ProgressBar = $CanvasLayer/sprintui/sprintbar
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var hand: Node3D = $Head/Camera3D/hand
@onready var camera_3d: Camera3D = $CanvasLayer/SubViewportContainer/SubViewport/Camera3D
@onready var interact_label: Label = $CanvasLayer/InteractLabel
@onready var crosshair_ui: Control = $CanvasLayer/CrosshairUI
@onready var crosshair: TextureRect = $CanvasLayer/CrosshairUI/Crosshair
@onready var texture_rect: TextureRect = $CanvasLayer/TextureRect
@onready var player: CharacterBody3D = $"."
@onready var color_rect: ColorRect = $CanvasLayer/ColorRect
@onready var small_target: RayCast3D = $Head/Camera3D/small_target
@onready var light: SpotLight3D = $Head/Camera3D/SpotLight3D
@onready var hand_target: Marker3D = $Head/Camera3D/HandTarget

#audio
@onready var footstep_walk: AudioStreamPlayer3D = $SFX/footstep_walk
@onready var footstep_run: AudioStreamPlayer3D = $SFX/footstep_run
@onready var jump_sound: AudioStreamPlayer3D = $SFX/Jump
@onready var door: AudioStreamPlayer3D = $SFX/door
@onready var paper: AudioStreamPlayer3D = $SFX/paper
@onready var pickup: AudioStreamPlayer3D = $SFX/pickup
@onready var sweep: AudioStreamPlayer3D = $SFX/sweep
@onready var bed: AudioStreamPlayer3D = $SFX/bed
@onready var trash: AudioStreamPlayer3D = $SFX/trash
@onready var locked: AudioStreamPlayer3D = $SFX/locked


@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var fade_anim: AnimationPlayer = $CanvasLayer/FadeAnim

@onready var shop_ui: Control = $CanvasLayer/ShopUI
@onready var shop_script := shop_ui  # the ShopUI node (the node that emits buy_item / exit_shop)

# === Preloads (must be constants) ===
const ACOUSTIC_VISUAL = preload("res://asset/interactable/item_visuals/acoustic_visual.tscn")
const ACOUSTIC_PHYSICS = preload("res://asset/interactable/rigid_acoustic.tscn")
const GUITAR_VISUAL = preload("res://asset/interactable/item_visuals/guitar_visual.tscn")
const GUITAR_PHYSICS = preload("res://asset/interactable/Rigid_guitar.tscn")
const DUMBELL_VISUAL = preload("res://asset/interactable/item_visuals/dumbell_small_visual.tscn")
const DUMBELL_PHYSICS = preload("res://asset/interactable/rigid_dumbell_small.tscn")
const BROOM_VISUAL = preload("res://asset/interactable/item_visuals/broom_visual.tscn")
const BROOM_PHYSICS = preload("res://asset/interactable/rigid_broom.tscn")
const BOTTLES_VISUAL = preload("res://asset/interactable/trash object/bottles_visual.tscn")
const BOTTLES_PHYSICS = preload("res://asset/interactable/trash object/rigid_bottles.tscn")
const TRASH_VISUAL = preload("res://asset/interactable/item_visuals/trash_visual.tscn")
const TRASH_PHYSICS = preload("res://asset/interactable/trash object/rigid_trash.tscn")
const KEY_VISUAL = preload("res://asset/interactable/item_visuals/key_visual.tscn")
const KEY_PHYSICS = preload("res://asset/interactable/trash object/rigid_key.tscn")

# === Weapon Pickup System ===
var held_visual: Node3D = null
var held_item_id: String = ""
var viewing_image := false
var input_locked := false
var label_default_pos := Vector2()

var last_position: Vector3

var trash_counter := 0
var big_trash_counter := 0
const TRASH_LIMIT := 5

var cutscene_active = false

var item_database := {
	"acoustic": {
		"visual": ACOUSTIC_VISUAL,
		"physics": ACOUSTIC_PHYSICS
	},
	"guitar": {
		"visual": GUITAR_VISUAL,
		"physics": GUITAR_PHYSICS
	},
	"dumbell_small": {
		"visual": DUMBELL_VISUAL,
		"physics": DUMBELL_PHYSICS
	},
	"broom": {
		"visual": BROOM_VISUAL,
		"physics": BROOM_PHYSICS
	},
	"bottles": {
		"visual": BOTTLES_VISUAL,
		"physics": BOTTLES_PHYSICS
	},
	"trash": {
		"visual": TRASH_VISUAL,
		"physics": TRASH_PHYSICS
	},
	"key": {
		"visual": KEY_VISUAL,
		"physics": KEY_PHYSICS
	}
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	color_rect.visible = false
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.5
	label_default_pos = interact_label.position
	last_position = global_transform.origin
	light.visible = false
	

	# Play initial cutscene
	play_cutscene("enter")
	
	objects.append(preload("res://asset/BuildObject/Table.tscn"))
	objects.append(preload("res://asset/BuildObject/wardrobe.tscn"))

func building(_delta):
	var snap_pos: Vector3 = snap_to_grid(hand_target.global_position, grid_size)

	# --- Floor snapping ---
	var floor_y = get_floor_height(snap_pos)
	var mesh: MeshInstance3D = ghost_block.get_node_or_null("Model")
	if mesh:
		var aabb = mesh.get_aabb()
		# Offset so bottom sits slightly above floor
		var bottom_offset = -aabb.position.y * mesh.scale.y + 0.05  # add 0.05 to lift a bit
		snap_pos.y = floor_y + bottom_offset
	else:
		snap_pos.y = floor_y

	# Smooth ghost movement
	ghost_block.global_position = ghost_block.global_position.lerp(snap_pos, 0.1)

	# Rotation control
	if Input.is_action_just_pressed("rotate"):
		ghost_block.rotation.y += deg_to_rad(90)

	# Placement
	if Input.is_action_just_pressed("left_click") and ghost_block.can_place:
		var block_instance = objects[current_object_index].instantiate()
		get_parent().add_child(block_instance)
		block_instance.place()
		block_instance.global_transform.origin = snap_to_grid(ghost_block.global_transform.origin, grid_size)
		block_instance.global_rotation = ghost_block.global_rotation


	if shop_ui:
		# Godot 4 style: connect signals to Callables
		shop_script.buy_item.connect(Callable(self, "_on_shop_buy_item"))
		shop_script.exit_shop.connect(Callable(self, "_on_shop_exit"))
	shop_ui.visible = false


func get_floor_height(start_pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var ray_start = start_pos + Vector3(0, 2, 0)
	var ray_end = start_pos + Vector3(0, -5, 0)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [ghost_block]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	else:
		return start_pos.y  # fallback if no floor hit


func snap_to_grid(pos: Vector3, grid_snap: float) -> Vector3:
	var x = round(pos.x/grid_snap) * grid_snap
	var y = round(pos.y/grid_snap) * grid_snap
	var z = round(pos.z/grid_snap) * grid_snap
	return Vector3(x, y, z)

func spawn_ghost_block():
	ghost_block = objects [current_object_index].instantiate()
	get_parent().add_child(ghost_block)
	ghost_block.global_position= self.global_position
	ghost_block.global_position.y -= 1.0

func _unhandled_input(event):
	if input_locked:
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
func _physics_process(delta):
	if cutscene_active:
		return  # ignore input and movement during cutscene
	if not can_move:
		interact_label.visible = false
		footstep_run.play()
		footstep_walk.play()
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	if input_locked:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if not is_exhausted and Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		speed = SPRINT_SPEED
		stamina -= STAMINA_DRAIN_RATE * delta
		stamina = max(stamina, 0)
		if stamina == 0:
			is_exhausted = true
	else:
		speed = WALK_SPEED
		stamina += STAMINA_RECOVERY_RATE * delta
		stamina = min(stamina, MAX_STAMINA)
		if is_exhausted and stamina >= MAX_STAMINA:
			is_exhausted = false

	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, 0.0, delta * 7.0)
			velocity.z = lerp(velocity.z, 0.0, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	var current_position = global_transform.origin
	var moved_distance = current_position.distance_to(last_position)
	var is_moving = moved_distance > 0.02 and is_on_floor()
	var is_sprinting = Input.is_action_pressed("sprint")and not is_exhausted

	if is_moving:
		if is_sprinting:
			if not footstep_run.playing:
				footstep_walk.stop()
				footstep_run.play()
		else:
			if not footstep_walk.playing:
				footstep_run.stop()
				footstep_walk.play()
	else:
		footstep_walk.stop()
		footstep_run.stop()

	last_position = current_position
	
	
	if Input.is_action_just_pressed("Build"):
		if ghost_block:
			ghost_block.destroy()
			ghost_block = null
		else:
			spawn_ghost_block()

	if ghost_block:
		building(delta)
		if Input.is_action_just_pressed("next_item"):
			object_change(1)
		elif Input.is_action_just_pressed("previous_item"):
			object_change(-1)
		
	elif raycast.is_colliding():
		var collider = raycast.get_collider()
		if Input.is_action_just_pressed("right_click"):
			if collider and collider.is_in_group("Object"):
				if collider.has_method("destroy"):
					collider.destroy()
				else:
					print("Collider has no destroy() method")

	
	
	move_and_slide()

func object_change(direction: int):
	if ghost_block:
		ghost_block.queue_free()

	current_object_index += direction

	# Wrap around correctly
	if current_object_index < 0:
		current_object_index = objects.size() - 1
	elif current_object_index >= objects.size():
		current_object_index = 0

	spawn_ghost_block()




func _process(_delta):
	camera_3d.global_transform = camera.global_transform
	camera_3d.fov = camera.fov
	camera_3d.near = camera.near
	camera_3d.far = camera.far

	sprint_bar.value = stamina
	var new_style := StyleBoxFlat.new()
	new_style.bg_color = Color.RED if is_exhausted else Color.ROYAL_BLUE
	sprint_bar.add_theme_stylebox_override("fill", new_style)

	handle_interaction()

func handle_interaction():
	if !can_move:
		interact_label.visible = false
		crosshair_ui.visible = false  # optional: also hide crosshair if you want
		footstep_walk.stop()
		return
		
	interact_label.visible = false
	crosshair_ui.visible = true
	

	if raycast.is_colliding():
		var target = raycast.get_collider()
		# Pickup item
		print("Raycast hit:", target)
		print("Groups:", target.get_groups())

		if held_visual == null and target is RigidBody3D and target.is_in_group("pickable"):
			interact_label.text = "Press E to Pick Up"
			interact_label.visible = true
			crosshair_ui.visible = false
			if Input.is_action_just_pressed("interact"):
				pick_up_weapon(target)
				pickup.play()

		# Toggle interaction
		elif target and target.has_method("toggle"):
			var is_locked = target.has_meta("locked") and target.get_meta("locked")
			var door_key_id = target.get_meta("key_id") if target.has_meta("key_id") else null
			var player_key_id = held_visual.get_meta("key_id") if held_visual and held_visual.has_meta("key_id") else null

			if is_locked:
				if Input.is_action_just_pressed("interact"):
					locked.play()
				interact_label.text = "Locked"
				interact_label.visible = true
				crosshair_ui.visible = false
				if door_key_id != null and door_key_id == player_key_id:
					interact_label.text = "Press E to Unlock"
					interact_label.visible = true
					crosshair_ui.visible = false

					if Input.is_action_just_pressed("interact"):
						target.set("is_locked", false)              # ✅ Properly unlock
						target.set_meta("locked", false)            # ✅ Optional if used elsewhere
						target.toggle()                             # ✅ Now toggle works
						door.play()
						locked.stop()
						
						if held_visual:  # The currently held item node
							held_visual.queue_free()
							held_visual = null
							held_item_id = ""

			else:
				interact_label.text = "Press E to Open"
				interact_label.visible = true
				crosshair_ui.visible = false
				target.set_meta("locked", false)
				if Input.is_action_just_pressed("interact"):
					target.toggle()
					door.play()

		elif target and target.has_method("try_clean"):
			if held_visual and held_visual.has_method("try_clean"):
				interact_label.text = "Press E to Clean"
				interact_label.visible = true
				crosshair_ui.visible = false
				if Input.is_action_just_pressed("interact"):
					if await held_visual.try_clean(target):
						target.try_clean("broom")
						sweep.play()
						
		elif target and target.has_method("view"):
			interact_label.text = "Press E to View"
			interact_label.visible = true
			crosshair_ui.visible = false
			
			if not viewing_image:
				interact_label.text = "Press E to View"
			else:
				interact_label.text = "[E] to Escape"
				
			if Input.is_action_just_pressed("interact"):
				if viewing_image:
					texture_rect.visible = false
					color_rect.visible = false
					texture_rect.texture = null
					crosshair_ui.visible = true
					viewing_image = false
					input_locked = false
					footstep_walk.stop()
					paper.play()
					
					interact_label.visible = false
					interact_label.position = label_default_pos
				else:
					var preview_texture = target.view()
					if preview_texture:
						texture_rect.texture = preview_texture
						color_rect.visible = true
						texture_rect.visible = true
						crosshair_ui.visible = false
						viewing_image = true
						input_locked = true
						paper.play()
						footstep_walk.stop()
						footstep_run.stop()
						
						interact_label.text = "[E] to Escape"
						interact_label.visible = true
						interact_label.position = label_default_pos + Vector2(0, 200)
						
		elif target != null and target.is_in_group("trash_can"):
			if held_visual != null and held_visual.is_in_group("trash"):
				interact_label.text = "Press E to Throw Away"
				interact_label.visible = true
				crosshair_ui.visible = false
				if Input.is_action_just_pressed("interact"):
					if held_visual != null:
						held_visual.queue_free()
						held_visual = null
						held_item_id = ""
						trash_counter += 1
						trash.play()

					print("Trash thrown away. Count: ", trash_counter)

					if trash_counter >= TRASH_LIMIT:
						trash_counter = 0
						await get_tree().process_frame  # Wait 1 frame
						spawn_recyclable(target.global_transform.origin)
		
		
		elif target != null and target.is_in_group("big_trash_can"):
			if held_visual != null and held_visual.is_in_group("final_trash"):
				interact_label.text = "Press E to Throw Away"
				interact_label.visible = true
				crosshair_ui.visible = false
				if Input.is_action_just_pressed("interact"):
					if held_visual != null:
						held_visual.queue_free()
						held_visual = null
						held_item_id = ""
						big_trash_counter += 1
						trash.play()
					print("big trash thrown. Count: ", big_trash_counter)
					
		elif target and target.name == "light":
			interact_label.text = "Press E to Equip light"
			interact_label.visible = true
			crosshair_ui.visible = false
			if Input.is_action_just_pressed("interact"):
				target.queue_free()
				pickup.play()
				light.visible = true
				
					
		elif not in_bed_camera:
			if target and (target.is_in_group("sleepable") or target.name == "Bed"):
				interact_label.text = "Press E to Sleep"
				interact_label.visible = true
				crosshair_ui.visible = false

				if Input.is_action_just_pressed("interact"):
					footstep_walk.stop()
					footstep_run.stop()
					var bed_camera = target.get_node("SleepView")
					if bed_camera and bed_camera is Camera3D:
						previous_camera = camera
						in_bed_camera = true
						input_locked = true
						sleep_label_shown = true
						
						bed.play()
						await fade_and_switch_camera(bed_camera)
						
						

			elif target:
				var hit = target
				# Climb upward until we find something in group "PC"
				while hit and not hit.is_in_group("PC"):
					hit = hit.get_parent()

				if hit and hit.is_in_group("PC"):
					interact_label.text = "Press E to Use PC"
					interact_label.visible = true
					crosshair_ui.visible = false

					if Input.is_action_just_pressed("interact"):
						if hit.has_method("interact"):
							hit.interact(self)



		else:
			# While sleeping
			if sleep_label_shown:
				interact_label.text = "Press Q to Get Up"
				interact_label.visible = true
				crosshair_ui.visible = false
				sleep_label_shown = true

			if Input.is_action_just_pressed("Drop"):
				bed.play()
				await fade_and_switch_camera(previous_camera)
				in_bed_camera = false
				input_locked = false
				interact_label.visible = false
				crosshair_ui.visible = true
				
			

# Wake up from bed
	if in_bed_camera and Input.is_action_just_pressed("Drop"):
		if previous_camera:
			previous_camera.current = true
		in_bed_camera = false
		input_locked = false
		
			
	# Drop item
	if held_visual and Input.is_action_just_pressed("Drop"):
		drop_weapon()
		pickup.play()

	if small_target.is_colliding():
		var target_short = small_target.get_collider()
		if target_short and target_short.is_in_group("border"):
			interact_label.text = "Cant Enter"
			interact_label.visible = true
			crosshair_ui.visible = false


func pick_up_weapon(world_weapon: RigidBody3D):
	if not world_weapon.has_meta("item_id"):
		print("Error: picked object missing item_id")
		return

	held_item_id = world_weapon.get_meta("item_id") as String
	if not item_database.has(held_item_id):
		print("Unknown item_id:", held_item_id)
		return

	# Save key_id before queue_free
	var key_id := ""
	if world_weapon.has_meta("key_id"):
		key_id = world_weapon.get_meta("key_id") as String
		print("Picked up key_id:", key_id)
	
	world_weapon.queue_free()
	var visual_scene = item_database[held_item_id]["visual"]
	held_visual = visual_scene.instantiate()
	hand.add_child(held_visual)
	held_visual.transform = Transform3D.IDENTITY

	if key_id != "":
		held_visual.set_meta("key_id", key_id)

	if world_weapon.has_meta("key_id"):
		held_visual.set_meta("key_id", world_weapon.get_meta("key_id"))

		if held_visual.has_node("KeyLabel"):
			var label = held_visual.get_node("KeyLabel") as Label3D
			label.text = "Kamar " + str(world_weapon.get_meta("key_id"))

func drop_weapon():
	if held_visual == null or held_item_id == "":
		return

	var key_id := ""
	if held_visual.has_meta("key_id"):
		key_id = held_visual.get_meta("key_id") as String  # ✅ Extract key_id BEFORE deleting visual

	# Check proximity using small_target
	if small_target.is_colliding():
		# Drop gently near the player (e.g., into trash bin)
		var drop_position = global_transform.origin + Vector3.UP * 0.5
		var saved_transform = Transform3D(camera.global_transform.basis, drop_position)

		held_visual.queue_free()
		held_visual = null

		var weapon_scene = item_database[held_item_id]["physics"]
		var weapon_instance: RigidBody3D = weapon_scene.instantiate()
		weapon_instance.global_transform = saved_transform
		weapon_instance.set_meta("item_id", held_item_id)
		if key_id != "":
			weapon_instance.set_meta("key_id", key_id)
			if weapon_instance.has_variable("key_id"):
				weapon_instance.key_id = key_id  # Also assign exported var

		get_tree().current_scene.add_child(weapon_instance)
		weapon_instance.sleeping = false
		weapon_instance.freeze = false
		weapon_instance.gravity_scale = 1.0

	else:
		# Drop normally with throw force
		var saved_transform = held_visual.global_transform

		held_visual.queue_free()
		held_visual = null

		var weapon_scene = item_database[held_item_id]["physics"]
		var weapon_instance: RigidBody3D = weapon_scene.instantiate()
		weapon_instance.global_transform = saved_transform
		weapon_instance.set_meta("item_id", held_item_id)
		if key_id != "":
			weapon_instance.set_meta("key_id", key_id)
			
			# Assign to script variable if it exists
			if "key_id" in weapon_instance:
				weapon_instance.key_id = key_id
			else:
				print("Warning: Dropped item has no 'key_id' variable, only meta applied")

		get_tree().current_scene.add_child(weapon_instance)
		weapon_instance.sleeping = false
		weapon_instance.freeze = false
		weapon_instance.gravity_scale = 1.0

		var forward_dir = -camera.global_transform.basis.z.normalized()
		var throw_force = forward_dir * 4.0
		weapon_instance.apply_central_impulse(throw_force)

	# Reset internal state
	held_item_id = ""

func spawn_recyclable(spawn_pos: Vector3):
	var new_object = preload("res://asset/interactable/trash object/rigid_trash.tscn").instantiate()
	get_tree().current_scene.add_child(new_object)
	new_object.global_transform.origin = spawn_pos + Vector3(0, 1, 0)
	print("Spawned recyclable!")

func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func fade_and_switch_camera(to_camera: Camera3D) -> void:
	var going_to_sleep := to_camera.name == "SleepView" or to_camera.get_parent().is_in_group("sleepable")

	# Fade out
	fade_anim.play("fade_out")
	await fade_anim.animation_finished

	# Switch camera
	if to_camera:
		to_camera.current = true
	
	
	# Update states AFTER switching camera
	in_bed_camera = going_to_sleep
	input_locked = going_to_sleep
	if in_bed_camera == true:
		color_rect.visible = true
	else:
		color_rect.visible = false
	# Hide or show held item
	if held_visual:
		held_visual.visible = not going_to_sleep

	# Fade back in
	fade_anim.play("fade_in")
	await fade_anim.animation_finished


#cutscene
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "enter":
		cutscene_active = false
		camera.current = true
		$"../CutsceneCamera".current = false

func play_cutscene(anim_name: String) -> void:
	if not $"../AnimationPlayer".has_animation(anim_name):
		push_error("Cutscene not found: " + anim_name)
		return

	# Hide held item during cutscene
	if held_visual:
		held_visual.visible = false

	cutscene_active = true
	input_locked = true
	velocity = Vector3.ZERO
	crosshair.visible = false
	sprint_bar.visible = false
	
	$"../CutsceneCamera".current = true
	camera.current = false

	$"../AnimationPlayer".play(anim_name)
	
	# Wait for animation or skip input
	while $"../AnimationPlayer".is_playing():
		if not is_inside_tree():
			return  # Exit early if player is removed from scene
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):  # Spacebar by default
			fade_anim.play("fade_in")
			$"../AnimationPlayer".stop()
			break

	# Reset camera and UI
	camera.current = true
	$"../CutsceneCamera".current = false
	cutscene_active = false
	input_locked = false
	crosshair.visible = true
	sprint_bar.visible = true

	# Show held item again
	if held_visual:
		held_visual.visible = true


var money = 100

func open_shop_ui():
	input_locked = true
	can_move = false
	velocity = Vector3.ZERO

	fade_anim.play("fade_out")
	await fade_anim.animation_finished

	if shop_ui:
		shop_ui.visible = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	crosshair_ui.visible = false
	interact_label.visible = false

	fade_anim.play("fade_in")
	await fade_anim.animation_finished


func close_shop_ui():
	fade_anim.play("fade_out")
	await fade_anim.animation_finished

	if shop_ui:
		shop_ui.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	crosshair_ui.visible = true

	input_locked = false
	can_move = true

	fade_anim.play("fade_in")
	await fade_anim.animation_finished


# -------------------------------------------------
#  BUY HANDLER (clean version)
# -------------------------------------------------
func _on_shop_buy(item_id: String, quantity: int = 0):
	var price := _get_price(item_id)
	if price == -1:
		print("Unknown item:", item_id)
		return

	var total_cost := price * quantity

	if money < total_cost:
		print("Not enough money!")
		return

	# SUCCESS
	money -= total_cost
	print("Bought:", item_id, "x", quantity)
	print("Remaining money:", money)

	pickup.play()

	if shop_ui:
		shop_ui.set_money_text(money)


# Helper: item price table
func _get_price(item_id: String) -> int:
	var prices = {
		"acoustic": 50,
		"guitar": 10,
		"broom": 15,
		"trash": 5,
		"flashlight": 30,
		"dumbell_small": 3
	}
	return prices.get(item_id, -1)


# Exit button
func _on_shop_exit():
	close_shop_ui()
