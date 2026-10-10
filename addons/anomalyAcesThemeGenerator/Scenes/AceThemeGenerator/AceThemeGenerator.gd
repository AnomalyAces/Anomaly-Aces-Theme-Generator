@tool
extends Control

# Configuration file paths
const CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/working/config.json"
const OLD_CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/config.json"

# Property type to section name mapping (shared constant)
const SECTION_MAP = {
	"color": "colors",
	"constant": "constants",
	"font": "fonts",
	"font_size": "font_sizes",
	"icon": "icons",
	"stylebox": "styleboxes"
}

var image_folder: String = "res://addons/anomalyAcesThemeGenerator/working/Images"
var fonts_folder: String = "res://addons/anomalyAcesThemeGenerator/working/Fonts"
var metadata_file: String = "res://addons/anomalyAcesThemeGenerator/working/Metadata/metadata.json"
var output_file: String = "res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres"

# UI References via Unique Names
@onready var control_type_edit: LineEdit = %ControlTypeNameEdit
@onready var select_control_type_btn: Button = %SelectControlTypeBtn
@onready var prop_type_option: OptionButton = %PropertyTypeOption
@onready var prop_name_option: OptionButton = %PropertyNameOption
@onready var value_container: HBoxContainer = %PropertyValueContainer
@onready var parts_tree: Tree = %PartsTree

@onready var preview_area: PanelContainer = %PreviewArea
@onready var preview_scroll: ScrollContainer = %PreviewScroll
@onready var preview_scale_wrapper: Control = %PreviewScaleWrapper
@onready var preview_margin: MarginContainer = %PreviewMargin
@onready var preview_grid: GridContainer = %PreviewGrid
@onready var h_split: HSplitContainer = %MainPanel/HSplit

@onready var custom_type_check: CheckBox = %CustomTypeCheck
@onready var custom_type_name_edit: LineEdit = %CustomTypeNameEdit
@onready var override_name_edit: LineEdit = %OverrideNameEdit

# UI References for Export Settings Panel
@onready var images_edit: LineEdit = %ImagesEdit
@onready var images_browse_btn: Button = %ImagesBrowseBtn
@onready var fonts_edit: LineEdit = %FontsEdit
@onready var fonts_browse_btn: Button = %FontsBrowseBtn
@onready var metadata_edit: LineEdit = %MetadataEdit
@onready var metadata_browse_btn: Button = %MetadataBrowseBtn
@onready var output_edit: LineEdit = %OutputEdit
@onready var output_browse_btn: Button = %OutputBrowseBtn

# UI References for Collapsible Sections
@onready var settings_header_btn: Button = %SettingsHeaderBtn
@onready var settings_content: VBoxContainer = %SettingsContent
@onready var parts_builder_header_btn: Button = %PartsBuilderHeaderBtn
@onready var parts_builder_content: VBoxContainer = %PartsBuilderContent

@onready var preview_columns_spin: SpinBox = %PreviewColumnsSpin
@onready var settings_view_option: OptionButton = %SettingsViewOption
@onready var preview_scale_option: OptionButton = %PreviewScaleOption
@onready var preview_scale_spin: SpinBox = %PreviewScaleSpin
@onready var preview_item_width_spin: SpinBox = %PreviewItemWidthSpin
@onready var preview_font_size_spin: SpinBox = %PreviewFontSizeSpin
@onready var preview_separation_spin: SpinBox = %PreviewSeparationSpin
@onready var new_override_btn: Button = %NewOverrideBtn
@onready var duplicate_override_btn: Button = %DuplicateOverrideBtn
@onready var delete_override_btn: Button = %DeleteOverrideBtn

