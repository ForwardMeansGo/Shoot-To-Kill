# File Structure — Shoot To Kill

## Root

C:\
└─ Shoot-To-Kill
   │  .gitignore
   │  file_tree.txt
   │
   ├─ docs/
   │   ├─ file_structure.md
   │   ├─ gameplay_systems.md
   │   ├─ project_index.md
   │   └─ todos.md
   │
   └─ game/
       │  .gitattributes
       │  .gitignore
       │  icon.svg
       │  icon.svg.import        # import metadata (ignored in future)
       │  project.godot
       │
       ├─ .godot/                # Godot editor/cache data (not tracked going forward)
       │   ... (editor + cache files)
       │
       ├─ Assets/
       │   ├─ Sounds/
       │   │   ├─ Pistol Sound effect(1).mp3.import
       │   │   ├─ Pistol Sound effect.mp4
       │   │   └─ pistol_shot.mp3          # main pistol SFX used in game
       │   │
       │   └─ Sprites/
       │       ├─ Enemy/
       │       │   ├─ Demo Enemy.png
       │       │   └─ Demo Enemy.png.import
       │       │
       │       ├─ Guns/
       │       │   ├─ Demo Bullet.png
       │       │   ├─ Demo Bullet.png.import
       │       │   ├─ Demo Bullet2.png
       │       │   ├─ Demo Bullet2.png.import
       │       │   ├─ Demo Bullet3.png
       │       │   ├─ Demo Bullet3.png.import
       │       │   ├─ Demo Pistol.png
       │       │   └─ Demo Pistol.png.import
       │       │
       │       ├─ Player/
       │       │   ├─ Demo Guy (facing right).aseprite
       │       │   ├─ Demo Guy.aseprite
       │       │   ├─ Demo Guy.png
       │       │   └─ Demo Guy.png.import
       │       │
       │       └─ Tilesets/
       │           ├─ Demo World 1.aseprite
       │           ├─ Demo World 1.png
       │           └─ Demo World 1.png.import
       │
       ├─ Scenes/
       │   ├─ bullet.tscn        # Bullet Area2D
       │   ├─ enemy.tscn         # Basic enemy CharacterBody2D
       │   ├─ gun.tscn           # Pistol weapon scene
       │   ├─ level_01.tscn      # Main test level
       │   └─ player.tscn        # Player CharacterBody2D
       │
       └─ Scripts/
           │  bullet.gd          # Bullet logic (raycast, damage, lifetime)
           │  bullet.gd.uid
           │  camera_2d.gd       # Camera shake logic
           │  camera_2d.gd.uid
           │  player.gd          # Player movement + aiming + weapon hookup
           │  player.gd.uid
           │
           ├─ enemies/
           │   ├─ enemy.gd       # Basic enemy movement + HP + death
           │   └─ enemy.gd.uid
           │
           └─ weapons/
               │  bullet.gd      # (check if this is used; name clashes with main bullet.gd)
               │  bullet.gd.uid
               │  weapon_base.gd   # Base weapon behaviour (aim, flip, spawn, sound, signal)
               │  weapon_base.gd.uid
               │  weapon_pistol.gd # Pistol-specific behaviour (semi-auto)
               │  weapon_pistol.gd.uid
