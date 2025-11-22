# Shoot To Kill — Project Index

## High-Level Summary

2D side-scrolling shooter built in Godot 4.

Core ideas:
- Advanced movement (later: roll, dash, mantling, etc.)
- Gun-focused combat with different weapon types
- Modular, reusable scenes (Player, Weapon, Bullet, Enemy)
- Coop planned for the future, but not implemented yet.

Current dev focus: **core combat loop** – player, gun, bullets, killable enemies, juice (camera shake, sound).

---

## Implemented Features (Gameplay)

### Player
- Movement:
  - Left / right movement
  - Jump
  - Gravity
- Gun aiming:
  - Gun rotates to face mouse using `look_at`
  - Gun flips correctly when aiming left vs right
  - Gun holder moves to left/right side of player sprite so it looks like the character turned around
- Shooting:
  - Pistol fires **once per mouse click** (semi-auto only)
  - No rate limit beyond how fast you can click
- Camera:
  - `Camera2D` with `camera_2d.gd` script
  - Camera shake triggered by weapon via signal

### Weapons (Modular System)
- All weapons live under `scripts/weapons/`
- **WeaponBase (`weapon_base.gd`):**
  - Exports:
    - `bullet_scene` (defaults to Bullet.tscn)
    - `shake_strength`, `shake_duration`
  - Handles:
    - Flipping weapon sprite vertically when facing left (`set_facing_left`)
    - Aiming at mouse (`aim_at`)
    - Spawning bullets at the `Muzzle` position (`spawn_bullet`)
    - Playing gunshot sound using a one-shot `AudioStreamPlayer2D`
    - Emitting `fired(shake_strength, shake_duration)` signal on each shot
- **Pistol (`weapon_pistol.gd`):**
  - Extends WeaponBase
  - `try_shoot(target_pos)` calls `spawn_bullet(target_pos)` directly
  - No fire-rate or cooldown – fully semi-auto, driven by `Input.is_action_just_pressed("shoot")` in `player.gd`

### Bullets
- Scene: `Bullet.tscn`
- Script: `bullet.gd` (located in `scripts/weapons/bullet.gd`)
- Behaviour:
  - Uses raycast-based movement each physics frame to avoid visible clipping through ground/enemies
  - Moves from `from` → `to` and checks `intersect_ray`
  - On hit:
    - Moves to exact hit position
    - Damages enemies in `"enemy"` group (if they have `take_damage`)
    - `queue_free` after hit
  - Has `speed`, `direction`, `lifetime`, `damage` (currently 10 damage per bullet)
  - Auto-despawns when `lifetime` reaches 0

### Enemies
- Scene: `EnemyBasic.tscn` (or `enemy.tscn`)
- Script: `enemy.gd` (located in `scripts/enemies/enemy.gd`)
- Behaviour:
  - `CharacterBody2D` with gravity
  - Moves horizontally towards the **assigned** `player` export (currently set manually in the editor)
  - Uses `move_speed` (currently 45.0)
  - Flips `Sprite2D` based on movement direction
- Health:
  - `max_health` exported (currently 100); `current_health` initialised in `_ready`
  - `take_damage(amount)`:
    - Reduces health
    - Calls `flash_hit` (brief red tint using `modulate`)
    - Updates health bar via `_update_health_bar()`
    - Calls `die` when health <= 0
  - `die()` currently just `queue_free()`
- Health Bar:
  - Child node `HealthBar` (TextureProgressBar) cached in `@onready var health_bar`
  - `_update_health_bar()` function sets `max_value` and `value` based on current health
  - Automatically updates when enemy takes damage
- Group:
  - Adds itself to `"enemy"` group in `_ready` so bullets can recognise it

---

## Scene + Node Overview

### `Level_01.tscn`
- Holds the main level layout (TileMap/ground etc.)
- Contains:
  - `Player` instance
  - One or more `EnemyBasic` instances
  - Other world nodes as needed