# Data model for custom theme overrides (Theme Parts)
# Structure: { "Button": { "colors": { "font_color": { "value": Color, "id": String } } } }
var theme_parts: Dictionary = {}
var theme_variations: Dictionary = {}
var _config_loaded: bool = false
var preview_scale: float = 1.0
var preview_scale_mode: String = ""
var scale_presets: Array[Dictionary] = []
var _is_syncing_scale_ui: bool = false
var preview_columns: int = 3
var preview_item_width: int = 200
var preview_font_size: int = 16
var preview_separation: int = 40
var preview_texts: Dictionary = {}
var settings_split_ratio: float = 0.5
var _target_select_meta = null
var _active_prop_key: String = ""
var _creating_new_override: bool = false
var _loading_from_tree: bool = false
var status_bar: PanelContainer
var status_label: Label
var status_icon: Label

# Metadata stylebox builder controls (positioned right after Custom Name in Grid)
var metadata_build_check: CheckBox
var metadata_build_label: Label
var metadata_file_label: Label
var metadata_builder_box: HBoxContainer
var metadata_dropdown: OptionButton
var metadata_build_btn: Button

# Helper module instances
var _svg_utils
var _dialog_utils
var _config
var _parts_manager
var _builder
var _preview
var _stylebox_builder
var _exporter

# Preload helper scripts
const SvgUtilsScript = preload("Scripts/SvgUtils.gd")
const DialogUtilsScript = preload("Scripts/DialogUtils.gd")
const ThemeConfigScript = preload("Scripts/ThemeConfig.gd")
const ThemePartsManagerScript = preload("Scripts/ThemePartsManager.gd")
const ThemeBuilderScript = preload("Scripts/ThemeBuilder.gd")
const ThemePreviewScript = preload("Scripts/ThemePreview.gd")
const StyleboxBuilderScript = preload("Scripts/StyleboxBuilder.gd")
const ThemeExporterScript = preload("Scripts/ThemeExporter.gd")

# Shared utility functions (used by all helpers via _owner reference)
func get_part_value(entry) -> Variant:
	if entry is Dictionary and entry.has("value"):
		return entry["value"]
	return entry

func get_part_id(entry) -> String:
	if entry is Dictionary and entry.has("id"):
		return entry["id"]
	return ""

func get_base_prop_name(name: String) -> String:
	var copy_idx = name.find("_copy")
	if copy_idx != -1:
		return name.substr(0, copy_idx)
	return name

func _ready() -> void:
	print("AceThemeGenerator _ready() called.")
	
	# Initialize all helper modules
	_svg_utils = SvgUtilsScript.new(self)
	_dialog_utils = DialogUtilsScript.new(self)
	_config = ThemeConfigScript.new(self)
	_parts_manager = ThemePartsManagerScript.new(self)
	_builder = ThemeBuilderScript.new(self)
	_preview = ThemePreviewScript.new(self)
	_stylebox_builder = StyleboxBuilderScript.new(self)
	_exporter = ThemeExporterScript.new(self)
	
	setup_ui()
	_config.load_config()
	_parts_manager.refresh_parts_tree()
	_preview.apply_preview()
	
	if h_split:
		h_split.dragged.connect(_on_h_split_dragged)
		call_deferred("_apply_settings_split_ratio")

