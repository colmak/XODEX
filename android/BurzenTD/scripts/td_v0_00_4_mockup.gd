extends Control

const GRID_SIZE: float = 48.0
const PATH_SAFE_DISTANCE: float = 72.0
const MIN_HEAT_DAMAGE_SCALE: float = 0.35

@onready var tower_menu: Tree = %TowerMenu
@onready var tower_detail_label: Label = %TowerDetailLabel
@onready var mob_overlay_label: Label = %MobOverlayLabel
@onready var safety_state_label: Label = %SafetyStateLabel
@onready var placement_hint_label: Label = %PlacementHintLabel
@onready var settings_popup: PopupPanel = %SettingsPopup
@onready var snap_to_grid_check: CheckBox = %SnapToGridCheck

var selected_tower_id: String = ""
var snap_to_grid: bool = true
var placed_towers: Array[Dictionary] = []
var tower_bonds: Array[Dictionary] = []
var wave_index: int = 1
var level_index: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var graph_engine: TowerGraph = TowerGraph.new()
var current_terrain: Dictionary = {
	"id": "baseline",
	"label": "Baseline Causeway",
	"damage_mult": 1.0,
	"heat_bias": 0.0,
}
var path_points: PackedVector2Array = PackedVector2Array([
	Vector2(90, 220),
	Vector2(460, 220),
	Vector2(460, 520),
	Vector2(860, 520),
	Vector2(860, 790),
	Vector2(1200, 790),
])

var tower_catalog: Dictionary = {
	"geometric": [
		{"id": "triangle", "label": "△ Triangle", "dps": 42.0, "range": 150.0, "cooldown": 1.2, "residue_class": &"nonpolar", "special": "Burst damage vs clustered mobs.", "targeting": "Closest", "heat_scale": 0.24, "replacements": ["square", "fire"]},
		{"id": "square", "label": "▢ Square", "dps": 28.0, "range": 180.0, "cooldown": 0.8, "residue_class": &"nonpolar", "special": "Balanced fire; can apply slow.", "targeting": "Highest HP", "heat_scale": 0.16, "replacements": ["triangle", "water"]},
		{"id": "rectangle", "label": "▭ Rectangle", "dps": 24.0, "range": 260.0, "cooldown": 1.0, "residue_class": &"nonpolar", "special": "Long corridor pressure tower.", "targeting": "First", "heat_scale": 0.12, "replacements": ["air", "zhe"]},
	],
	"elemental": [
		{"id": "fire", "label": "火 Fire", "dps": 34.0, "range": 170.0, "cooldown": 0.9, "residue_class": &"positively_charged", "special": "Burn DoT and 1.5x AoE splash.", "targeting": "Clustered", "heat_scale": 0.08, "replacements": ["earth", "triangle"]},
		{"id": "water", "label": "水 Water", "dps": 21.0, "range": 200.0, "cooldown": 0.7, "residue_class": &"polar_uncharged", "special": "Slow aura and single-target control.", "targeting": "Fastest", "heat_scale": 0.06, "replacements": ["fire", "air"]},
		{"id": "earth", "label": "土 Earth", "dps": 26.0, "range": 165.0, "cooldown": 1.1, "residue_class": &"special", "special": "Armor break + adjacency durability.", "targeting": "Highest Armor", "heat_scale": 0.1, "replacements": ["square", "zhe"]},
		{"id": "air", "label": "风 Air", "dps": 25.0, "range": 220.0, "cooldown": 0.6, "residue_class": &"negatively_charged", "special": "Fast projectile + knockback.", "targeting": "First", "heat_scale": 0.15, "replacements": ["water", "rectangle"]},
	],
	"keystone": [
		{"id": "zhe", "label": "Ж Keystone", "dps": 18.0, "range": 210.0, "cooldown": 1.8, "residue_class": &"special", "special": "Buff aura + periodic adjacent shield.", "targeting": "Support", "heat_scale": 0.05, "replacements": ["earth", "rectangle"]},
	],
}

var terrain_profiles: Array[Dictionary] = [
	{"id": "baseline", "label": "Baseline Causeway", "damage_mult": 1.0, "heat_bias": 0.0},
	{"id": "ash_dunes", "label": "Ash Dunes", "damage_mult": 0.92, "heat_bias": 0.18},
	{"id": "frost_lane", "label": "Frost Lane", "damage_mult": 1.08, "heat_bias": -0.12},
	{"id": "ion_plateau", "label": "Ion Plateau", "damage_mult": 1.02, "heat_bias": 0.05},
]

