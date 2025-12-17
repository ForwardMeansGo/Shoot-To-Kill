# Change Log — Shoot To Kill Documentation

This file tracks significant documentation updates and corrections.

---

## 2025-01-XX — Documentation Cleanup: Removed Arc System and _handle_hit() References

### Summary
Documentation cleanup to remove outdated references to damage number arc motion system and bullet `_handle_hit()` method, while adding clarifications for bullet speed and knockback defaults.

### Updates Made
- **Arc System Removal**: Removed all mentions of parametric arc motion, arc direction logic, rotation system, and `movement_dir_sign` usage from damage number documentation
- **_handle_hit() Removal**: Removed references to `_handle_hit()` method describing current bullet behavior (bullet system now uses direct damage/knockback application in penetration loop)
- **Bullet Speed Clarification**: Added explicit note that bullet scene has a default speed (500.0), but WeaponBase always overrides it when spawning; clarified that current weapon tuning values (AK/Pistol = 450.0) are per-weapon Inspector values, not global defaults
- **Knockback Defaults Clarification**: Updated documentation to reflect that `bullet_knockback` code default is 0.0 (no knockback unless set per weapon), while current weapon tuning (AK/Pistol = 15.0) is documented as per-weapon Inspector values, not code defaults

### Files Updated
- `project_index.md`: Removed arc system and rotation system subsections from Damage Numbers; removed `movement_dir_sign` from properties passed list; added bullet speed clarification; corrected knockback default documentation
- `gameplay_systems.md`: Added bullet speed clarification; corrected knockback default documentation
- `scripts_copy.md`: Verified scripts match live code (movement_dir_sign still passed in enemy.gd code but unused by damage_number.gd)
- `todos.md`: Already updated (no changes needed)
- `change_log.md`: This entry

### Notes
- Damage numbers now exclusively use pop + fade animation (no arc motion)
- Bullet system uses direct damage/knockback application in penetration loop (no `_handle_hit()` helper)
- Code defaults (0.0 for knockback, 500.0 for bullet speed) are clearly separated from per-weapon Inspector tuning values

---

## 2025-01-XX — Major Documentation Synchronization: Bullet Penetration, Knockback, and Damage Number Animation

### Summary
Complete documentation update to reflect major combat system implementations: multi-hit bullet penetration system, per-weapon bullet range/speed/knockback, enemy penetration resistance and knockback, and damage number pop + fade animation (replacing arc motion).

### Major Systems Added/Updated

#### Bullet System
- **Multi-Hit Penetration**: Complete rewrite to document multi-hit penetration raycast loop system
- **Penetration Mechanics**: `penetration_power`, `penetration_damage_drop_per_pen`, `_hit_enemy_ids` tracking, `_enemies_damaged` counter
- **Range System**: `max_range` and `_distance_travelled` for range-based bullet termination
- **Speed System**: `speed` variable for per-weapon bullet velocity control
- **Knockback System**: `knockback_strength`, `knockback_drop_per_pen`, `crit_knockback_multiplier` with cumulative reduction
- **Helper Function**: `_resolve_enemy_from_collider()` for correct enemy root node resolution
- Removed outdated single-hit `_handle_hit()` system documentation

#### Damage Number System
- **Animation Change**: Complete rewrite from parametric arc motion to pop + fade animation
- **New Constants**: `HOLD_TIME = 0.22`, `FADE_TIME = 0.14`, `TOTAL_TIME = 0.36`
- **Scale Animation**: Pop effect (scale up to 1.15x, ease back to final scale)
- **Fade Animation**: Alpha stays at 1.0 during hold, then fades over fade time
- **Upward Drift**: Simple upward movement over total time
- Removed arc motion, rotation, and `movement_dir_sign` documentation