func setup_ui() -> void:
	print("AceThemeGenerator setup_ui() called.")
	setup_status_bar()
	# Connect the Select button to show the Node Picker dialog
	select_control_type_btn.pressed.connect(_on_select_control_type_pressed)

	# Populate Property Types dropdown based on selected type change
	prop_type_option.clear()
	prop_name_option.clear()
	prop_type_option.item_selected.connect(_parts_manager.on_prop_type_selected)
	prop_name_option.item_selected.connect(_parts_manager.on_prop_name_selected)

	# Wire the custom type checkbox toggle
	custom_type_check.toggled.connect(_on_custom_type_toggled)

	# Wire Export Settings inputs
	images_edit.text_changed.connect(_on_images_edit_changed)
	fonts_edit.text_changed.connect(_on_fonts_edit_changed)
	metadata_edit.text_changed.connect(_on_metadata_edit_changed)
	output_edit.text_changed.connect(_on_output_edit_changed)

	# Wire Export Settings browse buttons
	images_browse_btn.pressed.connect(_on_images_browse_pressed)
	fonts_browse_btn.pressed.connect(_on_fonts_browse_pressed)
	metadata_browse_btn.pressed.connect(_on_metadata_browse_pressed)
	output_browse_btn.pressed.connect(_on_output_browse_pressed)

	# Wire Collapsible Section Headers
	settings_header_btn.toggled.connect(_on_settings_header_toggled)
	parts_builder_header_btn.toggled.connect(_on_parts_builder_header_toggled)

	# Wire Columns SpinBox
	preview_columns_spin.value_changed.connect(_on_preview_columns_changed)

	# Dynamic creation of Import Config button
	if settings_content:
		var import_btn = Button.new()
		import_btn.name = "ImportConfigBtn"
		import_btn.text = "Import Theme Configuration..."
		import_btn.pressed.connect(_config.on_import_config_pressed)
		settings_content.add_child(import_btn)

	# Connect actions
	%AddPartBtn.pressed.connect(_parts_manager.on_add_part_pressed)
	%NewOverrideBtn.pressed.connect(_parts_manager.on_new_override_pressed)
	%DuplicateOverrideBtn.pressed.connect(_parts_manager.on_duplicate_override_pressed)
	%DeleteOverrideBtn.pressed.connect(_parts_manager.on_delete_override_pressed)
	%ApplyPreviewBtn.pressed.connect(_preview.apply_preview)
	%CompileBtn.pressed.connect(_exporter.on_compile_pressed)
	parts_tree.item_selected.connect(_parts_manager.on_tree_item_selected)
	override_name_edit.text_changed.connect(_parts_manager.on_override_name_changed)

	# Setup Parts Tree titles
	parts_tree.columns = 4
	parts_tree.set_column_title(0, "Control")
	parts_tree.set_column_title(1, "Name / ID")
	parts_tree.set_column_title(2, "Property")
	parts_tree.set_column_title(3, "Value")
	parts_tree.column_titles_visible = true

	# Dynamic insertion of Metadata stylebox builder right after Custom Name in Grid
	_stylebox_builder.ensure_metadata_controls()
	
	# Update PreviewHeader label to indicate it represents the Panel Container style
	var preview_header = preview_area.get_parent().get_node("PreviewHeaderBox/PreviewHeader") as Label
	if preview_header:
		preview_header.text = "Live Theme Preview (Panel Container)"
		
	# Wire live preview controls
	if preview_item_width_spin:
		preview_item_width_spin.value = preview_item_width
		preview_item_width_spin.value_changed.connect(_on_preview_item_width_changed)

	if preview_font_size_spin:
		preview_font_size_spin.value = preview_font_size
		preview_font_size_spin.value_changed.connect(_on_preview_font_size_changed)

	if preview_separation_spin:
		preview_separation_spin.value = preview_separation
		preview_separation_spin.value_changed.connect(_on_preview_separation_changed)

	if preview_scale_spin:
		preview_scale_spin.value = round(preview_scale * 100.0)
		preview_scale_spin.value_changed.connect(_on_preview_scale_spin_changed)

	if preview_scale_option:
		populate_scale_presets()
		preview_scale_option.item_selected.connect(_on_preview_scale_option_selected)
		sync_scale_ui(false)

	if preview_scroll:
		preview_scroll.resized.connect(_on_preview_scroll_resized)
	if preview_margin:
		preview_margin.resized.connect(_on_preview_margin_resized)

	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(_on_root_window_resized)
		
	if settings_view_option:
		settings_view_option.clear()
		settings_view_option.add_item("20% Settings (80% Preview)")
		settings_view_option.add_item("50% Split")
		settings_view_option.add_item("80% Settings (20% Preview)")
		settings_view_option.add_item("100% Full Settings")
		settings_view_option.selected = 1 # Default to 50% Split
		settings_view_option.item_selected.connect(_on_settings_view_option_selected)

	_apply_editor_scaling()

