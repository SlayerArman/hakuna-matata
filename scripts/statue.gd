extends Area2D

@export var end_overlay: Node
@export var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var area: Area2D = self if self is Area2D else find_child("Area2D", true, false)

var player_in_range: CharacterBody2D = null
var has_triggered: bool = false

func _ready():
	if end_overlay == null:
		end_overlay = find_child("CanvasLayer", true, false)

	if end_overlay != null:
		end_overlay.visible = false
		end_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if area != null:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)
	else:
		push_warning("No Area2D found in the Statue scene!")

func _physics_process(_delta: float):
	if has_triggered or player_in_range == null or not is_instance_valid(player_in_range):
		return

	var is_player_crouching: bool = Input.is_action_pressed("crouch") and player_in_range.is_on_floor()
	if "is_meleeing" in player_in_range and player_in_range.is_meleeing:
		is_player_crouching = false

	if is_player_crouching:
		trigger_game_end()

func trigger_game_end():
	has_triggered = true

	if end_overlay != null:
		end_overlay.visible = true

	get_tree().paused = true

func _on_area_body_entered(body: Node2D):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = body as CharacterBody2D

func _on_area_body_exited(body: Node2D):
	if body == player_in_range:
		player_in_range = null

func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed():
	get_tree().paused = false
	if ResourceLoader.exists(main_menu_scene):
		get_tree().change_scene_to_file(main_menu_scene)
