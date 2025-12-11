# Shoot To Kill — Project Index (Updated)

## High-Level Summary
2D side-scrolling shooter built in Godot 4.

Core gameplay pillars:
- Clean & responsive movement
- Modular weapon system with weapon switching (primary/secondary)
- Per-weapon fire rate and full-auto support
- Per-weapon bullet spread (accuracy) system
- Reliable bullets with continuous collision detection
- Damage ranges + crit system
- Floating damage numbers with smooth arcing motion and color-coded hit types
- Enemies with full health logic and damage feedback
- Camera shake + gun audio
- Weighted aim dot system with per-weapon smoothing
- Arm and gun aiming system with per-weapon hand offsets
- Enemy damage lag bar system
- Visual weapon kickback system
- Custom crosshair replacing OS mouse cursor with outer crosshair pulse on weapon fire
- Centralized GameManager singleton for currency, XP, permanent progression, and scene management
- Gold (run currency) and Essence (permanent currency) systems
- Gold → Essence conversion on death
- XP/Level progression system
- Permanent progression: Stash (inventory) and Loadout (equipment) systems
- ItemDatabase autoload for centralized item metadata
- Shop system for purchasing items with Essence and level gating
- Coin pickup system with arc motion and idle bobbing
- Tavern hub with shop interaction and run door
- Scene management (death → tavern, door → new run)
- Debug console (debug builds only) with command system and input blocking

Current dev focus: **Combat polish + enemy interactions**

---

## Player
### Movement
- Horizontal left/right movement.
- Jumping.
- Gravity system.
- Uses `move_and_slide`.

### Animation
- Animation logic in `_update_animation()` helper function.
- Called from `_physics_process()` after `move_and_slide()`.
- "run" animation plays when moving horizontally on floor.
- "idle" animation plays when when on floor and not moving.
- "jump" animation plays while ascending.
- "fall" animation plays while descending.
- "land" animation plays once when hitting the floor.
- "run_backwards" animation plays when moving opposite to facing direction.

### Weapon Bob & Kickback
- **Weapon Bob**: Per-frame vertical offsets synced with player animations (idle, run, run_backwards, jump/fall).
- Bob values stored in arrays matching animation frames.
- Applied to `WeaponBobOffset` node each frame.
- **Visual Kickback**: Purely cosmetic weapon/arm movement backward along shot direction on firing.
- Kickback smoothly returns to zero over time.
- Configurable `kick_strength` (default 4.0) and `kick_return_speed` (default 20.0).
- Kickback combines with weapon bob for layered visual effect.
- Landing animation does not currently apply a bob offset (to be implemented).

### Gun Aiming & Facing
- Weighted aim dot system: crosshair dot lags behind mouse with configurable smoothing.
- Gun and arm aim independently at the weighted dot position.
- Arm sprite rotates toward aim point.
- Gun positioned relative to arm using hand offset.
- **Per-weapon hand offsets**: Each weapon defines its own `hand_offset_right` and `hand_offset_left` (configurable in Inspector).
- Per-facing offsets for weapon holder position.
- Weapon flips vertically using `set_facing_left()`.
- Player sprite flips horizontally using sprite scale.
- Weapon holder position shifts left/right depending on mouse direction.
- OS mouse cursor is hidden; crosshair follows mouse position every frame.
- Visual weapon kickback: gun/arm moves backward along shot direction on firing (purely cosmetic).

### Shooting & Weapon Switching
- Driven from `player.gd`.
- **Weapon Switching**:
  - `primary_weapon_scene` and `secondary_weapon_scene` exports allow assigning weapon scenes.
  - Press `weapon_1` (key 1) to switch to primary weapon.
  - Press `weapon_2` (key 2) to switch to secondary weapon.
  - Switching preserves weapon position/rotation and reconnects signals.
  - Primary weapon is automatically equipped on startup if assigned.
