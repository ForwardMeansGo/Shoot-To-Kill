# Gameplay Systems — Shoot To Kill

## Weapons System

### Architecture
- All weapons are scenes that use scripts under `scripts/weapons/`.
- Base script: `weapon_base.gd` (extends `Node2D`).
- Specific weapons (e.g. `weapon_pistol.gd`) extend the base.

### WeaponBase Responsibilities
- Rotation:
  - `aim_at(target_global_pos)` uses `look_at` so weapon points toward mouse.
- Flipping:
  - `set_facing_left(is_left)` flips weapon sprite vertically when facing left.
  - Player decides facing and calls this.
- Bullet spawn:
  - `spawn_bullet(target_global_pos)`:
    - Uses `Muzzle` marker to get spawn position.
    - Instantiates `Bullet.tscn`.
    - Sets `direction`, `rotation`, and adds it to the current scene.
- Camera shake:
  - Emits `fired(shake_strength, shake_duration)` signal per shot.
  - Player listens and forwards this to Camera2D.
- Sound:
  - Uses `GunAudio` (AudioStreamPlayer2D) as a template.
  - Spawns a new one-shot `AudioStreamPlayer2D` at the muzzle each shot.
  - Applies slight random pitch variation for feel.

### Pistol
- `weapon_pistol.gd`:
  - Extends WeaponBase.
  - `try_shoot(target_pos)` simply calls `spawn_bullet(target_pos)` and returns `true`.
- Semi-auto behaviour:
  - Player uses `Input.is_action_just_pressed("shoot")`, so holding the mouse does not rapid-fire.

---

## Bullet System

- Scene: `Bullet.tscn`
- Script: `bullet.gd` (located in `scripts/weapons/bullet.gd`)
- Movement:
  - Uses raycast logic each physics frame:
    - Computes `from` (current position) and `to` (intended new position).
    - Calls `intersect_ray` with the bullet's `collision_mask`.
    - If hit:
      - Moves to hit position.
      - Calls `_handle_hit(collider)`.
      - `queue_free()`.
    - If no hit:
      - Moves to `to` normally.
- Damage:
  - `damage` exported variable (currently set to 10).
  - `_handle_hit`:
    - Ignores nodes in `"player"` group.
    - If node is in `"enemy"` group and has `take_damage`, calls it with `damage`.
- Lifetime:
  - `lifetime` counts down each frame.
  - Bullet despawns when lifetime <= 0.

---

## Enemy System

### Basic Enemy (EnemyBasic)
- Movement:
  - Uses gravity to stay grounded.
  - Horizontal direction computed from `player.global_position.x - global_position.x`.
  - Requires `player` reference (currently exported and set manually in the editor).
- Visuals:
  - `Sprite2D.flip_h` based on direction (left/right).
- Health:
  - `max_health` exported (currently 100); `current_health` initialised in `_ready`.
  - `take_damage(amount)`:
    - Reduces `current_health`.
    - Calls `flash_hit` for brief red flash feedback.
    - Calls `_update_health_bar()` to update the visual health bar.
    - Calls `die()` when health <= 0.
  - `die()` currently just `queue_free()`.
- Health Bar:
  - Child node `HealthBar` (TextureProgressBar) cached via `@onready var health_bar`.
  - `_update_health_bar()` function:
    - Sets `health_bar.max_value = max_health`.
    - Sets `health_bar.value = current_health`.
    - Called in `_ready()` to initialize and in `take_damage()` to update.
- Groups:
  - Enemy adds itself to `"enemy"` group for bullet detection.

---

## Player Movement System

### Current
- Horizontal movement:
  - Left/Right via input actions (`move_left`, `move_right`).
  - Speed controlled with exported constants in `player.gd`.
- Vertical:
  - Gravity applied when not on floor.
  - Jump via `Input.is_action_just_pressed("jump")` when `is_on_floor()`.
- Movement solved with `move_and_slide()`.

### Planned Extensions
- Dodge roll / ground roll.
- Air dash.
- Wall slide + wall jump.
- Ledge grab and climb.
- Bars / hooks for swinging.

---

## Camera System

- Camera scene: `Camera2D` in `Player.tscn`.
- Script: `camera_2d.gd`
- Features:
  - `start_shake(strength, duration)`:
    - Sets internal shake timers.
  - `_process`:
    - Applies random offset each frame, fading out over time.
    - Resets offset when shake ends.
- Trigger:
  - Weapon emits `fired` signal with shake values.
  - Player listens and calls `cam.start_shake(strength, duration)`.

---

## Audio System (Guns)

- Each gun scene has:
  - `GunAudio` (`AudioStreamPlayer2D`) with the correct pistol sound.
- WeaponBase:
  - Does not play `GunAudio` directly.
  - Instead, spawns a new `AudioStreamPlayer2D`:
    - Copies the stream from `GunAudio`.
    - Positions it at muzzle.
    - Randomises `pitch_scale` slightly.
    - Plays it, then auto-frees it on `finished`.
- Allows overlapping gunshots without cutting off previous sounds.

## Collision Setup

Layers:
1 – Player
2 – World
3 – PlayerBullets
4 – Enemies

Player:
- Layer: 1
- Mask: 2, 4

World (TileMap / ground):
- Layer: 2
- Mask: 1, 3, 4

Enemy:
- Layer: 4
- Mask: 2, 3

Bullet:
- Layer: 3
- Mask: 2, 4

