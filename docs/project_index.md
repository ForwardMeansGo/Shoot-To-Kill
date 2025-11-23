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
- **Continuous Collision Detection**
  - Prevents tunnelling at high speeds.
  - Tracks `previous_position` each frame.
  - Raycast from previous_position → target_pos:
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
### Movement
- Moves toward exported `player` reference.
- Applies gravity.
- Sprite flips depending on direction.

### Health
- `max_health` exported.
- `current_health` initialized in `_ready()`.
- `take_damage(amount, is_crit=false)`:
  - Reduces health.
  - Brief red flash (`flash_hit`).
  - Updates health bar.
  - Spawns damage number:
    - Passes `damage` + `is_crit`.

### Health Bar
- Child `TextureProgressBar`.
- Updated each hit.

### Damage Numbers
- Exported `damage_number_scene`.
- Instantiates on hit.
- Positioned slightly above enemy.
- Passes crit info for visuals.

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

## Scenes Overview
### Level_01.tscn
- World layout + enemies + player.

### Player.tscn
- Player root (CharacterBody2D)
- Weapon holder
- Gun
- Camera2D
- (Player HP bar not yet implemented)

### Gun.tscn
- Weapon scene with muzzle + audio.

### Bullet.tscn
- Bullet Area2D + CollisionShape2D.

### EnemyBasic.tscn
- Enemy root.
- Health bar.
- Sprite.
- Damage number spawn logic.

### DamageNumber.tscn
- Node2D + RichTextLabel for damage display.

---

## Known Limitations
- Player HP system not implemented yet.
- Enemy attack (contact or melee) not implemented yet.
- Pistol only — no other weapons yet.
- No reload, ammo, UI.
- Enemy pathfinding is simple horizontal chase.
- No knockback for player or enemies yet.

---

## How to Use This File with ChatGPT
To load this project into a new chat:
1. Paste `project_index.md` (this file).
2. Paste `file_structure.md`.
3. Paste `gameplay_systems.md`.
4. Paste specific scripts you want help with.
