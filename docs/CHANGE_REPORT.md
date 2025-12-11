# DOCUMENTATION CHANGE REPORT

**Date:** 2024-12-28  
**Analysis Scope:** Full project-wide scan comparing documentation vs live codebase

---

## SUMMARY

Major discrepancies found between documentation and actual implementation. Several new weapon systems have been implemented but are completely missing from documentation. Script copies are significantly outdated.

---

## MISSING SYSTEMS (Not Documented Anywhere)

### 1. **Weapon Switching System** ⚠️ CRITICAL MISSING
**Status:** Fully implemented in code, NOT documented
**Location:** `game/Scripts/player.gd`

**What exists:**
- `@export var primary_weapon_scene: PackedScene`
- `@export var secondary_weapon_scene: PackedScene`
- `var current_weapon_slot: int = 0` (0 = unspecified, 1 = primary, 2 = secondary)
- `_equip_weapon_scene(scene: PackedScene)` - Instantiates weapons while preserving position/rotation
- `_connect_weapon_signals()` / `_disconnect_weapon_signals()` - Signal management
- `_switch_to_primary()` / `_switch_to_secondary()` - Convenience functions
- Weapon switching via `Input.is_action_just_pressed("weapon_1")` and `weapon_2` actions
- Input actions `weapon_1` and `weapon_2` defined in `project.godot`

**Where it should be documented:**
- `project_index.md` - Player section "Shooting" needs complete rewrite
- `gameplay_systems.md` - New "Weapon Switching" subsection under Player System
- `scripts_copy.md` - `player.gd` script copy is outdated (missing lines 32-137)

---

### 2. **Fire Rate & Full-Auto System** ⚠️ CRITICAL MISSING
**Status:** Fully implemented in code, NOT documented
**Location:** `game/Scripts/weapons/weapon_base.gd`, `game/Scripts/player.gd`

**What exists in WeaponBase:**
- `@export var fire_rate: float = 0.0` (shots per second, 0 = no cooldown)
- `@export var is_full_auto: bool = false` (enables hold-to-fire)
- `var _time_until_next_shot: float = 0.0` (internal cooldown timer)
- `can_fire() -> bool` - Checks if weapon can fire based on cooldown
- `_apply_fire_cooldown()` - Applies cooldown after firing
- `_process(delta)` - Decrements cooldown timer each frame
- `spawn_bullet()` - Calls `_apply_fire_cooldown()` after firing

**What exists in Player:**
- Full-auto vs semi-auto firing logic (lines 256-268)
- Distinguishes between `Input.is_action_pressed()` (hold) and `Input.is_action_just_pressed()` (click)
- Full-auto weapons fire while held, semi-auto fire on click only
- Kickback only applied when `try_shoot()` returns `true` (shot actually fires)

**What exists in weapon implementations:**
- `weapon_pistol.gd` - Calls `can_fire()` before shooting (semi-auto)
- `weapon_assault_rifle.gd` - Calls `can_fire()` before shooting (ready for full-auto)

**Where it should be documented:**
- `project_index.md` - Weapons section needs major expansion
- `gameplay_systems.md` - New "Fire Rate & Full-Auto" subsection under Weapons System
- `scripts_copy.md` - `weapon_base.gd` copy is outdated (missing fire rate features)
- `scripts_copy.md` - `weapon_pistol.gd` and `weapon_assault_rifle.gd` copies are outdated

---

### 3. **Bullet Spread System** ⚠️ CRITICAL MISSING
**Status:** Fully implemented in code, NOT documented
**Location:** `game/Scripts/weapons/weapon_base.gd`

**What exists:**
- `@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0`
- Random angular deviation applied in `spawn_bullet()` before computing bullet direction
- Spread logic: `var half := spread_degrees; var random_angle := deg_to_rad(randf_range(-half, half)); dir = dir.rotated(random_angle)`