#### Weapon System
- **New Exports**: `penetration_min`, `penetration_max`, `penetration_chance`, `penetration_damage_drop_per_pen`
- **New Exports**: `max_range`, `bullet_speed`
- **New Exports**: `bullet_knockback`, `knockback_drop_per_pen`, `crit_knockback_multiplier`
- **New Method**: `roll_penetration_power() -> int`
- **Updated**: `spawn_bullet()` now sets all penetration, range, speed, and knockback properties

#### Enemy System
- **New Export**: `penetration_resistance: int` (default 1)
- **New Exports**: `knockback_decay: float` (default 18.0), `knockback_max_speed: float` (default 220.0)
- **New Member**: `knockback_velocity: Vector2`
- **New Method**: `apply_knockback(dir: Vector2, strength: float) -> void`
- **New Behavior**: Knockback application and decay in `_physics_process()` (snappy, low-ice system)

### Files Updated
- `project_index.md`: Complete rewrites for Bullet System and Damage Number System sections; added weapon exports, enemy knockback section; updated core gameplay pillars; removed incorrect "No knockback" limitation
- `gameplay_systems.md`: Complete rewrites for Bullet System and Damage Number System sections; added weapon exports, enemy knockback section
- `scripts_copy.md`: Replaced `bullet.gd` script copy (197 lines with multi-hit penetration); replaced `damage_number.gd` script copy (69 lines with pop+fade); updated `weapon_base.gd` script copy (added new exports and method); updated summary sections
- `todos.md`: Updated damage number description from "arc animation" to "pop + fade animation"; added note that enemy knockback is implemented

### Outdated Information Corrected
- Bullet system documentation (was describing single-hit system, now reflects multi-hit penetration)
- Damage number documentation (was describing arc motion, now reflects pop+fade animation)
- Weapon system exports (added 9 missing exports and 1 missing method)
- Enemy system (added penetration resistance and complete knockback system)
- Known Limitations (removed incorrect "No knockback" statement)

### Notes
- All code in scripts_copy.md now matches live repository 1:1
- Default values aligned to live code (e.g., `max_range = 300.0`, `bullet_speed = 450.0`, `knockback_drop_per_pen = 0.4`)
- Terminology made consistent across all files (penetration, pop+fade, knockback)

---

## 2025-12-16 — Docs Resync: Approved Facts Only

### Summary
Docs resync: coin arc-to-ground+hover confirmed; kill_color corrected; debug console help lists spawn/godmode; enemy ATTACK wording corrected; removed outdated coin-system references.

### Updates Made
- **Coin System**: Updated to explicitly document motion simulation, TRAVEL_TIME 0.6, ground mask bit 0, and arc-to-ground + hover system
- **Damage Numbers**: Verified kill_color is `Color(1.0, 0.201, 0.059, 1.0)` in scripts_copy.md
- **Debug Console**: Verified help output includes spawn and godmode commands
- **Enemy ATTACK**: Verified wording states "continues pressing toward player at reduced speed" (not "stops moving")

### Files Updated
- `project_index.md`: Coin System section updated to match approved skeleton
- `gameplay_systems.md`: Coin System section updated to match approved skeleton
- **Damage numbers**: Clarified spawn offset to `Vector2(2, -19)` after sprite centering (no logic change).

---

## 2025-12-16 — Documentation Resync After Recovery

### Summary
Documentation resync after recovery; removed outdated coin-system description; ensured debug console help lists spawn/godmode; corrected damage number killing blow color in docs.

### Updates Made
- **Coin System**: Removed outdated "exported arc motion settings" descriptions; updated to arc-to-ground + hover system with single raycast ground detection
- **Damage Numbers**: Corrected killing blow color documentation to `Color(1.0, 0.201, 0.059, 1.0)` (was incorrectly documented as different values)
- **Debug Console**: Verified spawn and godmode commands are documented in help text
- **Scripts Copy**: Updated `damage_number.gd` kill_color constant to match actual code

### Files Updated
- `project_index.md`: Coin System section rewritten, Damage Numbers color corrected
- `gameplay_systems.md`: Coin System section updated, Damage Numbers color corrected
- `scripts_copy.md`: `damage_number.gd` kill_color constant corrected

