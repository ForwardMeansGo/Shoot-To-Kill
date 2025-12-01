# Development Workflow Guide

This document explains the current workflow for building **Shoot-To-Kill**, describing exactly how tasks flow between **Ewan**, **ChatGPT**, **Godot**, and **Cursor**.

This workflow keeps development fast, clean, and scalable.

---

# 🧩 1. Overall Development Philosophy

We keep **reasoning and ideas separate from code editing**.

* **ChatGPT** is used for planning, debugging, architecture, gameplay design, and explaining systems.
* **Cursor** is used for precise, safe editing of the codebase.
* **Godot** is used for engine-side changes such as node setup, scenes, UI layout, textures, and visual adjustments.

This ensures minimal breakage and maximum clarity.

When implementing a new system, the future of the game always needs to be considered. No bandage fixes. If there is a better, more future proof way to implement something, we do it that way, whilst always keeping things modular (if we can).

---

# 🧠 2. Role of ChatGPT

Ewan speaks to ChatGPT for anything involving:

### ✔ System design

Gameplay systems, health logic, crit system, HUD architecture, enemy AI, damage pipeline, projectile systems (and anything similar)

### ✔ Debugging

Figuring out why something is breaking or behaving strangely.

### ✔ Explaining issues

E.g., why the health bar didn’t move, why textures behave a certain way, how Godot nodes interact.

### ✔ Planning and architecture

Whether a new system should be its own scene, its own script, handled by signals, etc.

### ✔ Godot engine instructions

ChatGPT tells Ewan exactly:

* What nodes to add
* What to rename
* What collision layers/masks to use
* How to assign textures
* What settings to toggle (offset, stretch, import options, etc.)

ChatGPT produces **clear, step-by-step Godot instructions with as much detail in steps as possible**.

---

# 🛠️ 3. Role of Cursor

Cursor handles all **script changes**, because it applies:

* Diffs
* Patch previews
* Safe code edits
* Multi-file changes

ChatGPT provides a **Cursor-formatted prompt**, and Cursor handles the actual patching.

### ✔ When a script must be changed:

ChatGPT writes a full "Cursor prompt" that includes:

* What files to modify
* What functions to create, replace, or extend
* Exact behaviour required
* What NOT to touch

Ewan pastes the prompt into Cursor.
Cursor shows the patch.
Ewan reviews and clicks **Apply Patch**.

This guarantees:

* Clean diffs
* No accidental breakage
* Repeatable behaviour

---

# 🎮 4. Role of Godot

Godot is used for putting things together and creating the game as a whole. From ewans POV, he doesnt really work on scripts themsevles inside of GoDot:

Running the game to confirm behaviour.

Whenever ChatGPT instructs something engine-side, Ewan completes it directly in Godot.

---

# 🔁 5. Workflow Loop (Step-by-Step)

This is the exact loop used for every feature.

### **Step 1 — Ewan identifies a task or issue**

Example: “The health bar isn’t moving correctly.”

### **Step 2 — Ewan describes it to ChatGPT**

ChatGPT diagnoses and explains the cause.

### **Step 3 — ChatGPT provides:**

* Godot steps
* Cursor prompt (if script changes needed)

### **Step 4 — Ewan performs Godot steps**

Node setup, textures, importing, UI fixes, collision configuration.

### **Step 5 — Ewan copies Cursor prompt into Cursor**

Cursor applies patch.

### **Step 6 — Ewan tests in Godot**

Everything loops back from there.

---

# 📂 6. Division of Responsibilities

### ChatGPT

* System reasoning
* Debugging
* Planning new features
* Godot instructions
* Writing Cursor prompts

### Cursor

* Applying code patches
* Safely editing scripts
* Showing diffs
* Keeping code stable

### Godot

* Scene editing
* UI setup
* Resource assignment
* Running tests
* Creating the game

---

# ⭐ 7. Why This Workflow Works

* ChatGPT does the thinking.
* Cursor does the coding.
* Godot handles the visuals.
* Ewan stays fully in control.

This produces:

* Clean code
* Predictable behaviour
* Zero overwritten work
* Fast iteration
* No architecture mistakes

---

# Summary

The workflow is:

1. **Talk to ChatGPT** for design, debugging, and instructions.
2. **Follow engine steps in Godot** for non-script tasks.
3. **Paste Cursor prompts** for script changes.
4. **Test in Godot**.

This is for CHATGPT to follow:

1. Ewan asks question
2. ChatGPT replies
2.A If changes required in GoDot, ChatGPT provides step by step, detailed instructions for Ewan to follow to action these changes
2.B If a script change is required ChatGPT ALWAYS provide a cursor prompt for ewan to give cursor to safely implement these changes/update the script
3. Ewan Tests in GoDot and gives the goahead if the change has been successful/behaves as expected
That’s the full development pipeline.

---

This `workflow.md` file can evolve as the game scales