func _apply_editor_scaling() -> void:
	if not Engine.is_editor_hint():
		return
		
	var scale = EditorInterface.get_editor_scale()
	if scale == 1.0:
		return
		
	print("Applying editor scaling of ", scale, " to AceThemeGenerator UI.")
	
	# Scale font sizes for nodes that have hardcoded overrides in the tscn
	var title_lbl = get_node_or_null("MainPanel/HSplit/LeftScroll/LeftBox/TitleLabel") as Label
	if title_lbl:
		title_lbl.add_theme_font_size_override("font_size", int(20 * scale))
		
	if settings_header_btn:
		settings_header_btn.add_theme_font_size_override("font_size", int(14 * scale))
		
	if parts_builder_header_btn:
		parts_builder_header_btn.add_theme_font_size_override("font_size", int(14 * scale))
		
	var preview_header_lbl = preview_area.get_parent().get_node_or_null("PreviewHeaderBox/PreviewHeader") as Label
	if preview_header_lbl:
		preview_header_lbl.add_theme_font_size_override("font_size", int(16 * scale))
		
	var panel_label = preview_area.get_node_or_null("PreviewVBox/PanelContainerLabel") as Label
	if panel_label:
		panel_label.add_theme_font_size_override("font_size", int(12 * scale))
		
	if parts_tree:
		parts_tree.custom_minimum_size = Vector2(0, int(150 * scale))
	if preview_item_width_spin:
		preview_item_width_spin.custom_minimum_size = Vector2(int(80 * scale), 0)
	if preview_font_size_spin:
		preview_font_size_spin.custom_minimum_size = Vector2(int(80 * scale), 0)
	if preview_separation_spin:
		preview_separation_spin.custom_minimum_size = Vector2(int(80 * scale), 0)
	if preview_scale_option:
		preview_scale_option.custom_minimum_size = Vector2(int(140 * scale), 0)
	if preview_scale_spin:
		preview_scale_spin.custom_minimum_size = Vector2(int(80 * scale), 0)

# --- Signal Handlers (thin pass-throughs) ---

func _on_select_control_type_pressed() -> void:
	print("AceThemeGenerator _on_select_control_type_pressed() called. is_editor_hint: ", Engine.is_editor_hint())
	if Engine.is_editor_hint():
		var blocklist: Array[StringName] = []
		# Open the native node creation dialog, filtering for Control classes
		print("Calling EditorInterface.popup_create_dialog...")
		EditorInterface.popup_create_dialog(
			_on_control_type_selected,
			"Control",
			control_type_edit.text,
			"Select Control Type",
			blocklist
		)

func _on_control_type_selected(type_name: StringName) -> void:
	var type_str = str(type_name)
	if type_str != "":
		control_type_edit.text = type_str
		_active_prop_key = ""
		_creating_new_override = true
		_parts_manager.update_property_types()

func _on_custom_type_toggled(pressed: bool) -> void:
	custom_type_name_edit.editable = pressed
	if not pressed:
		custom_type_name_edit.text = ""

func _on_images_edit_changed(new_text: String) -> void:
	image_folder = new_text.strip_edges()
	_config.save_config()
	_svg_utils.reimport_svgs_as_dpi_textures(image_folder)

func _on_fonts_edit_changed(new_text: String) -> void:
	fonts_folder = new_text.strip_edges()
	_config.save_config()

func _on_metadata_edit_changed(new_text: String) -> void:
	metadata_file = new_text.strip_edges()
	_config.save_config()

func _on_output_edit_changed(new_text: String) -> void:
	output_file = new_text.strip_edges()
	_config.save_config()

func _on_images_browse_pressed() -> void:
	_dialog_utils.browse_dir(images_edit, "Select Images Folder")

func _on_fonts_browse_pressed() -> void:
	_dialog_utils.browse_dir(fonts_edit, "Select Fonts Folder")

func _on_metadata_browse_pressed() -> void:
	_dialog_utils.browse_file(metadata_edit, "*.json", "Select Metadata File")

