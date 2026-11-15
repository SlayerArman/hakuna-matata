extends Area2D

@export var speed: float = 650.0
@export var damage: int = 40

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var has_hit: bool = false

func _ready():
	if sprite.sprite_frames.has_animation("fly"):
		sprite.sprite_frames.set_animation_loop("fly", true)
	if sprite.sprite_frames.has_animation("hit"):
		sprite.sprite_frames.set_animation_loop("hit", false)

	if direction == Vector2.LEFT:
		sprite.flip_h = true
	elif direction == Vector2.UP:
		rotation = -PI / 2.0

	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	sprite.play("fly")
	
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float):
	if not has_hit:
		position += direction * speed * delta

func _on_body_entered(body: Node2D):
	if has_hit or body.name == "Player" or body.is_in_group("player"):
		return

	has_hit = true
	collision.set_deferred("disabled", true)

	if body.has_method("take_damage"):
		body.take_damage(damage)

	if sprite.sprite_frames.has_animation("hit"):
		sprite.frame = 0
		sprite.play("hit")
	else:
		queue_free()

func _on_sprite_animation_finished():
	if sprite.animation == "hit":
		queue_free()
