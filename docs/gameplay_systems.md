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
- **Ground Movement**:
  - "run" animation plays when `abs(velocity.x) > 1.0` AND `is_on_floor()`.
  - "run_backwards" animation plays when moving opposite to facing direction.
  - "idle" animation plays when not moving on ground.
- **Air Movement**:
  - "jump" animation plays while ascending (`velocity.y < 0.0`).
  - "fall" animation plays while descending (`velocity.y >= 0.0`).
- **Landing**:
  - "land" animation plays once when transitioning from air to floor.
  - Landing state tracked with `was_on_floor` and `is_landing` flags.
  - Landing animation must finish before returning to normal animation logic.
- No animation logic in `_process()`.

### Aiming System
- **Weighted Aim Dot**: Player aims at `crosshair.get_dot_world_position()` instead of raw mouse.
- **Arm and Gun Aiming**:
  - Arm sprite (`$WeaponHolder/WeaponBobOffset/ArmSprite`) rotates independently toward aim point.
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
- **Mouse Cursor Replacement**:
  - OS mouse cursor is hidden in `_ready()` using `Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)`.
  - Crosshair root node follows mouse position each frame: `crosshair.global_position = mouse_pos`.
  - Crosshair visually replaces the system cursor for better game immersion.

### Weapon Bob System
- **Per-Animation Bob Arrays**: Frame-by-frame vertical offsets stored in arrays:
  - `weapon_bob_idle`: [0.0, 1.0, 1.0, 0.0]
  - `weapon_bob_run`: [0.0, 0.0, -2.0, 0.0, 0.0, -1.0]
  - `weapon_bob_run_backwards`: [-1.0, 0.0, 0.0, -2.0, 0.0, 0.0]
  - `weapon_bob_jump`: [0.0, -1.0, -2.0, -1.0]
- **Bob Application**:
  - `_get_weapon_bob_for_current_frame()` retrieves offset based on current animation and frame.
  - `_update_weapon_bob()` applies bob to `WeaponBobOffset` node position each frame.
  - Bob values are local to `WeaponHolder` (Y-axis only).

### Visual Weapon Kickback System
- **Purely Cosmetic**: Kickback does not affect aim, recoil, crosshair, or animation behavior.
- **Kickback Variables**:
  - `kick_offset: Vector2` - Current kickback offset (starts at ZERO).
  - `@export var kick_strength: float = 4.0` - How far the weapon moves back on firing.
  - `@export var kick_return_speed: float = 20.0` - How quickly kickback returns to zero.
- **Kickback Application**:
  - On firing: Calculates shot direction from aim origin to aim point.
  - Applies kickback impulse: `kick_offset = shot_dir * -kick_strength` (opposite to shot direction).
  - `_update_kickback(delta)` smoothly lerps `kick_offset` back to `Vector2.ZERO` each frame.
  - `_update_weapon_bob()` combines base bob position with `kick_offset` for final position.
- **Layered Effect**: Kickback is added on top of weapon bob, creating a combined visual effect.

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
  - Calls `GameManager.on_player_died()` to handle scene transition.
  - Does NOT reload scene directly (GameManager handles transitions).

### Gold Currency System
- Gold is managed by `GameManager` singleton (not stored in player).
- `add_gold(amount)`:
  - Forwards gold to `GameManager.add_gold_run(amount)`.
  - All gold is tracked centrally in GameManager.
- Player is added to `"player"` group in `_ready()` for coin pickup detection.

### Signals
- `health_changed(current_health, max_health)` - emitted on health change.
- `died` - emitted when player dies.
- `gold_changed(current_gold)` - legacy signal (kept for backward compatibility).

---

## GameManager System

### Architecture
- **Autoload Singleton**: Configured as AutoLoad in Project Settings (name: `GameManager`).
- Centralized management for currency, XP/level, and scene transitions.

### Currency Management
- **Run Gold** (`gold_run: float`):
  - Currently permanent (no reset on death).
  - `add_gold_run(amount)`: Adds gold and emits `gold_run_changed` signal.
  - `spend_gold_run(amount)`: Attempts to spend gold, returns success/failure.
  - `reset_run_state()`: Resets run-only data (currently unused).
- **Essence** (`essence_total: int`):
  - Permanent currency kept between runs.
  - `add_essence(amount)`: Adds essence and emits `essence_changed` signal.
  - `spend_essence(amount)`: Attempts to spend essence, returns success/failure.

### XP/Level System
- **Variables**:
  - `xp: int`: Current XP amount.
  - `level: int`: Current player level (starts at 1).
  - `base_xp_to_level` (export, default 100): Base XP required for first level.
  - `xp_growth_factor` (export, default 1.4): Exponential growth multiplier.
