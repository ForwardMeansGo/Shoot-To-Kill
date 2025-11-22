extends "res://scripts/weapons/weapon_base.gd"

func try_shoot(target_global_pos: Vector2) -> bool:
	# Semi-auto pistol, no internal cooldown
	spawn_bullet(target_global_pos)
	return true
