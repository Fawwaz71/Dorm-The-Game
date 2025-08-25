extends Node3D

# === CONFIG ===
var sway_threshold := 2.0      # Minimum mouse movement to trigger sway
var sway_lerp := 5.0           # How quickly sway returns to center
var sway_amount := 6.0         # Maximum sway in degrees (you can change this!)

# === PRECOMPUTED ROTATIONS ===
var sway_left: Vector3
var sway_right: Vector3
var sway_normal := Vector3.ZERO

# === INPUT TRACKING ===
var mouse_mov := 0.0

func _ready():
	update_sway_angles()

func update_sway_angles():
	var angle_rad = deg_to_rad(sway_amount)
	sway_left = Vector3(0, angle_rad, 0)
	sway_right = Vector3(0, -angle_rad, 0)

func _input(event):
	if event is InputEventMouseMotion:
		mouse_mov = event.relative.x

func _process(delta):
	var target_rot := sway_normal

	if mouse_mov > sway_threshold:
		target_rot = sway_left
	elif mouse_mov < -sway_threshold:
		target_rot = sway_right

	rotation = rotation.lerp(target_rot, sway_lerp * delta)
	mouse_mov = 0.0  # Reset every frame