- **Fire Modes**:
  - **Semi-auto weapons**: Fire on click (`Input.is_action_just_pressed("shoot")`). Respect WeaponBase fire rate cooldown but require click per shot.
  - **Full-auto weapons**: Fire continuously while held (`Input.is_action_pressed("shoot")`). Controlled by WeaponBase `is_full_auto` flag and `fire_rate`.
- Calls `gun.try_shoot(aim_point)` using weighted dot position (not raw mouse).
- `try_shoot()` returns `bool` indicating if shot actually fired (respects cooldown).
- Visual kickback only applied when shot actually fires (when `try_shoot()` returns `true`).

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
  - Calls `GameManager.on_player_died()` to handle scene transition.
  - Does NOT reload scene directly (GameManager handles transitions).
- Signals:
  - `health_changed(current_health, max_health)` - emitted when health changes.
  - `died` - emitted when player dies.
  - `gold_changed(current_gold)` - legacy signal (kept for backward compatibility).

### Gold Currency System
- Gold is managed by `GameManager` singleton (not stored in player).
- `add_gold(amount)`:
  - Forwards gold to `GameManager.add_gold_run(amount)`.
  - All gold is tracked centrally in GameManager.
- Player is added to `"player"` group in `_ready()` for coin pickup detection.

---

## Weapons (Modular System)
### WeaponBase (`weapon_base.gd`)
- **Exports**
  - `base_damage_min` / `base_damage_max` - Damage range
  - `crit_chance` - Critical hit probability (default 0.1 = 10%)
  - `crit_multiplier` - Damage multiplier on crit (default 2.0)
  - `shake_strength`, `shake_duration` - Camera shake tuning
  - `aim_dot_lerp_speed` - Aim dot smoothing speed (default 10.0)
  - `fire_rate` - Shots per second (default 0.0 = no cooldown)
  - `is_full_auto` - If true, weapon can fire continuously while trigger held (default false)
  - `spread_degrees` - Maximum bullet spread angle in degrees (range 0.0-45.0, default 0.0)
  - `hand_offset_right` / `hand_offset_left` - Per-weapon hand position offsets (default Vector2(8, -2) / Vector2(8, 2))
  - `bullet_scene` - Bullet scene to spawn
- **Fire Rate System**
  - Internal cooldown timer (`_time_until_next_shot`) managed automatically.
  - `can_fire()` - Returns true if weapon can fire (cooldown expired).
  - `_apply_fire_cooldown()` - Applies cooldown after firing (calculated from `fire_rate`).
  - If `fire_rate <= 0`, no cooldown is applied.
- **Bullet Spread**
  - Applied in `spawn_bullet()` before computing bullet direction.
  - Random angular deviation: `-spread_degrees` to `+spread_degrees`.
  - Higher values = less accurate shots.
- **Handles**
  - Aiming + flipping
  - Damage rolling:
    - Random damage in `[base_damage_min, base_damage_max]`
    - Crit roll (`randf() < crit_chance`)
    - Crit damage multiplied by `crit_multiplier`
  - Spawning bullets (`Bullet.tscn`) with spread applied
  - Passing damage + crit info to bullets
  - Emitting `fired` signal for camera shake
  - Playing one-shot gun audio with random pitch

### Pistol (`weapon_pistol.gd`)
- Extends WeaponBase.
- Semi-auto weapon: respects WeaponBase cooldown via `can_fire()`, but requires click per shot.
- Default damage: **8–12**, with crit chance (default 10%).
- No internal fire rate cooldown by default (can be set in Inspector).

### Assault Rifle (`weapon_assault_rifle.gd`)
- Extends WeaponBase.
- Full-auto capable: respects WeaponBase cooldown via `can_fire()`.
- Can be configured as full-auto by setting `is_full_auto = true` in Inspector.
- Fire rate and spread can be tuned per weapon instance in Inspector.

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
- Shader-based flash system using `enemy_flash.gdshader`.
- Entire sprite turns pure white on hit.
- Configurable `flash_duration` (default 0.09s) and `flash_intensity` (default 1.0).
- Uses `ShaderMaterial` with `flash_amount` uniform.
- Prevents overlapping flashes with `is_flashing` flag.

