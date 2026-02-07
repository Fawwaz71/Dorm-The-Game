extends CharacterBody3D

# === State Variables ===
var speed: float
const WALK_SPEED := 2.7
const SPRINT_SPEED := 6.0
const JUMP_VELOCITY := 3.0
const SENSITIVITY := 0.0035
const BOB_FREQ := 3.4
const BOB_AMP := 0.04
var t_bob := 0.0
const BASE_FOV := 65.0
const FOV_CHANGE := 1.5
var gravity := 9.8

var stamina := 5.0
const MAX_STAMINA := 5.0
const STAMINA_DRAIN_RATE := 1.4
const STAMINA_RECOVERY_RATE := 0.85
var is_exhausted := false

var money := 1000
var can_move := true
var input_locked := false
var cutscene_active := false
var in_bed_camera := false
var previous_camera: Camera3D = null
var last_position: Vector3

# === Nodes ===
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand: Node3D = $Head/Camera3D/hand
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var small_target: RayCast3D = $Head/Camera3D/small_target
@onready var hand_target: Marker3D = $Head/Camera3D/HandTarget
@onready var object_spawn: Node3D = $ObjectSpawn

@onready var interact_label: Label = $CanvasLayer/InteractLabel
@onready var crosshair_ui: Control = $CanvasLayer/CrosshairUI
@onready var crosshair: TextureRect = $CanvasLayer/CrosshairUI/Crosshair
@onready var sprint_bar: ProgressBar = $CanvasLayer/sprintui/sprintbar
@onready var texture_rect: TextureRect = $CanvasLayer/TextureRect
@onready var color_rect: ColorRect = $CanvasLayer/ColorRect
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var fade_anim: AnimationPlayer = $CanvasLayer/FadeAnim
@onready var camera_viewport: Camera3D = $CanvasLayer/SubViewportContainer/SubViewport/Camera3D
@onready var shop_ui: Control = $CanvasLayer/ShopUI
@onready var light: SpotLight3D = $Head/Camera3D/SpotLight3D

# Components
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var building: BuildingComponent = $BuildingComponent

# SFX Helper Group
@onready var sfx = {
	"walk": $SFX/footstep_walk,
	"run": $SFX/footstep_run,
	"jump": $SFX/Jump,
	"door": $SFX/door,
	"paper": $SFX/paper,
	"pickup": $SFX/pickup,
	"sweep": $SFX/sweep,
	"bed": $SFX/bed,
	"trash": $SFX/trash,
	"locked": $SFX/locked
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	last_position = global_transform.origin
	light.visible = false
	shop_ui.visible = false
	
	if shop_ui:
		shop_ui.buy_item.connect(_on_shop_buy_item)
		shop_ui.exit_shop.connect(_on_shop_exit)
	
	play_cutscene("enter")
	color_rect.visible = false
	texture_rect.visible = false
	
	# The FadeRect is often the culprit
	fade_rect.visible = false
	fade_rect.modulate.a = 0.0 # Force transparency
	# Ensure the mouse is captured so the UI doesn't block rotation
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if input_locked or cutscene_active: return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	# 1. Cutscene Gate
	if cutscene_active:
		return 

	# 2. Gravity (Should always run so you don't float when locked)
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 3. GLOBAL INTERACTION CALL
	# This must stay above the 'input_locked' return so you can 'wake up' or 'close images'
	interaction.handle_interaction(self, delta)

	# 4. Input & Movement Lock Gate
	if input_locked or not can_move:
		if not can_move:
			interact_label.visible = false
		
		# Smoothly stop movement if locked
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		move_and_slide()
		return

	# 5. Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sfx.jump.play()

	# 6. Direction Math
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 7. Stamina Logic
	if not is_exhausted and Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		speed = SPRINT_SPEED
		stamina -= STAMINA_DRAIN_RATE * delta
		if stamina <= 0:
			stamina = 0
			is_exhausted = true
	else:
		speed = WALK_SPEED
		stamina += STAMINA_RECOVERY_RATE * delta
		if is_exhausted and stamina >= MAX_STAMINA:
			is_exhausted = false
	stamina = clamp(stamina, 0, MAX_STAMINA)

	# 8. Movement Lerping
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

	# 9. Headbob & FOV
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	# 10. Footstep SFX
	var current_position = global_transform.origin
	var moved_distance = current_position.distance_to(last_position)
	var is_moving = moved_distance > 0.02 and is_on_floor()
	var is_sprinting = Input.is_action_pressed("sprint") and not is_exhausted

	if is_moving:
		if is_sprinting:
			if not sfx.run.playing:
				sfx.walk.stop()
				sfx.run.play()
		else:
			if not sfx.walk.playing:
				sfx.run.stop()
				sfx.walk.play()
	else:
		sfx.walk.stop()
		sfx.run.stop()

	last_position = current_position
	
	# 11. Final Component Calls & Physics Execution
	building.process_building(self, delta)
	move_and_slide()
func _process(_delta):
	camera_viewport.global_transform = camera.global_transform
	camera_viewport.fov = camera.fov
	sprint_bar.value = stamina
	
	# UI Color change for stamina
	var style = sprint_bar.get_theme_stylebox("fill").duplicate()
	style.bg_color = Color.RED if is_exhausted else Color.ROYAL_BLUE
	sprint_bar.add_theme_stylebox_override("fill", style)

func _headbob(time: float) -> Vector3:
	return Vector3(cos(time * BOB_FREQ / 2) * BOB_AMP, sin(time * BOB_FREQ) * BOB_AMP, 0)

# Cutscene Logic
func play_cutscene(anim_name: String) -> void:
	if not $"../AnimationPlayer".has_animation(anim_name):
		push_error("Cutscene not found: " + anim_name)
		return

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

# Shop Handlers
func _on_shop_buy_item(item_id, qty): inventory.buy_item(self, item_id, qty)
func _on_shop_exit(): close_shop_ui()
func open_shop_ui():
	input_locked = true; can_move = false; velocity = Vector3.ZERO
	shop_ui.visible = true; shop_ui._update_money_label(money)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func close_shop_ui():
	shop_ui.visible = false; Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	input_locked = false; can_move = true
