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

### Aim Dot Smoothing
- Each weapon exposes `aim_dot_lerp_speed` (default 10.0).
- Controls how quickly the weighted aim dot catches up to the mouse.
- Higher values = snappier aiming (lighter weapons).
- Lower values = heavier aiming (heavier weapons).
- Player queries weapon via `get_aim_dot_lerp_speed()` method.

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

### Animation
- Animation logic consolidated in `_update_animation()` helper function.
- Called from `_physics_process()` after `move_and_slide()`.
- "run" animation plays when `abs(velocity.x) > 1.0` AND `is_on_floor()`.
- "idle" animation plays when not moving OR in the air.
- No animation logic in `_process()`.

### Aiming System
- **Weighted Aim Dot**: Player aims at `crosshair.get_dot_world_position()` instead of raw mouse.
- **Arm and Gun Aiming**:
  - Arm sprite (`$WeaponHolder/ArmSprite`) rotates independently toward aim point.
  - Gun positioned relative to arm using `hand_offset` rotated by arm rotation.
  - Per-facing offsets for weapon holder position and gun hand offset.
  - Arm visual flip helper prevents upside-down appearance when aiming across top.
- **Per-Facing Offsets**:
  - Weapon holder: `weapon_base_offset + Vector2(8, 0)` when facing left, `weapon_base_offset` when facing right.
  - Gun hand offset: `Vector2(8, 2)` when facing left, `Vector2(8, -2)` when facing right.
- **Crosshair Integration**:
  - Player references `$"../Crosshair"` node.
  - Gun and arm both aim at weighted dot position.
  - Shooting uses weighted dot position, not raw mouse.

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

### State Machine
Enemies use a state-based system with three states:
- **CHASE**: Enemy moves horizontally toward player at `move_speed`.
- **ATTACK**: Enemy stops horizontal movement and deals contact damage repeatedly.
- **DEAD**: Enemy is dead and all physics/movement is disabled.

### Movement
- Horizontal chasing toward Player in `CHASE` state.
- Stops horizontal movement in `ATTACK` state (prevents pushing through player).
- Uses gravity (except when `DEAD`).
- Sprite flipping based on direction.
- Dead enemies (`DEAD` state) skip all physics processing via early return in `_physics_process()`.

### Health
- `max_health` exported (default 100).
- `current_health` initialized in `_ready()`.
- `take_damage(amount, is_crit=false)`:
  - Returns early if enemy is already `DEAD`.
  - Applies white hit flash (`flash_hit()`).
  - Reduces health.
  - Updates enemy health bar.
  - Spawns damage number with crit info.
  - Calls `die()` when health <= 0.

### Hit Flash
- Shader-based flash system using `enemy_flash.gdshader`.
- **Shader Material**:
  - Each enemy gets a unique `ShaderMaterial` instance in `_ready()`.
  - Shader uses `flash_amount` uniform (0.0–1.0) to mix texture with pure white.
  - Ensures visible flash even on dark/black sprites.
- **Flash Behavior**:
  - `flash_hit()` sets `flash_amount` to `flash_intensity` (default 1.0).
  - Waits for `flash_duration` (default 0.09s).
  - Resets `flash_amount` to 0.0 (unless enemy is dead).
  - `is_flashing` flag prevents overlapping flashes.
- **Exports**:
  - `flash_duration`: float (default 0.09s)
  - `flash_intensity`: float 0.0–1.0 (default 1.0)

### Enemy Health Bar System
- **HealthBar** (TextureProgressBar): Direct child of Enemy node.
  - Updates instantly to `current_health`.
  - `max_value` set to `max_health`.
- **DamageBar** (TextureProgressBar): Direct child of Enemy node.
  - Lags behind health bar for visual feedback.
  - `max_value` set to `max_health + damage_bar_max_offset` (prevents edge clipping).
  - **Behavior**:
    - If `damage_bar.value < current_health` (healed): snaps up immediately.
    - If `damage_bar.value > current_health` (taking damage): smoothly tweens down.
  - Uses `damage_bar_tween` to animate value changes.
  - **Exports**:
    - `damage_bar_lag_duration`: float (default 0.2s)
    - `damage_bar_max_offset`: float (default 1.0)

### Damage Numbers
- Exported `damage_number_scene` (PackedScene).
- Spawned on each hit at `global_position + Vector2(15, -10)`.
- **Properties Passed**:
  - `damage`: int
  - `is_crit`: bool
  - `is_killing_blow`: bool (computed as `current_health <= 0` after damage)
  - `movement_dir_sign`: float (enemy movement direction: `sign(player.x - enemy.x)`)
- Added to current scene root.

### Contact Damage (State-Based)
- `contact_damage` exported (default 10).
- `contact_cooldown` exported (default 0.5s).
- `DamageArea` (Area2D) child node:
  - Collision mask includes Player layer (layer 2).
  - `body_entered` and `body_exited` signals connected in `_ready()`.
- `contact_timer` decremented in `_physics_process()`.
- **Contact damage is only applied while the enemy is in the ATTACK state.**
- **Once the enemy dies, they can no longer enter ATTACK or deal damage.**
- **State transitions**:
  - When player enters `DamageArea`: enemy enters `ATTACK` state.
  - When player exits `DamageArea`: enemy returns to `CHASE` state.
