extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	if sprite.sprite_frames.has_animation("idle"):
		sprite.sprite_frames.set_animation_loop("idle", true)
	if sprite.sprite_frames.has_animation("hit"):
		sprite.sprite_frames.set_animation_loop("hit", false)

	area_entered.connect(_on_area_entered)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	sprite.play("idle")

func _on_area_entered(area: Area2D):
	if area.has_method("reflect"):
		area.reflect(self)
		
		if sprite.sprite_frames.has_animation("hit"):
			sprite.frame = 0
			sprite.play("hit")

func _on_sprite_animation_finished():
	if sprite.animation == "hit":
		sprite.play("idle")
