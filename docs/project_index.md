# Shoot To Kill — Project Index (Updated)

## High-Level Summary
2D side-scrolling shooter built in Godot 4.

Core gameplay pillars:
- Clean & responsive movement
- Modular weapon system with weapon switching (primary/secondary)
- Two-handed weapon support with separate back arm sprite and *_noarms animations
- Per-weapon fire rate and full-auto support
- Per-weapon bullet spread (accuracy) system
- Reliable bullets with continuous collision detection
- Damage ranges + crit system
- Floating damage numbers with pop + fade animation and color-coded hit types
- Enemies with full health logic and damage feedback
- Endless wave system with difficulty scaling and off-screen spawning
- Wave-based enemy spawning with kill/remaining tracking
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
- Coin pickup system with arc-to-ground landing using ground detection, then hover/bob (motion simulated; no physics body)
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
- **Two-handed weapon animations**: When using two-handed weapons, uses `*_noarms` variants:
  - `idle_noarms` - Idle animation without back arm (back arm drawn separately)
  - `run_noarms` - Forward run without back arm
  - `run_backwards_noarms` - Backwards run without back arm
- Animation selection checks if `*_noarms` variant exists before using it.

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
- **Two-handed weapon support**: 
  - Two-handed weapons use separate `BackArmSprite` under `WeaponBobOffset`.
  - Back arm positioned relative to gun using `support_hand_offset_right` and `support_hand_offset_left`.
  - Back arm rotates with gun and follows gun position.
  - Only visible when current weapon has `is_two_handed = true`.
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
  - Returns early if `godmode_enabled` is true.
  - Checks invulnerability timer (ignores damage if active).
  - Reduces health (clamped to 0 minimum).
  - Sets invulnerability timer.
  - Emits `health_changed(current_health, max_health)` signal.
  - Calls `die()` if health <= 0.
- **Godmode**:
  - `godmode_enabled` boolean on Player.
  - When enabled, `take_damage()` returns early (no HP change).
  - Debug console toggles this.
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
  - `is_two_handed` - If true, weapon uses two-handed pose with BackArmSprite (default false)
  - `support_hand_offset_right` / `support_hand_offset_left` - Back arm position offsets for two-handed weapons (default Vector2.ZERO)
  - `bullet_scene` - Bullet scene to spawn
  - **Bullet Penetration System**:
    - `penetration_min: int` - Minimum penetration power (default 0)
    - `penetration_max: int` - Maximum penetration power (default 0)
    - `penetration_chance: float` - Probability of penetration occurring (range 0.0-1.0, default 1.0)
    - `penetration_damage_drop_per_pen: float` - Damage reduction per additional enemy penetrated (default 0.10 = 10%)
  - **Bullet Range**: `max_range: float` - Maximum bullet travel distance (default 300.0)
  - **Bullet Speed**: `bullet_speed: float` - Bullet movement speed (default 450.0)
    - Bullet scene has a default speed (500.0), but WeaponBase always overrides it when spawning.
    - Note: Current weapon tuning in Inspector: AK and Pistol both set `bullet_speed` to 450.0 (these are per-weapon Inspector values, not global defaults).
  - **Bullet Knockback**:
    - `bullet_knockback: float` - Base knockback strength (default 0.0, no knockback unless set per weapon)
    - `knockback_drop_per_pen: float` - Knockback reduction per additional enemy penetrated (default 0.4 = 40%)
    - `crit_knockback_multiplier: float` - Knockback multiplier on critical hits (default 2.0)
    - Note: Current weapon tuning in Inspector: AK and Pistol both set `bullet_knockback` to 15.0 (these are per-weapon Inspector values, not code defaults).
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
  - Setting bullet penetration, range, speed, and knockback properties
  - Emitting `fired` signal for camera shake
  - Playing one-shot gun audio with random pitch
- **Penetration System**
  - `roll_penetration_power() -> int`: Rolls random penetration power based on `penetration_min`, `penetration_max`, and `penetration_chance`
  - Returns 0 if `penetration_max <= 0` or chance roll fails

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
  - Multi-hit penetration raycast loop (up to `MAX_HITS_PER_FRAME` per frame).
  - Uses `PhysicsRayQueryParameters2D.create()` with `hit_from_inside = true`.