---

## 2025-12-16 — Code & Documentation Restoration

### Summary
Complete restoration of all code and documentation changes that were accidentally reverted. All systems, features, and documentation from the previous synchronization session have been fully restored.

### Restored Code Systems

#### Enemy System (`enemy.gd`)
- **Separation Force**: Horizontal repulsion in CHASE state using SeparationArea, inverse distance weighting, neighbor limiting
- **Facing Stability**: Deadzone-based facing prevents flip jitter (`face_deadzone_px`, `facing_left` boolean)
- **ATTACK Movement**: Reduced-speed movement toward player via `attack_move_multiplier` (default 0.35)
- **Node Caching**: `@onready` caching for `damage_area` and `separation_area`
- **Early Return Safety**: Prevents physics errors when player dies from contact damage
- **Robust Body Exited Logic**: Overlap checking before switching to CHASE state
- **Damage Number Spawn**: Fixed position `Vector2(0, -19)` (was `Vector2(15, -10)`)
- **Coin Spawn**: Uses `COIN_SPAWN_OFFSET + jitter` to prevent stacking
- **Debug Print Wrapping**: All debug prints wrapped in `OS.is_debug_build()`

#### Coin System (`coin.gd`)
- **Arc-to-Ground + Hover**: Complete rewrite from old arc motion system
- **Ground Raycast Detection**: `_find_ground_y()` finds landing position
- **Constants**: `TRAVEL_TIME = 0.6`, `GROUND_CLEARANCE = 8.0`, `HOVER_HEIGHT = 2.0`, `HOVER_SPEED = 4.0`
- **Motion Simulation**: Intentional simulation (no physics bodies) for performance and determinism

#### Player System (`player.gd`)
- **Godmode**: `godmode_enabled` boolean checked in `take_damage()` before invulnerability
- **Parameter Fixes**: Unused parameters prefixed with `_` (`_input(_event)`, `_on_weapon_fired(_strength, _duration)`)

#### Debug Console (`debug_console.gd`)
- **Spawn Command**: `spawn <count> basicenemy [left|right|points]` with helper functions
- **Godmode Command**: `godmode` toggles player invincibility
- **Helper Functions**: `_get_player()`, `_get_wave_spawn_points()`, `_spawn_basic_enemy()`

#### GameManager (`game_manager.gd`)
- **Deferred Scene Transitions**: `go_to_tavern()` and `start_new_run()` use `call_deferred()` to prevent physics errors

#### HUD (`hud.gd`)
- **Parameter Fixes**: `_process(_delta)`, `_on_player_health_changed(current, max_health)`

#### Crosshair (`crosshair.gd`)
- **Parameter Fixes**: `on_weapon_fired(_strength, _duration)`

### Restored Documentation

#### project_index.md
- Updated Enemy System: Added separation force, facing stability, ATTACK movement subsections
- Updated Coin System: Complete rewrite (arc-to-ground + hover)
- Updated Damage Numbers: Corrected spawn position
- Updated Loot Drop System: Added COIN_SPAWN_OFFSET + jitter details
- Added Debug Console section: spawn and godmode commands
- Added Player Health godmode subsection
- Updated GameManager Scene Management: Mentioned deferred calls

#### gameplay_systems.md
- Updated Enemy System: Added all new subsections (separation, facing, attack movement, robust exit logic, early return safety)
- Updated Coin System: Complete rewrite (arc-to-ground + hover architecture)
- Updated Damage Numbers: Corrected spawn position
- Updated Loot Drop System: Added offset + jitter
- Updated Debug Console: Added spawn and godmode commands
- Added Player Health godmode subsection
- Updated GameManager Scene Management: Mentioned deferred calls

#### scripts_copy.md
- Updated `player.gd`: Added godmode_enabled, parameter fixes
- Updated `enemy.gd`: Added all new exports, constants, functions, and logic
- Updated `coin.gd`: Complete replacement with arc-to-ground system
- Updated `debug_console.gd`: Added spawn and godmode commands
- Updated `game_manager.gd`: Deferred scene transitions
- Updated `hud.gd`: Parameter name fixes
- Updated `crosshair.gd`: Parameter name fixes

