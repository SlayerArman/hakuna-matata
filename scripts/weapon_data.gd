class_name WeaponData
extends Resource

@export var weapon_name: String = "Pistol"
@export var bullet_scene: PackedScene
@export var damage: int = 40
@export var magazine_size: int = 7
@export var starting_reserve_ammo: int = 28
@export var max_reserve_ammo: int = 70
@export var reload_time: float = 0.8
@export var magazine_sprite_frames: SpriteFrames
@export var magazine_full_at_frame_zero: bool = true