- **Penetration System**
  - Bullets can hit multiple enemies in a single frame.
  - `penetration_power: int` - Remaining penetration power (reduced by enemy resistance).
  - `penetration_damage_drop_per_pen: float` - Cumulative damage reduction per enemy hit (default 0.20).
  - `_hit_enemy_ids: Dictionary` - Tracks enemies already hit (persists for bullet lifetime, prevents re-damaging).
  - `_enemies_damaged: int` - Counter for cumulative damage/knockback reduction.
  - `_resolve_enemy_from_collider(collider)` - Helper to resolve enemy root node from collider.
  - Bullet continues penetrating if `penetration_power >= 1` after each hit.
  - Uses RID-based collider exclusion for subsequent raycasts.

- **Range System**
  - `max_range: float` - Maximum travel distance (default INF, set by weapon).
  - `_distance_travelled: float` - Tracks cumulative distance traveled.
  - Bullet frees itself when `_distance_travelled >= max_range`.

- **Speed System**
  - `speed: float` - Bullet movement speed (set by weapon via `bullet_speed` export).
  - Bullet scene has a default speed, but WeaponBase always overrides it when spawning.
  - Movement: `target_pos = current_pos + direction * speed * delta`.

- **Damage & Crit**
  - Weapon sets: `bullet.damage` and `bullet.is_crit`.
  - Damage reduces cumulatively per enemy penetrated:
    - Formula: `damage_multiplier = pow(1.0 - penetration_damage_drop_per_pen, _enemies_damaged)`
    - First enemy takes full damage, subsequent enemies take reduced damage.
  - Always damages the enemy it collides with (cannot skip).

- **Knockback System**
  - `knockback_strength: float` - Base knockback (set by weapon).
  - `knockback_drop_per_pen: float` - Cumulative knockback reduction per enemy hit (default 0.20).
  - `crit_knockback_multiplier: float` - Knockback multiplier on crits (default 1.0, set by weapon).
  - Knockback calculation:
    - Apply crit multiplier first: `kb *= crit_knockback_multiplier` (if crit).
    - Apply penetration reduction: `kb *= pow(1.0 - knockback_drop_per_pen, _enemies_damaged)`.
  - Applied to enemies via `enemy.apply_knockback(direction, kb)`.

- **Lifetime**
  - Bullet has a `lifetime` countdown timer.
  - Frees itself when lifetime expires or max range exceeded.

---

## Enemy System (`enemy.gd`)
### State Machine
- Three states: `CHASE`, `ATTACK`, `DEAD`.
- `CHASE`: Moves horizontally toward player.
- `ATTACK`: Continues pressing toward player at reduced speed, deals repeated contact damage.
- `DEAD`: All physics disabled, enemy removed.

### Movement
- Moves toward exported `player` reference in `CHASE` state.
- Player reference can be assigned via `set_player(p: Node2D)` method (used by WaveManager).
- Continues pressing toward player at reduced speed in `ATTACK` state (via `attack_move_multiplier`).
- Applies gravity (except when `DEAD`).
- Sprite flips depending on direction.
- Dead enemies skip all physics via early return.

### Enemy Facing Stability (Deadzone)
- Prevents flip jitter when enemy is close to the player.
- Only updates facing when X distance exceeds `face_deadzone_px`.
- Uses `facing_left` boolean to track current facing direction.

### Enemy Separation Force (Crowd Flow)
- Uses `SeparationArea` (Area2D sensor) to detect nearby enemies.
- Applies a lightweight horizontal repulsion force in CHASE state only.
- Uses inverse distance weighting and clamps to `separation_max_push`.
- Limits neighbors processed via `separation_max_neighbors`.
- Exports: `separation_strength`, `separation_max_push`, `separation_max_neighbors`, `separation_min_dist_px`.

### Enemy ATTACK Movement
- In ATTACK, enemy continues pressing toward player at reduced speed via `attack_move_multiplier`.
- Export: `attack_move_multiplier` (default 0.35).

### Penetration Resistance
- `penetration_resistance: int` - Reduces bullet penetration power on hit (default 1).
- Bullet's `penetration_power` is reduced by this value after dealing damage.

### Knockback System
- **Exports**:
  - `knockback_decay: float` - Knockback decay rate (default 18.0).
  - `knockback_max_speed: float` - Maximum knockback velocity (default 220.0).
