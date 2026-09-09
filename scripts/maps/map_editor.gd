extends Control

const GRID_SIZE := Vector2i(160, 190)
const ARENA_TEST_RECT := Rect2i(25, 6, 110, 178)
const ARENA_TEST_LANDSCAPE := preload("res://scripts/maps/arena_test_landscape.gd")
const GRASS_LAYER_SCRIPT := preload("res://scripts/maps/map_grass_layer.gd")
const UNDO_LIMIT := 5
const ASSETS: Dictionary[String, String] = {
	"purple_tree_1": "res://assets/models/environment/purple_tree_01.glb",
	"purple_tree_2": "res://assets/models/environment/purple_tree_02.glb",
	"purple_tree_3": "res://assets/models/environment/purple_tree_03.glb",
	"large_tree": "res://assets/models/environment/large_tree.glb",
	"bush": "res://assets/models/environment/bush_grass_02.glb",
	"grass_1": "res://assets/models/environment/grass_clump_01.glb",
	"grass_2": "res://assets/models/environment/grass_clump_02.glb",
	"tree_real_1": "res://assets/environment/tree_packs/tree/Tree/Tree.fbx",
	"tree_real_2": "res://assets/environment/tree_packs/tree_02/Tree 02/Tree.obj",
	"bush_real_1": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_2": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_3": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_4": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_5": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_6": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_7": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_8": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_9": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_heather": "res://assets/environment/bush_packs/bush_01/source/Bush.fbx",
	"bush_cliff": "res://assets/environment/bush_packs/cliff_shrub/source/wallBush-01-terrainWallBush.fbx",
	"stylised_rocks": "res://assets/environment/stylised_rocks/source/Stylised_Rock_Collection.fbx",
	"arena_bridge": "res://assets/environment/bridges/long_wood_bridge/source/Long Wood Bridge.fbx",
	"arena_rock": "res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_4_br.glb",
	"arena_soil": "",
	"premium_tree_1": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_5194_Tris.FBX",
	"premium_tree_2": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_11364_Tris.FBX",
	"premium_shrub": "res://assets/environment/premium_imports/lycium_shrub/04 Lycium Shawii Shrubs.FBX",
	"moss_rock_08": "res://assets/environment/premium_imports/moss_rock_08/moss rock 08 sketchfab/low.obj",
	"moss_rock_09": "res://assets/environment/premium_imports/moss_rock_09/moss rock 09 sketchfab/moss rock 09.obj",
	"moss_rock_10": "res://assets/environment/premium_imports/moss_rock_10/moss rock 10 sketchfab/moss rock 10.obj",
	"moss_rock_11": "res://assets/environment/premium_imports/moss_rock_11/moss rock 11 sketchfab/moss rock 11.obj",
	"moss_rock_12": "res://assets/environment/premium_imports/moss_rock_12/moss rock 12 sketchfab/moss rock 12.obj",
	"moss_rock_13": "res://assets/environment/premium_imports/moss_rock_13/moss rock 13 sketchfab/moss rock 13.obj",
	"moss_rock_14": "res://assets/environment/premium_imports/moss_rock_14/moss rock 14 sketchfab/moss rock 14.obj",
}
const TOOL_GROUPS: Array[Dictionary] = [
	{"title": "RZEŹBIENIE TERRAIN3D", "open": false, "tools": [
		["terrain_raise", "Podnieś"], ["terrain_lower", "Obniż"],
		["terrain_smooth", "Wygładź"], ["terrain_flatten", "Wyrównaj"],
		["terrain_noise", "Naturalny szum"], ["terrain_erode", "Erozja"],
		["terrain_terrace", "Tarasy skalne"], ["terrain_ridge", "Grzbiet"],
	]},
	{"title": "WODA", "open": false, "tools": [
		["water_add", "Dodaj wodę"], ["water_remove", "Usuń wodę"],
	]},
	{"title": "OBIEKTY ŚRODOWISKOWE", "open": false, "thumbnails": true, "tools": [
		["purple_tree_1", "Drzewo I"], ["purple_tree_2", "Drzewo II"],
		["purple_tree_3", "Drzewo III"], ["large_tree", "Wielkie drzewo"],
		["tree_real_1", "Drzewo realistyczne I"], ["tree_real_2", "Drzewo realistyczne II"],
		["bush", "Krzak"], ["grass_1", "Trawa I"], ["grass_2", "Trawa II"],
		["bush_real_1", "Krzew leśny I"], ["bush_real_2", "Krzew leśny II"],
		["bush_real_3", "Krzew leśny III"], ["bush_real_4", "Krzew leśny IV"],
		["bush_real_5", "Krzew leśny V"], ["bush_real_6", "Krzew leśny VI"],
		["bush_real_7", "Krzew leśny VII"], ["bush_real_8", "Krzew leśny VIII"],
		["bush_real_9", "Krzew leśny IX"], ["bush_heather", "Krzew niski"],
		["bush_cliff", "Krzew skalny"], ["stylised_rocks", "Zestaw skał"],
		["simple_grass", "SimpleGrass — malowanie"],
		["arena_rock", "Skała areny"], ["arena_bridge", "Most areny"],
		["premium_tree_1", "Drzewo premium I"], ["premium_tree_2", "Drzewo premium II"],
		["premium_shrub", "Krzew Lycium premium"],
		["moss_rock_08", "Omszały kamień 08"], ["moss_rock_09", "Omszały kamień 09"],
		["moss_rock_10", "Omszały kamień 10"], ["moss_rock_11", "Omszały kamień 11"],
		["moss_rock_12", "Omszały kamień 12"], ["moss_rock_13", "Omszały kamień 13"],
		["moss_rock_14", "Omszały kamień 14"],
	]},
	{"title": "POSTACIE", "open": false, "tools": [
		["player_spawn", "Start gracza"], ["enemy_spawn", "Start wroga"],
	]},
	{"title": "EDYCJA", "open": false, "tools": [
		["select", "Zaznacz obiekt"], ["erase", "Usuń obiekt"],
	]},
]

