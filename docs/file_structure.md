# File Structure — Shoot To Kill

## Root

Shoot-To-Kill/
├─ game/
│  ├─ project.godot
│  ├─ assets/
│  │  ├─ sounds/
│  │  │  └─ pistol_shot.mp3   # pistol SFX (name may differ, update as needed)
│  │  └─ sprites/            # player, gun, enemy, tiles, etc.
│  ├─ scenes/
│  │  ├─ Level_01.tscn
│  │  ├─ Player.tscn
│  │  ├─ Gun.tscn
│  │  ├─ Bullet.tscn
│  │  └─ EnemyBasic.tscn
│  ├─ scripts/
│  │  ├─ player.gd
│  │  ├─ bullet.gd
│  │  ├─ camera_2d.gd
│  │  ├─ enemies/
│  │  │  └─ enemy_basic.gd
│  │  └─ weapons/
│  │     ├─ weapon_base.gd
│  │     └─ weapon_pistol.gd
│  └─ (other Godot files/folders)
└─ docs/
   ├─ project_index.md
   ├─ file_structure.md
   ├─ gameplay_systems.md
   └─ todos.md