- **Member**: `knockback_velocity: Vector2` - Current knockback velocity (horizontal only).
- **Method**: `apply_knockback(dir: Vector2, strength: float) -> void`
  - Applies horizontal knockback impulse.
  - If already being knocked back in same direction, reduces impulse by 55% (prevents long skating).
  - Clamps knockback velocity to `-knockback_max_speed` to `knockback_max_speed`.
- **Behavior in `_physics_process()`**:
  - Knockback velocity is blended into horizontal movement: `velocity.x += knockback_velocity.x`.
  - Decay: `knockback_velocity.x = move_toward(knockback_velocity.x, 0.0, knockback_decay * 3.5 * delta)`.
  - Snaps to zero if `abs(knockback_velocity.x) < 2.0` (prevents micro-sliding).

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
- Instantiates on hit at `global_position + Vector2(2, -19)`.
- Note: This offset assumes the damage number scene itself is visually centered.
- **Color System**:
  - Normal hits: white
  - Crit hits: yellow
  - Killing blows: red `Color(1.0, 0.201, 0.059, 1.0)` (priority over crit)
- Passes `damage`, `is_crit`, and `is_killing_blow` to damage number.

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
  - Player exits `DamageArea` → state returns to `CHASE` (only if player truly no longer overlapping).
- **Repeated damage**:
  - While in `ATTACK` state, deals `contact_damage` every `contact_cooldown` seconds.
  - Enemy continues pressing toward player at reduced speed (via `attack_move_multiplier`).
- **Contact Damage Robustness**:
  - Uses DamageArea overlap check on body_exited to avoid dropping out of ATTACK incorrectly.
  - Checks `damage_area.get_overlapping_bodies()` before switching to CHASE.
  - Only switches to CHASE if player is truly no longer overlapping.
- **Early Return Safety When Player Dies**:
  - After applying contact damage, checks if player health <= 0.
  - Early return from `_physics_process()` to prevent `move_and_slide()` on destroyed physics space.
- `_on_damage_area_body_entered(body)`:
  - Returns early if `DEAD`.
  - Handles parent/child node detection.
  - Sets `player` reference and state to `ATTACK` if player detected.
- `_on_damage_area_body_exited(body)`:
  - Returns early if `DEAD`.
  - Handles parent/child node detection.
  - Checks overlap before switching to CHASE (see robust exit logic above).

### Death System
- `die()` function:
  - Prevents multiple calls (checks `DEAD` state).
  - Sets state to `DEAD`.
  - Calls `_drop_loot()` to spawn coins.
  - Awards XP via `GameManager.add_xp(xp_reward)` if `xp_reward > 0`.
  - Emits `died` signal before freeing (allows WaveManager to track kills).
  - Immediately calls `queue_free()`.
- **Signals**:
  - `died` - emitted when enemy dies (before queue_free).
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
  - Coins spawn at `global_position + COIN_SPAWN_OFFSET + Vector2(randf_range(-3.0, 3.0), 0.0)` (fixed Y offset with small X jitter to prevent stacking).

### Group
- Enemy registers in `"enemy"` group.

---

## Wave System (`wave_manager.gd`)

### Architecture
- **WaveManager Node**: Added to level scene (typically under root of `level_01.tscn`).
- Manages endless waves with automatic progression and difficulty scaling.
- Spawns enemies from off-screen spawn points.
- Tracks active enemies and total kills.

### Wave Progression
- Waves start automatically on scene load.
- Each wave has configurable difficulty parameters that scale with wave index.
- Wave clears when all enemies are spawned and killed.
- Break timer between waves (configurable duration).
- Automatic progression to next wave after break.

### Wave Definition
- **Target Concurrent**: Maximum enemies alive at once (scales with wave).
- **Total Enemies**: Total enemies per wave (scales with wave).
- **Spawn Interval**: Time between spawns (decreases with wave for faster spawning).
- **Break Duration**: Time between waves (configurable).

### Spawn System
- **Spawn Points**: Marked with `wave_spawn_point.gd` script under `WaveSpawnPoints` node.
- **Spawn Groups**: Spawn points can be grouped (default: "default").
- **Off-Screen Detection**: Only spawns from points outside camera view (with margin).
- **Spawn Positioning**:
  - Enemies spawn 16 pixels above spawn point (vertical offset).
  - Small horizontal jitter (-8 to +8 pixels) to prevent perfect stacking.
  - Player reference automatically assigned to spawned enemies.

