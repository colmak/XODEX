extends Control

const GRID_SIZE := 48.0
const PATH_SAFE_DISTANCE := 72.0
const MIN_HEAT_DAMAGE_SCALE := 0.35

@onready var tower_menu: Tree = %TowerMenu
@onready var tower_detail_label: Label = %TowerDetailLabel
@onready var mob_overlay_label: Label = %MobOverlayLabel
@onready var safety_state_label: Label = %SafetyStateLabel
@onready var placement_hint_label: Label = %PlacementHintLabel
@onready var settings_popup: PopupPanel = %SettingsPopup
@onready var snap_to_grid_check: CheckBox = %SnapToGridCheck

var selected_tower_id := ""
var snap_to_grid := true
var placed_towers: Array[Dictionary] = []
var wave_index := 1
var level_index := 1
var rng := RandomNumberGenerator.new()
var current_terrain := {
	"id": "baseline",
	"label": "Baseline Causeway",
	"damage_mult": 1.0,
	"heat_bias": 0.0,
}
var path_points := PackedVector2Array([
	Vector2(90, 220),
	Vector2(460, 220),
	Vector2(460, 520),
	Vector2(860, 520),
	Vector2(860, 790),
	Vector2(1200, 790),
])

var tower_catalog := {
	"geometric": [
		{"id": "triangle", "label": "△ Triangle", "dps": 42, "range": 150, "cooldown": 1.2, "special": "Burst damage vs clustered mobs.", "targeting": "Closest", "heat_scale": 0.24, "replacements": ["square", "fire"]},
		{"id": "square", "label": "▢ Square", "dps": 28, "range": 180, "cooldown": 0.8, "special": "Balanced fire; can apply slow.", "targeting": "Highest HP", "heat_scale": 0.16, "replacements": ["triangle", "water"]},
		{"id": "rectangle", "label": "▭ Rectangle", "dps": 24, "range": 260, "cooldown": 1.0, "special": "Long corridor pressure tower.", "targeting": "First", "heat_scale": 0.12, "replacements": ["air", "zhe"]},
	],
	"elemental": [
		{"id": "fire", "label": "火 Fire", "dps": 34, "range": 170, "cooldown": 0.9, "special": "Burn DoT and 1.5x AoE splash.", "targeting": "Clustered", "heat_scale": 0.08, "replacements": ["earth", "triangle"]},
		{"id": "water", "label": "水 Water", "dps": 21, "range": 200, "cooldown": 0.7, "special": "Slow aura and single-target control.", "targeting": "Fastest", "heat_scale": 0.06, "replacements": ["fire", "air"]},
		{"id": "earth", "label": "土 Earth", "dps": 26, "range": 165, "cooldown": 1.1, "special": "Armor break + adjacency durability.", "targeting": "Highest Armor", "heat_scale": 0.1, "replacements": ["square", "zhe"]},
		{"id": "air", "label": "风 Air", "dps": 25, "range": 220, "cooldown": 0.6, "special": "Fast projectile + knockback.", "targeting": "First", "heat_scale": 0.15, "replacements": ["water", "rectangle"]},
	],
	"keystone": [
		{"id": "zhe", "label": "Ж Keystone", "dps": 18, "range": 210, "cooldown": 1.8, "special": "Buff aura + periodic adjacent shield.", "targeting": "Support", "heat_scale": 0.05, "replacements": ["earth", "rectangle"]},
	],
}

var terrain_profiles := [
	{"id": "baseline", "label": "Baseline Causeway", "damage_mult": 1.0, "heat_bias": 0.0},
	{"id": "ash_dunes", "label": "Ash Dunes", "damage_mult": 0.92, "heat_bias": 0.18},
	{"id": "frost_lane", "label": "Frost Lane", "damage_mult": 1.08, "heat_bias": -0.12},
	{"id": "ion_plateau", "label": "Ion Plateau", "damage_mult": 1.02, "heat_bias": 0.05},
]

