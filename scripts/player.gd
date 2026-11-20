extends CharacterBody2D

const SPEED = 250.0
const CROUCH_SPEED = 110.0
const JUMP_VELOCITY = -400.0

@export var bullet_scene: PackedScene
@export var max_health: int = 100
@export var melee_damage: int = 100

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var health: int = max_health

@onready var upper_body = $"Upper Body"
@onready var lower_body = $"Lower Body"
@onready var collision = $CollisionShape2D

@onready var muzzle_normal: Marker2D = find_child("MuzzleNormal", true, false)
@onready var muzzle_crouch: Marker2D = find_child("MuzzleCrouch", true, false)
@onready var muzzle_up: Marker2D = find_child("MuzzleUp", true, false)
@onready var melee_area: Area2D = find_child("MeleeArea", true, false)

@onready var default_shape_height = collision.shape.height
@onready var default_position = collision.position

var player_flash_material: ShaderMaterial

var default_melee_x: float = 0.0
var default_melee_child_x: Dictionary = {}

var is_running = false
var run_transition = ""

var was_crouching = false
var was_crouch_moving = false
var crouch_transition = ""

var is_shooting = false
var has_queued_shot = false
var active_shot = ""
var is_shooting_up = false
var shoot_up_transition = ""

var is_meleeing = false
var melee_hit_targets: Array[Node2D] = []

func _ready():
	setup_player_hit_flash()
	
	health = max_health
	
	if melee_area != null:
		default_melee_x = melee_area.position.x
		for child in melee_area.get_children():
			if child is Node2D:
				default_melee_child_x[child] = child.position.x
	
	var one_shot_anims = [
		"run start",
		"run end",
		"crouch start",
		"crouch end",
		"crouch move start-end",
		"shoot up start",
		"shoot up end",
		"shoot",
		"shoot up",
		"crouch shoot",
		"meele"
	]
	
	for anim in one_shot_anims:
		if upper_body.sprite_frames.has_animation(anim):
			upper_body.sprite_frames.set_animation_loop(anim, false)
		if lower_body.sprite_frames.has_animation(anim):
			lower_body.sprite_frames.set_animation_loop(anim, false)
			
	upper_body.animation_finished.connect(_on_upper_body_animation_finished)
	upper_body.frame_changed.connect(_on_upper_body_frame_changed)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("meele") and not is_meleeing:
		is_meleeing = true
		melee_hit_targets.clear()
		is_running = false
		run_transition = ""
		crouch_transition = ""
		is_shooting = false
		has_queued_shot = false
		active_shot = ""
		shoot_up_transition = ""
		is_shooting_up = false
		upper_body.frame = 0

	var is_crouching = false
	var direction = 0.0

	if is_meleeing:
		velocity.x = 0
		if upper_body.animation == "meele" and upper_body.frame in [2, 3]:
			check_melee_hit()
	else:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
		var current_speed = CROUCH_SPEED if is_crouching else SPEED

		if Input.is_action_just_pressed("shoot"):
			if not is_shooting:
				start_new_shot(is_crouching, Input.is_action_pressed("look up"))
			else:
				has_queued_shot = true

		direction = Input.get_axis("move_left", "move_right")
		
		if direction:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()
	
	update_animations(direction, is_crouching)
	update_collision(is_crouching)

func check_melee_hit():
	if melee_area == null:
		return
		
	for body in melee_area.get_overlapping_bodies():
		if body == self or body in melee_hit_targets:
			continue
		if body.has_method("take_damage"):
			melee_hit_targets.append(body)
			body.take_damage(melee_damage)

func update_melee_hitbox_direction(is_facing_left: bool):
	if melee_area == null:
		return
		
	var sign_mult: float = -1.0 if is_facing_left else 1.0
	melee_area.position.x = default_melee_x * sign_mult
	for child in default_melee_child_x:
		if is_instance_valid(child):
			child.position.x = default_melee_child_x[child] * sign_mult

