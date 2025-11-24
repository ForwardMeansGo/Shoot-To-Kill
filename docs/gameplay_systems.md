# Gameplay Systems — Shoot To Kill (Updated)

## Weapons System

### Core Architecture
Weapons live under `scripts/weapons/`.
- Base class: `weapon_base.gd`, `class_name WeaponBase`.
- Specific weapons (pistol, etc.) extend WeaponBase.

### Aiming + Orientation
- `aim_at(mouse_pos)` rotates weapon towards mouse.
- `set_facing_left(is_left)` flips weapon sprite via vertical flip.
- Player handles facing logic.

### Damage System
- Generic damage + crit logic lives in WeaponBase.
- Exports:
  - `base_damage_min` (float)
  - `base_damage_max` (float)
  - `crit_chance` (float)
  - `crit_multiplier` (float)
- `_roll_damage()`:
  - Random damage between min/max.
  - Crit roll using `crit_chance`.
  - Crit multiplies damage by `crit_multiplier`.
  - Returns `{ "damage": int, "is_crit": bool }`.

### Bullet Spawning
- `spawn_bullet(target_global_pos)`:
  - Gets `dmg_info` from `_roll_damage()`.
  - Instantiates bullet.
  - Sets:
    - `bullet.direction`
    - `bullet.rotation`
    - `bullet.damage = dmg_info.damage`
    - `bullet.is_crit = dmg_info.is_crit`
  - Positions at `Muzzle`.
  - One-shot sound plays with slight pitch randomization.
  - Emits `fired` signal for camera shake.

---

## Bullet System

### Continuous Collision Detection
Bullets use raycasting each frame to avoid tunneling.
- Track `previous_position`.
- Compute `target_pos`.
- Raycast from `previous_position → target_pos + margin`.
- Use `hit_from_inside = true` to catch inside collider cases.
- If a hit:
  - Move to exact hit position.
  - Call `_handle_hit`.
  - Free bullet.
- If no hit:
  - Move normally.
  - Update `previous_position`.

### Damage Pass-through
- Bullet carries:
  - `damage`
  - `is_crit`
- `_handle_hit`:
  - Ignores `"player"`.
  - If in `"enemy"` group → call:
    - `enemy.take_damage(damage, is_crit)`.

### Lifetime
- Bullet counts down lifetime.
- Frees itself when low.

---

## Player System

### Movement
- Uses `CharacterBody2D` with `move_and_slide()`.
- Horizontal movement via input actions.
- Jump and gravity system.

### Health
- `max_health` exported (default 100).
- `current_health` initialized in `_ready()`.
- `invulnerability_time` exported (default 0.5s).
- `invuln_timer` decremented in `_process()`.
- `take_damage(amount)`:
  - Returns early if invulnerable.
  - Reduces health (clamped to 0).
  - Sets invulnerability timer.
  - Emits `health_changed` signal.
  - Calls `die()` if health <= 0.
- `die()`:
  - Emits `died` signal.
  - Reloads current scene.

### Signals
- `health_changed(current_health, max_health)` - emitted on health change.
- `died` - emitted when player dies.

---

## HUD System

### Architecture
- Separate `HUD.tscn` scene (CanvasLayer).
- `hud.gd` script listens to Player signals.
- No direct UI references in Player script.

### Health Bar
- `PlayerHealthBar` (TextureProgressBar) child of HUD.
- Finds Player node via `player_path` export or as sibling.
- Connects to Player's `health_changed` signal in `_ready()`.
- Initializes from Player's current health values.
- The HUD displays health using raw HP values (0 → max_health) with a smooth tween animation. No percentage conversion is used.
- Smooth tweening:
  - Uses `hp_tween` to animate health bar value.
  - 0.15s duration with `TRANS_SINE` and `EASE_OUT`.
  - Kills existing tween before creating new one.
- **Texture Requirements:**
  - Progress texture must only contain the fill bar, with no heart or frame. Background holds all decorative art. Use Progress Offset to align the fill.

---

## Enemy System

### Movement
- Horizontal chasing toward Player.
- Uses gravity.
- Sprite flipping based on direction.

### Health
- `max_health` exported.
- `current_health` initialized in `_ready()`.
- `take_damage(amount, is_crit=false)`:
  - Applies hit flash.
  - Reduces health.
  - Updates enemy health bar.
  - Spawns damage number.
  - Dies when <= 0.

### Enemy Health Bar
- Child TextureProgressBar.
- `_update_health_bar()` sets value/max_value.

### Damage Numbers
- Exported `damage_number_scene`.
- Spawned on each hit.
- Receives `damage` + `is_crit`.

### Contact Damage
- `contact_damage` exported (default 10).
- `contact_cooldown` exported (default 0.5s).
- `DamageArea` (Area2D) child node:
  - Collision mask includes Player layer (layer 2).
  - `body_entered` signal connected in `_ready()`.
- `contact_timer` decremented in `_physics_process()`.
- `_on_damage_area_body_entered(body)`:
  - Checks contact cooldown (returns if active).
  - Handles parent/child node detection:
    - If collider isn't in `"player"` group but parent is, uses parent.
  - If target is in `"player"` group and has `take_damage` method:
    - Calls `target.take_damage(contact_damage)`.
    - Sets `contact_timer = contact_cooldown`.

---

## Damage Number System

### Behaviour
On enemy hit:

1. DamageNumber instance created.
2. Positioned above enemy.
3. Displays damage text.
4. If crit:
   - Yellow color
   - Increased scale
5. Moves along an arcing path.
6. Fades out.
7. Deletes itself.

### Motion (parametric)
- Internal `t` parameter animated from 0.0 → 0.6 over lifetime (only first ~60% of arc is shown).
- Horizontal:
  - `x = start_x + direction_sign * arc_distance * t`
- Vertical:
  - `y = start_y - float_distance * sin(t * PI)`
- Produces a smooth "pop-out + rise" arc.
- Random left/right arc per number.

### Fade
- Alpha fades from 1 → 0 over lifetime.
- `queue_free()` when done.

---

## Camera System

### Shake
- Camera2D script receives shake strength/duration.
- Applies random jitter until fade-out.
- Triggered via `weapon.fired` signal.

---

## Audio System

### Gunshot System
- Each weapon has a template `GunAudio` node.
- WeaponBase duplicates and spawns a one-shot audio player:
  - Copies stream.
  - Applies pitch variance.
  - Plays + frees itself.

---

## Collision System (Layers)
- **1 – world**
- **2 – player**
- **3 – enemy**
- **4 – bullet**

**Player**
- Layer: 2  
- Masks: 1, 3  

**World**
- Layer: 1  
- Masks: 2, 3, 4  

**Enemy**
- Layer: 3  
- Masks: 1, 2, 4  

**Bullet**
- Layer: 4  
- Masks: 1, 3  

---