var objects: Array[Dictionary] = []
var player_spawns: Array[Dictionary] = []
var enemy_spawns: Array[Dictionary] = []
var grass_entries: Array[Dictionary] = []
var selected_object_indices: Array[int] = []
var _undo_stack: Array[Dictionary] = []
var _stroke_snapshot_taken := false
var _selection_dragging := false
var _selection_start := Vector2.ZERO
var _selection_end := Vector2.ZERO
var grass_width := 1.0
var grass_height := 1.0
var grass_color := Color(0.42, 0.72, 0.22)
var _grass_preview: TextureRect
var active_tool: String = "paint_0"
var brush_radius: float = 6.0
var brush_strength: float = 0.65
var object_density: float = 0.18
var _object_renderer: MapObjectMultiMeshRenderer
var _dragging_camera := false
var _painting_objects := false
var _object_rebuild_pending := false
var _last_object_stamp := Vector3(INF, INF, INF)
var _fpp_enabled := false
var _ghost_placed := false
var _ghost_position := Vector3.ZERO
var _ghost_yaw := 0.0
var _fpp_pitch := 0.0
var _editor_camera_transform := Transform3D.IDENTITY
var _editor_camera_size := 92.0
var _fpp_speed := 18.0
var _last_mouse_position := Vector2.ZERO
var _last_action_msec := 0
var _selected_object_index := -1
var _selection_ring: MeshInstance3D
var _transform_label: Label
var _transform_buttons: Array[Button] = []

@onready var canvas: Control = %MapCanvas
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _terrain_surface: TerrainMapSurface
var _water_surface: WaterMapSurface
var _objects_root: Node3D
var _markers_root: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _cursor: MeshInstance3D
var _brush_radius_slider: HSlider
var _brush_strength_slider: HSlider
var _density_slider: HSlider
var _grass_width_slider: HSlider
var _grass_height_slider: HSlider
var _brush_label: Label
var _grass_layer: Node3D
var _selection_box: ColorRect
var _bottom_panel: PanelContainer

func _ready() -> void:
	_build_sidebar_controls()
	_build_3d_view()
	_build_bottom_toolbar()
	await _terrain_surface.setup(_camera)
	_water_surface.setup(_terrain_surface)
	_connect_ui()
	_rebuild_objects()
	_update_markers()
	_update_status("Biała plansza gotowa — wybierz materiał i maluj po terenie")

func _build_sidebar_controls() -> void:
	%ToolOption.visible = false
	var parent := %ToolOption.get_parent() as VBoxContainer
	var insertion_index := %ToolOption.get_index()
	var scroll := ScrollContainer.new()
	scroll.name = "ToolPaletteScroll"
	scroll.custom_minimum_size = Vector2(0.0, 360.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.move_child(scroll, insertion_index)
	var tools_panel := VBoxContainer.new()
	tools_panel.name = "VisibleToolPalette"
	tools_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_panel.add_theme_constant_override("separation", 5)
	scroll.add_child(tools_panel)
	var arena_preset_button := Button.new()
	arena_preset_button.name = "LoadArenaTestPresetButton"
	arena_preset_button.text = "Wczytaj Arena (test)"
	arena_preset_button.tooltip_text = "Skopiuj aktualny teren, wodę, roślinność i punkty startowe Areny (test) do edytora"
	arena_preset_button.custom_minimum_size = Vector2(0.0, 42.0)
	arena_preset_button.pressed.connect(_load_arena_test_preset)
	tools_panel.add_child(arena_preset_button)
	for group: Dictionary in TOOL_GROUPS:
		if str(group["title"]) == "WODA":
			_add_material_section(tools_panel)
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		tools_panel.add_child(section)
		var title := Button.new()
		title.text = ("▼ " if bool(group.get("open", false)) else "▶ ") + str(group["title"])
		title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.add_theme_font_size_override("font_size", 13)
		section.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		grid.visible = bool(group.get("open", false))
		section.add_child(grid)
		title.pressed.connect(_toggle_section.bind(title, grid, str(group["title"])))
		for entry: Array in group["tools"]:
			var tool_id := str(entry[0])
			var label := str(entry[1])
			grid.add_child(_create_tool_button(tool_id, label, bool(group.get("thumbnails", false))))
	_transform_label = Label.new()
	_transform_label.text = "TRANSFORMACJA — brak zaznaczenia"
	_transform_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_panel.add_child(_transform_label)
	var transform_grid := GridContainer.new()
	transform_grid.columns = 3
	tools_panel.add_child(transform_grid)
	for entry: Array in [
		["↶ 15°", -15.0, 0.0, false], ["↷ 15°", 15.0, 0.0, false],
		["Odwróć", 0.0, 0.0, true], ["Obniż", 0.0, -0.25, false],
		["Wyzeruj", 0.0, INF, false], ["Podnieś", 0.0, 0.25, false],
	]:
		var button := Button.new()
		button.text = str(entry[0])
		button.custom_minimum_size = Vector2(84.0, 28.0)
		button.disabled = true
		button.pressed.connect(_transform_selected.bind(float(entry[1]), float(entry[2]), bool(entry[3])))
		transform_grid.add_child(button)
		_transform_buttons.append(button)
	_brush_label = Label.new()
	_brush_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_panel.add_child(_brush_label)
	_brush_radius_slider = HSlider.new()
	_brush_radius_slider.min_value = 1.5
	_brush_radius_slider.max_value = 18.0
	_brush_radius_slider.step = 0.5
	_brush_radius_slider.value = brush_radius
	tools_panel.add_child(_brush_radius_slider)
	_brush_strength_slider = HSlider.new()
	_brush_strength_slider.min_value = 0.1
	_brush_strength_slider.max_value = 2.0
	_brush_strength_slider.step = 0.05
	_brush_strength_slider.value = brush_strength
	tools_panel.add_child(_brush_strength_slider)
	_density_slider = HSlider.new()
	_density_slider.min_value = 0.02
	_density_slider.max_value = 0.65
	_density_slider.step = 0.01
	_density_slider.value = object_density
	_density_slider.tooltip_text = "Gestosc obiektow na metr kwadratowy"
	tools_panel.add_child(_density_slider)
	_update_brush_label()

func _build_bottom_toolbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "BottomEditPanel"
	_bottom_panel = panel
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 472.0
	panel.offset_right = -48.0
	panel.offset_top = -202.0
	panel.offset_bottom = -48.0
	panel.z_index = 100
	panel.top_level = true
	add_child(panel)
	panel.move_to_front()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	panel.add_child(rows)
	var edit_row := HBoxContainer.new()
	edit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	edit_row.add_theme_constant_override("separation", 10)
	rows.add_child(edit_row)
	var transform_grid := _transform_buttons[0].get_parent()
	for control: Control in [_transform_label, transform_grid]:
		control.reparent(edit_row)
	_transform_label.custom_minimum_size.x = 220.0
	var select_all := Button.new()
	select_all.text = "Zaznacz wszystko"
	select_all.custom_minimum_size.x = 150.0
	select_all.pressed.connect(_select_all_objects)
	edit_row.add_child(select_all)
	var sliders_row := HBoxContainer.new()
	sliders_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sliders_row.add_theme_constant_override("separation", 12)
	rows.add_child(sliders_row)
	_brush_label.reparent(sliders_row)
	_brush_label.custom_minimum_size.x = 190.0
	_wrap_existing_slider(sliders_row, _brush_radius_slider, "Promień")
	_wrap_existing_slider(sliders_row, _brush_strength_slider, "Siła")
	_wrap_existing_slider(sliders_row, _density_slider, "Gęstość")
	_grass_width_slider = _make_bottom_slider(sliders_row, "Szerokość", 0.25, 3.0, grass_width)
	_grass_height_slider = _make_bottom_slider(sliders_row, "Wysokość", 0.25, 4.0, grass_height)
	_build_grass_color_control(sliders_row)
	_selection_box = ColorRect.new()
	_selection_box.color = Color(0.15, 0.72, 1.0, 0.20)
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.visible = false
	_selection_box.z_index = 19
	canvas.add_child(_selection_box)


func _build_grass_color_control(parent: Container) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 150.0
	var label := Label.new()
	label.text = "Kolor RGB trawy"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(preview_row)
	_grass_preview = TextureRect.new()
	_grass_preview.texture = load("res://addons/simplegrasstextured/textures/grassbushcc008.png") as Texture2D
	_grass_preview.custom_minimum_size = Vector2(52.0, 42.0)
	_grass_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grass_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grass_preview.modulate = grass_color
	_grass_preview.tooltip_text = "Podgląd wyglądu trawy z wybranym kolorem"
	preview_row.add_child(_grass_preview)
	var picker := ColorPickerButton.new()
	picker.color = grass_color
	picker.custom_minimum_size = Vector2(70.0, 34.0)
	picker.tooltip_text = "Ustaw kolor RGB trawy"
	picker.color_changed.connect(_on_grass_color_changed)
	preview_row.add_child(picker)
	parent.add_child(column)


func _on_grass_color_changed(color: Color) -> void:
	grass_color = Color(color.r, color.g, color.b, 1.0)
	if _grass_preview != null:
		_grass_preview.modulate = grass_color
	if _grass_layer != null:
		_grass_layer.call("set_grass_color", grass_color)


func _wrap_existing_slider(parent: Container, slider: HSlider, title: String) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 112.0
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	slider.reparent(column)
	slider.custom_minimum_size = Vector2(112.0, 24.0)
	var value_label := Label.new()
	value_label.text = "%.2f" % slider.value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value_label)
	slider.value_changed.connect(func(new_value: float) -> void: value_label.text = "%.2f" % new_value)
	parent.add_child(column)


