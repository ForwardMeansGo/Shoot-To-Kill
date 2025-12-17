# Development Workflow – Shoot-To-Kill

This document defines how work flows between Ewan, ChatGPT, Cursor, and Godot.

The core rule: think first, edit safely, keep everything future-proof and modular.

---

# Roles

## ChatGPT – Design and Reasoning

Used for system design, debugging, and architectural decisions.

* Explains why things break or behave a certain way.
* Provides step-by-step Godot engine instructions.
* Provides Cursor prompts for any script or documentation changes.
* Does not modify files directly.

## Cursor – Code and Documentation Editing

Applies all script changes.

* Updates all docs under `C:\Users\Ewan\Documents\GitHub\Shoot-To-Kill\docs`.
* Shows diffs before applying.
* Ensures minimal, safe, targeted code changes.
* Executes only what ChatGPT specifies in the prompt.

## Godot – Engine and Scene Work

Used for node setup, scene creation, UI layout, collision configuration, resource assignment, and testing.

* Ewan does not manually edit scripts inside Godot.
* All logic changes go through ChatGPT → Cursor.

---

# Core Philosophy

Reasoning is separate from editing.

* Avoid bandage fixes.
* Prefer modular, future-proof solutions.
* If there is a cleaner long-term approach, choose that.
* Keep systems generalised rather than hardcoded.

---

# Standard Workflow Loop

This is the exact loop used for every feature.

### **Step 1 — Ewan identifies a task, issue, or feature**
Example: "The health bar isn't moving correctly."

### **Step 2 — Ewan describes it to ChatGPT**
ChatGPT responds with:
* Godot steps (if scene or UI work is required).
* A Cursor prompt (if script or documentation changes are required).

### **Step 3 — Ewan performs Godot steps exactly as written**
Node setup, textures, importing, UI fixes, collision configuration.

### **Step 4 — Ewan pastes the Cursor prompt into Cursor and reviews the diff**
Cursor applies the patch.

### **Step 5 — Ewan tests the results in Godot**
If something is wrong, Ewan reports it and the loop repeats.

---

# Division of Responsibilities

### ChatGPT

* System reasoning and design.
* Debugging.
* Planning new features.
* Providing detailed engine instructions.
* Writing all Cursor prompts.

### Cursor

* Applying code and documentation changes.
* Keeping edits isolated and safe.
* Ensuring the docs in `/docs` remain accurate and updated.
* Maintaining clean diffs and consistent behaviour.

### Godot

* Scene editing.
* UI layout and visual adjustments.
* Resource assignments.
* Running and testing the game.

---

# Rules for ChatGPT

When participating in development, ChatGPT must follow this pattern:

1. **Ewan asks a question.**
2. **ChatGPT replies** with explanations and instructions.
3. **If engine changes are needed**, ChatGPT provides clear, numbered Godot steps.
4. **If script or documentation changes are needed**, ChatGPT provides a Cursor prompt ready to paste.
5. **Ewan performs Godot steps and applies Cursor prompt.**
6. **Ewan tests and confirms** whether it behaves as expected.

ChatGPT should never suggest editing code directly in Godot and should never provide vague instructions. All edits must be repeatable, explicit, and safe.

---

# Example Cursor Prompt:

CURSOR PROMPT — Title of prompt goes here:

File to Edit: File to edit goes here
What needs doing: e.g "update the penetration raycast hit handling so a bullet can only apply damage to the same enemy once for its entire lifetime."

Requirements (as a minimum, always have these):
-Do NOT change existing inspector exports/settings.
-Only edit: document(s) to edit go here
-Any additional requirements

Rest of Prompt
---

# Summary

The workflow is:

1. **Talk to ChatGPT** for design, debugging, and instructions.
2. **Follow engine steps in Godot** for non-script tasks.
3. **Paste Cursor prompts** for script and documentation changes.
4. **Test results in Godot.**

This ensures consistent architecture, clean code, and predictable behaviour throughout the project.

---

This `workflow.md` file can evolve as the game scales.