### Health Bar System
- **HealthBar** (TextureProgressBar): Updates instantly to current health.
- **DamageBar** (TextureProgressBar): Lags behind, smoothly animates down to match health.
- Damage bar uses `max_health + damage_bar_max_offset` to prevent edge clipping.
- Configurable `damage_bar_lag_duration` (default 0.2s) for lag animation.
- If healed, damage bar snaps up immediately.
- If taking damage, damage bar smoothly tweens down.

### Damage Numbers
- Exported `damage_number_scene`.
- Instantiates on hit at `global_position + Vector2(15, -10)`.
- **Color System**:
  - Normal hits: white
  - Crit hits: yellow
  - Killing blows: red (priority over crit)
- **Arc System**:
  - Random left/right arc direction for normal hits.
  - Crit/killing blows: arc opposite to enemy movement direction.
  - Dynamic arc distance: boosted when arc goes WITH enemy movement (compensates for enemy running away).
- **Rotation System**:
  - Rotation only applied when arc direction is OPPOSITE to enemy movement.
  - If arc goes same direction as movement, rotation is 0.
  - Rotation range: 10°–30° based on `min_rot_deg` and `max_rot_deg`.
- Passes `damage`, `is_crit`, `is_killing_blow`, and `movement_dir_sign` to damage number.

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
  - Calls `_drop_loot()` to spawn coins.
  - Awards XP via `GameManager.add_xp(xp_reward)` if `xp_reward > 0`.
  - Immediately calls `queue_free()`.
- **XP Reward**:
  - `xp_reward` exported (default 10): XP granted when enemy dies.
  - XP is added directly to GameManager, triggering level-ups automatically.
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
  - `arc_boost_factor` (default 1.4, user set to 5.0)
  - `min_rot_deg`, `max_rot_deg` (rotation range)
  - `normal_color`, `crit_color`, `kill_color`
- **Visual**
  - Normal: white, default size.
  - Crit: yellow, 1.5x scale.
  - Killing blow: red, 1.5x scale.
- **Motion**
  - Parametric arc:
    - `t` animates from 0 → 0.6
    - Horizontal drift based on `arc_distance` (dynamically adjusted).
    - Vertical curve using `sin(t * PI)`.
  - Arc direction:
    - Normal hits: random left/right.
    - Crit/killing blows: opposite to enemy movement.
  - Dynamic arc distance:
    - Base `arc_distance` when arc goes opposite to movement.
    - `arc_distance * arc_boost_factor` when arc goes with movement.
- **Rotation**
  - Only applied when arc direction is OPPOSITE to enemy movement.
  - Rotation range: `min_rot_deg` to `max_rot_deg`.
  - If arc goes same direction as movement, rotation is 0.
- Alpha fades to 0.
- Auto frees when tween ends.

---

## GameManager System (`game_manager.gd`)
- **Autoload Singleton**: Configured as AutoLoad in Project Settings.
- **Centralized Currency Management**:
  - `gold_run` (float): Run-only currency (reset on death/new run).
  - `essence_total` (int): Permanent currency kept between runs.
  - `GOLD_TO_ESSENCE_RATE` (const, default 100.0): Conversion rate (100 gold = 1 essence).
  - Gold → Essence conversion happens automatically on player death.
- **Permanent Progression System**:
  - **Stash** (permanent inventory): Arrays for weapons, throwables, and gear (feet/back/head).
  - **Loadout** (per-run equipment): Selected items for each slot (primary/secondary/throwable + gear).
  - `owns_item(category, id)`: Checks if item is in stash.
  - `unlock_item(category, id)`: Adds item to stash.
  - `set_loadout_item(slot, id)`: Assigns item to loadout slot.
  - `_initialize_default_stash_and_loadout()`: Syncs with ItemDatabase defaults on startup.