**Where it should be documented:**
- `project_index.md` - Weapons section
- `gameplay_systems.md` - New "Bullet Spread" subsection under Weapons System
- `scripts_copy.md` - `weapon_base.gd` copy missing spread code

---

### 4. **Per-Weapon Hand Offsets** ⚠️ PARTIALLY DOCUMENTED
**Status:** Implemented, but docs say "hard-coded" when they're now configurable
**Location:** `game/Scripts/weapons/weapon_base.gd`, `game/Scripts/player.gd`

**What exists:**
- `@export var hand_offset_right: Vector2 = Vector2(8, -2)`
- `@export var hand_offset_left: Vector2 = Vector2(8, 2)`
- Player uses `gun.hand_offset_left` / `gun.hand_offset_right` when gun is WeaponBase
- Fallback to old constants for non-WeaponBase weapons

**Documentation issue:**
- `project_index.md` says "Per-facing offsets" but doesn't mention they're per-weapon configurable
- `gameplay_systems.md` mentions per-facing offsets but doesn't explain per-weapon system
- `scripts_copy.md` - `player.gd` copy shows hard-coded values (line 163-172) instead of per-weapon lookup

---

### 5. **Assault Rifle Weapon** ⚠️ COMPLETELY MISSING
**Status:** Fully implemented, NOT mentioned anywhere
**Location:** `game/Scripts/weapons/weapon_assault_rifle.gd`, `game/Scenes/gun_assault_rifle.tscn`

**What exists:**
- Complete weapon implementation extending WeaponBase
- `try_shoot()` method with cooldown checking
- Scene file exists: `gun_assault_rifle.tscn`

**Where it should be documented:**
- `project_index.md` - Weapons section needs "Assault Rifle" entry
- `gameplay_systems.md` - Weapons System needs Assault Rifle details
- `scripts_copy.md` - Missing `weapon_assault_rifle.gd` script copy entirely
- `file_structure.md` - Missing `weapon_assault_rifle.gd` and `gun_assault_rifle.tscn`

---

## OUTDATED INFORMATION

### 6. **Player Shooting System Description**
**File:** `project_index.md` line 74-79
**Issue:** Says "Pistol fires with `Input.is_action_just_pressed("shoot")`" and "Semi-auto: 1 bullet per click" - but now has full-auto support and weapon switching
**Needs:** Complete rewrite to describe semi-auto vs full-auto, weapon switching, and try_shoot() return value handling

### 7. **WeaponBase Documentation**
**File:** `project_index.md` line 114-130
**Issue:** Missing:
- `fire_rate` and `is_full_auto` exports
- `spread_degrees` export
- `hand_offset_right` and `hand_offset_left` exports
- `can_fire()` method
- `_apply_fire_cooldown()` method
- `_time_until_next_shot` variable
- Updated `_process()` for cooldown timer
- Bullet spread application in `spawn_bullet()`

### 8. **Pistol Weapon Description**
**File:** `project_index.md` line 132-135
**Issue:** Says "No cooldown — fires every click" but now respects WeaponBase cooldown via `can_fire()`

### 9. **Player Script Copy**
**File:** `scripts_copy.md` line 14-352
**Issue:** Missing:
- Lines 32-35: `primary_weapon_scene`, `secondary_weapon_scene`, `current_weapon_slot`
- Lines 74-137: All weapon switching functions (`_connect_weapon_signals`, `_disconnect_weapon_signals`, `_equip_weapon_scene`, `_switch_to_primary`, `_switch_to_secondary`)
- Lines 222-238: Per-weapon hand offset logic (currently shows hard-coded values)
- Lines 244-275: Updated shooting logic with weapon switching, full-auto/semi-auto distinction, and kickback on successful shot only