### Enemy Tracking
- Tracks `_active_enemies` count via `died` signal connections.
- Increments `_total_kills` when enemies die.
- Provides `get_total_kills()` and `get_monsters_remaining()` methods for HUD.

### Signals
- `wave_started(wave_index: int)` - emitted when a new wave begins.
- `wave_cleared(wave_index: int)` - emitted when a wave is completed.

### Exports
- `base_break_duration` - Break time between waves (default 15.0s).
- `base_target_concurrent` - Starting max concurrent enemies (default 4).
- `max_target_concurrent` - Maximum concurrent enemies cap (default 25).
- `base_total_basic` - Starting enemy count per wave (default 6).
- `total_basic_per_wave` - Additional enemies per wave (default 3).
- `max_total_basic` - Maximum enemies per wave cap (default 80).
- `base_spawn_interval` - Starting spawn interval (default 0.8s).
- `min_spawn_interval` - Minimum spawn interval (default 0.25s).
- `spawn_interval_decay_per_wave` - Spawn interval reduction per wave (default 0.03s).

### WaveSpawnPoint (`wave_spawn_point.gd`)
- Simple Node2D script with `spawn_group` export.
- Used by WaveManager to locate spawn positions.
- Place multiple spawn points under `WaveSpawnPoints` node, positioned off-screen.

---

## Damage Number System (`damage_number.gd`)
- Shows floating numbers above enemy with pop + fade animation.
- **Exports**
  - `damage` (int) - Damage value to display
  - `is_crit` (bool) - Whether this is a critical hit
  - `normal_color` - Color for normal hits (default white)
  - `crit_color` - Color for crit hits (default yellow `Color(1.0, 1.0, 0.2)`)
  - `kill_color` - Color for killing blows (default red `Color(1.0, 0.201, 0.059, 1.0)`)
- **Visual**
  - Normal: white, default size (final scale 1.0).
  - Crit: yellow, larger size (final scale 2.0).
  - Killing blow: red, larger size (final scale 2.0).
- **Animation (Pop + Fade)**
  - **Constants**: `HOLD_TIME = 0.22`, `FADE_TIME = 0.14`, `TOTAL_TIME = 0.36`.
  - **Initial Setup**:
    - Random offset: `Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))`.
    - Initial scale: `0.7` (normal), `1.05` (crit/kill with 1.5x base multiplier).
  - **Scale Animation (Pop)**:
    - Scales up to `final_scale * 1.15` over 0.08s (TRANS_BACK, EASE_OUT).
    - Eases back to `final_scale` over 0.10s (delayed 0.08s).
    - `final_scale`: `1.0` (normal), `2.0` (crit/kill).
  - **Upward Drift**: Moves upward `-8.0` pixels over `TOTAL_TIME`.
  - **Fade**: Alpha stays at `1.0` during `HOLD_TIME`, then fades to `0.0` over `FADE_TIME`.
  - **Cleanup**: Node freed after `TOTAL_TIME` interval.

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
  - `go_to_tavern()`: Transitions to Tavern scene (uses deferred call to prevent physics errors).
  - `start_new_run()`: Transitions to run scene (uses deferred call to prevent physics errors).
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
- **Info Panel**
  - `InfoPanel` (container) with multiple display boxes:
    - `WaveBox/WaveLabel`: Displays current wave number ("WAVE: X").
    - `StatsBox/MonstersKilledLabel`: Displays total kills ("KILLS: X").
    - `StatsBox/MonstersRemainingLabel`: Displays remaining enemies in current wave ("REMAINING: X").
    - `GoldBox/GoldLabel`: Displays run gold from GameManager (1 decimal place).
    - `EssenceBox/EssenceLabel`: Displays permanent essence from GameManager.
    - `XPBox/XPLabel`: Displays level and XP in format "Lv X  XP Y".
  - Connects to GameManager signals in `_ready()`:
    - `gold_run_changed` → `_on_gold_run_changed()`
    - `essence_changed` → `_on_essence_changed()`
    - `xp_changed` → `_on_xp_changed()`
  - Connects to WaveManager in `_ready()`:
    - `wave_started` → `_on_wave_started()`
  - Updates kill/remaining stats every frame in `_process()`.
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
- **WaveManager** node (script: `wave_manager.gd`) manages endless waves.
- **WaveSpawnPoints** node contains multiple spawn point markers (script: `wave_spawn_point.gd`).

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
- InfoPanel (container):
  - WaveBox/WaveLabel: Displays current wave
  - StatsBox/MonstersKilledLabel: Displays total kills
  - StatsBox/MonstersRemainingLabel: Displays remaining enemies
  - GoldBox/GoldLabel: Displays run gold
  - EssenceBox/EssenceLabel: Displays permanent essence
  - XPBox/XPLabel: Displays level and XP