- **Item Purchase System**:
  - `can_purchase_item(item_id)`: Validates purchase (checks level, essence, ownership).
  - `purchase_item_with_essence(item_id)`: Purchases item with Essence, unlocks in stash.
  - Level gating: Items require minimum player level.
  - Essence gating: Items cost permanent Essence currency.
- **XP/Level System**:
  - `xp` (int): Current XP amount.
  - `level` (int): Current player level.
  - `base_xp_to_level` (export, default 100): Base XP required for first level.
  - `xp_growth_factor` (export, default 1.4): Exponential growth multiplier.
  - `get_xp_required_for_next_level()`: Calculates XP needed for next level.
  - `add_xp(amount)`: Adds XP and handles level-ups automatically.
- **Testing/Debug**:
  - Exported testing overrides: `start_level`, `start_xp`, `start_essence`, `start_gold_run`.
  - Debug input blocking: `debug_input_blocked` flag and helper methods.
  - Instances DebugConsole in debug builds only.
- **Signals**:
  - `gold_run_changed(current_gold: float)` - emitted when run gold changes.
  - `essence_changed(current_essence: int)` - emitted when essence changes.
  - `xp_changed(current_xp: int, current_level: int)` - emitted when XP or level changes.
  - `item_unlocked(item_id: String, category: String)` - emitted when item is purchased/unlocked.
- **Scene Management**:
  - `TAVERN_SCENE_PATH`: Path to Tavern scene (`res://Scenes/Tavern.tscn`).
  - `RUN_SCENE_PATH`: Path to run scene (`res://Scenes/level_01.tscn`).
  - `go_to_tavern()`: Transitions to Tavern scene.
  - `start_new_run()`: Transitions to run scene (starts new run).
  - `on_player_died()`: Converts gold to essence, then transitions to Tavern.
  - `reset_run_state()`: Resets run-only data (including gold).

## HUD System (`hud.gd`)
- Separate CanvasLayer scene (`HUD.tscn`).
- The HUD is separated from the Player and loaded into the level as its own scene. It listens to the Player via signals and does not live inside the Player.tscn hierarchy.
- **Player Health Bar**
  - `PlayerHealthBar` (TextureProgressBar) child node.
  - Finds Player via `player_path` export or as sibling.
  - Connects to Player's `health_changed` signal in `_ready()`.
  - Initializes from Player's current health values.
  - Smooth tweening:
    - Uses `hp_tween` to animate value changes.
    - 0.15s duration with `TRANS_SINE` and `EASE_OUT`.
    - Kills existing tween before creating new one.
- **Currency Panel**
  - `CurrencyPanel` (HBoxContainer) with three boxes:
    - `GoldBox/GoldLabel`: Displays run gold from GameManager (1 decimal place).
    - `EssenceBox/EssenceLabel`: Displays permanent essence from GameManager.
    - `XPBox/XPLabel`: Displays level and XP in format "Lv X  XP Y".
  - Connects to GameManager signals in `_ready()`:
    - `gold_run_changed` → `_on_gold_run_changed()`
    - `essence_changed` → `_on_essence_changed()`
    - `xp_changed` → `_on_xp_changed()`
  - Initializes labels from current GameManager state.
- **Texture Requirements (Player Health Bar):**
  - Background texture contains the heart, frame, and bar track.
  - Progress texture must be tightly cropped so it includes ONLY the fill bar (no heart, no frame, no large padding).
  - Align the fill using the TextureProgressBar "Progress → Offset" property.
  - This fixes the issue where the bar appeared empty at 40 HP.

---

## Scenes Overview
### Level_01.tscn
- World layout + enemies + player.
- Main run scene loaded when starting a new run.

