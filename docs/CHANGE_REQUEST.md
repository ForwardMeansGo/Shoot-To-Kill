# CHANGE REQUEST — Documentation Synchronization
**Date:** 2025-01-XX  
**Phase:** 2 — Change Request (REPORT ONLY)  
**Status:** AWAITING APPROVAL

---

## Executive Summary

This Change Request identifies significant discrepancies between the live project code and the documentation set. Multiple major systems implemented in the current chat session are either completely missing from documentation, incorrectly described, or documented with outdated information.

**Primary Issues:**
1. **Bullet System**: Documentation describes old single-hit system, but live code implements multi-hit penetration with knockback
2. **Damage Number System**: Documentation describes arc motion, but live code implements pop+fade animation
3. **Weapon System**: Missing documentation for penetration, range, speed, and knockback exports
4. **Enemy System**: Missing documentation for penetration resistance and knockback system
5. **Known Limitations**: Incorrectly states "No knockback" when knockback is implemented
6. **scripts_copy.md**: Contains outdated bullet.gd and damage_number.gd code that doesn't match live files

---

## Detailed Change Request

### 1. BULLET SYSTEM (`bullet.gd`) — MAJOR REWRITE REQUIRED

#### Files Affected:
- `docs/project_index.md` (Bullet System section, lines 191-213)
- `docs/gameplay_systems.md` (Bullet System section, lines 104-132)
- `docs/scripts_copy.md` (bullet.gd section, lines ~1050-1137)

#### Current Documentation Issues:
- **Outdated**: Documentation describes single-hit system with `_handle_hit()` function
- **Missing**: Multi-hit penetration system completely undocumented
- **Missing**: Max range tracking system
- **Missing**: Bullet speed system
- **Missing**: Knockback application system
- **Missing**: Enemy hit tracking (`_hit_enemy_ids` dictionary)
- **Missing**: Cumulative damage/knockback reduction per penetration
- **Missing**: `_resolve_enemy_from_collider()` helper function
- **Missing**: Constants: `MAX_HITS_PER_FRAME`, `PIERCE_EPSILON`

#### Live Code Has:
- Multi-hit penetration raycast loop (up to `MAX_HITS_PER_FRAME` per frame)
- `penetration_power`, `penetration_damage_drop_per_pen` variables
- `_hit_enemy_ids` dictionary tracking enemies hit (persists for bullet lifetime)
- `_enemies_damaged` counter for cumulative damage/knockback reduction
- `max_range` and `_distance_travelled` for range-based bullet termination
- `speed` variable used for movement calculation
- `knockback_strength`, `knockback_drop_per_pen`, `crit_knockback_multiplier` variables
- `_resolve_enemy_from_collider()` helper function
- Complex damage/knockback reduction formula using `pow()` for cumulative effect
- Resistance-based penetration power reduction
- RID-based collider exclusion for subsequent raycasts

#### Required Changes:
1. **project_index.md**: Replace entire Bullet System section (lines 191-213) with new multi-hit penetration documentation
2. **gameplay_systems.md**: Replace entire Bullet System section (lines 104-132) with new multi-hit penetration documentation
3. **scripts_copy.md**: Replace `bullet.gd` script copy (lines ~1050-1137) with current live code (197 lines)

---

### 2. DAMAGE NUMBER SYSTEM (`damage_number.gd`) — MAJOR REWRITE REQUIRED

#### Files Affected:
- `docs/project_index.md` (Damage Number System section, lines 410-441)
- `docs/gameplay_systems.md` (Damage Number System section, lines 680-739)
- `docs/scripts_copy.md` (damage_number.gd section — need to locate)

#### Current Documentation Issues:
- **Outdated**: Documentation describes parametric arc motion system with:
  - `t` parameter animation (0 → 0.6)
  - Horizontal drift based on `arc_distance`
  - Vertical curve using `sin(t * PI)`
  - Dynamic arc distance with `arc_boost_factor`
  - Rotation system based on arc vs movement direction
  - `movement_dir_sign` parameter
- **Missing**: Pop + fade animation system completely undocumented

#### Live Code Has:
- Pop + fade animation using tween system
- Constants: `HOLD_TIME = 0.22`, `FADE_TIME = 0.14`, `TOTAL_TIME = 0.36`
- Initial random offset: `Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))`
- Initial scale: `0.7` (base), `1.05` (crit/kill with 1.5x multiplier)
- Scale animation: pop to `final_scale * 1.15`, ease back to `final_scale`
- Final scale: `1.0` (normal), `2.0` (crit/kill — user-modified from 1.5)
- Upward drift: `-8.0` pixels over `TOTAL_TIME`
- Alpha fade: stays at `1.0` for `HOLD_TIME`, then fades to `0.0` over `FADE_TIME`
- No arc motion, no rotation, no `movement_dir_sign` usage

