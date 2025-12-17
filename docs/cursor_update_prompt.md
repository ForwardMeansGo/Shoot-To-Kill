You are updating the documentation set for Shoot-To-Kill.
You MUST scan, verify, and synchronise ALL documentation in:

C:\Users\Ewan\Documents\GitHub\Shoot-To-Kill\docs

Files:
1. project_index.md
2. gameplay_systems.md
3. scripts_copy.md
4. workflow.md
5. file_structure.md
6. todos.md
7. change_log.md

You must also scan the live project (scripts, scenes, resources) to determine the actual current game state.
--------------------------------------------
## Phase 1 — Scan & Analyse (NO edits allowed)
--------------------------------------------
1. Scan all documentation files listed above.
2. Scan the entire live project (code, scripts, scenes, autoloads, UI).
3. Perform a full project-wide diff between:
	Documentation
	Live implementation
	Changes made in current chat

4. Identify every discrepancy, including:
	Missing systems or scripts
	New systems or scripts (likely from active Chat)
	Outdated or incorrect descriptions
	Inconsistent terminology
	Mismatched variables, exports, signals, or behaviour
	Systems documented in one file but missing or incorrect in others

5. For scripts_copy.md, compare each script against the repository and note anything that does not match 1:1.

Do NOT modify any documentation in this phase.
---------------------------------------
## Phase 2 — Change Request (REPORT ONLY)
---------------------------------------
6. Produce a CHANGE REQUEST document that lists:
	What is missing
	What is outdated
	What is incorrect
	What is inconsistent across files
	What needs rewriting, removal, or clarification
7. Clearly reference:
	Which documentation file(s) are affected
	Which live script/system they should match

8. Output ONLY the Change Request.

9. Stop and wait for Ewan’s review and approval.
-------------------------
## Phase 3 — Approval Gate
-------------------------
10. No changes may be applied until explicit approval is given by Ewan.
11. If approval is denied or adjustments are requested, revise the Change Request only.
----------------------------------
## Phase 4 — Apply Approved Changes
----------------------------------
12. After approval, update documentation by:
	Editing only sections that require changes
	Preserving existing structure and formatting
	Ensuring accuracy and clarity

13. Remove documentation for legacy systems that have been fully replaced in live code. This includes (but is not limited to):
	Systems that no longer exist in the repository
	Behaviour that is no longer executed at runtime
	Helper functions, variables, or concepts that have been superseded
	Visual or gameplay systems that have been redesigned

	Rules for removal:
		Only remove legacy documentation if the live project clearly no longer uses it
		Do NOT keep outdated descriptions “for reference”
		Do NOT leave partially-documented or contradictory systems
		Prefer removal over annotation when a system is fully obsolete

This rule takes precedence over preserving legacy descriptions for completeness.

14. Update scripts_copy.md so all scripts match the live repository exactly.

15. Cross-check all docs to ensure:
	No contradictions
	Consistent terminology
	No undocumented live systems remain
------------------------
## Phase 5 — Finalisation
------------------------
16. Append a new entry to change_log.md (never overwrite) including:
	Date
	Brief titles of major changes
	Summary of additions, removals, fixes, and rewrites

17. Deliver:
	All updated documentation files
	Updated change_log.md
	Confirmation that:
		Docs match the live project 100%
		No systems are missing
		No contradictions remain
		scripts_copy.md matches the repo 1:1
---------------------------
## Absolute rules (never break)
---------------------------
Do not invent systems or behaviour.
Do not partially document anything.
Do not apply edits before approval.
Accuracy beats brevity every time.
Outdated documentation is more harmful than missing documentation.
The documentation set must describe the CURRENT project state only.

--Start now--

Begin Phase 1 by scanning all documentation and the live project.
Then proceed to Phase 2 and output the Change Request only.