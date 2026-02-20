extends Control

class_name LevelProgressBar

const NODE_COUNT: int = 10

@onready var node_row: HBoxContainer = %NodeRow

func _ready() -> void:
	if node_row.get_child_count() == 0:
		for i: int in range(NODE_COUNT):
			var node: ColorRect = ColorRect.new()
			node.custom_minimum_size = Vector2(18.0, 18.0)
			node.color = Color(0.2, 0.2, 0.2, 0.9)
			node.name = "Node_%02d" % (i + 1)
			node_row.add_child(node)

func update_progress(current_level: int, completed_levels: int) -> void:
	for i: int in range(node_row.get_child_count()):
		var node: ColorRect = node_row.get_child(i) as ColorRect
		if node == null:
			continue
		if i < completed_levels:
			node.color = Color(0.1, 0.8, 0.2, 1.0)
		elif i + 1 == current_level:
			node.color = Color(1.0, 0.85, 0.15, 1.0)
		else:
			node.color = Color(0.2, 0.2, 0.2, 0.9)
