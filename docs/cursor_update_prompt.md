You are scanning and updating the full documentation set for Shoot-To-Kill.

You MUST scan, verify, and synchronise ALL documentation files located in:
C:\Users\Ewan\Documents\GitHub\Shoot-To-Kill\docs

The docs are:
1. project_index.md  
2. gameplay_systems.md  
3. scripts_copy.md  
4. workflow.md  
5. file_structure.md  
6. todos.md  
7. change_log.md

---------------------------------------
YOUR RULES – DO NOT IGNORE ANY OF THESE
---------------------------------------

1. **Perform a full project-wide diff analysis before editing ANY file.**
   - You MUST scan both the documentation AND the current codebase/scripts/scenes to understand the real game state.
   - Identify every new system, script, feature, variable, signal, mechanic, interaction, UI element, scene, or architectural change.
   - Check if the documentation already reflects it.
   - If ANY discrepancy exists, they must be changed to how the system is currently working.

2. **Absolutely NOTHING may be missed or partially documented.**
   - If something exists in code or scenes, it MUST exist in documentation.
   - If something is wrong or outdated in documentation, it MUST be corrected.

3. **Scripts must match 1:1 with live code.**
   - For scripts_copy.md, extract the latest version of each script directly from the repository.
   - Ensure script sections reflect the actual behaviour (e.g., debug input blocking, GameManager-only gold, death → Tavern flow, shop behaviour, etc).

4. **Cross-reference ALL files during the update.**
   For every documented system, confirm:
   - Terminology is consistent across all files.
   - Descriptions match the actual implementation.
   - Signals, variables, autoloads, and scene references align.
   - No system is documented in one file but missing in another.
   - Nothing contradicts anything else.

5. **Never hallucinate new systems or invent behaviour.**
   Only document what already exists in the live project.

6. **All edits you make MUST be documented and appended to change_log.md**
   This must include:
   - What was missing
   - What was outdated
   - What was inconsistent
   - What needed major rewrites
   - What was added, removed, corrected, or clarified

   *change_log.md must never be overwritten — entries must be appended.*

7. **You MUST NOT modify any documentation file until I have reviewed and approved the CHANGE REPORT.**
   - First produce the CHANGE REPORT summarising everything that needs modification.
   - Then wait for confirmation.
   - Only after approval can you apply changes.

8. **After approval, perform updates in the cleanest possible way:**
   - Rewrite only the sections that require changes.
   - Preserve original formatting and structure.
   - Maintain clarity, accuracy, and completeness.

9. **Final output after edits must include:**
   - All updated documentation files
   - An updated change_log.md entry (with brief titles of the new systems & a date)
     - No systems missing
     - No contradictions remain
     - All docs are in sync with each other AND the live codebase
     - All scripts in scripts_copy.md match the real codebase exactly
     - All new or modified features have been fully documented

---------------------------------------
GOAL
---------------------------------------
Maintain 100% accuracy across the entire documentation set.
Missed or outdated documentation can break long-term development,
so this process must be airtight and thorough.

Begin by scanning and analysing ALL documentation files and the live project codebase.
Then implement the appropriate changes and update change_log.