func _on_output_browse_pressed() -> void:
	_dialog_utils.browse_file(output_edit, "*.tres,*.theme", "Select Output Theme File", true)

func _on_settings_header_toggled(pressed: bool) -> void:
	settings_content.visible = pressed
	settings_header_btn.text = "▼ Export Settings" if pressed else "▶ Export Settings"

func _on_parts_builder_header_toggled(pressed: bool) -> void:
	parts_builder_content.visible = pressed
	parts_builder_header_btn.text = "▼ Theme Parts Builder" if pressed else "▶ Theme Parts Builder"

func _on_preview_columns_changed(value: float) -> void:
	preview_columns = int(value)
	_config.save_config()
	if preview_grid and not theme_parts.is_empty():
		preview_grid.columns = preview_columns

func _on_preview_item_width_changed(value: float) -> void:
	preview_item_width = int(value)
	_config.save_config()
	_preview.apply_preview()

func _on_preview_font_size_changed(value: float) -> void:
	preview_font_size = int(value)
	_config.save_config()
	_preview.apply_preview()

func _on_preview_separation_changed(value: float) -> void:
	preview_separation = int(value)
	_config.save_config()
	_preview.apply_preview()

func get_user_window_resolution() -> Vector2i:
	if Engine.is_editor_hint():
		var win_size = DisplayServer.window_get_size()
		if win_size.x > 0 and win_size.y > 0:
			return win_size
		var vp = get_viewport()
		if vp and vp.size.x > 0 and vp.size.y > 0:
			return vp.size
	return Vector2i(1920, 1080)

func get_user_screen_resolution() -> Vector2i:
	if Engine.is_editor_hint():
		var screen = DisplayServer.window_get_current_screen()
		var scr_size = DisplayServer.screen_get_size(screen)
		if scr_size.x > 0 and scr_size.y > 0:
			return scr_size
	return Vector2i(1920, 1080)

func populate_scale_presets() -> void:
	if not preview_scale_option:
		return

	var win_res = get_user_window_resolution()
	var scr_res = get_user_screen_resolution()

	var win_scale = clamp(1080.0 / float(win_res.y), 0.10, 5.0) if win_res.y > 0 else 1.0
	var scr_scale = clamp(1080.0 / float(scr_res.y), 0.10, 5.0) if scr_res.y > 0 else 1.0

	scale_presets.clear()
	scale_presets.append({
		"label": "Match Window (%d×%d - %d%%)" % [win_res.x, win_res.y, int(round(win_scale * 100.0))],
		"scale": win_scale,
		"mode": "window"
	})
	scale_presets.append({
		"label": "Match Screen (%d×%d - %d%%)" % [scr_res.x, scr_res.y, int(round(scr_scale * 100.0))],
		"scale": scr_scale,
		"mode": "screen"
	})
	scale_presets.append({"label": "1920×1080 (Base - 100%)", "scale": 1.0, "mode": "resolution"})
	scale_presets.append({"label": "3840×2160 (4K - 50%)", "scale": 1080.0 / 2160.0, "mode": "resolution"})
	scale_presets.append({"label": "2560×1440 (2K - 75%)", "scale": 1080.0 / 1440.0, "mode": "resolution"})
	scale_presets.append({"label": "1600×900 (900p - 120%)", "scale": 1080.0 / 900.0, "mode": "resolution"})
	scale_presets.append({"label": "1366×768 (141%)", "scale": 1080.0 / 768.0, "mode": "resolution"})
	scale_presets.append({"label": "1280×720 (720p - 150%)", "scale": 1080.0 / 720.0, "mode": "resolution"})
	scale_presets.append({"label": "25% Scale", "scale": 0.25, "mode": "percent"})
	scale_presets.append({"label": "50% Scale", "scale": 0.50, "mode": "percent"})
	scale_presets.append({"label": "75% Scale", "scale": 0.75, "mode": "percent"})
	scale_presets.append({"label": "100% Scale", "scale": 1.00, "mode": "percent"})
	scale_presets.append({"label": "125% Scale", "scale": 1.25, "mode": "percent"})
	scale_presets.append({"label": "150% Scale", "scale": 1.50, "mode": "percent"})
	scale_presets.append({"label": "200% Scale", "scale": 2.00, "mode": "percent"})
	scale_presets.append({"label": "Custom", "scale": -1.0, "mode": "custom"})

	var cur_sel = preview_scale_option.selected
	preview_scale_option.clear()
	for preset in scale_presets:
		preview_scale_option.add_item(preset["label"])

	if cur_sel >= 0 and cur_sel < scale_presets.size():
		preview_scale_option.selected = cur_sel

