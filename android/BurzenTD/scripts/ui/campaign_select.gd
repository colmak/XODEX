# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.6
extends Control

func _on_back_pressed() -> void:
	LevelManager.return_to_menu()

func _on_level_pressed(level_id: String) -> void:
	LevelManager.start_demo_level(level_id)