- Listens to Player's `health_changed` signal, GameManager currency/XP signals, and WaveManager wave signals
- Updates all displays with smooth tweening (health) or instant updates (currency/XP/wave/stats)

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
- `game/Scripts/player.gd` - Player movement, health, shooting, weapon switching, animation, aiming, two-handed weapon support, gold forwarding, debug input blocking, UI mouse mode
- `game/Scripts/hud.gd` - HUD health bar, currency/XP display, wave display, and kill/remaining stats management
- `game/Scripts/wave_manager.gd` - Endless wave system with difficulty scaling, off-screen spawning, kill tracking
- `game/Scripts/wave_spawn_point.gd` - Spawn point marker script for wave system
- `game/Scripts/camera_2d.gd` - Camera shake system
- `game/Scripts/crosshair.gd` - Crosshair and weighted aim dot system with outer pulse effect
- `game/Scripts/damage_number.gd` - Floating damage number animation
- `game/Scripts/enemies/enemy.gd` - Enemy AI, health, contact damage, flash, health bars, loot drops, XP rewards, died signal
- `game/Scripts/weapons/weapon_base.gd` - Base weapon class with damage/crit system, fire rate, full-auto, spread, aim dot smoothing, hand offsets, two-handed weapon support
- `game/Scripts/weapons/weapon_pistol.gd` - Pistol weapon implementation (semi-auto)
- `game/Scripts/weapons/weapon_assault_rifle.gd` - Assault Rifle weapon implementation (full-auto capable)
- `game/Scripts/weapons/bullet.gd` - Bullet movement and collision
- `game/Scripts/coin.gd` - Coin animation: arc-to-ground landing using ground detection, then hover/bob (motion simulated; no physics body)
- `game/Scripts/tavern_bartender.gd` - Bartender interaction script (opens ShopUI when interacted with)
- `game/Scripts/tavern_run_door.gd` - Run door interaction script (calls GameManager.start_new_run())

### Shaders
- `game/shaders/enemy_flash.gdshader` - Shader for enemy hit flash effect

---

## Coin System (`coin.gd`)
- **Lightweight Pickup**: Area2D, not physics body.
- **Motion Simulation**: Simulated intentionally for performance/determinism.
- **Spawn**: Spawned by enemies on death (fixed Y offset + small X jitter to prevent stacking).
- **Arc-to-ground**:
  - Pick random ±X, raycast once down at landing X, tween arc to landing position above ground.
  - Ground mask targets World layer bit 0.
  - TRAVEL_TIME currently 0.6.
- **Hover/Bob**: Sine bob after landing.
- **Pickup**: body_entered, disable collision deferred, hide sprite, play audio, free.

## Debug Console (`debug_console.gd`)
- Debug builds only.
- Commands:
  - `help` - Shows available commands
  - `give_gold <amount>` - Adds gold to current run
  - `give_essence <amount>` - Adds essence (permanent currency)
  - `set_level <level>` - Sets player level
  - `set_xp <amount>` - Sets player XP amount
  - `unlock_all` - Unlocks all items in ItemDatabase that aren't already owned
  - `spawn <count> basicenemy [left|right|points]` - Spawns enemies dynamically
    - `left/right`: spawn relative to player
    - `points`: distribute across `WaveSpawnPoints` (round-robin)
    - clamps count to safe maximum (1-200)
  - `godmode` - Toggles player invincibility (debug builds only)
- **Aliases**:
  - `give gold <amount>`: Alias for `give_gold`
  - `give essence <amount>`: Alias for `give_essence`
  - `set level <level>`: Alias for `set_level`
  - `set xp <amount>`: Alias for `set_xp`

## Known Limitations
- Limited weapon variety — only Pistol and Assault Rifle implemented.
- No reload, ammo UI.
- Enemy pathfinding is simple horizontal chase.
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
