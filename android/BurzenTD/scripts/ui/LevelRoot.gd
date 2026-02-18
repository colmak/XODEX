# GODOT 4.6.1 STRICT – MOBILE HUD v0.02.0
extends CanvasLayer

class_name LevelRoot

signal tower_selected(selection: Dictionary)
signal tower_info_requested(selection: Dictionary)
signal pause_pressed
signal speed_changed(multiplier: float)
signal retry_pressed
signal settings_pressed
signal settings_changed(user_settings: Dictionary)
signal start_wave_pressed
signal tower_upgrade_requested(tower_index: int)
signal tower_sell_requested(tower_index: int, sell_value: int)

const SPEEDS: Array[float] = [1.0, 2.0, 3.0]
const INFO_AUTO_COLLAPSE_SECONDS: float = 4.0
const SAFE_MARGIN_FALLBACK: int = 18

var speed_mode: int = 0
var global_heat_ratio: float = 0.0
var info_visible_for: float = 0.0
var current_tower_index: int = -1
var pending_sell_confirm: bool = false
var current_sell_value: int = 0
var user_settings: Dictionary = {
	"show_grid_highlights": true,
	"high_contrast_mode": false,
	"color_scheme": "Default Dark Lab",
	"heat_gradient_style": "Standard",
	"grid_opacity": 0.25,
}

