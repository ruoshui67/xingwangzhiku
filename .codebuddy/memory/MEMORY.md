# Project Memory

## Tech Stack
- Godot 4, GDScript
- 3D RPG game with click-to-move

## Architecture
- `Interactable` base → `Npc`, `Item(Pickable, DialogItem(Door))`
- `BasePlayer` base → `Player`, `Player2` (2026-06-16 恢复)
- Wall transparency: ray-cast from camera to player
- DeepSeek API for journal reasoning (journal_panel.gd)

## Key Systems
- Main Menu (MainMenu.tscn): 新游戏/继续游戏/设置/退出游戏 at bottom-left
- Backpack (B key), Journal (J key), Skills (TAB), Settings (ESC)
- TopBar toolbar: mouse-click panel switching (toolbar.gd)
- NPC dialogue with dice mini-game
- Door locked → needs key to unlock
- Pause menu: 返回主菜单 + 退出游戏 buttons

## File Structure
- MainMenu.tscn → MainMenu.gd (entry scene, project.godot)
- Main.tscn → game scene (Player1, Player2, NPCs, UI)
- Shadow: Sprite3D child node on chars, ray-casted to ground

## Conventions
- Wall texture loaded via code (load()), not tscn surface_material_override (causes crash)
- `surface_material_override/0` in tscn is NOT supported, causes crash
- FBX animations from Mixamo often named "mixamo_com"
- `editable_children = true` needed on instanced scenes to add child nodes
- Background image replacement: assign texture to BgImage in MainMenu
