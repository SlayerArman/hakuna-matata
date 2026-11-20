extends CanvasLayer

@onready var particles: CPUParticles2D = $CPUParticles2D

var last_mouse_pos: Vector2 = Vector2.ZERO

func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	particles.local_coords = false
	particles.emitting = false

func _process(_delta: float):
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	particles.global_position = mouse_pos
	
	particles.emitting = mouse_pos.distance_to(last_mouse_pos) > 0.1
	last_mouse_pos = mouse_pos
