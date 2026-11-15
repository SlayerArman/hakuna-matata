extends Button

@export_file("*.tscn") var game_scene: String = "res://scenes/game.tscn"

func _ready() -> void:
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene)
