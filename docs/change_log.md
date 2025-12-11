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