var mob_archetypes: Array[Dictionary] = [
	{"id": "runner", "hp": 80.0, "armor": 8.0, "speed": 1.45, "heat": 0.22},
	{"id": "tank", "hp": 210.0, "armor": 28.0, "speed": 0.72, "heat": 0.55},
	{"id": "swarm", "hp": 62.0, "armor": 5.0, "speed": 1.65, "heat": 0.34},
	{"id": "ember", "hp": 130.0, "armor": 14.0, "speed": 1.12, "heat": 0.75},
]

func _ready() -> void:
	rng.randomize()
	graph_engine.configure(AffinityTable.create_default(), 0.20, false)
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
	var root: TreeItem = tower_menu.create_item()
	_add_tower_group(root, "Geometric", tower_catalog["geometric"])
	_add_tower_group(root, "Elemental", tower_catalog["elemental"])
	_add_tower_group(root, "Keystone", tower_catalog["keystone"])

func _add_tower_group(root: TreeItem, title: String, entries: Array) -> void:
	var group: TreeItem = tower_menu.create_item(root)
	group.set_text(0, title)
	group.collapsed = false
	for entry: Dictionary in entries:
		var normalized_entry: Dictionary = ResidueEngine.normalize_tower_definition(entry)
		var item: TreeItem = tower_menu.create_item(group)
		item.set_text(0, str(normalized_entry["label"]))
		item.set_text(1, str(normalized_entry["dps"]))
		item.set_metadata(0, normalized_entry)