### `Player.tscn`
- Root: `Player` (`CharacterBody2D`)
  - `Sprite2D`
  - `WeaponHolder` (`Node2D`)
    - `Gun` (`Node2D`)
      - `Sprite2D`
      - `Muzzle` (`Marker2D`)
      - `GunAudio` (`AudioStreamPlayer2D`)
  - `Camera2D` (with `camera_2d.gd`)

### `Gun.tscn`
- Root: `Gun` (`Node2D`, script: `weapon_pistol.gd`)
  - `Sprite2D`
  - `Muzzle` (`Marker2D`)
  - `GunAudio` (`AudioStreamPlayer2D` with pistol shot sound)

### `EnemyBasic.tscn` / `enemy.tscn`
- Root: `EnemyBasic` / `Enemy` (`CharacterBody2D`)
  - `Sprite2D`
  - `CollisionShape2D`
  - `HealthBar` (`TextureProgressBar`) - displays enemy health

### `Bullet.tscn`
- Root: `Bullet` (`Area2D`)
  - `CollisionShape2D`

---

## Script Overview (Quick Reference)

### `scripts/player.gd`
- Movement (walk, jump, gravity)
- Aiming:
  - Gets mouse position via `get_global_mouse_position()`
  - Calls `gun.aim_at(mouse_pos)`
- Facing logic:
  - Computes `facing_left` based on `mouse_pos.x < global_position.x`
  - Flips `Sprite2D` horizontally for body
  - Moves `WeaponHolder.position.x` to left or right side using a stored base offset
- Weapon integration:
  - Calls `gun.set_facing_left(facing_left)` if method exists
  - On `Input.is_action_just_pressed("shoot")`, calls `gun.try_shoot(mouse_pos)`
- Camera integration:
  - Connects to weapon `fired` signal in `_ready`
  - `_on_weapon_fired(strength, duration)` → calls `cam.start_shake`

### `scripts/weapons/weapon_base.gd`
- Base class for all hand-held weapons
- Manages:
  - Flipping sprite when facing left (`sprite.flip_v`)
  - Aiming at target (`look_at`)
  - Spawning bullets at `Muzzle`
  - Playing shot sound via temporary `AudioStreamPlayer2D` instances
  - Emitting `fired` signal for camera shake

### `scripts/weapons/weapon_pistol.gd`
- Extends WeaponBase
- Semi-auto behaviour in `try_shoot` (no cooldown, one shot whenever called)

### `scripts/weapons/bullet.gd`
- Raycast movement
- Damage on hit (currently 10 damage per bullet)
- Lifetime countdown
- No visible clipping due to raycast hit placement

### `scripts/enemies/enemy.gd`
- Simple follow AI:
  - Moves horizontally toward assigned `player`
  - Applies gravity
- Health & death:
  - `max_health` = 100 (exported, configurable)
  - Takes damage from bullets (10 damage per bullet)
  - Flashes red briefly on hit
  - Updates health bar when damaged
  - Dies via `queue_free` when health <= 0
- Health Bar:
  - `_update_health_bar()` updates the `HealthBar` TextureProgressBar
  - Called in `_ready()` and `take_damage()`

### `scripts/camera_2d.gd`
- Handles camera shake:
  - `start_shake(strength, duration)`
  - Uses `_process` to apply falloff jitter

---

## Known Quirks / Current Limitations

- Extra enemies in a level:
  - Only enemies with `player` export set in the Inspector will move.
  - Improvement planned: auto-find player via group (`"player"`) instead of manual wiring.
- No player HP or damage system yet.
- No enemy attack behaviour yet (they only walk toward you).
- Enemy health bars implemented (TextureProgressBar), but no player health bar, ammo counter, or crosshair yet.
- Movement is basic (no dash, roll, wall slide, etc.) — all planned for later.

---

## How To Use This File With ChatGPT

When starting a **new ChatGPT chat** about this project:

1. Paste **this file (`project_index.md`)** first.
2. Paste `file_structure.md` after it.
3. Then paste any specific script(s) you want to work on (e.g. `player.gd`, `weapon_base.gd`).
4. Explain what you want to add/change.

This gives ChatGPT enough context to help without needing the old conversation.

---