var mob_archetypes := [
	{"id": "runner", "hp": 80.0, "armor": 8.0, "speed": 1.45, "heat": 0.22},
	{"id": "tank", "hp": 210.0, "armor": 28.0, "speed": 0.72, "heat": 0.55},
	{"id": "swarm", "hp": 62.0, "armor": 5.0, "speed": 1.65, "heat": 0.34},
	{"id": "ember", "hp": 130.0, "armor": 14.0, "speed": 1.12, "heat": 0.75},
]

func _ready() -> void:
	rng.randomize()
	tower_menu.columns = 2
	tower_menu.set_column_title(0, "Tower")
	tower_menu.set_column_title(1, "DPS")
	tower_menu.column_titles_visible = true
	_rebuild_tower_menu()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.position.y > 96.0 and event.position.y < size.y - 160.0 and event.position.x < size.x - 392.0:
			_try_place_tower(event.position)

func _rebuild_tower_menu() -> void:
	tower_menu.clear()
	var root := tower_menu.create_item()
	_add_tower_group(root, "Geometric", tower_catalog["geometric"])
	_add_tower_group(root, "Elemental", tower_catalog["elemental"])
	_add_tower_group(root, "Keystone", tower_catalog["keystone"])

func _add_tower_group(root: TreeItem, title: String, entries: Array) -> void:
	var group := tower_menu.create_item(root)
	group.set_text(0, title)
	group.collapsed = false
	for entry in entries:
		var item := tower_menu.create_item(group)
		item.set_text(0, entry["label"])
		item.set_text(1, str(entry["dps"]))
		item.set_metadata(0, entry)

func _on_tower_menu_item_selected() -> void:
	var item := tower_menu.get_selected()
	if item == null:
		return
	var meta = item.get_metadata(0)
	if meta == null:
		return
	selected_tower_id = str(meta["id"])
	var replacement_labels: Array[String] = []
	for replacement_id in meta["replacements"]:
		replacement_labels.append(str(replacement_id))
	tower_detail_label.text = "[%s]\nDPS %d | Range %d | CD %.2fs\n%s" % [
		meta["label"],
		meta["dps"],
		meta["range"],
		meta["cooldown"],
		"Target %s | Replace %s\n%s" % [
			meta["targeting"],
			", ".join(replacement_labels),
			meta["special"],
		],
	]
	placement_hint_label.text = "Selected %s. Click in world to place." % meta["label"]

func _try_place_tower(raw_position: Vector2) -> void:
	if selected_tower_id.is_empty():
		safety_state_label.text = "NESOROX Safety: Waiting for tower selection"
		return
	var target := raw_position
	if snap_to_grid:
		target = Vector2(round(target.x / GRID_SIZE) * GRID_SIZE, round(target.y / GRID_SIZE) * GRID_SIZE)
	for tower in placed_towers:
		if tower["pos"].distance_to(target) < 56.0:
			safety_state_label.text = "NESOROX Safety: overlap violation; placement reverted"
			return
	if _distance_to_path(target) < PATH_SAFE_DISTANCE:
		safety_state_label.text = "NESOROX Safety: pathing violation; placement reverted"
		return
	placed_towers.append({"id": selected_tower_id, "pos": target})
	safety_state_label.text = "NESOROX Safety: Stable"
	mob_overlay_label.text = "Mob Overlay: HP %d | Armor %d | Speed %.2f" % [120 + placed_towers.size() * 5, 14 + placed_towers.size(), 1.0 + placed_towers.size() * 0.03]
	queue_redraw()

func _distance_to_path(pos: Vector2) -> float:
	var closest := INF
	for i in range(path_points.size() - 1):
		var projected := Geometry2D.get_closest_point_to_segment(pos, path_points[i], path_points[i + 1])
		closest = min(closest, pos.distance_to(projected))
	return closest

func _on_settings_button_pressed() -> void:
	settings_popup.popup_centered()

func _on_snap_toggled(button_pressed: bool) -> void:
	snap_to_grid = button_pressed

