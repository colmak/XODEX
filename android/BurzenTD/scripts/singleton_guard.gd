# GODOT 4.6.1 STRICT – SINGLETON ARCHITECTURE FIXED – v0.00.6.1
extends Node

func assert_singleton_ready(singleton_name: String, context: String = "") -> bool:
	var root: Node = get_tree().root
	var node: Node = root.get_node_or_null(singleton_name)
	if node == null:
		push_error("[SingletonGuard] Missing autoload singleton '%s' before access (%s)." % [singleton_name, context])
		return false
	if not node.is_node_ready():
		push_error("[SingletonGuard] Autoload singleton '%s' accessed before ready (%s)." % [singleton_name, context])
		return false
	return true
