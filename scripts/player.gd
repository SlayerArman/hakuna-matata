extends CharacterBody2D

const SPEED = 300.0
const CROUCH_SPEED = 150.0
const JUMP_VELOCITY = -400.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var upper_body = $"Upper Body"
@onready var lower_body = $"Lower Body"
@onready var collision = $CollisionShape2D

# Store the original CapsuleShape2D height and position
@onready var default_shape_height = collision.shape.height
@onready var default_position = collision.position

var is_running = false
var run_transition = "" # "", "start", or "end"

func _ready():
	# Force transition animations not to loop so animation_finished always fires
	for anim in ["run start", "run end"]:
		if upper_body.sprite_frames.has_animation(anim):
			upper_body.sprite_frames.set_animation_loop(anim, false)
		if lower_body.sprite_frames.has_animation(anim):
			lower_body.sprite_frames.set_animation_loop(anim, false)
			
	upper_body.animation_finished.connect(_on_upper_body_animation_finished)

func _physics_process(delta):
	# Handle gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle Crouch state
	var is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	var current_speed = CROUCH_SPEED if is_crouching else SPEED

	# Get the input direction: -1 for left, 1 for right, 0 for idle
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()
	
	# Update states
	update_animations(direction, is_crouching)
	update_collision(is_crouching)

func update_animations(direction, is_crouching):
	# Flip the sprites horizontally based on movement direction
	if direction != 0:
		var is_facing_left = direction < 0
		upper_body.flip_h = is_facing_left
		lower_body.flip_h = is_facing_left

	if not is_on_floor():
		# Airborne: reset run states and show jumping legs
		is_running = false
		run_transition = ""
		lower_body.visible = true
		lower_body.play("jump")
		
		if Input.is_action_pressed("look up"):
			upper_body.play("look up")
		else:
			upper_body.play("idle")

	elif is_crouching:
		# Crouching: reset run states and use upper body only
		is_running = false
		run_transition = ""
		lower_body.visible = false
		
		if direction != 0:
			upper_body.play("crouch moving")
		else:
			upper_body.play("crouch")

	elif direction != 0:
		# Just started moving -> trigger "run start" from frame 0
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
			# "run start" finished -> switch to full-body "running"
			lower_body.visible = false
			upper_body.play("running")

	else:
		# Just stopped moving -> trigger "run end" from frame 0
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
			# "run end" finished -> return to idle / look up
			lower_body.visible = true
			lower_body.play("idle")
			
			if Input.is_action_pressed("look up"):
				upper_body.play("look up")
			else:
				upper_body.play("idle")

func _on_upper_body_animation_finished():
	if upper_body.animation == "run start" and run_transition == "start":
		run_transition = ""
	elif upper_body.animation == "run end" and run_transition == "end":
		run_transition = ""

func update_collision(is_crouching):
	if is_crouching:
		var target_height = max(default_shape_height * 0.5, collision.shape.radius * 2.0)
		var height_diff = default_shape_height - target_height
		
		collision.shape.height = target_height
		collision.position.y = default_position.y + (height_diff * 0.5)
	else:
		collision.shape.height = default_shape_height
		collision.position.y = default_position.y