### Notes
- All code changes have been fully restored and match the synchronized state
- Documentation has been updated to reflect all restored systems
- Scripts_copy.md contains updated script sections (full verbatim copies should be regenerated from actual code files for 100% accuracy)

---

## 2024-12-28 — Major Documentation Synchronization

### Summary
Full documentation audit and update to match current codebase. Multiple weapon systems had been implemented but were not documented.

### Added Systems
- **Weapon Switching System**: Primary/secondary weapon slots, weapon_1/weapon_2 input actions, dynamic weapon equipping with position/rotation preservation, signal management
- **Fire Rate & Full-Auto System**: Per-weapon fire rate (shots per second), full-auto toggle, internal cooldown timer system, `can_fire()` and `_apply_fire_cooldown()` methods
- **Bullet Spread System**: Per-weapon spread_degrees export (0-45 degrees), random angular deviation applied to bullet direction
- **Per-Weapon Hand Offsets**: Configurable `hand_offset_right` and `hand_offset_left` exports per weapon instance
- **Assault Rifle Weapon**: New weapon implementation (`weapon_assault_rifle.gd`) and scene (`gun_assault_rifle.tscn`)

### Updated Files

#### project_index.md
- Added weapon switching, fire rate, full-auto, spread to core gameplay pillars
- Updated "Shooting & Weapon Switching" section with complete weapon switching and fire mode details
- Expanded WeaponBase documentation with all new exports and methods
- Added Assault Rifle weapon entry
- Updated scene and script file listings
- Fixed "Known Limitations" (changed "Pistol only" to "Limited weapon variety")

#### gameplay_systems.md
- Added "Fire Rate & Full-Auto System" subsection under Weapons System
- Added "Bullet Spread System" subsection under Weapons System
- Added "Per-Weapon Hand Offsets" subsection under Weapons System
- Updated "Bullet Spawning" section to include spread and cooldown application
- Added "Weapon Switching System" subsection under Player System
- Added "Shooting System" subsection under Player System with fire mode detection details
- Updated "Aiming System" to reflect per-weapon hand offsets (not hard-coded)

#### scripts_copy.md
- Updated `player.gd` script copy (added weapon switching exports, helper functions, updated shooting logic)
- Updated `weapon_base.gd` script copy (added fire rate, full-auto, spread, hand offsets, cooldown methods)
- Updated `weapon_pistol.gd` script copy (added `can_fire()` check)
- Added `weapon_assault_rifle.gd` script copy (was completely missing)
- Updated summary section to reflect new features

#### file_structure.md
- Added `gun_assault_rifle.tscn` to scene listings
- Added `weapon_assault_rifle.gd` to script listings
- Added `LoadoutMenu.tscn` to scene listings

#### todos.md
- Marked "Weapon cooldowns" as complete [x]
- Marked "Weapon switching" as complete [x]

### Outdated Information Corrected
- Player shooting system description (was describing single-weapon behavior, now reflects switching + fire modes)
- WeaponBase exports and methods (added 7 missing exports and 2 missing methods)
- Pistol description (was saying "no cooldown", now correctly states respects WeaponBase cooldown)
- Player hand offset logic (was showing hard-coded values, now shows per-weapon lookup)
- Scene file listings (added missing scenes, corrected paths)

### Cross-References
- All terminology aligned across files
- Script paths verified and corrected (Scripts vs scripts casing)
- Scene paths updated to match actual file structure

---

## 2024-12-28 — Wave System & Two-Handed Weapons Documentation

### Summary
Comprehensive documentation synchronization to include two major new systems: endless wave system and two-handed weapon support. Also updated HUD structure documentation to reflect InfoPanel hierarchy.

