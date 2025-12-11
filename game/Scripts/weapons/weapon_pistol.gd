extends WeaponBase

func try_shoot(target_global_pos: Vector2) -> bool:
	# Semi-auto pistol: respect WeaponBase cooldown, but no hold-to-fire.
	if not can_fire():
		return false

	spawn_bullet(target_global_pos)
	return true