@onready var safe_area_root: Control = %SafeAreaRoot
@onready var top_section: Control = %TopSection
@onready var wave_label: Label = %WaveLabel
@onready var lives_label: Label = %LivesLabel
@onready var credits_label: Label = %CreditsLabel
@onready var status_label: Label = %StatusLabel
@onready var wave_preview_panel: PanelContainer = %WavePreviewPanel
@onready var wave_preview_label: RichTextLabel = %WavePreviewLabel
@onready var wave_preview_toggle_button: Button = %WavePreviewToggleButton
@onready var tower_selection_panel: Control = %TowerSelectionPanel
@onready var place_tower_button: Button = %PlaceTowerButton
@onready var upgrade_info_button: Button = %UpgradeInfoButton
@onready var sell_button: Button = %SellButton
@onready var speed_button: Button = %SpeedButton
@onready var pause_button: Button = %PauseButton
@onready var tower_info_panel: PanelContainer = %TowerInfoPanel
@onready var tower_info_label: RichTextLabel = %TowerInfoLabel
@onready var tower_upgrade_button: Button = %TowerUpgradeButton
@onready var tower_sell_button: Button = %TowerSellButton
@onready var pause_modal: PanelContainer = %PauseModal
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	place_tower_button.pressed.connect(_on_place_tower_pressed)
	upgrade_info_button.pressed.connect(_on_upgrade_info_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	tower_upgrade_button.pressed.connect(_on_upgrade_pressed)
	tower_sell_button.pressed.connect(_on_sell_pressed)
	wave_preview_toggle_button.pressed.connect(_on_toggle_wave_preview)
	resume_button.pressed.connect(_on_pause_pressed)
	settings_button.pressed.connect(func() -> void: emit_signal("settings_pressed"))
	quit_button.pressed.connect(func() -> void: emit_signal("retry_pressed"))
	tower_selection_panel.connect("tower_card_pressed", func(selection: Dictionary) -> void: emit_signal("tower_selected", selection))
	tower_selection_panel.connect("tower_card_long_pressed", func(selection: Dictionary) -> void: emit_signal("tower_info_requested", selection))
	for button: Button in [place_tower_button, upgrade_info_button, sell_button, speed_button, pause_button, tower_upgrade_button, tower_sell_button, resume_button, settings_button, quit_button, wave_preview_toggle_button]:
		button.button_down.connect(func() -> void: _pulse_button(button, 0.94))
		button.button_up.connect(func() -> void: _pulse_button(button, 1.0))
	tower_info_panel.visible = false
	pause_modal.visible = false
	_apply_safe_area_layout()
	emit_signal("settings_changed", get_user_settings())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_safe_area_layout()

func _process(delta: float) -> void:
	if tower_info_panel.visible:
		info_visible_for += delta
		if info_visible_for >= INFO_AUTO_COLLAPSE_SECONDS:
			hide_tower_info()

func _pulse_button(button: Button, target_scale: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * target_scale, 0.08)

func _apply_safe_area_layout() -> void:
	var fallback: Vector2 = Vector2(SAFE_MARGIN_FALLBACK, SAFE_MARGIN_FALLBACK)
	var insets: Vector4 = Vector4(fallback.x, fallback.y, fallback.x, fallback.y)
	if DisplayServer.has_method("get_display_safe_area"):
		var safe_rect_variant: Variant = DisplayServer.call("get_display_safe_area")
		if safe_rect_variant is Rect2i:
			var safe_rect: Rect2i = safe_rect_variant
			var viewport_rect: Rect2 = get_viewport().get_visible_rect()
			insets.x = maxf(float(safe_rect.position.x), fallback.x)
			insets.y = maxf(float(safe_rect.position.y), fallback.y)
			insets.z = maxf(viewport_rect.size.x - float(safe_rect.end.x), fallback.x)
			insets.w = maxf(viewport_rect.size.y - float(safe_rect.end.y), fallback.y)
	safe_area_root.offset_left = insets.x
	safe_area_root.offset_top = insets.y
	safe_area_root.offset_right = -insets.z
	safe_area_root.offset_bottom = -insets.w

func get_arena_rect() -> Rect2:
	return top_section.get_global_rect()

func get_user_settings() -> Dictionary:
	return user_settings.duplicate(true)

func configure_towers(next_heat_ratio: float, unlocked_towers: Array[String]) -> void:
	global_heat_ratio = next_heat_ratio
	tower_selection_panel.call("configure", next_heat_ratio, unlocked_towers)

func set_metrics(wave: int, wave_total: int, enemies_alive: int, enemies_total: int, lives: int, heat_ratio: float) -> void:
	global_heat_ratio = heat_ratio
	var defeated: int = maxi(enemies_total - enemies_alive, 0)
	wave_label.text = "🌊 %d/%d  •  %d/%d" % [wave, wave_total, defeated, enemies_total]
	lives_label.text = "♥ %d" % max(lives, 0)
	var heat_budget: int = int(round(100.0 * heat_ratio))
	credits_label.text = "⚗ %d" % max(0, 100 - heat_budget)
	if lives <= 2:
		lives_label.modulate = Color(1.0, 0.5, 0.5)
	else:
		lives_label.modulate = Color(1.0, 1.0, 1.0)

func set_wave_preview(icons_text: String, forecast: String) -> void:
	wave_preview_label.text = "[b]Next Wave[/b]\n%s\n%s" % [icons_text, forecast]

func set_status(message: String) -> void:
	status_label.text = message

func configure_pre_wave_overlay(show_overlay: bool, dismissable: bool) -> void:
	if show_overlay:
		pause_modal.visible = true
		resume_button.visible = dismissable

func set_pre_wave_visible(visible_state: bool) -> void:
	pause_modal.visible = visible_state

func show_tower_info(tower_index: int, tower_data: Dictionary) -> void:
	current_tower_index = tower_index
	pending_sell_confirm = false
	current_sell_value = int(round(float(tower_data.get("build_cost", 18)) * 0.7))
	var heat_gen: float = float(tower_data.get("heat_gen_rate", 0.0))
	var title: String = str(tower_data.get("display_name", tower_data.get("tower_id", "Residue")))
	var pulse: String = str(tower_data.get("folding_role", "Pulse"))
	var dps: float = 47.0 * (1.0 + maxf(0.0, float(tower_data.get("heat_tolerance_value", 0.8)) - 0.7))
	var fire_rate: float = 1.0 + heat_gen * 0.25
	var range: float = float(tower_data.get("radius", 180.0))
	var upgrade_cost: int = int(round(16.0 + heat_gen * 8.0))
	tower_upgrade_button.text = "Upgrade (+12 DPS) • %d⚗" % upgrade_cost
	tower_sell_button.text = "Sell • %d⚗" % current_sell_value
	tower_info_label.text = "[b]%s[/b]\nDMG 47 | Rate %.2f | Range %.0f\nDPS %.1f\nEffect: %s\nPath A: Stability (+Range)\nPath B: Burst (+Rate)" % [title, fire_rate, range, dps, pulse]
	tower_info_panel.visible = true
	info_visible_for = 0.0

func hide_tower_info() -> void:
	tower_info_panel.visible = false
	current_tower_index = -1
	pending_sell_confirm = false
	info_visible_for = 0.0

func _on_pause_pressed() -> void:
	pause_modal.visible = not pause_modal.visible
	emit_signal("pause_pressed")

func _on_place_tower_pressed() -> void:
	tower_selection_panel.call("set_collapse_highlight", true)
	set_status("Choose a tower card, then drag on map to place.")

func _on_upgrade_info_pressed() -> void:
	if current_tower_index >= 0:
		_on_upgrade_pressed()
	else:
		set_status("Tap a placed tower to inspect upgrade paths.")

func _on_sell_pressed() -> void:
	if current_tower_index < 0:
		set_status("Tap a tower first to sell it.")
		return
	if not pending_sell_confirm:
		pending_sell_confirm = true
		set_status("Tap Sell again to confirm (%d⚗ refund)." % current_sell_value)
		tower_sell_button.modulate = Color(1.0, 0.55, 0.55)
		return
	tower_sell_button.modulate = Color(1.0, 1.0, 1.0)
	pending_sell_confirm = false
	emit_signal("tower_sell_requested", current_tower_index, current_sell_value)
	hide_tower_info()

func _on_upgrade_pressed() -> void:
	if current_tower_index < 0:
		return
	emit_signal("tower_upgrade_requested", current_tower_index)
	info_visible_for = 0.0

func _on_speed_pressed() -> void:
	speed_mode = (speed_mode + 1) % SPEEDS.size()
	var speed: float = SPEEDS[speed_mode]
	speed_button.text = "x%.0f" % speed
	emit_signal("speed_changed", speed)

func _on_toggle_wave_preview() -> void:
	wave_preview_panel.visible = not wave_preview_panel.visible
	wave_preview_toggle_button.text = "Wave ▸" if not wave_preview_panel.visible else "Wave ▾"
