extends RigidBody2D

@export var throw_velocity: Vector2 = Vector2(360.0, -250.0)
@export var fuse_time: float = 2.0
@export var explosion_damage: int = 100
@export var damage_player: bool = false

@onready var fly_sprite: CanvasItem = $FlySprite
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var explosion_area: Area2D = $ExplosionArea

var has_exploded: bool = false

func _ready():
	fly_sprite.visible = true
	explosion_sprite.visible = false
	explosion_sprite.stop()

	if fly_sprite is AnimatedSprite2D and fly_sprite.sprite_frames != null:
		var fly_anim: String = get_valid_animation(fly_sprite.sprite_frames, ["fly", "idle", "default"])
		if fly_anim != "":
			fly_sprite.sprite_frames.set_animation_loop(fly_anim, true)
			fly_sprite.play(fly_anim)

	if explosion_sprite.sprite_frames != null:
		var exp_anim: String = get_valid_animation(explosion_sprite.sprite_frames, ["explode", "default"])
		if exp_anim != "":
			explosion_sprite.sprite_frames.set_animation_loop(exp_anim, false)

	explosion_sprite.animation_finished.connect(_on_explosion_animation_finished)

	get_tree().create_timer(fuse_time).timeout.connect(explode)

func get_valid_animation(sf: SpriteFrames, preferred: Array[String]) -> String:
	for anim_name in preferred:
		if sf.has_animation(anim_name) and sf.get_frame_count(anim_name) > 0:
			return anim_name
	for anim_name in sf.get_animation_names():
		if sf.get_frame_count(anim_name) > 0:
			return anim_name
	return ""

func launch(direction_x: float):
	linear_velocity = Vector2(throw_velocity.x * direction_x, throw_velocity.y)
	angular_velocity = 10.0 * direction_x

func explode():
	if has_exploded:
		return
	has_exploded = true

	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	body_collision.set_deferred("disabled", true)

	fly_sprite.visible = false
	explosion_sprite.visible = true

	var hit_targets: Array[Node2D] = []
	for body in explosion_area.get_overlapping_bodies():
		if body in hit_targets:
			continue
		var is_player: bool = body.name == "Player" or body.is_in_group("player")
		if is_player and not damage_player:
			continue
		if body.has_method("take_damage"):
			hit_targets.append(body)
			body.take_damage(explosion_damage)

	if explosion_sprite.sprite_frames != null:
		var exp_anim: String = get_valid_animation(explosion_sprite.sprite_frames, ["explode", "default"])
		if exp_anim != "":
			explosion_sprite.frame = 0
			explosion_sprite.play(exp_anim)
			return

	queue_free()

func _on_explosion_animation_finished():
	queue_free()
