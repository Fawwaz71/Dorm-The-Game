extends CanvasLayer

@onready var shop_ui: Control = $"../ShopUI"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 1000

func _process(_delta):
	if Input.is_action_just_pressed("esc"):
		if get_tree().paused:
			resume()
		else:
			pause()

	if get_tree().paused:
		_update_cursor_mode()

func pause():
	get_tree().paused = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume():
	_resume_next_frame()

func _resume_next_frame() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	visible = false
	_update_cursor_mode()

func _update_cursor_mode() -> void:
	# If pause menu OR shop is open → show mouse
	if visible or (shop_ui and shop_ui.visible):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().quit()