func start_new_shot(is_crouching: bool, is_looking_up: bool):
	is_shooting = true
	has_queued_shot = false
	
	if is_crouching and upper_body.sprite_frames.has_animation("crouch shoot"):
		active_shot = "crouch shoot"
		crouch_transition = ""
		is_shooting_up = false
		shoot_up_transition = ""
		upper_body.frame = 0
		spawn_bullet("crouch shoot")
	elif is_looking_up and not is_crouching:
		active_shot = "shoot up"
		upper_body.frame = 0
		if not is_shooting_up:
			is_shooting_up = true
			shoot_up_transition = "start"
		else:
			spawn_bullet("shoot up")
	else:
		active_shot = "shoot"
		if is_shooting_up:
			is_shooting_up = false
			shoot_up_transition = "end"
		upper_body.frame = 0
		spawn_bullet("shoot")

func spawn_bullet(shot_type: String):
	if bullet_scene == null:
		push_warning("Bullet Scene is not assigned on Player in the Inspector!")
		return

	var bullet = bullet_scene.instantiate()
	var selected_marker: Marker2D = muzzle_normal
	var shoot_dir: Vector2 = Vector2.LEFT if upper_body.flip_h else Vector2.RIGHT

	match shot_type:
		"crouch shoot":
			selected_marker = muzzle_crouch
		"shoot up":
			selected_marker = muzzle_up
			shoot_dir = Vector2.UP
		_:
			selected_marker = muzzle_normal

	bullet.direction = shoot_dir

	if selected_marker != null:
		var marker_parent := selected_marker.get_parent() as Node2D
		var offset: Vector2 = selected_marker.position
		if upper_body.flip_h:
			offset.x = -offset.x
		bullet.global_position = marker_parent.to_global(offset)
	else:
		bullet.global_position = global_position

	get_tree().current_scene.add_child(bullet)

func update_animations(direction, is_crouching):
	var is_looking_up = Input.is_action_pressed("look up")

	if direction != 0 and not is_meleeing:
		var is_facing_left = direction < 0
		upper_body.flip_h = is_facing_left
		lower_body.flip_h = is_facing_left
		update_melee_hitbox_direction(is_facing_left)

	if is_shooting:
		if is_crouching and active_shot != "crouch shoot":
			if upper_body.sprite_frames.has_animation("crouch shoot"):
				active_shot = "crouch shoot"
				is_shooting_up = false
				shoot_up_transition = ""
				crouch_transition = ""
			else:
				is_shooting = false
				active_shot = ""
		elif not is_crouching and active_shot == "crouch shoot":
			active_shot = "shoot"

	if is_crouching and not was_crouching:
		was_crouching = true
		was_crouch_moving = false
		if not is_shooting:
			crouch_transition = "start"
			upper_body.frame = 0
		is_running = false
		run_transition = ""
		is_shooting_up = false
		shoot_up_transition = ""
	elif not is_crouching and was_crouching:
		was_crouching = false
		was_crouch_moving = false
		if is_on_floor() and not is_meleeing and not is_shooting:
			crouch_transition = "end"
			upper_body.frame = 0
		else:
			crouch_transition = ""

	if is_meleeing:
		lower_body.visible = false
		upper_body.play("meele")
		return

	if is_crouching:
		lower_body.visible = false
		
		if is_shooting and active_shot == "crouch shoot":
			crouch_transition = ""
			upper_body.play("crouch shoot")
		elif crouch_transition == "start":
			upper_body.play("crouch start")
		else:
			var is_crouch_moving = direction != 0
			if is_crouch_moving != was_crouch_moving:
				was_crouch_moving = is_crouch_moving
				crouch_transition = "move_toggle"
				upper_body.frame = 0
				
			if crouch_transition == "move_toggle":
				upper_body.play("crouch move start-end")
			elif is_crouch_moving:
				upper_body.play("crouch moving")
			else:
				upper_body.play("crouch")
		return

	if crouch_transition == "end" and (not is_on_floor() or direction != 0 or is_shooting):
		crouch_transition = ""

	if crouch_transition == "end":
		lower_body.visible = false
		upper_body.play("crouch end")
		return

	if (is_shooting and active_shot == "shoot up") or shoot_up_transition == "end":
		update_standing_lower_body(direction)
		
		if shoot_up_transition == "start":
			upper_body.play("shoot up start")
		elif shoot_up_transition == "end":
			upper_body.play("shoot up end")
		else:
			upper_body.play("shoot up")
		return

	if not is_on_floor():
		is_running = false
		run_transition = ""
		lower_body.visible = true
		lower_body.play("jump")
		
		if is_shooting:
			upper_body.play("shoot")
		elif is_looking_up:
			upper_body.play("look up")
		else:
			upper_body.play("idle")
		return

	if is_shooting:
		update_standing_lower_body(direction)
		upper_body.play("shoot")
		return

	if direction != 0:
		if not is_running:
			is_running = true
			run_transition = "start"
			upper_body.frame = 0
			lower_body.frame = 0

		if run_transition == "start":
			lower_body.visible = true
			upper_body.play("run start")
			lower_body.play("run start")
		else:
			var sync_from_lower = lower_body.visible and lower_body.animation == "running"
			var saved_frame = lower_body.frame
			var saved_progress = lower_body.frame_progress
			
			lower_body.visible = false
			upper_body.play("running")
			
			if sync_from_lower:
				upper_body.set_frame_and_progress(saved_frame, saved_progress)
	else:
		if is_running:
			is_running = false
			run_transition = "end"
			upper_body.frame = 0
			lower_body.frame = 0

		if run_transition == "end":
			lower_body.visible = true
			upper_body.play("run end")
			lower_body.play("run end")
		else:
			lower_body.visible = true
			lower_body.play("idle")
			if is_looking_up:
				upper_body.play("look up")
			else:
				upper_body.play("idle")

