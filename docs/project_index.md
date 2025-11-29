# Shoot To Kill — Project Index (Updated)

## High-Level Summary
2D side-scrolling shooter built in Godot 4.

Core gameplay pillars:
- Clean & responsive movement
- Modular weapon system
- Reliable bullets with continuous collision detection
- Damage ranges + crit system
- Floating damage numbers with smooth arcing motion
- Enemies with full health logic and damage feedback
- Camera shake + gun audio

Current dev focus: **Combat polish + enemy interactions**

---

## Player
### Movement
- Horizontal left/right movement.
- Jumping.
- Gravity system.
- Uses `move_and_slide`.

### Gun Aiming & Facing
- Gun rotates using `look_at(mouse_pos)`.
- Weapon flips vertically using `set_facing_left()`.
- Player sprite flips horizontally using sprite scale.
- Weapon holder position shifts left/right depending on mouse direction.

### Shooting
- Driven from `player.gd`.
- Pistol fires with `Input.is_action_just_pressed("shoot")`.
- Semi-auto: 1 bullet per click.
- Calls `gun.try_shoot(mouse_pos)`.

### Camera
- `Camera2D` with shake system.
- Weapon emits a `fired` signal → Player forwards to camera.

### Health System
- `max_health` exported (default 100).
- `current_health` initialized in `_ready()`.
- `invulnerability_time` exported (default 0.5s).
- `take_damage(amount)`:
  - Checks invulnerability timer (ignores damage if active).
  - Reduces health (clamped to 0 minimum).
  - Sets invulnerability timer.
  - Emits `health_changed(current_health, max_health)` signal.
  - Calls `die()` if health <= 0.
- `die()`:
  - Emits `died` signal.
  - Reloads current scene.
- Signals:
  - `health_changed(current_health, max_health)` - emitted when health changes.
  - `died` - emitted when player dies.

---

## Weapons (Modular System)
### WeaponBase (`weapon_base.gd`)
- **Exports**
  - `base_damage_min` / `base_damage_max`
  - `crit_chance`
  - `crit_multiplier`
  - `shake_strength`, `shake_duration`
  - `bullet_scene`
- **Handles**
  - Aiming + flipping
  - Damage rolling:
    - Random damage in `[base_damage_min, base_damage_max]`
    - Crit roll (`randf() < crit_chance`)
    - Crit damage multiplied by `crit_multiplier`
  - Spawning bullets (`Bullet.tscn`)
  - Passing damage + crit info to bullets
  - Emitting `fired` signal for camera shake
  - Playing one-shot gun audio with random pitch

### Pistol
- Extends WeaponBase.
- No cooldown — fires every click.
- Default damage: **8–12**, with crit chance (default 10%).

---

## Bullet System (`bullet.gd`)
- **Continuous Collision Detection (CCD)**
  - Prevents tunnelling at high speeds.
  - Tracks `previous_position` each frame.
  - Raycast from `previous_position` → `target_pos`:
    - Includes safety margin.
    - Uses `hit_from_inside = true`.
  - If ray hits:
    - Bullet moves to exact hit point.
    - Calls `_handle_hit(collider)`.
    - Frees itself.

- **Damage & Crit**
  - Weapon sets:
    - `bullet.damage = dmg_value`
    - `bullet.is_crit = is_crit`
  - `_handle_hit` passes both to enemy:
    - `enemy.take_damage(damage, is_crit)`

- **Lifetime**
  - Bullet has a countdown.
  - Frees itself when finished.

---

## Enemy System (`enemy.gd`)
### State Machine
- Three states: `CHASE`, `ATTACK`, `DEAD`.
- `CHASE`: Moves horizontally toward player.
- `ATTACK`: Stops movement, deals repeated contact damage.
- `DEAD`: All physics disabled, enemy removed.

### Movement
- Moves toward exported `player` reference in `CHASE` state.
- Stops horizontal movement in `ATTACK` state.
- Applies gravity (except when `DEAD`).
- Sprite flips depending on direction.
- Dead enemies skip all physics via early return.

### Health
- `max_health` exported (default 100).
- `current_health` initialized in `_ready()`.
- `take_damage(amount, is_crit=false)`:
  - Returns early if already `DEAD`.
  - Reduces health.
  - Applies white hit flash (`flash_hit()`).
  - Updates health bar.
  - Spawns damage number with `damage` + `is_crit`.

### Hit Flash
- `flash_hit()`: Bright white flash (`Color(2.0, 2.0, 2.0)`) for 0.05s.

### Health Bar
- Child `TextureProgressBar`.
- Updated each hit via `_update_health_bar()`.

### Damage Numbers
- Exported `damage_number_scene`.
- Instantiates on hit at `global_position + Vector2(15, -10)`.
- Passes crit info for visuals.

### Contact Damage (State-Based)
- `contact_damage` exported (default 10).
- `contact_cooldown` exported (default 0.5s).
- `DamageArea` (Area2D) child node:
  - Collision mask includes Player layer.
  - `body_entered` and `body_exited` signals connected in `_ready()`.
- **Contact damage is only applied while the enemy is in the ATTACK state.**
- **Once the enemy dies, they can no longer enter ATTACK or deal damage.**
- **State transitions**:
  - Player enters `DamageArea` → state becomes `ATTACK`.
  - Player exits `DamageArea` → state returns to `CHASE`.