#### Required Changes:
1. **project_index.md**: Replace entire Damage Number System section (lines 410-441) with pop+fade documentation
2. **gameplay_systems.md**: Replace entire Damage Number System section (lines 680-739) with pop+fade documentation
3. **scripts_copy.md**: Update `damage_number.gd` script copy to match live code (69 lines)
4. **project_index.md**: Update core gameplay pillars (line 14): Change "smooth arcing motion" to "pop + fade animation"

---

### 3. WEAPON SYSTEM (`weapon_base.gd`) — MISSING EXPORTS AND METHODS

#### Files Affected:
- `docs/project_index.md` (WeaponBase section, lines 142-176)
- `docs/gameplay_systems.md` (Weapons System section, lines 3-101)
- `docs/scripts_copy.md` (weapon_base.gd section — need to locate)

#### Current Documentation Issues:
- **Missing Exports**: The following exports are not documented:
  - `penetration_min: int = 0`
  - `penetration_max: int = 0`
  - `penetration_chance: float = 1.0` (range 0.0-1.0)
  - `penetration_damage_drop_per_pen: float = 0.10`
  - `max_range: float = 300.0` (live code has 300, docs might suggest 800)
  - `bullet_speed: float = 450.0` (live code has 450, docs might suggest 900)
  - `bullet_knockback: float = 15.0`
  - `knockback_drop_per_pen: float = 0.4` (live code has 0.4, not 0.20)
  - `crit_knockback_multiplier: float = 2.0`
- **Missing Method**: `roll_penetration_power() -> int`
- **Missing Behavior**: `spawn_bullet()` sets all penetration, range, speed, and knockback properties on bullet instance

#### Live Code Has:
All above exports and method implemented. Default values in live code:
- `max_range: float = 300` (not 800.0 as might be documented)
- `bullet_speed: float = 450` (not 900.0 as might be documented)
- `knockback_drop_per_pen: float = 0.4` (not 0.20)

#### Required Changes:
1. **project_index.md**: Add bullet penetration, range, speed, and knockback exports to WeaponBase section
2. **gameplay_systems.md**: Add bullet penetration, range, speed, and knockback exports to Weapons System section
3. **project_index.md**: Add `roll_penetration_power()` method documentation
4. **gameplay_systems.md**: Update "Bullet Spawning" section to document property assignments
5. **scripts_copy.md**: Update `weapon_base.gd` script copy to include all new exports and method (183 lines)

---

### 4. ENEMY SYSTEM (`enemy.gd`) — MISSING PENETRATION RESISTANCE AND KNOCKBACK

#### Files Affected:
- `docs/project_index.md` (Enemy System section, lines 216-350)
- `docs/gameplay_systems.md` (Enemy System section, lines 457-604)
- `docs/scripts_copy.md` (enemy.gd section — need to verify is current)

#### Current Documentation Issues:
- **Missing Export**: `penetration_resistance: int = 1`
- **Missing Exports**: 
  - `knockback_decay: float = 18.0`
  - `knockback_max_speed: float = 220.0`
- **Missing Member**: `knockback_velocity: Vector2 = Vector2.ZERO`
- **Missing Method**: `apply_knockback(dir: Vector2, strength: float) -> void`
- **Missing Behavior**: Knockback application and decay logic in `_physics_process()`
  - Horizontal-only knockback
  - Decay: `knockback_decay * 3.5 * delta`
  - Snap to zero if `abs(knockback_velocity.x) < 2.0`
  - Soft add: if same direction, multiply by 0.55

#### Live Code Has:
All above exports, member, and method implemented. Knockback system is fully functional.

#### Required Changes:
1. **project_index.md**: Add penetration resistance export to Enemy System
2. **project_index.md**: Add new "Knockback System" subsection to Enemy System documenting:
   - `knockback_decay`, `knockback_max_speed` exports
   - `knockback_velocity` member
   - `apply_knockback()` method
   - Knockback application/decay behavior in `_physics_process()`
3. **gameplay_systems.md**: Add same knockback documentation to Enemy System section
4. **scripts_copy.md**: Verify `enemy.gd` script copy is current (375 lines — appears current but verify)

---

### 5. KNOWN LIMITATIONS — INCORRECT STATEMENT

#### Files Affected:
- `docs/project_index.md` (Known Limitations section, line 675)