### Added Systems
- **Wave System**: Complete endless wave system with WaveManager, spawn point markers, difficulty scaling, off-screen spawning, kill tracking, and HUD integration
- **Two-Handed Weapons**: Support for two-handed weapon poses with BackArmSprite, support hand offsets, and *_noarms animation variants
- **Enemy Improvements**: Added `set_player()` method and `died` signal for wave system integration
- **HUD Stats Display**: Wave display, kill counter, and remaining enemies counter integrated into InfoPanel

### Updated Files

#### project_index.md
- Added wave system and two-handed weapons to core gameplay pillars
- Added complete "Wave System" section with architecture, progression, spawn system, and tracking details
- Updated Player animation section to document *_noarms variants
- Updated Gun Aiming & Facing section to document two-handed weapon support and BackArmSprite
- Updated WeaponBase section to include two-handed exports (`is_two_handed`, `support_hand_offset_*`)
- Updated Enemy System to document `set_player()` method and `died` signal
- Updated HUD System section to reflect InfoPanel structure (replaced CurrencyPanel references)
- Updated Level_01.tscn scene description to mention WaveManager and WaveSpawnPoints
- Updated HUD.tscn scene description to reflect InfoPanel hierarchy
- Added wave scripts to script listings

#### gameplay_systems.md
- Added complete "Wave System" section with architecture, progression, spawn system, enemy tracking, signals, and exports
- Added "Two-Handed Weapon Support" subsection under Weapons System
- Updated Player System animation section to document *_noarms variants and selection logic
- Updated Player System aiming section to document BackArmSprite and two-handed support
- Updated HUD System section to reflect InfoPanel structure with WaveBox, StatsBox, and all display boxes
- Updated Enemy System to document `set_player()` method and `died` signal

#### scripts_copy.md
- Added complete `wave_manager.gd` script copy (285 lines)
- Added complete `wave_spawn_point.gd` script copy (4 lines)
- Updated `weapon_base.gd` script copy (added two-handed exports: `is_two_handed`, `support_hand_offset_right`, `support_hand_offset_left`)
- Updated `player.gd` script copy:
  - Added `back_arm_sprite` @onready reference
  - Added back arm initialization in `_ready()`
  - Added back arm posing logic in `_process()`
  - Updated `_update_animation()` with *_noarms animation selection logic
  - Updated `_get_weapon_bob_for_current_frame()` to match *_noarms animations
  - Added `_is_current_weapon_two_handed()` helper function
- Updated `enemy.gd` script copy:
  - Added `signal died` declaration
  - Added `set_player(p: Node2D)` method
  - Updated `die()` to emit `died` signal before `queue_free()`
- Updated `hud.gd` script copy:
  - Changed all @onready paths from `CurrencyPanel/` to `InfoPanel/`
  - Added `wave_label`, `stats_box`, `monsters_killed_label`, `monsters_remaining_label` references
  - Added `_wave_manager` member variable
  - Added WaveManager connection in `_ready()`
  - Added `_on_wave_started()` handler
  - Added `_process()` method for kill/remaining stats updates
- Updated summary section to include wave system scripts and updated feature descriptions

#### file_structure.md
- Added `wave_manager.gd` to Scripts listings
- Added `wave_spawn_point.gd` to Scripts listings

### Outdated Information Corrected
- HUD structure documentation (was referencing CurrencyPanel, now correctly shows InfoPanel hierarchy)
- Player animation system (was missing *_noarms variants and selection logic)
- WeaponBase exports (was missing two-handed weapon support exports)
- Enemy system (was missing `set_player()` method and `died` signal)
- Scene descriptions (was missing WaveManager and WaveSpawnPoints in Level_01.tscn)

### Cross-References
- All terminology aligned across files
- Wave system terminology consistent (WaveManager, WaveSpawnPoint, spawn_group, etc.)
- Two-handed weapon terminology consistent (is_two_handed, BackArmSprite, *_noarms, etc.)
- HUD node paths verified and corrected (InfoPanel structure)
- Script paths verified (game/Scripts/ with capital S)

---

