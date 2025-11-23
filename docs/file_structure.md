# File Structure — Shoot To Kill (Updated)

Shoot-To-Kill/
│
├── game/
│   ├── project.godot
│   ├── assets/
│   │   ├── sounds/
│   │   │     └── pistol_shot.mp3
│   │   └── sprites/
│   │         └── (player, guns, enemies, tiles, UI)
│   │
│   ├── scenes/
│   │   ├── Level_01.tscn
│   │   ├── Player.tscn
│   │   ├── Gun.tscn
│   │   ├── Bullet.tscn
│   │   ├── EnemyBasic.tscn
│   │   └── DamageNumber.tscn
│   │
│   ├── scripts/
│   │   ├── player.gd
│   │   ├── bullet.gd
│   │   ├── camera_2d.gd
│   │   ├── damage_number.gd
│   │   ├── enemies/
│   │   │     └── enemy.gd
│   │   └── weapons/
│   │         ├── weapon_base.gd
│   │         └── weapon_pistol.gd
│   │
│   └── other Godot files...
│
└── docs/
    ├── project_index.md
    ├── gameplay_systems.md
    ├── todos.md
    └── file_structure.md