### Tavern.tscn
- Hub scene where player returns after death.
- Contains interaction areas for Bartender and RunDoor.
- **Bartender**: Opens ShopUI when interacted with (shop system implemented).
- **RunDoor**: Starts new run when interacted with.
- **ShopUI**: CanvasLayer scene for purchasing items with Essence.

### Player.tscn
- Player root (CharacterBody2D, script: `player.gd`, in group `"player"`)
- Weapon holder
- Gun
- Camera2D
- No UI nodes (HUD is separate)

### HUD.tscn
- HUD root (CanvasLayer, script: `hud.gd`)
- PlayerHealthBar (TextureProgressBar)
- CurrencyPanel (HBoxContainer):
  - GoldBox/GoldLabel: Displays run gold
  - EssenceBox/EssenceLabel: Displays permanent essence
  - XPBox/XPLabel: Displays level and XP
- Listens to Player's `health_changed` signal and GameManager currency/XP signals
- Updates all displays with smooth tweening (health) or instant updates (currency/XP)

### Gun.tscn
- Weapon scene with muzzle + audio.

### Bullet.tscn
- Bullet Area2D + CollisionShape2D.

### EnemyBasic.tscn
- Enemy root (CharacterBody2D, script: `enemy.gd`)
- Sprite2D (with shader material for flash effect)
- HealthBarBackground (TextureRect)
- DamageBar (TextureProgressBar) - direct child, lags behind health
- HealthBar (TextureProgressBar) - direct child, updates instantly
- DamageArea (Area2D) for contact damage
- Damage number spawn logic

### DamageNumber.tscn
- Node2D + RichTextLabel for damage display.

### CoinSilver.tscn / CoinGold.tscn
- Coin pickup scenes (Area2D with AnimatedSprite2D).
- Different values for silver vs gold coins.

---

## Crosshair System (`crosshair.gd`)
- **Outer Crosshair**: Follows mouse instantly in world space.
- **Outer Crosshair Pulse**: Scales up briefly when weapon fires, then smoothly returns to normal size.
  - Driven by weapon's `fired(strength, duration)` signal.
  - Exported `outer_pulse_scale` (default 1.25) and `outer_pulse_duration` (default 0.08s).
  - Uses tween with `TRANS_SINE` and `EASE_OUT` for smooth return.
  - Stores base scale in `_ready()` to pulse around it.
- **Weighted Aim Dot**: Smoothly lags behind mouse using screen-space lerp.
- Screen-space smoothing prevents lag from player movement.
- Converts smoothed screen position back to world space using canvas transform.
- Per-weapon smoothing speed via `weapon_base.gd.aim_dot_lerp_speed`.
- Player aims gun and arm at `crosshair.get_dot_world_position()`.
- **Mouse Cursor Replacement**: OS mouse cursor is hidden; crosshair root follows mouse position each frame to replace system cursor.
- **Signal Connection**: Player connects weapon's `fired` signal to `crosshair.on_weapon_fired()` in addition to camera shake.

## Key Files
### Scenes
- `game/Scenes/Player.tscn` - Player character scene
- `game/Scenes/HUD.tscn` - HUD UI scene (CanvasLayer)
- `game/Scenes/Level_01.tscn` - Main level scene
- `game/Scenes/Gun_Pistol.tscn` - Pistol weapon scene
- `game/Scenes/Gun_AssaultRifle.tscn` - Assault Rifle weapon scene
- `game/Scenes/Bullet.tscn` - Bullet scene
- `game/Scenes/EnemyBasic.tscn` - Enemy scene
- `game/Scenes/DamageNumber.tscn` - Damage number display scene
- `game/Scenes/Crosshair.tscn` - Crosshair with outer and dot sprites
- `game/Scenes/CoinSilver.tscn` - Silver coin pickup scene (Area2D with AnimatedSprite2D)
- `game/Scenes/CoinGold.tscn` - Gold coin pickup scene (Area2D with AnimatedSprite2D)
- `game/Scenes/ShopUI.tscn` - Shop UI scene (CanvasLayer)
- `game/Scenes/DebugConsole.tscn` - Debug console scene (CanvasLayer, debug builds only)
- `game/Scenes/Tavern.tscn` - Tavern hub scene
- `game/Scenes/LoadoutMenu.tscn` - Loadout menu scene (work in progress)

