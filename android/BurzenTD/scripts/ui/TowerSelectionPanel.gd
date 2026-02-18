# GODOT 4.6.1 STRICT – FINAL TYPE FIX v0.00.9.5 – NO CLASS_NAME
extends Control


signal tower_card_pressed(selection: Dictionary)
signal tower_card_long_pressed(selection: Dictionary)

const LONG_PRESS_SECONDS: float = 0.45
const CARD_MIN_SIZE: Vector2 = Vector2(140.0, 200.0)
const TOWER_DEFINITIONS_PATH: String = "res://data/towers/tower_definitions.json"

var module: TowerSelectionUI
var cards: Dictionary = {}
var active_press_id: String = ""
var press_elapsed: float = 0.0
var long_press_fired: bool = false
var is_collapsed: bool = false
var language_code: String = "EN"
var last_global_heat_ratio: float = 0.0
var last_unlocked_towers: Array[String] = []

@onready var collapse_button: Button = %CollapseButton
@onready var content: VBoxContainer = %Content
@onready var card_container: BoxContainer = %CardContainer

func _ready() -> void:
	module = TowerSelectionUI.new()
	add_child(module)
	module.hide()
	collapse_button.pressed.connect(_on_collapse_pressed)
	_set_collapsed(false)
	set_process(true)

func configure(global_heat_ratio: float, unlocked_towers: Array[String]) -> void:
	last_global_heat_ratio = global_heat_ratio
	last_unlocked_towers = unlocked_towers.duplicate()
	_refresh_cards()

func _refresh_cards() -> void:
	for child: Node in card_container.get_children():
		child.queue_free()
	cards.clear()
	var visible: Array[Dictionary] = _load_all_tower_definitions()
	if visible.is_empty():
		visible = module.visible_catalog(last_global_heat_ratio, last_unlocked_towers)
	if visible.is_empty():
		visible = module.catalog
	for entry: Dictionary in visible:
		_create_card(entry, last_global_heat_ratio)

func _create_card(entry: Dictionary, global_heat_ratio: float) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_FILL
	var vbox: VBoxContainer = VBoxContainer.new()
	card.add_child(vbox)
	var shape: String = str(Dictionary(entry.get("visuals", {})).get("shape", "circle"))
	var icon_texture: Texture2D = _resolve_tower_texture(str(entry.get("tower_id", "")), entry)
	if icon_texture != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(112.0, 84.0)
		vbox.add_child(icon_rect)
	else:
		var icon: Label = Label.new()
		icon.text = _shape_glyph(shape)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.modulate = Color(0.75, 0.92, 1.0, 1.0)
		icon.add_theme_font_size_override("font_size", 38)
		vbox.add_child(icon)
	var title: Label = Label.new()
	title.text = "%s\n%s\n%s" % [str(entry.get("display_name", "")), str(entry.get("display_name_zh", "")), str(entry.get("display_name_ru", ""))]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color("e0e0e0")
	vbox.add_child(title)
	card.self_modulate = Color("1e3a52")
	var role: Label = Label.new()
	role.text = str(entry.get("folding_role", ""))
	role.modulate = Color(0.75, 0.85, 1.0, 1.0)
	vbox.add_child(role)
	var stats: Label = Label.new()
	stats.text = "Cost %d | Heat %.2f | Tol %.2f" % [int(entry.get("build_cost", 0)), float(entry.get("heat_gen_rate", 0.0)), float(entry.get("heat_tolerance_value", 0.0))]
	stats.modulate = Color(0.85, 0.95, 0.82, 1.0)
	vbox.add_child(stats)
	var heat_bar: ProgressBar = ProgressBar.new()
	heat_bar.min_value = 0.0
	heat_bar.max_value = 1.5
	heat_bar.value = float(entry.get("tower_heat_gen", entry.get("heat_gen_rate", 0.0)))
	heat_bar.show_percentage = false
	vbox.add_child(heat_bar)
	var tolerance_bar: ProgressBar = ProgressBar.new()
	tolerance_bar.min_value = 0.0
	tolerance_bar.max_value = 1.5
	tolerance_bar.value = float(entry.get("tower_heat_tol", entry.get("heat_tolerance_value", 0.0)))
	tolerance_bar.show_percentage = false
	vbox.add_child(tolerance_bar)
	card.tooltip_text = str(entry.get("tooltip", ""))
	if _is_recommended(entry, global_heat_ratio):
		var badge: Label = Label.new()
		badge.text = "Recommended"
		badge.modulate = Color(0.5, 1.0, 0.6, 1.0)
		vbox.add_child(badge)
	card.gui_input.connect(func(event: InputEvent) -> void:
		_handle_card_input(event, str(entry.get("tower_id", "")), entry)
	)
	card_container.add_child(card)
	cards[str(entry.get("tower_id", ""))] = card