func _on_tower_menu_item_selected() -> void:
	var item: TreeItem = tower_menu.get_selected()
	if item == null:
		return
	var meta: Dictionary = item.get_metadata(0)
	if meta.is_empty():
		return
	selected_tower_id = str(meta["id"])
	var replacement_labels: Array[String] = []
	for replacement_id: String in meta["replacements"]:
		replacement_labels.append(replacement_id)
	tower_detail_label.text = "[%s]\nDPS %d | Range %d | CD %.2fs\n%s" % [
		meta["label"],
		int(meta["dps"]),
		int(meta["range"]),
		float(meta["cooldown"]),
		"Residue %s | Target %s | Replace %s\n%s" % [
			str(meta["residue_class"]),
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
	var target: Vector2 = raw_position
	if snap_to_grid:
		target = Vector2(round(target.x / GRID_SIZE) * GRID_SIZE, round(target.y / GRID_SIZE) * GRID_SIZE)
	for tower_data: Dictionary in placed_towers:
		if Vector2(tower_data["pos"]).distance_to(target) < 56.0:
			safety_state_label.text = "NESOROX Safety: overlap violation; placement reverted"
			return
	if _distance_to_path(target) < PATH_SAFE_DISTANCE:
		safety_state_label.text = "NESOROX Safety: pathing violation; placement reverted"
		return
	var tower_entry: Dictionary = _find_tower_entry(selected_tower_id)
	var tower_node: Dictionary = {
		"id": placed_towers.size() + 1,
		"tower_id": selected_tower_id,
		"pos": target,
		"grid_x": int(round(target.x / GRID_SIZE)),
		"grid_y": int(round(target.y / GRID_SIZE)),
		"residue_class": tower_entry.get("residue_class", &"special"),
		"thermal_state": 0.0,
	}
	placed_towers.append(tower_node)
	_refresh_tower_graph()
	safety_state_label.text = "NESOROX Safety: Stable"
	mob_overlay_label.text = "Mob Overlay: HP %d | Armor %d | Speed %.2f" % [120 + placed_towers.size() * 5, 14 + placed_towers.size(), 1.0 + placed_towers.size() * 0.03]
	queue_redraw()

func _refresh_tower_graph() -> void:
	var graph_payload: Dictionary = graph_engine.sync_from_towers(placed_towers)
	tower_bonds = graph_payload["bonds"]

func _distance_to_path(pos: Vector2) -> float:
	var closest: float = INF
	for i: int in range(path_points.size() - 1):
		var projected: Vector2 = Geometry2D.get_closest_point_to_segment(pos, path_points[i], path_points[i + 1])
		closest = minf(closest, pos.distance_to(projected))
	return closest

func _on_settings_button_pressed() -> void:
	settings_popup.popup_centered()

func _on_snap_toggled(button_pressed: bool) -> void:
	snap_to_grid = button_pressed

func _on_simulate_wave_pressed() -> void:
	var mobs: Array[Dictionary] = _generate_wave_mobs(level_index, wave_index)
	var sim: Dictionary = _simulate_tower_damage(mobs)
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
	tower_bonds.clear()
	wave_index = 1
	safety_state_label.text = "NESOROX Safety: Stable (baseline restored)"
	mob_overlay_label.text = "Mob Overlay: HP 120 | Armor 14 | Speed 1.0"
	queue_redraw()

func _find_tower_entry(tower_id: String) -> Dictionary:
	for group: Array in tower_catalog.values():
		for tower_entry: Dictionary in group:
			if str(tower_entry["id"]) == tower_id:
				return ResidueEngine.normalize_tower_definition(tower_entry)
	return {}

func _generate_wave_mobs(level: int, wave: int) -> Array[Dictionary]:
	current_terrain = terrain_profiles[rng.randi_range(0, terrain_profiles.size() - 1)]
	var mobs: Array[Dictionary] = []
	var count: int = 5 + level + int(wave * 0.75)
	for i: int in range(count):
		var archetype: Dictionary = mob_archetypes[rng.randi_range(0, mob_archetypes.size() - 1)]
		var hp_scale: float = 1.0 + 0.13 * float(wave - 1)
		var armor_scale: float = 1.0 + 0.08 * float(level - 1)
		mobs.append({
			"id": archetype["id"],
			"hp": float(archetype["hp"]) * hp_scale,
			"armor": float(archetype["armor"]) * armor_scale,
			"speed": archetype["speed"],
			"heat": clamp(float(archetype["heat"]) + float(current_terrain["heat_bias"]), 0.0, 1.0),
		})
	return mobs

func _simulate_tower_damage(mobs: Array[Dictionary]) -> Dictionary:
	if placed_towers.is_empty():
		return {"kills": 0, "remaining_hp": _sum_hp(mobs), "composition": _mob_mix(mobs)}
	var total_dps: float = 0.0
	for placed: Dictionary in placed_towers:
		var tower_entry: Dictionary = _find_tower_entry(str(placed["tower_id"]))
		if tower_entry.is_empty():
			continue
		total_dps += float(tower_entry["dps"])
	var kills: int = 0
	var remaining_hp: float = 0.0
	for mob_data: Dictionary in mobs:
		var heat: float = float(mob_data["heat"])
		var mean_heat_scale: float = 1.0
		for placed: Dictionary in placed_towers:
			var tower_entry: Dictionary = _find_tower_entry(str(placed["tower_id"]))
			if tower_entry.is_empty():
				continue
			mean_heat_scale *= clamp(1.0 - heat * float(tower_entry["heat_scale"]), MIN_HEAT_DAMAGE_SCALE, 1.0)
		var armor_reduction: float = maxf(0.2, 1.0 - float(mob_data["armor"]) / 100.0)

		# ─────────────────────────────────────────────────────────────
		# FIXED TYPED DAMAGE BLOCK – GODOT 4.6.1 STRICT MODE
		# Applied by Codex – eliminates all Variant warnings
		# ─────────────────────────────────────────────────────────────
		var base_damage: float = total_dps * mean_heat_scale * armor_reduction * float(current_terrain["damage_mult"])
		var multiplier: float = 1.0
		var damage_amount: float = base_damage * multiplier  # use exact surrounding variable names
		var dealt: float = 0.0
		var mob: Variant = mob_data.get("instance", null)

		if is_instance_valid(mob) and mob.has_method("take_damage"):
			dealt = mob.take_damage(damage_amount) as float
		else:
			dealt = damage_amount

		var hp_left: float = maxf(0.0, float(mob_data["hp"]) - dealt)
		if hp_left == 0.0:
			kills += 1
		remaining_hp += hp_left
	return {"kills": kills, "remaining_hp": remaining_hp, "composition": _mob_mix(mobs)}

func _sum_hp(mobs: Array[Dictionary]) -> float:
	var total: float = 0.0
	for mob: Dictionary in mobs:
		total += float(mob["hp"])
	return total

func _mob_mix(mobs: Array[Dictionary]) -> String:
	var counter: Dictionary = {}
	for mob: Dictionary in mobs:
		var mob_id: String = str(mob["id"])
		counter[mob_id] = int(counter.get(mob_id, 0)) + 1
	var parts: Array[String] = []
	for mob_id: Variant in counter.keys():
		parts.append("%s %d" % [mob_id, counter[mob_id]])
	parts.sort()
	return ", ".join(parts)

func _draw() -> void:
	if path_points.size() > 1:
		draw_polyline(path_points, Color("f59e0b"), 26.0, true)
		draw_polyline(path_points, Color("fde68a"), 7.0, true)
	for bond: Dictionary in tower_bonds:
		var strength: float = float(bond["strength"])
		if absf(strength) >= 0.2:
			var alpha: float = clampf(absf(strength), 0.25, 1.0)
			draw_line(Vector2(bond["from"]), Vector2(bond["to"]), Color(0.6, 0.9, 1.0, alpha * 0.35), 2.0)
	for tower_data: Dictionary in placed_towers:
		var pos: Vector2 = tower_data["pos"]
		draw_circle(pos, 16.0, Color("93c5fd"))
		draw_arc(pos, 140.0, 0.0, TAU, 40, Color(0.6, 0.8, 1.0, 0.25), 2.0)