func _make_bottom_slider(parent: Container, title: String, minimum: float, maximum: float, value: float) -> HSlider:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 112.0
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var slider := HSlider.new()
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(112.0, 24.0)
	column.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value_label)
	slider.value_changed.connect(func(new_value: float) -> void: value_label.text = "%.2f" % new_value)
	parent.add_child(column)
	return slider


func _toggle_section(button: Button, content: Control, title: String) -> void:
	content.visible = not content.visible
	button.text = ("▼ " if content.visible else "▶ ") + title

func _create_tool_button(tool_id: String, label: String, thumbnail: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(140.0, 108.0 if thumbnail else 30.0)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_select_tool.bind(tool_id, label))
	if thumbnail and ASSETS.has(tool_id):
		button.icon = _create_asset_preview(ASSETS[tool_id])
		button.add_theme_constant_override("icon_max_width", 72)
		button.expand_icon = true
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return button

func _add_material_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	var title := Button.new()
	title.text = "▶ MATERIAŁY TERRAIN3D"
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.tooltip_text = "Natywne warstwy Terrain3D: albedo, normal, roughness i płynny blend"
	section.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	section.add_child(grid)
	grid.visible = false
	title.pressed.connect(_toggle_section.bind(title, grid, "MATERIAŁY TERRAIN3D"))
	for texture_id: int in range(TerrainMapSurface.PAINT_TEXTURES.size()):
		var definition: Dictionary = TerrainMapSurface.PAINT_TEXTURES[texture_id]
		var button := _create_tool_button("paint_%d" % texture_id, str(definition["name"]), false)
		button.custom_minimum_size = Vector2(140.0, 62.0)
		if definition.has("path"):
			button.icon = load(str(definition["path"])) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 48)
		button.tooltip_text = "%s\nNatywna warstwa Terrain3D" % str(definition["name"])
		grid.add_child(button)