func _shape_glyph(shape: String) -> String:
	match shape:
		"circle":
			return "●"
		"rounded_square":
			return "▣"
		"triangle_up":
			return "▲"
		"triangle_down":
			return "▼"
		"diamond":
			return "◆"
		"oval":
			return "⬭"
		"rectangle":
			return "▬"
		"pentagon":
			return "⬟"
		_:
			return "◉"

func _is_recommended(entry: Dictionary, global_heat_ratio: float) -> bool:
	var heat_gen: float = float(entry.get("heat_gen_rate", 0.0))
	var tolerance: float = float(entry.get("heat_tolerance_value", 0.7))
	if global_heat_ratio > 0.6:
		return tolerance >= 0.95 or heat_gen <= 0.4
	return tolerance >= 0.7 and heat_gen <= 1.0

func _handle_card_input(event: InputEvent, tower_id: String, entry: Dictionary) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			active_press_id = tower_id
			press_elapsed = 0.0
			long_press_fired = false
		else:
			if active_press_id == tower_id and not long_press_fired:
				module.select_tower(tower_id)
				emit_signal("tower_card_pressed", entry.duplicate(true))
			active_press_id = ""
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			module.select_tower(tower_id)
			emit_signal("tower_card_pressed", entry.duplicate(true))

func _process(delta: float) -> void:
	if active_press_id.is_empty():
		return
	press_elapsed += delta
	if press_elapsed >= LONG_PRESS_SECONDS and not long_press_fired:
		long_press_fired = true
		var selected: Dictionary = module.select_tower(active_press_id)
		emit_signal("tower_card_long_pressed", selected)

func _on_collapse_pressed() -> void:
	_set_collapsed(not is_collapsed)

func _set_collapsed(next_collapsed: bool) -> void:
	is_collapsed = next_collapsed
	content.visible = not is_collapsed
	collapse_button.text = "▼ Towers" if is_collapsed else "▲ Towers"
	if not is_collapsed:
		_refresh_cards()

func set_collapse_highlight(enabled: bool) -> void:
	if enabled:
		collapse_button.modulate = Color(1.0, 0.95, 0.4, 1.0)
	else:
		collapse_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_language(next_language: String) -> void:
	language_code = next_language.to_upper()

func _localized_title(entry: Dictionary) -> String:
	if language_code == "CN":
		return str(entry.get("display_name_zh", entry.get("display_name", "Tower")))
	if language_code == "RU":
		return str(entry.get("display_name_ru", entry.get("display_name", "Tower")))
	return str(entry.get("display_name", "Tower"))

func _resolve_tower_texture(tower_id: String, entry: Dictionary) -> Texture2D:
	var visuals: Dictionary = Dictionary(entry.get("visuals", {}))
	var explicit_path: String = str(visuals.get("icon_path", ""))
	if not explicit_path.is_empty() and ResourceLoader.exists(explicit_path):
		return load(explicit_path) as Texture2D
	return null

func _load_all_tower_definitions() -> Array[Dictionary]:
	return TowerSchema.load_catalog(TOWER_DEFINITIONS_PATH)
