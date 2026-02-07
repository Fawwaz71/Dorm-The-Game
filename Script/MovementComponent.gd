extends Node
class_name MovementComponent

const WALK_SPEED := 2.7
const SPRINT_SPEED := 6.0
const JUMP_VELOCITY := 3.0
const SENSITIVITY := 0.0035
const BOB_FREQ := 3.4
const BOB_AMP := 0.04
const BASE_FOV := 65.0
const FOV_CHANGE := 1.5

var speed: float
var stamina := 5.0
const MAX_STAMINA := 5.0
const STAMINA_DRAIN_RATE := 1.4
const STAMINA_RECOVERY_RATE := 0.85
var is_exhausted := false
var t_bob := 0.0
var last_position: Vector3

func process_movement(p, delta):
	if not p.is_on_floor():
		p.velocity.y -= 9.8 * delta
	
	if Input.is_action_just_pressed("jump") and p.is_on_floor():
		p.velocity.y = JUMP_VELOCITY
		p.sfx.jump.play()

	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (p.head.transform.basis * p.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if not is_exhausted and Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		speed = SPRINT_SPEED
		stamina = max(stamina - STAMINA_DRAIN_RATE * delta, 0)
		if stamina == 0: is_exhausted = true
	else:
		speed = WALK_SPEED
		stamina = min(stamina + STAMINA_RECOVERY_RATE * delta, MAX_STAMINA)
		if is_exhausted and stamina >= MAX_STAMINA: is_exhausted = false

	if p.is_on_floor():
		p.velocity.x = direction.x * speed if direction else lerp(p.velocity.x, 0.0, delta * 7.0)
		p.velocity.z = direction.z * speed if direction else lerp(p.velocity.z, 0.0, delta * 7.0)
	else:
		p.velocity.x = lerp(p.velocity.x, direction.x * speed, delta * 3.0)
		p.velocity.z = lerp(p.velocity.z, direction.z * speed, delta * 3.0)

func process_visuals(p, delta):
	t_bob += delta * p.velocity.length() * float(p.is_on_floor())
	p.camera.transform.origin.y = sin(t_bob * BOB_FREQ) * BOB_AMP
	p.camera.transform.origin.x = cos(t_bob * BOB_FREQ / 2) * BOB_AMP

	var target_fov = BASE_FOV + FOV_CHANGE * clamp(p.velocity.length(), 0.5, SPRINT_SPEED * 2)
	p.camera.fov = lerp(p.camera.fov, target_fov, delta * 8.0)
	p.sprint_bar.value = stamina