- **Level Calculation**:
  - `get_xp_required_for_next_level()`: Calculates XP needed using exponential growth.
  - Formula: `base_xp_to_level * pow(xp_growth_factor, level - 1)`
  - Example progression: 100, 140, 196, 274, ...
- **XP Addition**:
  - `add_xp(amount)`: Adds XP and automatically handles level-ups.
  - If XP exceeds required amount, level increases and excess XP is kept.
  - Can level up multiple times in one call if enough XP is added.
  - Emits `xp_changed(current_xp, current_level)` signal.
  - Prints "LEVEL UP!" message when level increases.

### Scene Management
- **Scene Paths**:
  - `TAVERN_SCENE_PATH`: `"res://Scenes/Tavern.tscn"`
  - `RUN_SCENE_PATH`: `"res://Scenes/level_01.tscn"`
- **Methods**:
  - `go_to_tavern()`: Loads and transitions to Tavern scene.
  - `start_new_run()`: Loads and transitions to run scene (starts new run).
  - `on_player_died()`: Called on player death, transitions to Tavern.

### Signals
- `gold_run_changed(current_gold: float)` - emitted when run gold changes.
- `essence_changed(current_essence: int)` - emitted when essence changes.
- `xp_changed(current_xp: int, current_level: int)` - emitted when XP or level changes.

---

## HUD System

### Architecture
- Separate `HUD.tscn` scene (CanvasLayer).
- `hud.gd` script listens to Player signals and GameManager signals.
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

### Currency Panel
- `CurrencyPanel` (HBoxContainer) with three display boxes:
  - **GoldBox/GoldLabel**: Displays run gold from GameManager.
    - Shows value with 1 decimal place precision (using `snapped()`).
    - Updates via `_on_gold_run_changed(current_gold)` handler.
  - **EssenceBox/EssenceLabel**: Displays permanent essence from GameManager.
    - Shows integer value.
    - Updates via `_on_essence_changed(current_essence)` handler.
  - **XPBox/XPLabel**: Displays level and XP.
    - Format: `"Lv %d  XP %d" % [current_level, current_xp]`
    - Updates via `_on_xp_changed(current_xp, current_level)` handler.
- **Signal Connections**:
  - Connects to GameManager signals in `_ready()`:
    - `GameManager.gold_run_changed` → `_on_gold_run_changed()`
    - `GameManager.essence_changed` → `_on_essence_changed()`
    - `GameManager.xp_changed` → `_on_xp_changed()`
  - Initializes all labels from current GameManager state after connecting signals.

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
  - Calls `_drop_loot()` to spawn coins.
  - Awards XP via `GameManager.add_xp(xp_reward)` if `xp_reward > 0`.
  - Immediately calls `queue_free()`.
- **XP Reward**:
  - `xp_reward` exported (default 10): XP granted when enemy dies.
  - XP is added directly to GameManager, triggering level-ups automatically.
  - HUD updates automatically via GameManager's `xp_changed` signal.
- **Physics Skip on Death**:
  - When an enemy enters the `DEAD` state, `_physics_process()` exits immediately via early return.
  - This disables all gravity, movement, sliding, and contact damage ticking without needing to modify collision layers or disable DamageArea.
- **Collision behaviour**:
  - Dead enemies do not interact with the player because the AI and physics code path is completely skipped while `DEAD`.
- Dead enemies cannot take damage or deal contact damage.

### Loot Drop System
- `_drop_loot()` function:
  - Spawns coins when enemy dies.
  - Exported `silver_coin_scene` and `gold_coin_scene` (PackedScene).
  - Exported `silver_drop_chance` (default 0.5) and `gold_drop_chance` (default 0.25).
  - Each coin type has independent drop chance (can drop both, one, or neither).
  - Coins spawn at enemy's `global_position` when dropped.

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
- **Mouse Cursor Replacement**: OS mouse cursor is hidden; crosshair root follows mouse to replace system cursor.

### Outer Crosshair
- Follows mouse instantly in world space.
- `outer_sprite.global_position = mouse_world` each frame.
- Represents raw player input.

### Outer Crosshair Pulse Effect
- **Trigger**: Driven by weapon's `fired(strength, duration)` signal (not raw input).
- **Behavior**: Outer crosshair briefly scales up when weapon fires, then smoothly returns to normal size.
- **Implementation**:
  - `on_weapon_fired(strength, duration)` method called by weapon signal.
  - Stores base scale in `_ready()` as `outer_base_scale`.
  - Instantly scales to `outer_base_scale * outer_pulse_scale` on fire.
  - Tweens back to `outer_base_scale` over `outer_pulse_duration`.