#### Current Documentation Issues:
- **Incorrect**: Line 675 states "No knockback for player or enemies yet."
- **Reality**: Enemy knockback system is fully implemented (see #4 above)

#### Required Changes:
1. **project_index.md**: Remove or update line 675 to reflect that enemy knockback is implemented
   - Suggested: Remove the line entirely, or change to "No knockback for player on hit yet" (if player knockback is not implemented)

---

### 6. TODOS — OUTDATED STATUS

#### Files Affected:
- `docs/todos.md` (line 7, line 11)

#### Current Documentation Issues:
- **Line 7**: "Player invulnerability frames + knockback on hit" is unchecked `[ ]`
  - **Note**: Only player knockback is missing; enemy knockback IS implemented
- **Line 11**: "Damage numbers with arc animation" is checked `[x]`
  - **Reality**: Arc animation was replaced with pop+fade animation

#### Required Changes:
1. **todos.md**: Update line 7 to clarify: "Player invulnerability frames + knockback on hit" — add note that enemy knockback is implemented
2. **todos.md**: Update line 11: Change "arc animation" to "pop + fade animation" OR uncheck and add new line for "pop + fade animation"

---

### 7. CORE GAMEPLAY PILLARS — OUTDATED DESCRIPTION

#### Files Affected:
- `docs/project_index.md` (High-Level Summary, line 14)

#### Current Documentation Issues:
- **Line 14**: States "Floating damage numbers with smooth arcing motion and color-coded hit types"
- **Reality**: Damage numbers use pop + fade animation, not arcing motion

#### Required Changes:
1. **project_index.md**: Update line 14 to: "Floating damage numbers with pop + fade animation and color-coded hit types"

---

### 8. SCRIPTS_COPY.MD — OUTDATED BULLET AND DAMAGE_NUMBER CODE

#### Files Affected:
- `docs/scripts_copy.md` (bullet.gd section, damage_number.gd section)

#### Current Documentation Issues:
- **bullet.gd**: Contains old single-hit code with `_handle_hit()` function (lines ~1050-1137)
  - Does not match live code (197 lines with multi-hit penetration)
- **damage_number.gd**: Likely contains old arc motion code
  - Does not match live code (69 lines with pop+fade)

#### Required Changes:
1. **scripts_copy.md**: Replace `bullet.gd` script copy with current live code from `game/Scripts/weapons/bullet.gd`
2. **scripts_copy.md**: Replace `damage_number.gd` script copy with current live code from `game/Scripts/damage_number.gd`
3. **scripts_copy.md**: Update summary section to mention bullet penetration, knockback, and damage number pop+fade

---

## Cross-File Consistency Issues

### Terminology Alignment Needed:
1. **"Arc animation" vs "Pop + fade animation"**: Ensure all files use consistent terminology
2. **"Penetration" vs "Piercing"**: Use "penetration" consistently (matches code)
3. **"Knockback" terminology**: Use consistently across all files

### Default Value Alignment:
1. **max_range**: Live code has `300.0`, documentation might suggest `800.0` — align to live code
2. **bullet_speed**: Live code has `450.0`, documentation might suggest `900.0` — align to live code
3. **knockback_drop_per_pen**: Live code has `0.4`, documentation might suggest `0.20` — align to live code
4. **penetration_damage_drop_per_pen**: Live code has `0.10` (10%), documentation matches — verify
5. **damage_number final_scale**: Live code has `2.0` for crit/kill, documentation suggests `1.5` — align to live code

---

## Summary of Changes Required

### Files Requiring Major Rewrites:
1. **project_index.md**: 
   - Bullet System section (complete rewrite)
   - Damage Number System section (complete rewrite)
   - WeaponBase exports (additions)
   - Enemy System knockback (new subsection)
   - Core gameplay pillars (one-line update)
   - Known Limitations (one-line removal/update)

2. **gameplay_systems.md**:
   - Bullet System section (complete rewrite)
   - Damage Number System section (complete rewrite)
   - Weapons System exports (additions)
   - Enemy System knockback (new subsection)

3. **scripts_copy.md**:
   - `bullet.gd` script copy (complete replacement)
   - `damage_number.gd` script copy (complete replacement)
   - `weapon_base.gd` script copy (verify and update if needed)
   - Summary section (update feature descriptions)

### Files Requiring Minor Updates:
1. **todos.md**: Update status/descriptions for knockback and damage numbers

### Verification Needed:
1. **scripts_copy.md**: Verify `enemy.gd` script copy matches live code (appears current but verify)

---

## Priority Classification

### CRITICAL (Blocks accurate documentation):
- Bullet System rewrite (multi-hit penetration)
- Damage Number System rewrite (pop+fade)
- Weapon System exports (penetration, range, speed, knockback)
- Enemy System knockback documentation

### HIGH (Incorrect information):
- Known Limitations "No knockback" statement
- Core gameplay pillars "arcing motion" description
- scripts_copy.md outdated code

### MEDIUM (Status updates):
- todos.md status updates

---

## Notes for Implementation

1. **Default Values**: Always match live code defaults, not suggested/default values from chat prompts
2. **Code Accuracy**: scripts_copy.md must match live code 1:1 (no approximations)
3. **Terminology**: Use consistent terminology across all files
4. **Structure**: Maintain existing documentation structure and formatting style
5. **Completeness**: Document ALL new exports, methods, and behaviors — nothing should be partially documented

---

## Approval Required

This Change Request requires explicit approval before Phase 4 (Apply Approved Changes) can proceed.

**Awaiting approval from:** Ewan

