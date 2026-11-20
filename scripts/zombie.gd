extends CharacterBody2D

@export var speed: float = 120.0
@export var max_health: int = 100
@export var attack_damage: int = 30
@export var attack_range: float = 45.0
@export var attack_vertical_tolerance: float = 50.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var detection_collision: CollisionShape2D = $Area2D/CollisionShape2D

var health: int
var player: CharacterBody2D = null

var attack_animations: Array[String] = ["attack 1", "attack 2", "attack 3"]
var current_attack_index: int = 0

var is_attacking: bool = false
var has_dealt_damage: bool = false
var is_dead: bool = false
var flash_material: ShaderMaterial

func _ready():
	health = max_health
	setup_hit_flash()
	
	for anim in ["attack 1", "attack 2", "attack 3", "dead"]:
		if sprite.sprite_frames.has_animation(anim):
			sprite.sprite_frames.set_animation_loop(anim, false)
			
	for anim in ["idle", "running"]:
		if sprite.sprite_frames.has_animation(anim):
			sprite.sprite_frames.set_animation_loop(anim, true)

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	sprite.play("idle")

func setup_hit_flash():
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
		uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

		void fragment() {
			vec4 tex_color = texture(TEXTURE, UV);
			COLOR = mix(tex_color, vec4(flash_color.rgb, tex_color.a), flash_amount);
		}
	"""
	flash_material = ShaderMaterial.new()
	flash_material.shader = shader
	sprite.material = flash_material

func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_dead:
		velocity.x = 0
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return

	if player != null and is_instance_valid(player):
		var dx: float = player.global_position.x - global_position.x
		var dy: float = abs(player.global_position.y - global_position.y)
		var distance_x: float = abs(dx)

		if dx != 0:
			sprite.flip_h = dx < 0

		if distance_x <= attack_range and dy <= attack_vertical_tolerance:
			start_next_attack()
		else:
			var direction: float = sign(dx)
			velocity.x = direction * speed
			sprite.play("running")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		sprite.play("idle")

	move_and_slide()

func start_next_attack():
	is_attacking = true
	has_dealt_damage = false
	velocity.x = 0

	var anim_name: String = attack_animations[current_attack_index]
	current_attack_index = (current_attack_index + 1) % attack_animations.size()
	
	sprite.frame = 0
	sprite.play(anim_name)

func try_deal_damage_to_player():
	if is_dead or has_dealt_damage or player == null or not is_instance_valid(player):
		return
		
	var distance_x: float = abs(player.global_position.x - global_position.x)
	var dy: float = abs(player.global_position.y - global_position.y)
	
	if distance_x <= attack_range + 15.0 and dy <= attack_vertical_tolerance:
		has_dealt_damage = true
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

func take_damage(amount: int = 40):
	if is_dead:
		return
		
	trigger_hit_haptics(amount)
	health -= amount
	if health <= 0:
		die()

func trigger_hit_haptics(amount: int):
	var flash_color: Color = Color(1.0, 0.9, 0.1, 1.0) if randf() < 0.35 else Color(1.0, 1.0, 1.0, 1.0)
	var blood_color := Color(0.85, 0.05, 0.05, 1.0)

	if flash_material != null:
		flash_material.set_shader_parameter("flash_color", flash_color)
		var tween := create_tween()
		tween.tween_method(
			func(val: float): flash_material.set_shader_parameter("flash_amount", val),
			0.9,
			0.0,
			0.12
		)

	var sparks := CPUParticles2D.new()
	sparks.global_position = global_position + Vector2(0, -16)
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 12
	sparks.lifetime = 0.25
	sparks.spread = 180.0
	sparks.initial_velocity_min = 75.0
	sparks.initial_velocity_max = 150.0
	sparks.gravity = Vector2(0, 320)
	sparks.scale_amount_min = 1.2
	sparks.scale_amount_max = 2.2
	sparks.color = blood_color
	get_parent().add_child(sparks)
	get_tree().create_timer(0.3).timeout.connect(sparks.queue_free)

	spawn_damage_number(amount, flash_color)

func spawn_damage_number(amount: int, color: Color):
	var label := Label.new()
	label.text = str(amount)
	label.z_index = 50
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)

	var start_pos := global_position + Vector2(randf_range(-12.0, 6.0), -34.0)
	label.global_position = start_pos
	get_parent().add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start_pos.y - 26.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func die():
	is_dead = true
	is_attacking = false
	velocity.x = 0
	
	collision_layer = 0
	detection_collision.set_deferred("disabled", true)
	
	sprite.frame = 0
	sprite.play("dead")

func _on_sprite_animation_finished():
	if sprite.animation == "dead":
		queue_free()
	elif sprite.animation in attack_animations:
		# Deal damage only after the attack animation finishes
		try_deal_damage_to_player()
		is_attacking = false

func _on_detection_area_body_entered(body: Node2D):
	if body.name == "Player" or body.is_in_group("player"):
		player = body as CharacterBody2D

func _on_detection_area_body_exited(body: Node2D):
	if body == player:
		player = null