func update_standing_lower_body(direction):
	var was_hidden = not lower_body.visible
	lower_body.visible = true
	
	if not is_on_floor():
		is_running = false
		run_transition = ""
		lower_body.play("jump")
	elif direction != 0:
		var sync_from_upper = was_hidden and upper_body.animation == "running"
		var saved_frame = upper_body.frame
		var saved_progress = upper_body.frame_progress
		
		is_running = true
		run_transition = ""
		lower_body.play("running")
		
		if sync_from_upper:
			lower_body.set_frame_and_progress(saved_frame, saved_progress)
	else:
		is_running = false
		run_transition = ""
		lower_body.play("idle")

func _on_upper_body_frame_changed():
	if is_meleeing and upper_body.animation == "meele" and upper_body.frame in [2, 3]:
		check_melee_hit()

func _on_upper_body_animation_finished():
	match upper_body.animation:
		"meele":
			is_meleeing = false
			melee_hit_targets.clear()
		"run start":
			if run_transition == "start":
				run_transition = ""
		"run end":
			if run_transition == "end":
				run_transition = ""
		"crouch start":
			if crouch_transition == "start":
				crouch_transition = ""
		"crouch end":
			if crouch_transition == "end":
				crouch_transition = ""
		"crouch move start-end":
			if crouch_transition == "move_toggle":
				crouch_transition = ""
		"shoot up start":
			if shoot_up_transition == "start":
				shoot_up_transition = ""
				upper_body.frame = 0
				if is_shooting and active_shot == "shoot up":
					spawn_bullet("shoot up")
		"shoot up end":
			if shoot_up_transition == "end":
				shoot_up_transition = ""
		"shoot":
			if is_shooting and active_shot == "shoot":
				if Input.is_action_pressed("shoot") or has_queued_shot:
					has_queued_shot = false
					if Input.is_action_pressed("crouch") and is_on_floor():
						active_shot = "crouch shoot"
						upper_body.frame = 0
						spawn_bullet("crouch shoot")
					elif Input.is_action_pressed("look up"):
						active_shot = "shoot up"
						is_shooting_up = true
						shoot_up_transition = "start"
						upper_body.frame = 0
					else:
						upper_body.frame = 0
						spawn_bullet("shoot")
				else:
					is_shooting = false
					active_shot = ""
		"shoot up":
			if is_shooting and active_shot == "shoot up":
				if Input.is_action_pressed("shoot") or has_queued_shot:
					has_queued_shot = false
					if Input.is_action_pressed("crouch") and is_on_floor():
						active_shot = "crouch shoot"
						is_shooting_up = false
						shoot_up_transition = ""
						upper_body.frame = 0
						spawn_bullet("crouch shoot")
					elif not Input.is_action_pressed("look up"):
						active_shot = "shoot"
						is_shooting_up = false
						shoot_up_transition = "end"
						upper_body.frame = 0
						spawn_bullet("shoot")
					else:
						upper_body.frame = 0
						spawn_bullet("shoot up")
				else:
					is_shooting = false
					active_shot = ""
					is_shooting_up = false
					shoot_up_transition = "end"
					upper_body.frame = 0
		"crouch shoot":
			if is_shooting and active_shot == "crouch shoot":
				if Input.is_action_pressed("shoot") or has_queued_shot:
					has_queued_shot = false
					if not (Input.is_action_pressed("crouch") and is_on_floor()):
						if Input.is_action_pressed("look up"):
							active_shot = "shoot up"
							is_shooting_up = true
							shoot_up_transition = "start"
							upper_body.frame = 0
						else:
							active_shot = "shoot"
							upper_body.frame = 0
							spawn_bullet("shoot")
					else:
						upper_body.frame = 0
						spawn_bullet("crouch shoot")
				else:
					is_shooting = false
					active_shot = ""