- **Repeated damage**:
  - While in `ATTACK` state, deals `contact_damage` every `contact_cooldown` seconds.
  - Enemy stops horizontal movement to prevent pushing through player.
- `_on_damage_area_body_entered(body)`:
  - Returns early if `DEAD`.
  - Handles parent/child node detection.
  - Sets state to `ATTACK` if player detected.
- `_on_damage_area_body_exited(body)`:
  - Returns early if `DEAD`.
  - Sets state back to `CHASE` if player exits.

### Death System
- `die()` function:
  - Prevents multiple calls (checks `DEAD` state).
  - Sets state to `DEAD`.
  - Immediately calls `queue_free()` (temporary placeholder).
- **Physics Skip on Death**:
  - When an enemy enters the `DEAD` state, `_physics_process()` exits immediately via early return.
  - This disables all gravity, movement, sliding, and contact damage ticking without needing to modify collision layers or disable DamageArea.
- **Collision behaviour**:
  - Dead enemies do not interact with the player because the AI and physics code path is completely skipped while `DEAD`.
- Dead enemies cannot take damage or deal contact damage.

### Group
- Enemy registers in `"enemy"` group.

---

## Damage Number System (`damage_number.gd`)
- Shows floating numbers above enemy.
- **Exports**
  - `damage` (int)
  - `is_crit` (bool)
  - `lifetime` (~0.3)
  - `float_distance`, `arc_distance`
- **Visual**
  - Normal: white, default size.
  - Crit:
    - larger (1.2x)
    - yellow (1.0, 0.9, 0.2)
- **Motion**
  - Parametric arc:
    - `t` animates from 0 → 0.6
    - Horizontal drift based on arc_distance.
    - Vertical curve using `sin(t * PI)`.
  - Random left or right arc.
  - Alpha fades to 0.
- Auto frees when tween ends.

---

## HUD System (`hud.gd`)
- Separate CanvasLayer scene (`HUD.tscn`).
- The HUD is separated from the Player and loaded into the level as its own scene. It listens to the Player via signals and does not live inside the Player.tscn hierarchy.
- Listens to Player's `health_changed` signal.
- **Player Health Bar**
  - `PlayerHealthBar` (TextureProgressBar) child node.
  - Finds Player via `player_path` export or as sibling.
  - Connects to `health_changed` signal in `_ready()`.
  - Initializes from Player's current health values.
  - Smooth tweening:
    - Uses `hp_tween` to animate value changes.
    - 0.15s duration with `TRANS_SINE` and `EASE_OUT`.
    - Kills existing tween before creating new one.
- **Texture Requirements (Player Health Bar):**
  - Background texture contains the heart, frame, and bar track.
  - Progress texture must be tightly cropped so it includes ONLY the fill bar (no heart, no frame, no large padding).
  - Align the fill using the TextureProgressBar "Progress → Offset" property.
  - This fixes the issue where the bar appeared empty at 40 HP.

---

## Scenes Overview
### Level_01.tscn
- World layout + enemies + player.

### Player.tscn
- Player root (CharacterBody2D, script: `player.gd`, in group `"player"`)
- Weapon holder
- Gun
- Camera2D
- No UI nodes (HUD is separate)

### HUD.tscn
- HUD root (CanvasLayer, script: `hud.gd`)
- PlayerHealthBar (TextureProgressBar)
- Listens to Player's `health_changed` signal
- Updates health bar with smooth tweening

### Gun.tscn
- Weapon scene with muzzle + audio.

### Bullet.tscn
- Bullet Area2D + CollisionShape2D.

### EnemyBasic.tscn
- Enemy root (CharacterBody2D, script: `enemy.gd`)
- Health bar (TextureProgressBar)
- Sprite
- DamageArea (Area2D) for contact damage
- Damage number spawn logic

### DamageNumber.tscn
- Node2D + RichTextLabel for damage display.

---

## Key Files
### Scenes
- `game/scenes/Player.tscn` - Player character scene
- `game/scenes/HUD.tscn` - HUD UI scene (CanvasLayer)
- `game/scenes/Level_01.tscn` - Main level scene
- `game/scenes/Gun.tscn` - Weapon scene
- `game/scenes/Bullet.tscn` - Bullet scene
- `game/scenes/EnemyBasic.tscn` - Enemy scene
- `game/scenes/DamageNumber.tscn` - Damage number display scene

### Scripts
- `game/scripts/player.gd` - Player movement, health, shooting
- `game/scripts/hud.gd` - HUD health bar management
- `game/scripts/camera_2d.gd` - Camera shake system
- `game/scripts/damage_number.gd` - Floating damage number animation
- `game/scripts/enemies/enemy.gd` - Enemy AI, health, contact damage
- `game/scripts/weapons/weapon_base.gd` - Base weapon class with damage/crit system
- `game/scripts/weapons/weapon_pistol.gd` - Pistol weapon implementation
- `game/scripts/weapons/bullet.gd` - Bullet movement and collision

---

## Known Limitations
- Pistol only — no other weapons yet.
- No reload, ammo UI.
- Enemy pathfinding is simple horizontal chase.
- No knockback for player or enemies yet.
- Player invulnerability visual feedback not yet implemented.

---

## How to Use This File with ChatGPT
To load this project into a new chat:
1. Paste `project_index.md` (this file).
2. Paste `file_structure.md`.
3. Paste `gameplay_systems.md`.
4. Paste specific scripts you want help with.
