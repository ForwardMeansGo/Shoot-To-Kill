extends WeaponBase

"""
Assault Rifle weapon implementation.

For now this behaves like a semi-auto weapon:
- One shot per click (same as pistol).
- All behaviour (damage, crit, shake, aim dot smoothing) is driven
  by the exported properties on WeaponBase and tuned per-scene.

Later we can extend this script with:
- Internal fire rate / cooldown.
- Proper full-auto behaviour when the shoot button is held.
- Per-weapon recoil patterns if needed.
"""

func try_shoot(target_global_pos: Vector2) -> bool:
	# Full-auto capable: WeaponBase handles cooldown.
	if not can_fire():
		return false

	spawn_bullet(target_global_pos)
	return true