func update_collision(is_crouching):
	if is_crouching:
		var target_height = max(default_shape_height * 0.5, collision.shape.radius * 2.0)
		var height_diff = default_shape_height - target_height
		
		collision.shape.height = target_height
		collision.position.y = default_position.y + (height_diff * 0.5)
	else:
		collision.shape.height = default_shape_height
		collision.position.y = default_position.y

func take_damage(amount: int):
	trigger_player_hit_haptics(amount)
	health = max(health - amount, 0)
	if health <= 0:
		get_tree().reload_current_scene()

func setup_player_hit_flash():
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 flash_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
		uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

		void fragment() {
			vec4 tex_color = texture(TEXTURE, UV);
			COLOR = mix(tex_color, vec4(flash_color.rgb, tex_color.a), flash_amount);
		}
	"""
	player_flash_material = ShaderMaterial.new()
	player_flash_material.shader = shader
	
	for child in get_children():
		if child is AnimatedSprite2D:
			child.material = player_flash_material

func trigger_player_hit_haptics(amount: int = 30):
	var hit_color := Color(1.0, 0.12, 0.12, 1.0)

	if player_flash_material != null:
		player_flash_material.set_shader_parameter("flash_color", hit_color)
		var tween := create_tween()
		tween.tween_method(
			func(val: float): player_flash_material.set_shader_parameter("flash_amount", val),
			0.85,
			0.0,
			0.15
		)

	var sparks := CPUParticles2D.new()
	sparks.global_position = global_position + Vector2(0, -14)
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 12
	sparks.lifetime = 0.24
	sparks.spread = 180.0
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 160.0
	sparks.gravity = Vector2(0, 300)
	sparks.scale_amount_min = 1.2
	sparks.scale_amount_max = 2.2
	sparks.color = hit_color
	get_parent().add_child(sparks)
	get_tree().create_timer(0.3).timeout.connect(sparks.queue_free)

	spawn_player_damage_number(amount, hit_color)

func spawn_player_damage_number(amount: int, color: Color):
	var label := Label.new()
	label.text = "-" + str(amount)
	label.z_index = 50
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)

	var start_pos := global_position + Vector2(randf_range(-10.0, 6.0), -34.0)
	label.global_position = start_pos
	get_parent().add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start_pos.y - 26.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)
