# Change Log — Shoot To Kill Documentation

This file tracks significant documentation updates and corrections.

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