- **Exports**:
  - `outer_pulse_scale`: float (default 1.25) - how much larger the crosshair grows.
  - `outer_pulse_duration`: float (default 0.08s) - how long the return animation takes.
- **Tween Settings**: Uses `TRANS_SINE` and `EASE_OUT` for smooth return.
- **Signal Connection**: Player connects weapon's `fired` signal to `crosshair.on_weapon_fired()` in addition to camera shake.

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

## Coin System

### Architecture
- Lightweight pickup system using `Area2D` (no physics simulation).
- Scene structure: Root `Area2D` with `AnimatedSprite2D`, `CollisionShape2D`, and optional `AudioStreamPlayer2D`.
- Two coin types: Silver and Gold (separate scenes with different values).

### Arc Motion Animation
- **Spawn Behavior**: Coins animate along a parametric arc from spawn to landing position.
- **Arc Parameters**:
  - Random horizontal direction (left/right) and distance.
  - Random vertical drop distance.
  - Sine-based arc height for smooth curve.
- **Animation**:
  - Tween-based animation over `travel_time` (default 0.4s).
  - Parametric `_t` value animates from 0.0 to 1.0.
  - Horizontal: linear interpolation from start to end.
  - Vertical: combines linear drop with sine-based arc (`-sin(_t * PI) * arc_height`).
- **Exports**:
  - `travel_time`: float (default 0.4s) - time for full arc animation.
  - `min_horizontal_distance`: float (default 20.0)
  - `max_horizontal_distance`: float (default 40.0)
  - `min_vertical_drop`: float (default 8.0)
  - `max_vertical_drop`: float (default 16.0)
  - `arc_height`: float (default 25.0) - peak height of the arc.

### Idle Bobbing
- **After Landing**: Once arc completes, coins bob up and down in place.
- **Implementation**: Uses sine wave with `_bob_time` accumulator.
- **Exports**:
  - `bob_height`: float (default 2.0) - vertical bobbing distance.
  - `bob_speed`: float (default 4.0) - bobbing animation speed.

### Player Detection
- Uses `Area2D.body_entered` signal to detect player overlap.
- **Parent/Child Handling**: Mirrors enemy contact damage pattern.
  - If collider isn't in `"player"` group but parent is, uses parent.
- **Pickup Behavior**:
  - Calls `player.add_gold(value)` when collected.
  - Player forwards gold to `GameManager.add_gold_run()`.
  - Disables collision shape using `set_deferred("disabled", true)` to avoid physics errors.
  - Hides sprite instantly for immediate visual feedback.
  - Plays optional pickup sound, then frees after audio finishes.

### Performance
- Lightweight design: no RigidBody2D physics, only position updates in `_process()`.
- Efficient for many coins on screen simultaneously.

## Tavern System

### Architecture
- Hub scene where player returns after death.
- Contains interaction areas for Bartender and RunDoor.
- Uses "interact" input action (mapped to E key).

### Bartender (`tavern_bartender.gd`)
- **Node Structure**:
  - Root: `Node2D`
  - `InteractionArea` (Area2D): Detects player proximity.
  - `PromptLabel` (Label): Shows/hides interaction prompt.
- **Behavior**:
  - Shows prompt when player enters interaction area.
  - Hides prompt when player exits.
  - Emits `interacted(player)` signal when player presses "interact".
  - Generic implementation (no shop logic yet).

### RunDoor (`tavern_run_door.gd`)
- **Node Structure**:
  - Root: `Node2D`
  - `InteractionArea` (Area2D): Detects player proximity.
  - `PromptLabel` (Label): Shows/hides interaction prompt.
- **Behavior**:
  - Shows prompt when player enters interaction area.
  - Hides prompt when player exits.
  - Emits `door_used(player)` signal when player presses "interact".
  - RunDoor Calls `GameManager.start_new_run()` to load run scene.

### Interaction Pattern
- Both scripts use the same pattern:
  - `_on_area_body_entered()`: Detects player, shows prompt, stores player reference.
  - `_on_area_body_exited()`: Detects player exit, hides prompt, clears reference.
  - `_process()`: Checks for "interact" input when player in range.
  - Handles parent/child node relationships (same pattern as coins/enemies).

---

## Collision System (Layers)
- **1 – world**
- **2 – player**
- **3 – enemy**
- **4 – bullet**
- **7 – Interaction**

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