func sync_scale_ui(save: bool = true) -> void:
	if _is_syncing_scale_ui:
		return
	_is_syncing_scale_ui = true

	if preview_scale_spin:
		preview_scale_spin.value = round(preview_scale * 100.0)

	if preview_scale_option and not scale_presets.is_empty():
		var matched_idx = -1
		if preview_scale_mode == "window":
			matched_idx = 0
		elif preview_scale_mode == "screen":
			matched_idx = 1
		else:
			for i in range(2, scale_presets.size() - 1):
				if abs(scale_presets[i]["scale"] - preview_scale) < 0.005:
					matched_idx = i
					break
			if matched_idx == -1:
				matched_idx = scale_presets.size() - 1 # "Custom"
		preview_scale_option.selected = matched_idx

	_is_syncing_scale_ui = false

	if save:
		_config.save_config()
	if _preview:
		_preview.update_preview_scale_layout()

func _on_preview_scale_option_selected(idx: int) -> void:
	if _is_syncing_scale_ui or idx < 0 or idx >= scale_presets.size():
		return

	var preset = scale_presets[idx]
	var mode = str(preset.get("mode", ""))

	if mode == "window":
		preview_scale_mode = "window"
		var win_res = get_user_window_resolution()
		if win_res.y > 0:
			preview_scale = clamp(1080.0 / float(win_res.y), 0.10, 5.0)
	elif mode == "screen":
		preview_scale_mode = "screen"
		var scr_res = get_user_screen_resolution()
		if scr_res.y > 0:
			preview_scale = clamp(1080.0 / float(scr_res.y), 0.10, 5.0)
	elif mode == "custom":
		preview_scale_mode = "custom"
	else:
		preview_scale_mode = "preset"
		preview_scale = float(preset["scale"])

	sync_scale_ui(true)

func _on_preview_scale_spin_changed(value: float) -> void:
	if _is_syncing_scale_ui:
		return

	preview_scale = clamp(value / 100.0, 0.10, 5.0)
	preview_scale_mode = "custom"
	sync_scale_ui(true)

func _on_root_window_resized() -> void:
	if preview_scale_mode == "window":
		var win_res = get_user_window_resolution()
		if win_res.y > 0:
			preview_scale = clamp(1080.0 / float(win_res.y), 0.10, 5.0)
		populate_scale_presets()
		sync_scale_ui(true)
	elif preview_scale_mode == "screen":
		var scr_res = get_user_screen_resolution()
		if scr_res.y > 0:
			preview_scale = clamp(1080.0 / float(scr_res.y), 0.10, 5.0)
		populate_scale_presets()
		sync_scale_ui(true)
	else:
		populate_scale_presets()

func _on_preview_scroll_resized() -> void:
	if _preview:
		_preview.update_preview_scale_layout()

func _on_preview_margin_resized() -> void:
	if _preview:
		_preview.update_preview_scale_layout()

func _update_preview_scale_deferred() -> void:
	if _preview:
		_preview.update_preview_scale_layout()

func _on_settings_view_option_selected(idx: int) -> void:
	match idx:
		0: settings_split_ratio = 0.20
		1: settings_split_ratio = 0.50
		2: settings_split_ratio = 0.80
		3: settings_split_ratio = 0.98
	_apply_settings_split_ratio()
	_config.save_config()

