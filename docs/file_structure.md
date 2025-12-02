Shoot-To-Kill
│   .gitignore
│   file_tree.txt
│
├── docs
│       file_structure.md
│       gameplay_systems.md
│       project_index.md
│       todos.md
│
└── game
    │   .gitattributes
    │   .gitignore
    │   icon.svg
    │   project.godot
    │
    ├── Assets
    │   ├── Font
    │   │       origami-mommy.regular.ttf
    │   │
    │   ├── Sounds
    │   │       pistol_shot.mp3
    │   │
    │   └── Sprites
    │       ├── Enemy
    │       │       Demo Enemy.png
    │       │       EnemyHealthbar1Background.png
    │       │       EnemyHealthbar1Progress.png
    │       │       Healthbar1Empty.png
    │       │       Healthbar1Progress.png
    │       │
    │       ├── Guns
    │       │       Demo Bullet.png
    │       │       Demo Bullet2.png
    │       │       Demo Bullet3.png
    │       │       Demo Pistol.png
    │       │
    │       ├── Player
    │       │       Demo Guy.png
    │       │       Demo Guy (facing right).aseprite
    │       │       Demo Guy.aseprite
    │       │       PlayerHealthBarBackground.png
    │       │       PlayerHealthBarProgress.png
    │       │
    │       └── Tilesets
    │               Demo World 1.png
    │               Demo World 1.aseprite
    │
    ├── Assets
    │   ├── Font
    │   ├── Sounds
    │   │       Coin Pickup.mp3
    │   │       Money Bag Pickup.mp3
    │   │       Shop Purchase.mp3
    │   │       pistol_shot.mp3
    │   │
    │   └── Sprites
    │       ├── Enemy
    │       ├── Guns
    │       │       Demo AK.png
    │       │       Demo Bullet.png
    │       │       Demo Bullet2.png
    │       │       Demo Bullet3.png
    │       │       Demo Pistol.png
    │       ├── Pickups
    │       │       (coin sprites)
    │       ├── Player
    │       └── Tilesets
    │
    ├── Scenes
    │       bullet.tscn
    │       CoinGold.tscn
    │       CoinSilver.tscn
    │       crosshair.tscn
    │       damage_number.tscn
    │       EnemyBasic.tscn
    │       gun.tscn
    │       HUD.tscn
    │       level_01.tscn
    │       player.tscn
    │       Tavern.tscn
    │
    └── Scripts
        │   camera_2d.gd
        │   coin.gd
        │   crosshair.gd
        │   damage_number.gd
        │   game_manager.gd
        │   hud.gd
        │   player.gd
        │   tavern_bartender.gd
        │   tavern_run_door.gd
        │
        ├── enemies
        │       enemy.gd
        │
        └── weapons
                bullet.gd
                weapon_base.gd
                weapon_pistol.gd
