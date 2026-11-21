extends Area2D

@export var speed: float = 650.0
@export var damage: int = 25
@export var reflected_damage: int = 25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var shoot_sound: AudioStreamPlayer = $AudioStreamPlayer

var direction: Vector2 = Vector2.RIGHT
var has_hit: bool = false
var anim_finished: bool = false
var is_reflected: bool = false
var last_reflector: Area2D = null
var lifetime: float = 3.0

func _ready():
	if sprite.sprite_frames.has_animation("fly"):
		sprite.sprite_frames.set_animation_loop("fly", true)
	if sprite.sprite_frames.has_animation("hit"):
		sprite.sprite_frames.set_animation_loop("hit", false)

	update_orientation()

	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	shoot_sound.finished.connect(_on_shoot_sound_finished)
	
	sprite.play("fly")
	if shoot_sound.stream != null:
		shoot_sound.play()

func _physics_process(delta: float):
	if not has_hit:
		position += direction * speed * delta
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()

func reflect(reflector: Area2D = null):
	if has_hit or (reflector != null and reflector == last_reflector):
		return

	last_reflector = reflector
	is_reflected = true
	direction = -direction
	lifetime = 3.0
	update_orientation()

func update_orientation():
	sprite.flip_h = false
	rotation = 0.0
	
	if direction == Vector2.LEFT:
		sprite.flip_h = true
	elif direction == Vector2.UP:
		rotation = -PI / 2.0
	elif direction == Vector2.DOWN:
		rotation = PI / 2.0

func _on_body_entered(body: Node2D):
	if has_hit:
		return

	var is_player: bool = body.name == "Player" or body.is_in_group("player")

	if is_player:
		if not is_reflected:
			return
		trigger_hit(body, reflected_damage)
	else:
		trigger_hit(body, damage)

func trigger_hit(body: Node2D, dmg_amount: int):
	has_hit = true
	collision.set_deferred("disabled", true)

	if body.has_method("take_damage"):
		body.take_damage(dmg_amount)

	if sprite.sprite_frames.has_animation("hit"):
		sprite.frame = 0
		sprite.play("hit")
	else:
		anim_finished = true
		sprite.visible = false
		try_cleanup()

func _on_sprite_animation_finished():
	if sprite.animation == "hit":
		anim_finished = true
		sprite.visible = false
		try_cleanup()

func _on_shoot_sound_finished():
	if has_hit:
		try_cleanup()

func try_cleanup():
	if has_hit and anim_finished and not shoot_sound.playing:
		queue_free()