func _on_simulate_wave_pressed() -> void:
	var mobs := _generate_wave_mobs(level_index, wave_index)
	var sim := _simulate_tower_damage(mobs)
	mob_overlay_label.text = "Mob Overlay: %s | terrain %s | kills %d/%d | remHP %d" % [
		sim["composition"],
		current_terrain["id"],
		sim["kills"],
		mobs.size(),
		int(sim["remaining_hp"]),
	]
	wave_index += 1

func _on_clear_placements_pressed() -> void:
	placed_towers.clear()
	wave_index = 1
	safety_state_label.text = "NESOROX Safety: Stable (baseline restored)"
	mob_overlay_label.text = "Mob Overlay: HP 120 | Armor 14 | Speed 1.0"
	queue_redraw()

func _find_tower_entry(tower_id: String) -> Dictionary:
	for group in tower_catalog.values():
		for tower in group:
			if tower["id"] == tower_id:
				return tower
	return {}

func _generate_wave_mobs(level: int, wave: int) -> Array[Dictionary]:
	current_terrain = terrain_profiles[rng.randi_range(0, terrain_profiles.size() - 1)]
	var mobs: Array[Dictionary] = []
	var count := 5 + level + int(wave * 0.75)
	for i in range(count):
		var archetype: Dictionary = mob_archetypes[rng.randi_range(0, mob_archetypes.size() - 1)]
		var hp_scale := 1.0 + 0.13 * float(wave - 1)
		var armor_scale := 1.0 + 0.08 * float(level - 1)
		mobs.append({
			"id": archetype["id"],
			"hp": archetype["hp"] * hp_scale,
			"armor": archetype["armor"] * armor_scale,
			"speed": archetype["speed"],
			"heat": clamp(archetype["heat"] + current_terrain["heat_bias"], 0.0, 1.0),
		})
	return mobs

func _simulate_tower_damage(mobs: Array[Dictionary]) -> Dictionary:
	if placed_towers.is_empty():
		return {"kills": 0, "remaining_hp": _sum_hp(mobs), "composition": _mob_mix(mobs)}
	var total_dps := 0.0
	for placed in placed_towers:
		var tower := _find_tower_entry(placed["id"])
		if tower.is_empty():
			continue
		total_dps += float(tower["dps"])
	var kills := 0
	var remaining_hp := 0.0
	for mob in mobs:
		var heat := float(mob["heat"])
		var mean_heat_scale := 1.0
		for placed in placed_towers:
			var tower := _find_tower_entry(placed["id"])
			if tower.is_empty():
				continue
			mean_heat_scale *= clamp(1.0 - heat * float(tower["heat_scale"]), MIN_HEAT_DAMAGE_SCALE, 1.0)
		var armor_reduction: float = maxf(0.2, 1.0 - float(mob["armor"]) / 100.0)
		var dealt: float = total_dps * mean_heat_scale * armor_reduction * float(current_terrain["damage_mult"])
		var hp_left: float = maxf(0.0, float(mob["hp"]) - dealt)
		if hp_left == 0.0:
			kills += 1
		remaining_hp += hp_left
	return {"kills": kills, "remaining_hp": remaining_hp, "composition": _mob_mix(mobs)}

func _sum_hp(mobs: Array[Dictionary]) -> float:
	var total := 0.0
	for mob in mobs:
		total += float(mob["hp"])
	return total

func _mob_mix(mobs: Array[Dictionary]) -> String:
	var counter := {}
	for mob in mobs:
		var mob_id := str(mob["id"])
		counter[mob_id] = int(counter.get(mob_id, 0)) + 1
	var parts: Array[String] = []
	for id in counter.keys():
		parts.append("%s %d" % [id, counter[id]])
	parts.sort()
	return ", ".join(parts)

func _draw() -> void:
	if path_points.size() > 1:
		draw_polyline(path_points, Color("f59e0b"), 26.0, true)
		draw_polyline(path_points, Color("fde68a"), 7.0, true)
	for tower in placed_towers:
		var pos: Vector2 = tower["pos"]
		draw_circle(pos, 16.0, Color("93c5fd"))
		draw_arc(pos, 140.0, 0.0, TAU, 40, Color(0.6, 0.8, 1.0, 0.25), 2.0)
