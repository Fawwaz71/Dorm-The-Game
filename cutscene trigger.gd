extends Area3D

@export var cutscene_name: String = "example_cutscene"
@export var dialogue_res: Resource # Optional dialogue resource

var cutscene_played := false
var player_ref: Node = null
var balloon_ref: Node = null

func _ready():
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "Player" and not cutscene_played:
		player_ref = body
		_disable_player_movement()
		cutscene_played = true

		if dialogue_res:
			# Show dialogue balloon first
			balloon_ref = DialogueManager.show_dialogue_balloon(dialogue_res)
			if balloon_ref and balloon_ref.has_signal("tree_exited"):
				balloon_ref.connect("tree_exited", Callable(self, "_on_dialogue_finished"), Object.CONNECT_ONE_SHOT)
		else:
			# No dialogue, start cutscene immediately
			_start_cutscene()

func _on_dialogue_finished():
	if balloon_ref:
		balloon_ref.queue_free()
		balloon_ref = null

	_start_cutscene()

func _start_cutscene():
	print("Triggering cutscene:", cutscene_name)
	if player_ref and "play_cutscene" in player_ref:
		player_ref.play_cutscene(cutscene_name)

	if player_ref and player_ref.has_signal("cutscene_finished"):
		player_ref.connect("cutscene_finished", Callable(self, "_on_cutscene_finished"), Object.CONNECT_ONE_SHOT)
	else:
		_on_cutscene_finished()

func _on_cutscene_finished():
	_enable_player_movement()
	queue_free()

func _disable_player_movement():
	if player_ref and "can_move" in player_ref:
		player_ref.can_move = false
		print("Player movement disabled")

func _enable_player_movement():
	if player_ref and "can_move" in player_ref:
		player_ref.can_move = true
		print("Player movement enabled")