### 10. **WeaponBase Script Copy**
**File:** `scripts_copy.md` line 599-702
**Issue:** Missing:
- Lines 22-30: Fire rate, full-auto, and spread exports
- Lines 32-34: Hand offset exports
- Lines 40: `_time_until_next_shot` variable
- Lines 42-45: Updated `_process()` with cooldown timer
- Lines 56-64: `can_fire()` and `_apply_fire_cooldown()` methods
- Lines 75-79: Bullet spread application in `spawn_bullet()`
- Line 97: `_apply_fire_cooldown()` call after firing

### 11. **Pistol Script Copy**
**File:** `scripts_copy.md` line 704-716
**Issue:** Shows old implementation without `can_fire()` check. Current code calls `can_fire()` before shooting.

### 12. **Missing Assault Rifle Script Copy**
**File:** `scripts_copy.md`
**Issue:** Entire `weapon_assault_rifle.gd` script is missing from documentation

---

## SCENE FILE DISCREPANCIES

### 13. **gun_assault_rifle.tscn**
**Status:** Exists in `game/Scenes/`, not documented
**File:** `file_structure.md`, `project_index.md`
**Issue:** Scene file exists but not listed in file structure or scene overview

### 14. **LoadoutMenu.tscn**
**Status:** Exists in `game/Scenes/`, not documented
**File:** `file_structure.md`, `project_index.md`
**Issue:** Scene file exists but not mentioned anywhere. Purpose unknown - may be work-in-progress or unused.

---

## KNOWN LIMITATIONS UPDATE

### 15. **todos.md**
**File:** `docs/todos.md`
**Issue:** Line 23 says "[ ] Weapon switching" - should be marked complete [x]
**Issue:** Line 21 says "[ ] Weapon cooldowns" - should be marked complete [x] (fire rate system implemented)

---

## CROSS-REFERENCE INCONSISTENCIES

### 16. **Terminology**
- Docs use "gun" but code uses both "gun" and "weapon" - should be consistent
- Some docs say "hard-coded offsets" when they're now configurable per-weapon

### 17. **Script Paths**
- `scripts_copy.md` says "Location: `game/Scripts/weapons/weapon_base.gd`" but file is actually `game/scripts/weapons/weapon_base.gd` (lowercase 's' in Scripts vs scripts) - need to verify actual casing

---

## FILES REQUIRING UPDATES

### HIGH PRIORITY (Missing major systems):
1. `project_index.md` - Add weapon switching, fire rate, full-auto, spread, assault rifle, update player shooting section
2. `gameplay_systems.md` - Add new weapon system sections (switching, fire rate, full-auto, spread, hand offsets)
3. `scripts_copy.md` - Update player.gd, weapon_base.gd, weapon_pistol.gd, add weapon_assault_rifle.gd

### MEDIUM PRIORITY (Outdated info):
4. `file_structure.md` - Add gun_assault_rifle.tscn, weapon_assault_rifle.gd, LoadoutMenu.tscn (if relevant)
5. `todos.md` - Mark weapon switching and weapon cooldowns as complete

### LOW PRIORITY (Minor fixes):
6. `change_log.md` - Add entry for this documentation update session

---

## VERIFICATION CHECKLIST

After updates, verify:
- [ ] Weapon switching system fully documented
- [ ] Fire rate & full-auto system fully documented  
- [ ] Bullet spread system documented
- [ ] Per-weapon hand offsets correctly described
- [ ] Assault rifle weapon documented
- [ ] All script copies match live code 1:1
- [ ] All scenes listed in file structure
- [ ] Player shooting section describes current behavior
- [ ] No contradictions between documentation files
- [ ] todos.md reflects current implementation state

---

## ESTIMATED EFFORT

- **Major rewrites:** ~3-4 sections across multiple files
- **Script copy updates:** ~4 scripts need complete refresh
- **New content:** ~5-6 new subsections needed
- **Cross-reference fixes:** Multiple files need terminology alignment

**Total:** Significant documentation overhaul required. All changes are additive/corrective (no deprecated systems to remove).

