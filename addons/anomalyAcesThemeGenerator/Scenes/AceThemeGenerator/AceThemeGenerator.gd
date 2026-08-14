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
@onready var new_override_btn: Button = %NewOverrideBtn
@onready var duplicate_override_btn: Button = %DuplicateOverrideBtn
@onready var delete_override_btn: Button = %DeleteOverrideBtn

# Data model for custom theme overrides (Theme Parts)
# Structure: { "Button": { "colors": { "font_color": { "value": Color, "id": String } } } }
var theme_parts: Dictionary = {}
var theme_variations: Dictionary = {}
var _config_loaded: bool = false
var preview_columns: int = 3
var preview_item_width: int = 200
var preview_item_width_spin: SpinBox
var preview_font_size: int = 16
var preview_font_size_spin: SpinBox
var preview_texts: Dictionary = {}
var _target_select_meta = null
var _active_prop_key: String = ""
var _creating_new_override: bool = false

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
	h_split.resized.connect(_on_h_split_resized)

func setup_ui() -> void:
	print("AceThemeGenerator setup_ui() called.")
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
		
	# Dynamic creation of Preview Item Width controls in PreviewHeaderBox
	var header_box = preview_area.get_parent().get_node_or_null("PreviewHeaderBox")
	if header_box:
		# Add separator
		var sep = Control.new()
		sep.custom_minimum_size = Vector2(10, 0)
		header_box.add_child(sep)
		
		var width_label = Label.new()
		width_label.text = "Item Width:"
		header_box.add_child(width_label)
		
		preview_item_width_spin = SpinBox.new()
		preview_item_width_spin.name = "PreviewItemWidthSpin"
		preview_item_width_spin.min_value = 0
		preview_item_width_spin.max_value = 2000
		preview_item_width_spin.step = 10
		preview_item_width_spin.value = preview_item_width
		preview_item_width_spin.custom_minimum_size = Vector2(80, 0)
		preview_item_width_spin.value_changed.connect(_on_preview_item_width_changed)
		header_box.add_child(preview_item_width_spin)
		
		# Add separator
		var sep2 = Control.new()
		sep2.custom_minimum_size = Vector2(10, 0)
		header_box.add_child(sep2)
		
		var font_size_label = Label.new()
		font_size_label.text = "Font Size:"
		header_box.add_child(font_size_label)
		
		preview_font_size_spin = SpinBox.new()
		preview_font_size_spin.name = "PreviewFontSizeSpin"
		preview_font_size_spin.min_value = 8
		preview_font_size_spin.max_value = 72
		preview_font_size_spin.value = preview_font_size
		preview_font_size_spin.custom_minimum_size = Vector2(80, 0)
		preview_font_size_spin.value_changed.connect(_on_preview_font_size_changed)
		header_box.add_child(preview_font_size_spin)
		
	_apply_editor_scaling()

func _apply_editor_scaling() -> void:
	if not Engine.is_editor_hint():
		return
		
	var scale = EditorInterface.get_editor_scale()
	if scale == 1.0:
		return
		
	print("Applying editor scaling of ", scale, " to AceThemeGenerator UI.")
	
	# Scale font sizes for nodes that have hardcoded overrides in the tscn
	var title_lbl = $MainPanel/HSplit/LeftScroll/LeftBox/TitleLabel
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

func _on_h_split_resized() -> void:
	h_split.split_offset = int(h_split.size.x * 0.4) - int(h_split.size.x * 0.5)