func set_settings_panel_view_ratio(ratio: float) -> void:
	settings_split_ratio = clamp(ratio, 0.05, 1.0)
	_apply_settings_split_ratio()
	_config.save_config()

func _apply_settings_split_ratio() -> void:
	if not h_split:
		return
	var total_w = h_split.size.x
	if total_w <= 0:
		total_w = h_split.get_rect().size.x
	if total_w <= 0:
		total_w = get_viewport_rect().size.x
	if total_w > 0:
		h_split.split_offset = int(total_w * (settings_split_ratio - 0.5))
		
	if settings_view_option:
		if abs(settings_split_ratio - 0.20) < 0.05:
			settings_view_option.selected = 0
		elif abs(settings_split_ratio - 0.50) < 0.05:
			settings_view_option.selected = 1
		elif abs(settings_split_ratio - 0.80) < 0.05:
			settings_view_option.selected = 2
		elif abs(settings_split_ratio - 0.98) < 0.05:
			settings_view_option.selected = 3

func _on_h_split_dragged(offset: int) -> void:
	var total_w = h_split.size.x
	if total_w <= 0:
		total_w = h_split.get_rect().size.x
	if total_w > 0:
		settings_split_ratio = clamp((float(offset) + total_w * 0.5) / total_w, 0.05, 1.0)
		_config.save_config()
		
		if settings_view_option:
			if abs(settings_split_ratio - 0.20) < 0.05:
				settings_view_option.selected = 0
			elif abs(settings_split_ratio - 0.50) < 0.05:
				settings_view_option.selected = 1
			elif abs(settings_split_ratio - 0.80) < 0.05:
				settings_view_option.selected = 2
			elif abs(settings_split_ratio - 0.98) < 0.05:
				settings_view_option.selected = 3

func setup_status_bar() -> void:
	var right_panel = get_node_or_null("MainPanel/HSplit/RightPanel")
	if not right_panel:
		right_panel = find_child("RightPanel", true, false)
	if not right_panel:
		right_panel = get_node_or_null("MainPanel/HSplit/LeftScroll/LeftBox")
	if not right_panel:
		return
		
	var existing = right_panel.get_node_or_null("StatusBar")
	if existing:
		existing.name = "StatusBar_Old"
		existing.queue_free()
		
	status_bar = PanelContainer.new()
	status_bar.name = "StatusBar"
	status_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
	sb_style.border_color = Color(0.2, 0.55, 0.4, 0.7)
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(6)
	sb_style.content_margin_left = 12
	sb_style.content_margin_right = 12
	sb_style.content_margin_top = 6
	sb_style.content_margin_bottom = 6
	status_bar.add_theme_stylebox_override("panel", sb_style)
	
	var hbox = HBoxContainer.new()
	hbox.name = "StatusHBox"
	hbox.add_theme_constant_override("separation", 8)
	status_bar.add_child(hbox)
	
	status_icon = Label.new()
	status_icon.name = "StatusIcon"
	status_icon.text = "✓"
	status_icon.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
	hbox.add_child(status_icon)
	
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Ready"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	hbox.add_child(status_label)
	
	# Add below PreviewArea in RightPanel (always visible)
	right_panel.add_child(status_bar)

func set_status(text: String, is_loading: bool = false) -> void:
	if not status_bar or not is_instance_valid(status_bar):
		return
		
	status_bar.visible = true
	if status_label:
		status_label.text = text
		
	var style = status_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if is_loading:
		if status_icon:
			status_icon.text = "⏳"
			status_icon.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		if style:
			style.border_color = Color(0.95, 0.75, 0.2, 0.9)
			style.bg_color = Color(0.18, 0.16, 0.10, 0.95)
		status_bar.queue_redraw()
		if is_inside_tree():
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BUSY)
			await get_tree().process_frame
	else:
		if status_icon:
			status_icon.text = "✓"
			status_icon.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
		if style:
			style.border_color = Color(0.2, 0.6, 0.35, 0.6)
			style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
		status_bar.queue_redraw()
		if is_inside_tree():
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