- **Repeated damage**:
  - While in `ATTACK` state and `contact_timer <= 0`:
    - Deals `contact_damage` to player.
    - Resets `contact_timer` to `contact_cooldown`.
  - This allows continuous damage while player remains in contact range.
- `_on_damage_area_body_entered(body)`:
  - Returns early if enemy is `DEAD`.
  - Handles parent/child node detection:
    - If collider isn't in `"player"` group but parent is, uses parent.
  - If target is in `"player"` group and has `take_damage` method:
    - Sets state to `ATTACK`.
- `_on_damage_area_body_exited(body)`:
  - Returns early if enemy is `DEAD`.
  - Handles parent/child node detection.
  - If player exits, sets state back to `CHASE`.

### Death System
- `die()` function:
  - Prevents multiple death calls (returns if already `DEAD`).
  - Sets state to `DEAD`.
  - Immediately calls `queue_free()` (temporary placeholder).
- **Physics Skip on Death**:
  - When an enemy enters the `DEAD` state, `_physics_process()` exits immediately via early return.
  - This disables all gravity, movement, sliding, and contact damage ticking without needing to modify collision layers or disable DamageArea.
- **Collision behaviour**:
  - Dead enemies do not interact with the player because the AI and physics code path is completely skipped while `DEAD`.
- Dead enemies cannot take damage or deal contact damage.

---

## Damage Number System

### Behaviour
On enemy hit:

1. DamageNumber instance created.
2. Positioned above enemy.
3. Displays damage text.
4. Color determined by hit type (priority: killing blow > crit > normal).
5. Moves along an arcing path with dynamic distance.
6. Rotation applied conditionally based on arc vs. movement direction.
7. Fades out.
8. Deletes itself.

### Color System
- **Normal hits**: `normal_color` (default: white).
- **Crit hits**: `crit_color` (default: yellow `Color(1.0, 1.0, 0.2)`).
- **Killing blows**: `kill_color` (default: red `Color(0.672, 0.101, 0.0, 1.0)`).
- Priority: killing blow > crit > normal.
- Crit and killing blows use 1.5x scale.

### Motion (parametric)
- Internal `t` parameter animated from 0.0 → 0.6 over lifetime (only first ~60% of arc is shown).
- Horizontal:
  - `x = start_x + direction_sign * arc_distance * t`
- Vertical:
  - `y = start_y - float_distance * sin(t * PI)`
- Produces a smooth "pop-out + rise" arc.

### Arc Direction System
- **Normal hits**: Random left/right (`direction_sign = ±1.0`).
- **Crit/Killing blows**: Arc opposite to enemy movement direction.
  - If `movement_dir_sign > 0` (enemy moving right): `direction_sign = -1.0` (arc left).
  - If `movement_dir_sign < 0` (enemy moving left): `direction_sign = 1.0` (arc right).
  - Fallback to random if movement direction unknown.

### Dynamic Arc Distance
- Base `arc_distance` (default 10.0, user set).
- **Arc Boost Factor**: `arc_boost_factor` (default 1.4, user set to 5.0).
- **Logic**:
  - If arc goes WITH enemy movement (`sign(arc_dir) == sign(move_dir)`):
    - `arc_distance *= arc_boost_factor` (compensates for enemy running away).
  - If arc goes OPPOSITE enemy movement:
    - `arc_distance` remains unchanged.
- Prevents visual size discrepancy when enemy moves.

### Rotation System
- **Rotation Range**: `min_rot_deg` to `max_rot_deg` (default 10°–30°).
- **Conditional Application**:
  - Rotation ONLY applied when arc direction is OPPOSITE to enemy movement.
  - If arc goes SAME direction as movement: `rotation_degrees = 0.0`.
- **Rotation Direction**:
  - Enemy moving LEFT, arc RIGHT: positive rotation.
  - Enemy moving RIGHT, arc LEFT: negative rotation.
- Prevents rotation when arc and movement align.

### Fade
- Alpha fades from 1 → 0 over lifetime.
- `queue_free()` when done.

---

## Crosshair System

### Architecture
- Separate `Crosshair.tscn` scene (Node2D root).
- Two child sprites: `Outer` (Sprite2D) and `Dot` (Sprite2D).
- `crosshair.gd` script manages both sprites independently.

### Outer Crosshair
- Follows mouse instantly in world space.
- `outer_sprite.global_position = mouse_world` each frame.
- Represents raw player input.

### Weighted Aim Dot
- Smoothly lags behind mouse using screen-space lerp.
- **Screen-Space Smoothing**:
  - Lerp performed in screen coordinates (`get_viewport().get_mouse_position()`).
  - Prevents lag from player movement (only lags behind mouse movement).
  - Smoothed screen position converted back to world space using canvas transform.
- **Per-Weapon Smoothing**:
  - Each weapon exposes `aim_dot_lerp_speed` (default 10.0).
  - Player provides `get_current_dot_lerp_speed()` helper.
  - Crosshair queries player for current weapon's speed.
  - Heavier weapons (RPG, LMG) use lower values (5–7).
  - Lighter weapons (pistol, SMG) use higher values (12–18).
- **World Position**:
  - `get_dot_world_position()` returns dot's current world position.
  - Player aims gun and arm at this position.
  - Bullets fire toward this position (not raw mouse).

### Screen-to-World Conversion
- Uses `get_viewport().get_canvas_transform().affine_inverse() * dot_screen_pos`.
- Correct Godot 4 method for converting screen coordinates to world space.

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
