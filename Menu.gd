extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	layer = 1000  # Always on top

func _process(_delta):
	if Input.is_action_just_pressed("esc"):
		if get_tree().paused:
			resume()
		else:
			pause()

func pause():
	get_tree().paused = true
	visible = true

	var dialogue = get_tree().current_scene.get_node_or_null("Dialogue")
	if dialogue:
		dialogue.visible = false  # Hide visually, but don't free it

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume():
	_resume_next_frame()

func _resume_next_frame() -> void:
	get_tree().paused = false
	await get_tree().process_frame  # Let pause state settle
	visible = false

	var dialogue = get_tree().current_scene.get_node_or_null("Dialogue")
	if dialogue:
		dialogue.visible = true
		dialogue.process_mode = Node.PROCESS_MODE_ALWAYS
		if dialogue.has_method("restore_focus_after_resume"):
			dialogue.restore_focus_after_resume()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().quit()