### Scripts
- `game/Scripts/game_manager.gd` - Centralized singleton for currency, XP/level, permanent progression, purchase system, scene management, and debug input blocking
- `game/Scripts/item_database.gd` - Item metadata autoload (weapons, throwables, gear definitions)
- `game/Scripts/shop_ui.gd` - Shop UI for purchasing items with Essence and level gating
- `game/Scripts/debug_console.gd` - Debug console with commands (debug builds only)
- `game/Scripts/player.gd` - Player movement, health, shooting, weapon switching, animation, aiming, gold forwarding, debug input blocking, UI mouse mode
- `game/Scripts/hud.gd` - HUD health bar and currency/XP display management
- `game/Scripts/camera_2d.gd` - Camera shake system
- `game/Scripts/crosshair.gd` - Crosshair and weighted aim dot system with outer pulse effect
- `game/Scripts/damage_number.gd` - Floating damage number animation
- `game/Scripts/enemies/enemy.gd` - Enemy AI, health, contact damage, flash, health bars, loot drops, XP rewards
- `game/Scripts/weapons/weapon_base.gd` - Base weapon class with damage/crit system, fire rate, full-auto, spread, aim dot smoothing, hand offsets
- `game/Scripts/weapons/weapon_pistol.gd` - Pistol weapon implementation (semi-auto)
- `game/Scripts/weapons/weapon_assault_rifle.gd` - Assault Rifle weapon implementation (full-auto capable)
- `game/Scripts/weapons/bullet.gd` - Bullet movement and collision
- `game/Scripts/coin.gd` - Coin pickup system with arc motion and bobbing animation
- `game/Scripts/tavern_bartender.gd` - Bartender interaction script (opens ShopUI when interacted with)
- `game/Scripts/tavern_run_door.gd` - Run door interaction script (calls GameManager.start_new_run())

### Shaders
- `game/shaders/enemy_flash.gdshader` - Shader for enemy hit flash effect

---

## Coin System (`coin.gd`)
- **Lightweight Pickup System**: Uses Area2D (no physics simulation) for performance.
- **Arc Motion**: Coins animate along a parametric arc from spawn to landing position.
  - Random horizontal direction (left/right) and distance.
  - Random vertical drop distance.
  - Sine-based arc height for smooth curve.
  - Tween-based animation over `travel_time` (default 0.4s).
- **Idle Bobbing**: After landing, coins bob up and down using sine wave.
  - Configurable `bob_height` (default 2.0) and `bob_speed` (default 4.0).
- **Player Detection**: Uses `Area2D.body_entered` to detect player overlap.
  - Handles parent/child node relationships (same pattern as enemy contact damage).
  - Calls `player.add_gold(value)` when collected.
- **Pickup Behavior**: 
  - Disables collision and hides sprite instantly on pickup.
  - Plays optional pickup sound, then frees after audio finishes.
  - Uses `set_deferred()` for collision shape disabling to avoid physics errors.

## Known Limitations
- Limited weapon variety — only Pistol and Assault Rifle implemented.
- No reload, ammo UI.
- Enemy pathfinding is simple horizontal chase.
- No knockback for player or enemies yet.
- Player invulnerability visual feedback not yet implemented.
- Save/load system not yet implemented (currencies, XP, stash, and loadout are session-only).
- Loadout items not yet applied to player during runs (equipment system pending).

---

## How to Use This File with ChatGPT
To load this project into a new chat:
1. Paste `project_index.md` (this file).
2. Paste `file_structure.md`.
3. Paste `gameplay_systems.md`.
4. Paste specific scripts you want help with.
