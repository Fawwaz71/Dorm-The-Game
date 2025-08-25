extends Control

func _ready():
	var example_dialogue = {
		"lines": [
			{"speaker":"Guard","text":"Halt! Who goes there?"},
			{"speaker":"Player","text":"It's just me."},
			{"speaker":"Guard","text":"Move along then."}
		]
	}
	$DialogueUI.start_dialogue(example_dialogue)