func _create_asset_preview(scene_path: String) -> Texture2D:
	var preview := SubViewport.new()
	preview.size = Vector2i(96, 72)
	preview.transparent_bg = true
	preview.own_world_3d = true
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(preview)
	var resource := load(scene_path)
	var model: Node3D
	if resource is PackedScene:
		model = (resource as PackedScene).instantiate() as Node3D
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		model = mesh_instance
	if model == null:
		return preview.get_texture()
	preview.add_child(model)
	var bounds := _node_bounds(model)
	model.position -= bounds.get_center()
	var extent := maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(1.5, extent * 1.35)
	preview.add_child(camera)
	camera.look_at_from_position(Vector3(extent * 1.15, extent * 0.7, extent * 1.65), Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	light.light_energy = 1.4
	preview.add_child(light)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	preview.add_child(world_environment)
	return preview.get_texture()

func _node_bounds(root: Node3D) -> AABB:
	var result := AABB(Vector3.ZERO, Vector3.ONE)
	var initialized := false
	for child: Node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		var child_bounds := visual.get_aabb()
		child_bounds = visual.transform * child_bounds
		if initialized:
			result = result.merge(child_bounds)
		else:
			result = child_bounds
			initialized = true
	return result

func _select_tool(tool_id: String, label: String) -> void:
	active_tool = tool_id
	_update_status("Narzedzie: " + label)

func _push_undo_state() -> void:
	_undo_stack.append({
		"objects": objects.duplicate(true),
		"grass": grass_entries.duplicate(true),
		"player_spawns": player_spawns.duplicate(true),
		"enemy_spawns": enemy_spawns.duplicate(true),
		"water": _water_surface.serialize_cells(),
		"terrain": _terrain_surface.capture_state(),
	})
	while _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()


func _undo_last_action() -> void:
	if _undo_stack.is_empty():
		_update_status("Brak wcześniejszych akcji do cofnięcia")
		return
	var state: Dictionary = _undo_stack.pop_back()
	objects.assign(state["objects"])
	grass_entries.assign(state["grass"])
	player_spawns.assign(state["player_spawns"])
	enemy_spawns.assign(state["enemy_spawns"])
	_terrain_surface.restore_state(state["terrain"])
	_water_surface.load_cells(state["water"])
	selected_object_indices.clear()
	_selected_object_index = -1
	_rebuild_objects()
	_rebuild_grass()
	_update_markers()
	_update_selection_ui()
	_update_status("Cofnięto akcję — pozostało %d kroków" % _undo_stack.size())


func _select_all_objects() -> void:
	selected_object_indices.clear()
	for index: int in range(objects.size()):
		selected_object_indices.append(index)
	_selected_object_index = selected_object_indices[0] if not selected_object_indices.is_empty() else -1
	_update_selection_ui()


func _select_objects_in_screen_rect(rect: Rect2) -> void:
	selected_object_indices.clear()
	for index: int in range(objects.size()):
		var screen_point := _camera.unproject_position(_object_renderer.get_instance_position(index))
		if rect.has_point(screen_point):
			selected_object_indices.append(index)
	_selected_object_index = selected_object_indices[0] if not selected_object_indices.is_empty() else -1
	_update_selection_ui()


func _delete_selected_objects() -> void:
	if selected_object_indices.is_empty() and _selected_object_index >= 0:
		selected_object_indices.append(_selected_object_index)
	if selected_object_indices.is_empty():
		return
	_push_undo_state()
	selected_object_indices.sort()
	selected_object_indices.reverse()
	for index: int in selected_object_indices:
		if index >= 0 and index < objects.size():
			objects.remove_at(index)
	selected_object_indices.clear()
	_selected_object_index = -1
	_rebuild_objects()
	_update_selection_ui()


func _select_nearest(world_position: Vector3) -> void:
	var best_index := -1
	var best_distance := 3.0
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var distance := Vector2(float(data.get("x", 0)), float(data.get("z", 0))).distance_to(Vector2(world_position.x, world_position.z))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	_selected_object_index = best_index
	selected_object_indices.clear()
	if best_index >= 0:
		selected_object_indices.append(best_index)
	_update_selection_ui()

func _transform_selected(rotation_delta: float, height_delta: float, flip: bool) -> void:
	if _selected_object_index < 0 or _selected_object_index >= objects.size():
		return
	var data: Dictionary = objects[_selected_object_index]
	data["rotation"] = fposmod(float(data.get("rotation", 0.0)) + rotation_delta, 360.0)
	if is_inf(height_delta):
		data["height_offset"] = 0.0
	else:
		data["height_offset"] = clampf(float(data.get("height_offset", 0.0)) + height_delta, -5.0, 12.0)
	if flip:
		data["flipped"] = not bool(data.get("flipped", false))
	objects[_selected_object_index] = data
	_rebuild_objects()
	_update_selection_ui()

func _update_selection_ui() -> void:
	var valid := _selected_object_index >= 0 and _selected_object_index < objects.size()
	for button: Button in _transform_buttons:
		button.disabled = not valid
	if not valid:
		_transform_label.text = "TRANSFORMACJA — brak zaznaczenia"
		if _selection_ring != null:
			_selection_ring.visible = false
		return
	var data: Dictionary = objects[_selected_object_index]
	if selected_object_indices.size() > 1:
		_transform_label.text = "ZAZNACZONO: %d obiektów | DEL usuwa" % selected_object_indices.size()
	else:
		_transform_label.text = "TRANSFORMACJA — %s | kąt %.0f° | wysokość %+.2f" % [str(data.get("type", "obiekt")), float(data.get("rotation", 0.0)), float(data.get("height_offset", 0.0))]
	if _selection_ring != null and _object_renderer != null:
		_selection_ring.visible = true
		_selection_ring.position = _object_renderer.get_instance_position(_selected_object_index) + Vector3.UP * 0.08

func _build_3d_view() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "RenderedMap"
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_default_cursor_shape = Control.CURSOR_CROSS
	canvas.add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "MapViewport"
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.scaling_3d_scale = 0.78
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_objects_root = Node3D.new()
	_world.add_child(_objects_root)
	_object_renderer = MapObjectMultiMeshRenderer.new()
	_object_renderer.name = "ObjectMultiMeshes"
	_objects_root.add_child(_object_renderer)
	_object_renderer.configure(ASSETS, _resolve_editor_object_position, false)
	_grass_layer = GRASS_LAYER_SCRIPT.new() as Node3D
	_grass_layer.name = "SimpleGrassLayer"
	_objects_root.add_child(_grass_layer)
	_grass_layer.call_deferred("set_grass_color", grass_color)
	_markers_root = Node3D.new()
	_world.add_child(_markers_root)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 92.0
	_camera.position = Vector3(80.0, 105.0, 134.0)
	_camera.rotation_degrees = Vector3(-56.0, 0.0, 0.0)
	_camera.current = true
	_world.add_child(_camera)
	_terrain_surface = TerrainMapSurface.new()
	_world.add_child(_terrain_surface)
	_water_surface = WaterMapSurface.new()
	_world.add_child(_water_surface)
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-55.0, -32.0, 0.0)
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.955, 0.86)
	sun.light_energy = 1.35
	sun.shadow_opacity = 0.82
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = true
	_world.add_child(sun)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_SKY
	environment.sky = _create_day_sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.72
	environment.ambient_light_energy = 0.78
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.ssao_intensity = 2.1
	environment.ssao_power = 1.35
	environment.ssil_enabled = false
	world_environment.environment = environment
	_world.add_child(world_environment)
	_cursor = MeshInstance3D.new()
	var cursor_mesh := CylinderMesh.new()
	cursor_mesh.top_radius = 0.5
	cursor_mesh.bottom_radius = 0.5
	cursor_mesh.height = 0.08
	cursor_mesh.radial_segments = 48
	_cursor.mesh = cursor_mesh
	var cursor_material := StandardMaterial3D.new()
	cursor_material.albedo_color = Color(0.16, 0.92, 0.66, 0.42)
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor.material_override = cursor_material
	_cursor.visible = false
	_markers_root.add_child(_cursor)
	_selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 1.05
	_selection_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.78, 0.18)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.55, 0.08)
	ring_material.emission_energy_multiplier = 1.6
	_selection_ring.material_override = ring_material
	_selection_ring.visible = false
	_markers_root.add_child(_selection_ring)

func _create_day_sky() -> Sky:
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 5; i++) {
		value += noise2d(p) * amplitude;
		p = p * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.48;
	}
	return value;
}
void sky() {
	float horizon = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 color = mix(vec3(0.72, 0.87, 1.0), vec3(0.16, 0.48, 0.88), smoothstep(0.42, 0.98, horizon));
	if (EYEDIR.y > 0.015) {
		vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y + 0.24, 0.08);
		float cloud_noise = fbm(cloud_uv * 0.72 + vec2(TIME * 0.006, 0.0));
		float clouds = smoothstep(0.53, 0.72, cloud_noise) * smoothstep(0.02, 0.30, EYEDIR.y);
		vec3 cloud_color = mix(vec3(0.72, 0.78, 0.84), vec3(1.0), clamp(EYEDIR.y * 2.2, 0.0, 1.0));
		color = mix(color, cloud_color, clouds * 0.88);
	}
	COLOR = color;
}
"""
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	return sky


func _connect_ui() -> void:
	_viewport_container.gui_input.connect(_on_viewport_input)
	%SaveButton.pressed.connect(_save)
	%ClearButton.pressed.connect(_clear_map)
	%BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	_brush_radius_slider.value_changed.connect(func(value: float) -> void:
		brush_radius = value
		_update_brush_label()
	)
	_brush_strength_slider.value_changed.connect(func(value: float) -> void:
		brush_strength = value
		_update_brush_label()
	)
	_density_slider.value_changed.connect(func(value: float) -> void:
		object_density = value
		_update_brush_label()
	)
	_grass_width_slider.value_changed.connect(func(value: float) -> void:
		grass_width = value
		_rebuild_grass()
		_update_brush_label()
	)
	_grass_height_slider.value_changed.connect(func(value: float) -> void:
		grass_height = value
		_rebuild_grass()
		_update_brush_label()
	)

func _process(delta: float) -> void:
	if not _fpp_enabled:
		if _viewport_container != null and _viewport_container.get_rect().has_point(_viewport_container.get_local_mouse_position()):
			_last_mouse_position = _viewport_container.get_local_mouse_position()
			_update_cursor(_last_mouse_position)
		return
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var direction := _camera.global_basis.x * input_vector.x + _camera.global_basis.z * input_vector.y
	if Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL):
		direction -= Vector3.UP
	var speed := _fpp_speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if direction.length_squared() > 0.0:
		_camera.position += direction.normalized() * speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.ctrl_pressed and key.keycode == KEY_Z:
			_undo_last_action()
			get_viewport().set_input_as_handled()
		elif key.pressed and not key.echo and key.keycode == KEY_DELETE:
			_delete_selected_objects()
			get_viewport().set_input_as_handled()
		elif key.pressed and not key.echo and key.keycode == KEY_TAB:
			if key.shift_pressed:
				_place_ghost_at_cursor()
			else:
				_toggle_fpp()
			get_viewport().set_input_as_handled()
	elif _fpp_enabled and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_ghost_yaw -= motion.relative.x * 0.0025
		_fpp_pitch = clampf(_fpp_pitch - motion.relative.y * 0.0025, deg_to_rad(-88.0), deg_to_rad(88.0))
		_camera.rotation = Vector3(_fpp_pitch, _ghost_yaw, 0.0)
	elif _fpp_enabled and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_fpp_speed = minf(80.0, _fpp_speed * 1.2)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_fpp_speed = maxf(2.0, _fpp_speed / 1.2)

func _place_ghost_at_cursor() -> void:
	if _fpp_enabled:
		return
	var value: Variant = _screen_to_map(_last_mouse_position)
	if value == null:
		_update_status("Najedz kursorem na teren, aby ustawic ducha kamery")
		return
	var hit := value as Vector3
	_ghost_position = hit + Vector3.UP * 1.7
	_ghost_yaw = 0.0
	_fpp_pitch = 0.0
	_ghost_placed = true
	_update_status("Duch kamery ustawiony — Tab: wejdz do FPP")

func _toggle_fpp() -> void:
	if not _fpp_enabled and not _ghost_placed:
		_place_ghost_at_cursor()
		if not _ghost_placed:
			return
	_fpp_enabled = not _fpp_enabled
	if _fpp_enabled:
		_editor_camera_transform = _camera.transform
		_editor_camera_size = _camera.size
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.position = _ghost_position
		_camera.rotation = Vector3(_fpp_pitch, _ghost_yaw, 0.0)
		_camera.far = 260.0
		_viewport.scaling_3d_scale = 0.68
		if _environment != null:
			_environment.ssao_enabled = false
		if _sun != null:
			_sun.directional_shadow_max_distance = 140.0
		_cursor.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_update_status("FPP — WASD/mysz, Space/Ctrl: gora/dol, Shift: szybciej, Tab: powrot")
	else:
		_ghost_position = _camera.position
		_ghost_yaw = _camera.rotation.y
		_fpp_pitch = _camera.rotation.x
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.transform = _editor_camera_transform
		_camera.size = _editor_camera_size
		_viewport.scaling_3d_scale = 0.78
		if _environment != null:
			_environment.ssao_enabled = true
		if _sun != null:
			_sun.directional_shadow_max_distance = 260.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_status("Widok edycji — Shift+Tab ustawia ducha, Tab: FPP")

func _on_viewport_input(event: InputEvent) -> void:
	if _bottom_panel != null and _bottom_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	if _fpp_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging_camera:
			_pan_camera(motion.position - _last_mouse_position)
		else:
			_update_cursor(motion.position)
			if _selection_dragging:
				_selection_end = motion.position
				var rect := Rect2(_selection_start, _selection_end - _selection_start).abs()
				_selection_box.position = rect.position
				_selection_box.size = rect.size
			elif _painting_objects:
				_try_apply_at_screen(motion.position)
		_last_mouse_position = motion.position
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_camera = button.pressed
			_last_mouse_position = button.position
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.size = maxf(24.0, _camera.size * 0.88)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.size = minf(210.0, _camera.size * 1.12)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if active_tool == "select":
				_selection_dragging = button.pressed
				if button.pressed:
					_selection_start = button.position
					_selection_end = button.position
					_selection_box.position = button.position
					_selection_box.size = Vector2.ZERO
					_selection_box.visible = true
				else:
					_selection_box.visible = false
					var selection_rect := Rect2(_selection_start, _selection_end - _selection_start).abs()
					if selection_rect.size.length() < 8.0:
						var hit: Variant = _screen_to_map(button.position)
						if hit != null:
							_select_nearest(hit as Vector3)
					else:
						_select_objects_in_screen_rect(selection_rect)
			else:
				_painting_objects = button.pressed
				if button.pressed:
					_stroke_snapshot_taken = false
					_last_object_stamp = Vector3(INF, INF, INF)
					_try_apply_at_screen(button.position)
				elif _object_rebuild_pending:
					_flush_object_rebuild()

func _try_apply_at_screen(screen_position: Vector2) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_action_msec < 75:
		return
	var hit: Variant = _screen_to_map(screen_position)
	if hit == null:
		return
	var world_position := hit as Vector3
	var minimum_spacing := maxf(0.65, brush_radius * 0.22)
	if ASSETS.has(active_tool) and not is_inf(_last_object_stamp.x) and _last_object_stamp.distance_to(world_position) < minimum_spacing:
		return
	if not _stroke_snapshot_taken:
		_push_undo_state()
		_stroke_snapshot_taken = true
	_last_action_msec = now_msec
	_last_object_stamp = world_position
	_apply_tool(world_position)

func _pan_camera(delta: Vector2) -> void:
	var factor := _camera.size / maxf(320.0, _viewport_container.size.y)
	_camera.position.x = clampf(_camera.position.x - delta.x * factor, -20.0, float(GRID_SIZE.x) + 20.0)
	_camera.position.z = clampf(_camera.position.z - delta.y * factor, 20.0, float(GRID_SIZE.y) + 100.0)

func _screen_to_map(screen_position: Vector2) -> Variant:
	var hit := _terrain_surface.get_intersection(
		_camera.project_ray_origin(screen_position),
		_camera.project_ray_normal(screen_position)
	)
	if is_nan(hit.x) or hit.x < -0.5 or hit.z < -0.5 or hit.x >= GRID_SIZE.x - 0.5 or hit.z >= GRID_SIZE.y - 0.5:
		return null
	return hit

func _update_cursor(screen_position: Vector2) -> void:
	var value: Variant = _screen_to_map(screen_position)
	if value == null:
		_cursor.visible = false
		return
	var hit := value as Vector3
	_cursor.visible = true
	_cursor.position = hit + Vector3.UP * 0.16
	var uses_brush := active_tool.begins_with("terrain_") or active_tool.begins_with("paint_") or active_tool.begins_with("water_") or ASSETS.has(active_tool)
	var radius := brush_radius if uses_brush else 0.75
	_cursor.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

func _apply_tool(world_position: Vector3) -> void:
	var cell := Vector2i(roundi(world_position.x), roundi(world_position.z))
	if active_tool.begins_with("terrain_"):
		_terrain_surface.apply_brush(world_position, brush_radius, brush_strength, active_tool.trim_prefix("terrain_"))
		_reposition_scene_content()
		_water_surface.load_cells(_water_surface.serialize_cells())
	elif active_tool.begins_with("paint_"):
		_terrain_surface.paint_texture(world_position, brush_radius, brush_strength, int(active_tool.trim_prefix("paint_")))
	elif active_tool == "water_add" or active_tool == "water_remove":
		_water_surface.apply_brush(world_position, brush_radius, active_tool == "water_remove")
	elif active_tool == "simple_grass":
		_paint_simple_grass(world_position)
	elif active_tool == "select":
		_select_nearest(world_position)
	elif active_tool == "erase":
		_erase_nearest(world_position)
	elif active_tool == "player_spawn":
		_set_spawn(player_spawns, cell)
		_update_markers()
	elif active_tool == "enemy_spawn":
		_set_spawn(enemy_spawns, cell)
		_update_markers()
	else:
		_scatter_objects(world_position)
	_update_status("Obiekty: %d | Woda: %d pol" % [objects.size(), _water_surface.get_cell_count()])

func _paint_simple_grass(center: Vector3) -> void:
	var requested := clampi(roundi(PI * brush_radius * brush_radius * object_density * 5.0), 1, 600)
	for index: int in range(requested):
		var angle := randf() * TAU
		var distance := sqrt(randf()) * brush_radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if x < 0.0 or z < 0.0 or x >= float(GRID_SIZE.x) or z >= float(GRID_SIZE.y):
			continue
		grass_entries.append({"x": x, "z": z, "rotation": randf_range(0.0, 360.0), "scale": randf_range(0.78, 1.22)})
	_rebuild_grass()


func _scatter_objects(center: Vector3) -> void:
	if not ASSETS.has(active_tool):
		return
	var obstacle := active_tool.begins_with("purple_tree_") or active_tool.begins_with("tree_real_") or active_tool == "large_tree"
	var effective_density := minf(object_density, 0.015) if obstacle else object_density
	var maximum := 24 if obstacle else 240
	var requested := clampi(roundi(PI * brush_radius * brush_radius * effective_density), 1, maximum)
	var added := 0
	for index: int in range(requested * 3):
		if added >= requested:
			break
		var angle := randf() * TAU
		var distance := sqrt(randf()) * brush_radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if x < 0.0 or z < 0.0 or x >= float(GRID_SIZE.x) or z >= float(GRID_SIZE.y):
			continue
		if _has_nearby_object(active_tool, Vector2(x, z), 0.7 if obstacle else 0.35):
			continue
		objects.append({
			"type": active_tool,
			"x": x,
			"z": z,
			"rotation": randf_range(0.0, 360.0),
			"scale": randf_range(0.86, 1.14),
			"height_offset": 0.0,
			"flipped": randf() < 0.5,
		})
		added += 1
	_selected_object_index = objects.size() - 1 if added > 0 else -1
	_object_rebuild_pending = _object_rebuild_pending or added > 0
	if not _painting_objects:
		_flush_object_rebuild()

func _has_nearby_object(kind: String, target_position: Vector2, minimum_distance: float) -> bool:
	for data: Dictionary in objects:
		if str(data.get("type", "")) != kind:
			continue
		var existing := Vector2(float(data.get("x", 0.0)), float(data.get("z", 0.0)))
		if existing.distance_to(target_position) < minimum_distance:
			return true
	return false

func _erase_nearest(world_position: Vector3) -> void:
	var best_index := -1
	var best_distance := 2.5
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var distance := Vector2(float(data.get("x", 0)), float(data.get("z", 0))).distance_to(Vector2(world_position.x, world_position.z))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index >= 0:
		objects.remove_at(best_index)
		_selected_object_index = -1
		_rebuild_objects()
		_update_selection_ui()

func _set_spawn(spawns: Array[Dictionary], cell: Vector2i) -> void:
	if not spawns.is_empty():
		spawns.pop_front()
	spawns.append({"x": cell.x, "z": cell.y})

func terrain_height(world_x: float, world_z: float) -> float:
	return _terrain_surface.get_height(world_x, world_z)

func _flush_object_rebuild() -> void:
	if not _object_rebuild_pending:
		return
	_object_rebuild_pending = false
	_rebuild_objects()
	_update_selection_ui()

func _rebuild_objects() -> void:
	if _object_renderer == null:
		return
	_object_renderer.rebuild(objects)
	_rebuild_grass()


func _rebuild_grass() -> void:
	if _grass_layer == null:
		return
	_grass_layer.call("rebuild", grass_entries, Callable(self, "terrain_height"), grass_width, grass_height)

func _resolve_editor_object_position(data: Dictionary) -> Vector3:
	var x := float(data.get("x", 0.0))
	var z := float(data.get("z", 0.0))
	return Vector3(x, terrain_height(x, z), z)

func _reposition_scene_content() -> void:
	_rebuild_objects()
	_update_markers()
	_update_selection_ui()

func _update_markers() -> void:
	for child: Node in _markers_root.get_children():
		if child != _cursor and child != _selection_ring:
			child.queue_free()
	for spawn: Dictionary in player_spawns:
		_create_spawn_marker(spawn, Color.CYAN)
	for spawn: Dictionary in enemy_spawns:
		_create_spawn_marker(spawn, Color.ORANGE_RED)

func _create_spawn_marker(data: Dictionary, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 0.12
	marker.mesh = mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = color
	marker_material.emission_enabled = true
	marker_material.emission = color
	marker_material.emission_energy_multiplier = 1.4
	marker.material_override = marker_material
	var x := float(data.get("x", 0))
	var z := float(data.get("z", 0))
	marker.position = Vector3(x, terrain_height(x, z) + 0.1, z)
	_markers_root.add_child(marker)

func _load_arena_test_preset() -> void:
	_update_status("Wczytywanie Areny (test)...")
	objects.clear()
	player_spawns = [{"x": 78, "z": 10}, {"x": 81, "z": 10}]
	enemy_spawns = [{"x": 78, "z": 180}, {"x": 81, "z": 180}]
	_terrain_surface.reset_blank()
	_terrain_surface.import_height_sampler(_arena_test_height)
	var water_cells: Array[Dictionary] = []
	for x: int in range(ARENA_TEST_RECT.position.x + 1, ARENA_TEST_RECT.end.x - 1):
		var river_center: float = ARENA_TEST_LANDSCAPE.river_z(ARENA_TEST_RECT, float(x))
		for z: int in range(floori(river_center - ARENA_TEST_LANDSCAPE.RIVER_HALF_WIDTH), ceili(river_center + ARENA_TEST_LANDSCAPE.RIVER_HALF_WIDTH) + 1):
			if ARENA_TEST_LANDSCAPE.is_water(ARENA_TEST_RECT, float(x), float(z)):
				water_cells.append({"x": x, "z": z})
	_water_surface.load_cells(water_cells)

	var rng := RandomNumberGenerator.new()
	rng.seed = 71_409_233
	for index: int in range(42):
		var point := _arena_random_natural_point(rng, 7.0)
		if point != Vector2.INF:
			objects.append(_arena_editor_object("large_tree" if index % 2 == 0 else "tree_real_1", point, rng, rng.randf_range(0.82, 1.22)))
	for index: int in range(96):
		var point := _arena_random_natural_point(rng, 4.0)
		if point != Vector2.INF:
			objects.append(_arena_editor_object("bush_heather" if index % 3 == 0 else "bush", point, rng, rng.randf_range(0.72, 1.18)))
	for index: int in range(180):
		var point := _arena_random_natural_point(rng, 3.0)
		if point != Vector2.INF:
			objects.append(_arena_editor_object("grass_1" if index % 2 == 0 else "grass_2", point, rng, rng.randf_range(0.72, 1.34)))
	var arena_center := Vector2(ARENA_TEST_RECT.position) + Vector2(ARENA_TEST_RECT.size) * 0.5
	objects.append({"type": "arena_bridge", "x": arena_center.x, "z": arena_center.y, "rotation": 0.0, "scale": 1.0, "height_offset": 0.20, "flipped": false})
	for ridge_index: int in range(32):
		var ridge_side := -1.0 if ridge_index < 16 else 1.0
		var ridge_point := arena_center + Vector2(ridge_side * rng.randf_range(24.0, 36.0), ridge_side * rng.randf_range(34.0, 54.0))
		objects.append(_arena_editor_object("arena_rock", ridge_point, rng, rng.randf_range(1.2, 3.4)))

	# Recreate editable soil islands and the route leading exactly into the bridge.
	var soil_ratios: Array[Vector2] = [
		Vector2(0.20, 0.32), Vector2(0.80, 0.28), Vector2(0.50, 0.22),
		Vector2(0.47, 0.68), Vector2(0.32, 0.50), Vector2(0.68, 0.55),
		Vector2(0.12, 0.60), Vector2(0.88, 0.45), Vector2(0.18, 0.76),
		Vector2(0.74, 0.78), Vector2(0.84, 0.63), Vector2(0.39, 0.27),
		Vector2(0.61, 0.31), Vector2(0.24, 0.44), Vector2(0.56, 0.47),
		Vector2(0.42, 0.57), Vector2(0.79, 0.58), Vector2(0.58, 0.72)
	]
	for ratio: Vector2 in soil_ratios:
		var soil_point := Vector2(ARENA_TEST_RECT.position) + Vector2(ARENA_TEST_RECT.size) * ratio
		_terrain_surface.paint_texture(Vector3(soil_point.x, _arena_test_height(soil_point.x, soil_point.y), soil_point.y), 9.0, 1.35, 4)
		objects.append({"type": "arena_soil", "x": soil_point.x, "z": soil_point.y, "rotation": rng.randf_range(0.0, 360.0), "scale": rng.randf_range(4.0, 6.5), "height_offset": 0.08, "flipped": false})
	for z: int in range(ARENA_TEST_RECT.position.y + 4, ARENA_TEST_RECT.end.y - 4, 6):
		var path_x := _arena_editor_path_x(float(z))
		_terrain_surface.paint_texture(Vector3(path_x, _arena_test_height(path_x, float(z)), float(z)), 4.2, 1.0, 3)
		objects.append({"type": "arena_soil", "x": path_x, "z": float(z), "rotation": 0.0, "scale": 2.7, "height_offset": 0.09, "flipped": false})
	_selected_object_index = -1
	_rebuild_objects()
	_update_markers()
	_reposition_scene_content()
	%NameEdit.text = "Arena Test - edycja"
	_update_status("Arena (test) wczytana — teren, woda i %d obiektow sa edytowalne" % objects.size())


func _arena_test_height(x: float, z: float) -> float:
	if not Rect2(ARENA_TEST_RECT).has_point(Vector2(x, z)):
		return 0.0
	return ARENA_TEST_LANDSCAPE.sample_height(ARENA_TEST_RECT, x, z)


func _arena_editor_path_x(z: float) -> float:
	var delta := z - 95.0
	var bridge_clearance := smoothstep(8.0, 18.0, absf(delta))
	return 80.0 + bridge_clearance * (sin(delta * 0.041) * 7.2 + sin(delta * 0.093) * 2.4)


func _arena_random_natural_point(rng: RandomNumberGenerator, margin: float) -> Vector2:
	for attempt: int in range(32):
		var point := Vector2(
			rng.randf_range(float(ARENA_TEST_RECT.position.x) + margin, float(ARENA_TEST_RECT.end.x) - margin),
			rng.randf_range(float(ARENA_TEST_RECT.position.y) + margin, float(ARENA_TEST_RECT.end.y) - margin)
		)
		var center := Vector2(ARENA_TEST_RECT.position) + Vector2(ARENA_TEST_RECT.size) * 0.5
		if ARENA_TEST_LANDSCAPE.is_water(ARENA_TEST_RECT, point.x, point.y):
			continue
		if absf(point.x - center.x) < 8.0 or absf(point.x - (center.x + ARENA_TEST_LANDSCAPE.FORD_X_OFFSET)) < 9.0:
			continue
		return point
	return Vector2.INF


func _arena_editor_object(kind: String, point: Vector2, rng: RandomNumberGenerator, scale_value: float) -> Dictionary:
	return {
		"type": kind,
		"x": point.x,
		"z": point.y,
		"rotation": rng.randf_range(0.0, 360.0),
		"scale": scale_value,
		"height_offset": 0.0,
		"flipped": rng.randf() < 0.5,
	}


func _clear_map() -> void:
	objects.clear()
	grass_entries.clear()
	_undo_stack.clear()
	player_spawns.clear()
	enemy_spawns.clear()
	_selected_object_index = -1
	_terrain_surface.reset_blank()
	_water_surface.clear()
	_rebuild_objects()
	_update_markers()
	_update_selection_ui()
	_update_status("Utworzono pustą mapę Terrain3D")

func _save() -> void:
	var map_name := str(%NameEdit.text).strip_edges()
	if map_name.is_empty():
		_update_status("Podaj nazwe mapy.")
		return
	var safe_name := map_name.to_lower().replace(" ", "_")
	var terrain_directory := "user://maps/terrain/" + safe_name
	_terrain_surface.save_to_directory(terrain_directory)
	var path: String = get_node("/root/MapCatalog").save_map({
		"version": 4,
		"name": map_name,
		"objects": objects,
		"grass": grass_entries,
		"grass_width": grass_width,
		"grass_height": grass_height,
		"grass_color": grass_color.to_html(false),
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
		"terrain_directory": terrain_directory,
		"water_cells": _water_surface.serialize_cells(),
	})
	_update_status("Zapisano: " + path)

func _update_brush_label() -> void:
	_brush_label.text = "PĘDZEL %.1f m | siła %.2f | gęstość %.2f\nTRAWA szer. %.2f | wys. %.2f" % [brush_radius, brush_strength, object_density, grass_width, grass_height]

func _update_status(message: String) -> void:
	%StatusLabel.text = message + "\nLPM: maluj | PPM/MMB: przesuń | Shift+Tab: ustaw ducha | Tab: FPP"
