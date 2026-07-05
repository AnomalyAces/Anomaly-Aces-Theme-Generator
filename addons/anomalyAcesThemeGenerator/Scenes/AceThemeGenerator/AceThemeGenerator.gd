@tool
extends Control

# Configuration file paths
const CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/working/config.json"
const OLD_CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/config.json"

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

func _get_part_value(entry) -> Variant:
	if entry is Dictionary and entry.has("value"):
		return entry["value"]
	return entry

func _get_part_id(entry) -> String:
	if entry is Dictionary and entry.has("id"):
		return entry["id"]
	return ""

func _get_base_prop_name(name: String) -> String:
	var copy_idx = name.find("_copy")
	if copy_idx != -1:
		return name.substr(0, copy_idx)
	return name

func _ensure_config_loaded() -> void:
	if not _config_loaded:
		load_config()

func _cleanup_unique_properties() -> void:
	for ctrl_type in theme_parts.keys():
		var sections = theme_parts[ctrl_type]
		for sec_name in sections.keys():
			var overrides = sections[sec_name]
			
			# Group keys by their base property name
			var groups = {}
			for prop_name in overrides.keys():
				var base_name = _get_base_prop_name(prop_name)
				if not groups.has(base_name):
					groups[base_name] = []
				groups[base_name].append(prop_name)
			
			# Process each group to ensure at most one entry exists per base property
			for base_name in groups.keys():
				var keys = groups[base_name]
				var keep_key = ""
				
				if keys.size() > 1:
					# There are duplicates for this base property.
					# Check if one of the duplicates is the active key being edited.
					# If the active key is in this group and contains "_copy", we keep both the base name and the active copy.
					var has_active_copy = false
					for k in keys:
						if k == _active_prop_key and k.contains("_copy"):
							has_active_copy = true
							break
					
					if has_active_copy:
						# Keep both the base key and the active copy, erase any other inactive copies.
						for k in keys:
							if k != base_name and k != _active_prop_key:
								overrides.erase(k)
						# Skip renaming of keep_key since we want to keep it as _copy for now
						continue
					else:
						# No active copy being edited, deduplicate: keep base name or first key
						keep_key = base_name if keys.has(base_name) else keys[0]
						for k in keys:
							if k != keep_key:
								overrides.erase(k)
								if _active_prop_key == k:
									_active_prop_key = keep_key
								if _target_select_meta is Dictionary and _target_select_meta.get("prop_name") == k:
									_target_select_meta["prop_name"] = keep_key
				else:
					keep_key = keys[0]
				
				# If the remaining key is a copy, rename it to the base name
				if keep_key != base_name:
					var record = overrides[keep_key]
					overrides.erase(keep_key)
					overrides[base_name] = record
					
					if _active_prop_key == keep_key:
						_active_prop_key = base_name
					if _target_select_meta is Dictionary and _target_select_meta.get("prop_name") == keep_key:
						_target_select_meta["prop_name"] = base_name

func _ready() -> void:
	print("AceThemeGenerator _ready() called.")
	setup_ui()
	load_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()
	h_split.resized.connect(_on_h_split_resized)

func setup_ui() -> void:
	print("AceThemeGenerator setup_ui() called.")
	# Connect the Select button to show the Node Picker dialog
	select_control_type_btn.pressed.connect(_on_select_control_type_pressed)

	# Populate Property Types dropdown based on selected type change
	prop_type_option.clear()
	prop_name_option.clear()
	prop_type_option.item_selected.connect(_on_prop_type_selected)
	prop_name_option.item_selected.connect(_on_prop_name_selected)

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
		import_btn.pressed.connect(_on_import_config_pressed)
		settings_content.add_child(import_btn)

	# Connect actions
	%AddPartBtn.pressed.connect(_on_add_part_pressed)
	%NewOverrideBtn.pressed.connect(_on_new_override_pressed)
	%DuplicateOverrideBtn.pressed.connect(_on_duplicate_override_pressed)
	%DeleteOverrideBtn.pressed.connect(_on_delete_override_pressed)
	%ApplyPreviewBtn.pressed.connect(_on_apply_preview_pressed)
	%CompileBtn.pressed.connect(_on_compile_pressed)
	parts_tree.item_selected.connect(_on_tree_item_selected)
	override_name_edit.text_changed.connect(_on_override_name_changed)

	# Setup Parts Tree titles
	parts_tree.columns = 4
	parts_tree.set_column_title(0, "Control")
	parts_tree.set_column_title(1, "Name / ID")
	parts_tree.set_column_title(2, "Property")
	parts_tree.set_column_title(3, "Value")
	parts_tree.column_titles_visible = true

	# Dynamic insertion of Metadata stylebox builder right after Custom Name in Grid
	_ensure_metadata_controls()
	
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
		update_property_types()

func update_property_types() -> void:
	var previous_type_text = ""
	if prop_type_option.selected != -1:
		previous_type_text = prop_type_option.get_item_text(prop_type_option.selected)

	prop_type_option.clear()
	prop_name_option.clear()
	
	var selected_type = control_type_edit.text.strip_edges()
	if selected_type == "":
		return
		
	# Resolve base class if it's a custom variation
	var base_class = selected_type
	if theme_variations.has(base_class):
		base_class = theme_variations[base_class]
		
	if not ClassDB.class_exists(base_class):
		base_class = "Control"
		
	var default_theme = ThemeDB.get_default_theme()
	
	# Check each category to see if there are default properties
	var has_colors = not default_theme.get_color_list(base_class).is_empty()
	var has_constants = not default_theme.get_constant_list(base_class).is_empty()
	var has_fonts = not default_theme.get_font_list(base_class).is_empty()
	var has_font_sizes = not default_theme.get_font_size_list(base_class).is_empty()
	var has_icons = not default_theme.get_icon_list(base_class).is_empty()
	var has_styleboxes = not default_theme.get_stylebox_list(base_class).is_empty()
	
	if has_colors:
		prop_type_option.add_item("Color")
	if has_constants:
		prop_type_option.add_item("Constant")
	if has_fonts:
		prop_type_option.add_item("Font")
	if has_font_sizes:
		prop_type_option.add_item("Font Size")
	if has_icons:
		prop_type_option.add_item("Icon")
	if has_styleboxes:
		prop_type_option.add_item("StyleBox")
		
	var reselected = false
	if previous_type_text != "":
		for i in range(prop_type_option.item_count):
			if prop_type_option.get_item_text(i) == previous_type_text:
				prop_type_option.selected = i
				reselected = true
				break
				
	if not reselected and prop_type_option.item_count > 0:
		prop_type_option.selected = 0
		
	if prop_type_option.selected != -1:
		update_property_names()

func update_property_names() -> void:
	var previous_name_text = ""
	if prop_name_option.selected != -1:
		previous_name_text = prop_name_option.get_item_text(prop_name_option.selected)

	prop_name_option.clear()
	
	var selected_type = control_type_edit.text.strip_edges()
	if selected_type == "" or prop_type_option.selected == -1:
		update_value_input_control()
		return
		
	# Resolve base class if it's a custom variation
	var base_class = selected_type
	if theme_variations.has(base_class):
		base_class = theme_variations[base_class]
		
	if not ClassDB.class_exists(base_class):
		base_class = "Control"
		
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	var default_theme = ThemeDB.get_default_theme()
	
	var names: PackedStringArray = []
	match prop_type:
		"color":
			names = default_theme.get_color_list(base_class)
		"constant":
			names = default_theme.get_constant_list(base_class)
		"font":
			names = default_theme.get_font_list(base_class)
		"font_size":
			names = default_theme.get_font_size_list(base_class)
		"icon":
			names = default_theme.get_icon_list(base_class)
		"stylebox":
			names = default_theme.get_stylebox_list(base_class)
			
	names.sort()
	for n in names:
		prop_name_option.add_item(n)
		
	var reselected = false
	if previous_name_text != "":
		for i in range(prop_name_option.item_count):
			if prop_name_option.get_item_text(i) == previous_name_text:
				prop_name_option.selected = i
				reselected = true
				break
				
	if not reselected:
		prop_name_option.selected = -1

	update_value_input_control()

func update_value_input_control() -> void:
	_ensure_metadata_controls()
	
	# Clear previous children in the container
	for child in value_container.get_children():
		child.queue_free()
		
	if prop_type_option.selected == -1:
		# Hide metadata builder options if no property is selected
		if metadata_build_check and metadata_build_label:
			metadata_build_label.visible = false
			metadata_build_check.visible = false
			metadata_file_label.visible = false
			metadata_builder_box.visible = false
			metadata_build_check.button_pressed = false
		return
		
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	
	# Attempt to load existing value
	var existing_val = null
	var current_control = control_type_edit.text.strip_edges()
	if custom_type_check and custom_type_check.button_pressed:
		var custom_name = custom_type_name_edit.text.strip_edges()
		if custom_name != "":
			current_control = custom_name
	var current_prop_name = ""
	if prop_name_option.selected != -1:
		current_prop_name = prop_name_option.get_item_text(prop_name_option.selected)
		
	var prop_key = current_prop_name
	if _active_prop_key != "" and _get_base_prop_name(_active_prop_key) == current_prop_name:
		prop_key = _active_prop_key
		
	var section_map = {
		"color": "colors",
		"constant": "constants",
		"font": "fonts",
		"font_size": "font_sizes",
		"icon": "icons",
		"stylebox": "styleboxes"
	}
	var sec = section_map.get(prop_type, "")
	if sec != "" and current_control != "" and prop_key != "":
		if theme_parts.has(current_control) and theme_parts[current_control].has(sec) and theme_parts[current_control][sec].has(prop_key):
			existing_val = theme_parts[current_control][sec][prop_key]

	var raw_val = null
	if existing_val != null:
		var ext_id = _get_part_id(existing_val)
		override_name_edit.text = ext_id
		raw_val = _get_part_value(existing_val)
	else:
		# Preserve the custom override name/ID if creating a new override from scratch
		if parts_tree == null or parts_tree.get_selected() != null:
			override_name_edit.text = ""

	match prop_type:
		"color":
			# Add a ColorPickerButton
			var cp = ColorPickerButton.new()
			cp.name = "ColorPicker"
			if raw_val is String and raw_val.begins_with("#"):
				cp.color = Color.from_string(raw_val, Color.WHITE)
			else:
				cp.color = Color.WHITE
			cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cp.color_changed.connect(_on_color_picker_changed)
			value_container.add_child(cp)
		"constant", "font_size":
			# Add a SpinBox
			var sb = SpinBox.new()
			sb.name = "SpinBox"
			sb.min_value = -10000
			sb.max_value = 10000
			if raw_val != null:
				sb.value = float(raw_val)
			else:
				sb.value = 0
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.value_changed.connect(_on_spin_box_changed)
			value_container.add_child(sb)
		"font", "icon", "stylebox":
			# Add an EditorResourcePicker or fallback Button
			var erp = null
			if Engine.is_editor_hint() and ClassDB.class_exists("EditorResourcePicker"):
				erp = ClassDB.instantiate("EditorResourcePicker")
			else:
				erp = Button.new() # Fallback for headless tests
			erp.name = "ResourcePicker"
			erp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if "base_type" in erp:
				match prop_type:
					"font":
						erp.base_type = "Font"
					"icon":
						erp.base_type = "Texture2D"
					"stylebox":
						erp.base_type = "StyleBox"
			
			if raw_val is String and raw_val != "":
				if ResourceLoader.exists(raw_val):
					var res = ResourceLoader.load(raw_val)
					if res:
						if "edited_resource" in erp:
							erp.edited_resource = res
						elif erp is Button:
							erp.text = raw_val
			
			if erp.has_signal("resource_changed"):
				erp.resource_changed.connect(_on_erp_resource_changed)
			if erp.has_signal("resource_selected"):
				erp.resource_selected.connect(_on_erp_resource_selected)
			
			value_container.add_child(erp)

	# Update visibility of Build from Metadata options (opt-in, right after Custom Name in Grid)
	if metadata_build_check and metadata_build_label:
		if prop_type == "stylebox":
			metadata_build_label.visible = true
			metadata_build_check.visible = true
			var pressed = metadata_build_check.button_pressed
			if metadata_file_label: metadata_file_label.visible = pressed
			if metadata_builder_box: metadata_builder_box.visible = pressed
			_refresh_metadata_dropdown()
		else:
			metadata_build_label.visible = false
			metadata_build_check.visible = false
			if metadata_file_label: metadata_file_label.visible = false
			if metadata_builder_box: metadata_builder_box.visible = false
			metadata_build_check.button_pressed = false

# Config Load/Save
func save_config() -> void:
	_ensure_config_loaded()
	_cleanup_unique_properties()
	var dir_path = CONFIG_FILE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			printerr("Failed to create working directory: ", dir_path, " Error: ", err)
	var config = {
		"image_folder": image_folder,
		"fonts_folder": fonts_folder,
		"metadata_file": metadata_file,
		"output_file": output_file,
		"theme_parts": theme_parts,
		"theme_variations": theme_variations,
		"preview_columns": preview_columns,
		"preview_item_width": preview_item_width,
		"preview_font_size": preview_font_size,
		"preview_texts": preview_texts
	}
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()

func load_config() -> void:
	_config_loaded = false
	
	# Migrate old config.json to the new working directory if it exists
	if FileAccess.file_exists(OLD_CONFIG_FILE_PATH) and not FileAccess.file_exists(CONFIG_FILE_PATH):
		var new_dir = CONFIG_FILE_PATH.get_base_dir()
		if not DirAccess.dir_exists_absolute(new_dir):
			DirAccess.make_dir_recursive_absolute(new_dir)
		var err = DirAccess.copy_absolute(OLD_CONFIG_FILE_PATH, CONFIG_FILE_PATH)
		if err == OK:
			DirAccess.remove_absolute(OLD_CONFIG_FILE_PATH)
			print("Migrated old config.json to: ", CONFIG_FILE_PATH)
		else:
			printerr("Failed to migrate old config.json: ", err)

	# Initialize default paths
	var default_image_folder = "res://addons/anomalyAcesThemeGenerator/working/Images"
	var default_fonts_folder = "res://addons/anomalyAcesThemeGenerator/working/Fonts"
	var default_metadata_file = "res://addons/anomalyAcesThemeGenerator/working/Metadata/metadata.json"
	var default_output_file = "res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres"

	if FileAccess.file_exists(CONFIG_FILE_PATH):
		var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			var error = json.parse(json_string)
			if error == OK:
				var data = json.get_data()
				if data is Dictionary:
					image_folder = data.get("image_folder", "")
					fonts_folder = data.get("fonts_folder", "")
					metadata_file = data.get("metadata_file", "")
					output_file = data.get("output_file", "")
					theme_parts = data.get("theme_parts", {})
					theme_variations = data.get("theme_variations", {})
					preview_columns = int(data.get("preview_columns", 3))
					preview_item_width = int(data.get("preview_item_width", 200))
					preview_font_size = int(data.get("preview_font_size", 16))
					preview_texts = data.get("preview_texts", {})
			else:
				printerr("Failed to parse config.json: ", json.get_error_message(), " at line ", json.get_error_line())

	# Apply fallbacks if empty
	if image_folder.strip_edges() == "":
		image_folder = default_image_folder
	if fonts_folder.strip_edges() == "":
		fonts_folder = default_fonts_folder
	if metadata_file.strip_edges() == "":
		metadata_file = default_metadata_file
	if output_file.strip_edges() == "":
		output_file = default_output_file

	# Ensure the subdirectories exist
	_ensure_dir_exists(image_folder)
	_ensure_dir_exists(fonts_folder)
	_ensure_dir_exists(metadata_file.get_base_dir())
	_ensure_dir_exists(output_file.get_base_dir())

	# Update UI inputs
	if images_edit:
		images_edit.text = image_folder
	if fonts_edit:
		fonts_edit.text = fonts_folder
	if metadata_edit:
		metadata_edit.text = metadata_file
	if output_edit:
		output_edit.text = output_file

	if preview_columns_spin:
		preview_columns_spin.value = preview_columns
	if preview_item_width_spin:
		preview_item_width_spin.value = preview_item_width
	if preview_font_size_spin:
		preview_font_size_spin.value = preview_font_size

	_config_loaded = true
	_cleanup_unique_properties()
	
	# Save the cleaned configuration to disk to repair any stale copy-suffixed unique entries
	var cleaned_config = {
		"image_folder": image_folder,
		"fonts_folder": fonts_folder,
		"metadata_file": metadata_file,
		"output_file": output_file,
		"theme_parts": theme_parts,
		"theme_variations": theme_variations,
		"preview_columns": preview_columns,
		"preview_item_width": preview_item_width,
		"preview_font_size": preview_font_size,
		"preview_texts": preview_texts
	}
	var save_file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(cleaned_config, "\t"))
		save_file.close()
		print("Cleaned up and saved config on load.")
	
	_reimport_svgs_as_dpi_textures(image_folder)

func _ensure_dir_exists(path: String) -> void:
	if path == "":
		return
	if not DirAccess.dir_exists_absolute(path):
		var err = DirAccess.make_dir_recursive_absolute(path)
		if err == OK:
			print("Created directory: ", path)
		else:
			printerr("Failed to create directory: ", path, " Error: ", err)

# Parts Builder Management
func _on_new_override_pressed() -> void:
	_active_prop_key = ""
	_creating_new_override = true
	if metadata_build_check:
		metadata_build_check.button_pressed = false
	if parts_tree:
		parts_tree.deselect_all()
	if override_name_edit:
		override_name_edit.text = ""
	if control_type_edit:
		control_type_edit.text = ""
	if custom_type_check:
		custom_type_check.button_pressed = false
	if custom_type_name_edit:
		custom_type_name_edit.text = ""
	if prop_type_option:
		prop_type_option.selected = -1
	if prop_name_option:
		prop_name_option.selected = -1
	update_value_input_control()

func _on_duplicate_override_pressed() -> void:
	if not _config_loaded:
		if is_inside_tree() and Engine.is_editor_hint():
			load_config()
		else:
			return
			
	var item = parts_tree.get_selected()
	if not item:
		return
		
	var meta = item.get_metadata(0)
	if not (meta is Dictionary and meta.has("control_type")):
		return
		
	var ctrl_type = meta["control_type"]
	var sec_name = meta["sec_name"]
	var prop_name = meta["prop_name"]
	
	if not (theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has(sec_name) and theme_parts[ctrl_type][sec_name].has(prop_name)):
		return
		
	var existing_record = theme_parts[ctrl_type][sec_name][prop_name]
	
	var base_prop = _get_base_prop_name(prop_name)
	var new_key = base_prop + "_copy"
	var counter = 1
	while theme_parts[ctrl_type][sec_name].has(new_key):
		counter += 1
		new_key = base_prop + "_copy_" + str(counter)
		
	var current_id = _get_part_id(existing_record)
	var new_id = ""
	if current_id != "":
		new_id = current_id + "_copy"
	else:
		new_id = base_prop + "_copy"
		
	var new_record = {}
	if existing_record is Dictionary:
		new_record = existing_record.duplicate()
		new_record["id"] = new_id
	else:
		new_record = {
			"value": existing_record,
			"id": new_id
		}
		
	theme_parts[ctrl_type][sec_name][new_key] = new_record
	
	_target_select_meta = {
		"control_type": ctrl_type,
		"sec_name": sec_name,
		"prop_name": new_key
	}
	
	_active_prop_key = new_key
	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func _on_delete_override_pressed() -> void:
	if not _config_loaded:
		if is_inside_tree() and Engine.is_editor_hint():
			load_config()
		else:
			return

	var item = parts_tree.get_selected()
	if not item:
		return

	var meta = item.get_metadata(0)
	if not (meta is Dictionary and meta.has("control_type")):
		return

	var ctrl_type = meta["control_type"]
	var sec_name = meta["sec_name"]
	var prop_name = meta["prop_name"]

	if theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has(sec_name) and theme_parts[ctrl_type][sec_name].has(prop_name):
		theme_parts[ctrl_type][sec_name].erase(prop_name)
		if theme_parts[ctrl_type][sec_name].is_empty():
			theme_parts[ctrl_type].erase(sec_name)
		if theme_parts[ctrl_type].is_empty():
			theme_parts.erase(ctrl_type)
			if theme_variations.has(ctrl_type):
				theme_variations.erase(ctrl_type)

	_active_prop_key = ""
	_creating_new_override = true
	if override_name_edit:
		override_name_edit.text = ""

	update_value_input_control()
	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

# Parts Builder Management
func _on_add_part_pressed() -> void:
	_ensure_config_loaded()
	var control_type: String
	var is_custom = custom_type_check.button_pressed

	var selected_base = control_type_edit.text.strip_edges()
	if selected_base == "":
		printerr("Please select a base control type!")
		push_warning("Please select a base control type!")
		_show_warning_dialog("Please select a base control type!")
		return

	if is_custom:
		control_type = custom_type_name_edit.text.strip_edges()
		if control_type == "":
			return
		theme_variations[control_type] = selected_base
	else:
		control_type = selected_base
		if theme_variations.has(control_type):
			theme_variations.erase(control_type)

	if prop_type_option.selected == -1 or prop_name_option.selected == -1:
		return
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = prop_name_option.get_item_text(prop_name_option.selected)
	var prop_key = prop_name
	if _active_prop_key != "" and _get_base_prop_name(_active_prop_key) == prop_name:
		prop_key = _active_prop_key
	var override_id = override_name_edit.text.strip_edges()
	
	var section_map = {
		"color": "colors",
		"constant": "constants",
		"font": "fonts",
		"font_size": "font_sizes",
		"icon": "icons",
		"stylebox": "styleboxes"
	}
	var sec = section_map.get(prop_type, "")
	if sec == "":
		return

	var is_cleared = false
	var prop_val = ""
	if value_container.has_node("ColorPicker"):
		var cp = value_container.get_node("ColorPicker") as ColorPickerButton
		prop_val = "#" + cp.color.to_html(true)
	elif value_container.has_node("SpinBox"):
		var sb = value_container.get_node("SpinBox") as SpinBox
		prop_val = str(int(sb.value))
	elif value_container.find_child("ResourcePicker", true, false):
		var rp = value_container.find_child("ResourcePicker", true, false)
		if "edited_resource" in rp:
			if rp.edited_resource == null:
				is_cleared = true
			else:
				prop_val = rp.edited_resource.resource_path.strip_edges()
		else:
			if rp is Button:
				prop_val = rp.text.strip_edges()
			if prop_val == "":
				is_cleared = true
		if not is_cleared and prop_val == "":
			printerr("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			push_warning("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			_show_warning_dialog("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			return

	if is_cleared:
		if theme_parts.has(control_type) and theme_parts[control_type].has(sec) and theme_parts[control_type][sec].has(prop_key):
			theme_parts[control_type][sec].erase(prop_key)
			if theme_parts[control_type][sec].is_empty():
				theme_parts[control_type].erase(sec)
			if theme_parts[control_type].is_empty():
				theme_parts.erase(control_type)
				if theme_variations.has(control_type):
					theme_variations.erase(control_type)
		update_value_input_control()
		save_config()
		refresh_parts_tree()
		_on_apply_preview_pressed()
		return

	if prop_key == "" or prop_val == "":
		return

	if not theme_parts.has(control_type):
		theme_parts[control_type] = {}

	# Ensure sections exist
	if not theme_parts[control_type].has(sec):
		theme_parts[control_type][sec] = {}

	# Assign values structured as dictionary
	var new_entry = {
		"value": prop_val,
		"id": override_id
	}
	
	match prop_type:
		"color":
			theme_parts[control_type]["colors"][prop_key] = new_entry
		"constant":
			theme_parts[control_type]["constants"][prop_key] = {
				"value": prop_val.to_int(),
				"id": override_id
			}
		"font":
			theme_parts[control_type]["fonts"][prop_key] = new_entry
		"font_size":
			theme_parts[control_type]["font_sizes"][prop_key] = {
				"value": prop_val.to_int(),
				"id": override_id
			}
		"icon":
			theme_parts[control_type]["icons"][prop_key] = new_entry
		"stylebox":
			theme_parts[control_type]["styleboxes"][prop_key] = new_entry

	_target_select_meta = {
		"control_type": control_type,
		"sec_name": sec,
		"prop_name": prop_key
	}
	update_value_input_control()
	if is_custom:
		custom_type_name_edit.text = ""
		custom_type_check.button_pressed = false
	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func refresh_parts_tree() -> void:
	parts_tree.clear()
	var root = parts_tree.create_item()
	parts_tree.hide_root = true

	for ctrl_type in theme_parts.keys():
		var ctrl_item = parts_tree.create_item(root)
		if theme_variations.has(ctrl_type) and theme_variations[ctrl_type] != "":
			ctrl_item.set_text(0, ctrl_type + " (" + theme_variations[ctrl_type] + ")")
		else:
			ctrl_item.set_text(0, ctrl_type)
		
		var sections = theme_parts[ctrl_type]
		for sec_name in sections.keys():
			var overrides = sections[sec_name]
			for prop_name in overrides.keys():
				var entry = overrides[prop_name]
				var val_item = parts_tree.create_item(ctrl_item)
				var entry_id = _get_part_id(entry)
				var entry_val = _get_part_value(entry)
				val_item.set_text(0, "")
				val_item.set_text(1, entry_id)
				val_item.set_text(2, sec_name.to_upper() + ": " + prop_name)
				val_item.set_text(3, str(entry_val))
				var meta = {
					"control_type": ctrl_type,
					"sec_name": sec_name,
					"prop_name": prop_name
				}
				val_item.set_metadata(0, meta)
				
				if _target_select_meta is Dictionary:
					if _target_select_meta["control_type"] == ctrl_type \
						and _target_select_meta["sec_name"] == sec_name \
						and _target_select_meta["prop_name"] == prop_name:
							val_item.select(0)
							parts_tree.scroll_to_item(val_item)
							_on_tree_item_selected()

	_target_select_meta = null

# Build Native Theme Object from configuration parts and variations
func build_theme() -> Theme:
	var temp_theme = Theme.new()

	# Set Type Variations first so custom types inherit base properties
	for custom_type in theme_variations.keys():
		var base_type = theme_variations[custom_type]
		if base_type != "":
			temp_theme.set_type_variation(custom_type, base_type)

	for ctrl_type in theme_parts.keys():
		var section = theme_parts[ctrl_type]

		# Apply Colors
		if section.has("colors"):
			for col_name in section["colors"].keys():
				var base_name = _get_base_prop_name(col_name)
				var raw_color = _get_part_value(section["colors"][col_name])
				var color_val = Color.from_string(raw_color, Color.WHITE)
				temp_theme.set_color(base_name, ctrl_type, color_val)

		# Apply Constants
		if section.has("constants"):
			for const_name in section["constants"].keys():
				var base_name = _get_base_prop_name(const_name)
				var raw_const = _get_part_value(section["constants"][const_name])
				temp_theme.set_constant(base_name, ctrl_type, int(raw_const))

		# Apply Fonts
		if section.has("fonts"):
			for font_name in section["fonts"].keys():
				var base_name = _get_base_prop_name(font_name)
				var font_path = _get_part_value(section["fonts"][font_name])
				if font_path != "" and ResourceLoader.exists(font_path):
					var loaded_font = ResourceLoader.load(font_path)
					if loaded_font is Font:
						temp_theme.set_font(base_name, ctrl_type, loaded_font)

		# Apply Font Sizes
		if section.has("font_sizes"):
			for fs_name in section["font_sizes"].keys():
				var base_name = _get_base_prop_name(fs_name)
				var raw_fs = _get_part_value(section["font_sizes"][fs_name])
				temp_theme.set_font_size(base_name, ctrl_type, int(raw_fs))

		# Apply Icons
		if section.has("icons"):
			for icon_name in section["icons"].keys():
				var base_name = _get_base_prop_name(icon_name)
				var icon_path = _get_part_value(section["icons"][icon_name])
				if icon_path != "" and ResourceLoader.exists(icon_path):
					var loaded_icon = ResourceLoader.load(icon_path)
					if loaded_icon is Texture2D:
						temp_theme.set_icon(base_name, ctrl_type, loaded_icon)

		# Apply StyleBoxes
		if section.has("styleboxes"):
			for sb_name in section["styleboxes"].keys():
				var base_name = _get_base_prop_name(sb_name)
				var sb_path = _get_part_value(section["styleboxes"][sb_name])
				if sb_path != "" and ResourceLoader.exists(sb_path):
					var loaded_sb = ResourceLoader.load(sb_path)
					if loaded_sb is StyleBox:
						temp_theme.set_stylebox(base_name, ctrl_type, loaded_sb)

	return temp_theme

# Build Native Theme Object & Preview it
func _get_configured_states(ctrl_type: String) -> Array[String]:
	var states: Array[String] = []
	if not theme_parts.has(ctrl_type):
		return ["normal"]
		
	var section = theme_parts[ctrl_type]
	var has_normal_configs = false
	
	for sec_name in section.keys():
		var overrides = section[sec_name]
		for prop_name in overrides.keys():
			var base_name = _get_base_prop_name(prop_name)
			var prop_lower = base_name.to_lower()
			if "disabled" in prop_lower:
				if not states.has("disabled"):
					states.append("disabled")
			elif "pressed" in prop_lower:
				if not states.has("pressed"):
					states.append("pressed")
			elif "read_only" in prop_lower:
				if not states.has("read_only"):
					states.append("read_only")
			elif "focus" in prop_lower:
				if not states.has("focus"):
					states.append("focus")
			else:
				has_normal_configs = true
				
	if has_normal_configs or states.is_empty():
		states.insert(0, "normal")
		
	return states

# Build Native Theme Object & Preview it
func _on_apply_preview_pressed() -> void:
	var temp_theme = build_theme()
	preview_area.theme = temp_theme
 
	# Load metadata to retrieve component design width/height
	var metadata = {}
	if FileAccess.file_exists(metadata_file):
		var file = FileAccess.open(metadata_file, FileAccess.READ)
		if file:
			var json = JSON.new()
			var err = json.parse(file.get_as_text())
			file.close()
			if err == OK:
				var data = json.get_data()
				if data is Dictionary:
					metadata = data

	# Update the preview nodes dynamically
	if preview_grid:
		# Clear existing children
		for child in preview_grid.get_children():
			child.queue_free()
 
		if theme_parts.is_empty():
			preview_grid.columns = 1
			preview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var placeholder = Label.new()
			placeholder.text = "No theme parts configured yet. Add them in the Parts Builder to preview."
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			placeholder.add_theme_font_size_override("font_size", preview_font_size)
			preview_grid.add_child(placeholder)
		else:
			# Use columns = 1 to stack our sections vertically inside the main GridContainer
			preview_grid.columns = 1
			preview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Instantiate and add nodes that are defined in theme_parts
			for ctrl_type in theme_parts.keys():
				if ctrl_type == "PanelContainer":
					continue
					
				# Create section container
				var section_box = VBoxContainer.new()
				section_box.name = ctrl_type + "_Section"
				section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				section_box.add_theme_constant_override("separation", 10)
				
				# Create section header
				var header_box = VBoxContainer.new()
				header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				var header_lbl = Label.new()
				var type_display = ctrl_type
				if theme_variations.has(ctrl_type) and theme_variations[ctrl_type] != "":
					type_display += " (Variation of " + theme_variations[ctrl_type] + ")"
				header_lbl.text = type_display
				header_lbl.add_theme_font_size_override("font_size", preview_font_size + 4)
				header_lbl.add_theme_color_override("font_color", Color(0.26, 0.95, 1.0, 1.0)) # Neon Cyan
				
				var separator = HSeparator.new()
				separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				header_box.add_child(header_lbl)
				header_box.add_child(separator)
				section_box.add_child(header_box)
				
				# Create the sub-grid for states
				var sub_grid = GridContainer.new()
				sub_grid.columns = preview_columns
				sub_grid.add_theme_constant_override("h_separation", 15)
				sub_grid.add_theme_constant_override("v_separation", 15)
				
				if preview_item_width > 0:
					sub_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				else:
					sub_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					
				section_box.add_child(sub_grid)
				preview_grid.add_child(section_box)
				
				# Add padding spacing margin at the bottom of the section
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(0, 15)
				preview_grid.add_child(spacer)
				var states = _get_configured_states(ctrl_type)
				
				# Find a common design size from any state of this control type to use as fallback
				var common_width = 0.0
				var common_height = 0.0
				for s in states:
					if theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has("styleboxes"):
						var sboxes = theme_parts[ctrl_type]["styleboxes"]
						var rec = null
						for key in sboxes.keys():
							if _get_base_prop_name(key) == s:
								rec = sboxes[key]
								break
						
						if rec != null:
							var svg_key = ""
							var val_path = _get_part_value(rec)
							if val_path is String and val_path != "" and ResourceLoader.exists(val_path):
								var sb = ResourceLoader.load(val_path)
								if sb is StyleBoxTexture and sb.texture:
									svg_key = sb.texture.resource_path.get_file()
							
							if svg_key == "":
								var record_id = _get_part_id(rec)
								record_id = _get_base_prop_name(record_id)
								if record_id != "":
									svg_key = record_id + ".svg"
							
							if svg_key == "" and val_path is String and val_path != "":
								var filename = val_path.get_file().replace("_stylebox.tres", "")
								filename = _get_base_prop_name(filename)
								svg_key = filename + ".svg"
							
							if svg_key != "":
								var meta_entry = null
								if metadata.has(svg_key):
									meta_entry = metadata[svg_key]
								else:
									var lower_key = svg_key.to_lower()
									for m_key in metadata.keys():
										if m_key.to_lower() == lower_key or m_key.to_lower().replace(".svg", "") == lower_key.replace(".svg", ""):
											meta_entry = metadata[m_key]
											break
								
								if meta_entry != null:
									common_width = float(meta_entry.get("width", 0.0))
									common_height = float(meta_entry.get("height", 0.0))
									if common_width > 0.0:
										break
										
				for state in states:
					var inst: Control = null
					var display_name = ctrl_type
					
					# Check if this is a custom variation
					if theme_variations.has(ctrl_type) and theme_variations[ctrl_type] != "":
						var base_type = theme_variations[ctrl_type]
						inst = instantiate_class_by_name(base_type)
						if inst:
							inst.theme_type_variation = ctrl_type
							display_name = ctrl_type + " (" + base_type + ")"
					else:
						inst = instantiate_class_by_name(ctrl_type)
						
					if inst:
						var active_stylebox: StyleBox = null
						# Apply state to the instantiated node
						if state == "disabled" and "disabled" in inst:
							inst.disabled = true
							display_name += " (Disabled)"
						elif state == "pressed" and "button_pressed" in inst:
							if "toggle_mode" in inst:
								inst.toggle_mode = true
							inst.button_pressed = true
							display_name += " (Pressed)"
						elif state == "read_only":
							if "editable" in inst:
								inst.editable = false
							elif "read_only" in inst:
								inst.read_only = true
							display_name += " (Read Only)"
						elif state == "focus":
							display_name += " (Focus)"
							
						var text_key = ctrl_type + "_" + state
						var item_text = display_name
						if preview_texts.has(text_key):
							item_text = preview_texts[text_key]
							
						# Fetch design size from Figma metadata (handles copy key suffix and path mapping)
						var design_width = 0.0
						var design_height = 0.0
						if theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has("styleboxes"):
							var sboxes = theme_parts[ctrl_type]["styleboxes"]
							var record = null
							for key in sboxes.keys():
								if _get_base_prop_name(key) == state:
									record = sboxes[key]
									break
							
							if record != null:
								var svg_key = ""
								var val_path = _get_part_value(record)
								if val_path is String and val_path != "" and ResourceLoader.exists(val_path):
									var sb = ResourceLoader.load(val_path)
									if sb is StyleBox:
										active_stylebox = sb
										if sb is StyleBoxTexture and sb.texture:
											svg_key = sb.texture.resource_path.get_file()
								
								if svg_key == "":
									var record_id = _get_part_id(record)
									record_id = _get_base_prop_name(record_id)
									if record_id != "":
										svg_key = record_id + ".svg"
								
								if svg_key == "" and val_path is String and val_path != "":
									var filename = val_path.get_file().replace("_stylebox.tres", "")
									filename = _get_base_prop_name(filename)
									svg_key = filename + ".svg"
								
								# Retrieve dimensions from figma metadata
								if svg_key != "":
									if metadata.has(svg_key):
										var meta_entry = metadata[svg_key]
										design_width = float(meta_entry.get("width", 0.0))
										design_height = float(meta_entry.get("height", 0.0))
									else:
										# Case-insensitive/extension-agnostic fallback
										var lower_key = svg_key.to_lower()
										for m_key in metadata.keys():
											if m_key.to_lower() == lower_key or m_key.to_lower().replace(".svg", "") == lower_key.replace(".svg", ""):
												var meta_entry = metadata[m_key]
												design_width = float(meta_entry.get("width", 0.0))
												design_height = float(meta_entry.get("height", 0.0))
												break
								
						
						if design_width == 0.0 and common_width > 0.0:
							design_width = common_width
							design_height = common_height
							
						setup_preview_node(inst, item_text, temp_theme)
						
						# If stylebox wasn't directly loaded, look it up in the compiled theme
						if active_stylebox == null:
							var theme_type = inst.theme_type_variation if inst.theme_type_variation != "" else inst.get_class()
							var stylebox_prop_name = state
							if state == "read_only":
								stylebox_prop_name = "read_only"
								
							if temp_theme.has_stylebox(stylebox_prop_name, theme_type):
								active_stylebox = temp_theme.get_stylebox(stylebox_prop_name, theme_type)
							else:
								# Fallback to the variation base class in the theme (e.g. Button)
								var base_type = theme_variations.get(theme_type, "")
								if base_type != "" and temp_theme.has_stylebox(stylebox_prop_name, base_type):
									active_stylebox = temp_theme.get_stylebox(stylebox_prop_name, base_type)
								else:
									# Fallback to the class name itself (e.g. Button)
									var cls_name = inst.get_class()
									if temp_theme.has_stylebox(stylebox_prop_name, cls_name):
										active_stylebox = temp_theme.get_stylebox(stylebox_prop_name, cls_name)

						# Apply theme overrides to freeze the button's appearance and prevent visual changes on hover/focus/pressed
						# Only freeze the appearance if this is NOT the 'normal' state, so normal preview nodes show hover effects!
						if state != "normal" and active_stylebox != null:
							var overrides: Array[String] = []
							if inst is Button:
								overrides = ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]
							elif inst is LineEdit:
								overrides = ["normal", "read_only", "focus"]
							elif inst is TextEdit:
								overrides = ["normal", "read_only", "focus"]
							else:
								overrides = ["normal", "panel"]
								
							for override_name in overrides:
								inst.add_theme_stylebox_override(override_name, active_stylebox)
								
							# Also freeze font colors if defined in the compiled theme
							var color_names = ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_disabled_color"]
							var active_color_name = "font_color"
							if state == "disabled":
								active_color_name = "font_disabled_color"
							elif state == "pressed":
								active_color_name = "font_pressed_color"
							elif state == "hover":
								active_color_name = "font_hover_color"
								
							var theme_type = inst.theme_type_variation if inst.theme_type_variation != "" else inst.get_class()
							if temp_theme.has_color(active_color_name, theme_type):
								var color_val = temp_theme.get_color(active_color_name, theme_type)
								for c_name in color_names:
									inst.add_theme_color_override(c_name, color_val)
						
						# Apply sizing and shrink centering appropriately
						if preview_item_width > 0:
							inst.custom_minimum_size = Vector2(preview_item_width, design_height if design_height > 0 else 40.0)
							inst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
							inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
							if "clip_text" in inst:
								inst.clip_text = true
						else:
							if design_width > 0 and design_height > 0:
								inst.custom_minimum_size = Vector2(design_width, design_height)
								inst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
								inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
								if "clip_text" in inst:
									inst.clip_text = true
							else:
								inst.custom_minimum_size = Vector2(0, 40.0)
								inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
						
						# Store metadata for editing and persistence
						inst.set_meta("ctrl_type", ctrl_type)
						inst.set_meta("state", state)
						
						inst.gui_input.connect(_on_preview_item_gui_input.bind(inst))
						sub_grid.add_child(inst)

func instantiate_class_by_name(p_class: String) -> Control:
	if ClassDB.class_exists(p_class):
		var inst = ClassDB.instantiate(p_class)
		if inst is Control:
			return inst
	var global_classes = ProjectSettings.get_global_class_list()
	for entry in global_classes:
		if entry["class"] == p_class:
			var script = load(entry["path"])
			if script:
				var inst = script.new()
				if inst is Control:
					return inst
	return null

func setup_preview_node(inst: Control, display_name: String, theme_ref: Theme = null) -> void:
	if inst is Panel or inst is PanelContainer or inst is ColorRect or inst is TextureRect or inst is Container or inst is Tree:
		inst.custom_minimum_size = Vector2(0, 40)
		
	var theme_type = inst.theme_type_variation if inst.theme_type_variation != "" else inst.get_class()
	
	var has_theme_size = false
	if theme_ref != null:
		if theme_ref.has_font_size("font_size", theme_type):
			has_theme_size = true
		else:
			var base_type = theme_variations.get(theme_type, "")
			if base_type != "" and theme_ref.has_font_size("font_size", base_type):
				has_theme_size = true
			elif theme_ref.has_font_size("font_size", inst.get_class()):
				has_theme_size = true

	if inst is RichTextLabel:
		inst.text = "[color=magenta]Sample[/color] " + display_name
		inst.fit_content = true
		var has_rt_size = false
		if theme_ref != null:
			if theme_ref.has_font_size("normal_font_size", theme_type):
				has_rt_size = true
			else:
				var base_type = theme_variations.get(theme_type, "")
				if base_type != "" and theme_ref.has_font_size("normal_font_size", base_type):
					has_rt_size = true
				elif theme_ref.has_font_size("normal_font_size", inst.get_class()):
					has_rt_size = true
		if not has_rt_size:
			inst.add_theme_font_size_override("normal_font_size", preview_font_size)
	elif "placeholder_text" in inst:
		inst.placeholder_text = display_name
		if not has_theme_size:
			inst.add_theme_font_size_override("font_size", preview_font_size)
	elif "text" in inst:
		inst.text = display_name
		if not has_theme_size:
			inst.add_theme_font_size_override("font_size", preview_font_size)
	elif not (inst is Tree):
		var lbl = Label.new()
		lbl.text = display_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not has_theme_size:
			lbl.add_theme_font_size_override("font_size", preview_font_size)
		inst.add_child(lbl)
		
	if inst is Tree:
		var root = inst.create_item()
		inst.hide_root = true
		var item1 = inst.create_item(root)
		item1.set_text(0, "Sample Tree Item 1")
		var item2 = inst.create_item(root)
		item2.set_text(0, "Sample Tree Item 2")

# Generate native Godot Theme resource
func _on_compile_pressed() -> void:
	var out_path = output_file.strip_edges()
	if out_path == "":
		printerr("No output path specified!")
		return

	_ensure_dir_exists(out_path.get_base_dir())

	var theme = build_theme()
	var err = ResourceSaver.save(theme, out_path)
	if err == OK:
		print("Theme Resource generated successfully at: ", out_path)
		export_theme_package(out_path.get_base_dir())
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("Failed to save Theme Resource at: ", out_path, " Error: ", err)

func export_theme_package(target_dir: String) -> void:
	print("Packaging theme to target directory: ", target_dir)
	var target_res_dir = target_dir.path_join("ResourceFiles")
	var target_img_dir = target_dir.path_join("Images")
	var target_font_dir = target_dir.path_join("Fonts")
	
	_ensure_dir_exists(target_dir)
	_ensure_dir_exists(target_res_dir)
	_ensure_dir_exists(target_img_dir)
	_ensure_dir_exists(target_font_dir)
	
	var old_img_dir = image_folder
	
	var files_to_copy: Dictionary = {}
	var path_replacements: Dictionary = {}
	
	# Copy local configuration file as part of the package to make it round-trippable
	files_to_copy[CONFIG_FILE_PATH] = target_dir.path_join("config.json")
	path_replacements[CONFIG_FILE_PATH] = target_dir.path_join("config.json")
	
	# Add directory paths to path replacements so the exported config.json updates settings correctly
	path_replacements[image_folder] = target_img_dir
	path_replacements[fonts_folder] = target_font_dir
	
	# Copy metadata file if configured
	if metadata_file != "":
		var meta_filename = metadata_file.get_file()
		var source_meta_path = ""
		if FileAccess.file_exists("res://addons/anomalyAcesThemeGenerator/working/Metadata".path_join(meta_filename)):
			source_meta_path = "res://addons/anomalyAcesThemeGenerator/working/Metadata".path_join(meta_filename)
		elif FileAccess.file_exists(metadata_file):
			source_meta_path = metadata_file
			
		if source_meta_path != "":
			var target_meta_dir = target_dir.path_join("Metadata")
			_ensure_dir_exists(target_meta_dir)
			var new_meta_path = target_meta_dir.path_join(meta_filename)
			files_to_copy[source_meta_path] = new_meta_path
			path_replacements[metadata_file] = new_meta_path
	
	for ctrl_type in theme_parts.keys():
		var section = theme_parts[ctrl_type]
		
		# 1. Scan styleboxes
		if section.has("styleboxes"):
			for sb_name in section["styleboxes"].keys():
				var sb_val = _get_part_value(section["styleboxes"][sb_name])
				if sb_val is String and sb_val.begins_with("res://"):
					var old_sb_path = sb_val
					var sb_filename = old_sb_path.get_file()
					
					var source_sb_path = ""
					if FileAccess.file_exists("res://addons/anomalyAcesThemeGenerator/working/ResourceFiles".path_join(sb_filename)):
						source_sb_path = "res://addons/anomalyAcesThemeGenerator/working/ResourceFiles".path_join(sb_filename)
					elif FileAccess.file_exists(old_sb_path):
						source_sb_path = old_sb_path
						
					if source_sb_path != "":
						var new_sb_path = target_res_dir.path_join(sb_filename)
						files_to_copy[source_sb_path] = new_sb_path
						path_replacements[old_sb_path] = new_sb_path
					
					# Open StyleBox file to scan for referenced textures (images)
					var check_sb_path = source_sb_path if source_sb_path != "" else old_sb_path
					if FileAccess.file_exists(check_sb_path):
						var file = FileAccess.open(check_sb_path, FileAccess.READ)
						if file:
							var content = file.get_as_text()
							file.close()
							
							var regex = RegEx.new()
							regex.compile('path="(res://[^"]+)"')
							var results = regex.search_all(content)
							for result in results:
								var old_img_path = result.get_string(1)
								var img_filename = old_img_path.get_file()
								
								# Resolve the best source path for this image
								var source_img_path = ""
								if FileAccess.file_exists(image_folder.path_join(img_filename)):
									source_img_path = image_folder.path_join(img_filename)
								elif FileAccess.file_exists("res://addons/anomalyAcesThemeGenerator/working/Images".path_join(img_filename)):
									source_img_path = "res://addons/anomalyAcesThemeGenerator/working/Images".path_join(img_filename)
								elif FileAccess.file_exists(old_img_path):
									source_img_path = old_img_path
									
								if source_img_path != "":
									var new_img_path = target_img_dir.path_join(img_filename)
									files_to_copy[source_img_path] = new_img_path
									path_replacements[old_img_path] = new_img_path
									
		# 2. Scan fonts
		if section.has("fonts"):
			for font_name in section["fonts"].keys():
				var font_val = _get_part_value(section["fonts"][font_name])
				if font_val is String and font_val.begins_with("res://"):
					var old_font_path = font_val
					var font_filename = old_font_path.get_file()
					
					var source_font_path = ""
					if FileAccess.file_exists(fonts_folder.path_join(font_filename)):
						source_font_path = fonts_folder.path_join(font_filename)
					elif FileAccess.file_exists("res://addons/anomalyAcesThemeGenerator/working/Fonts".path_join(font_filename)):
						source_font_path = "res://addons/anomalyAcesThemeGenerator/working/Fonts".path_join(font_filename)
					elif FileAccess.file_exists(old_font_path):
						source_font_path = old_font_path
						
					if source_font_path != "":
						var new_font_path = target_font_dir.path_join(font_filename)
						files_to_copy[source_font_path] = new_font_path
						path_replacements[old_font_path] = new_font_path
					
		# 3. Scan icons
		if section.has("icons"):
			for icon_name in section["icons"].keys():
				var icon_val = _get_part_value(section["icons"][icon_name])
				if icon_val is String and icon_val.begins_with("res://"):
					var old_icon_path = icon_val
					var icon_filename = old_icon_path.get_file()
					
					var source_icon_path = ""
					if FileAccess.file_exists(image_folder.path_join(icon_filename)):
						source_icon_path = image_folder.path_join(icon_filename)
					elif FileAccess.file_exists("res://addons/anomalyAcesThemeGenerator/working/Images".path_join(icon_filename)):
						source_icon_path = "res://addons/anomalyAcesThemeGenerator/working/Images".path_join(icon_filename)
					elif FileAccess.file_exists(old_icon_path):
						source_icon_path = old_icon_path
						
					if source_icon_path != "":
						var new_icon_path = target_img_dir.path_join(icon_filename)
						files_to_copy[source_icon_path] = new_icon_path
						path_replacements[old_icon_path] = new_icon_path

	# Copy files to target package
	var copy_errors: Array[String] = []
	for old_path in files_to_copy.keys():
		var new_path = files_to_copy[old_path]
		if old_path == new_path:
			continue
			
		if FileAccess.file_exists(old_path):
			var err = DirAccess.copy_absolute(old_path, new_path)
			if err != OK:
				copy_errors.append("Failed to copy %s to %s (Error: %d)" % [old_path, new_path, err])
			else:
				var import_old = old_path + ".import"
				var import_new = new_path + ".import"
				if FileAccess.file_exists(import_old):
					DirAccess.copy_absolute(import_old, import_new)
		else:
			copy_errors.append("Source file not found: %s" % old_path)
			
	if not copy_errors.is_empty():
		for err_msg in copy_errors:
			printerr(err_msg)
			
	# Update path replacements for the compiled theme itself
	var old_theme_path = output_file
	var new_theme_path = target_dir.path_join(output_file.get_file())
	path_replacements[old_theme_path] = new_theme_path
	
	# Rewrite paths in copied files
	var files_to_patch: Array[String] = []
	files_to_patch.append(new_theme_path)
	for new_file_path in files_to_copy.values():
		files_to_patch.append(new_file_path)
		var import_new = new_file_path + ".import"
		if FileAccess.file_exists(import_new):
			files_to_patch.append(import_new)
			
	for new_file_path in files_to_patch:
		var ext = new_file_path.get_extension().to_lower()
		if not ext in ["tres", "theme", "import", "json"]:
			continue
			
		if FileAccess.file_exists(new_file_path):
			var file = FileAccess.open(new_file_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				
				var modified = false
				for old_res_path in path_replacements.keys():
					var new_res_path = path_replacements[old_res_path]
					if content.contains(old_res_path):
						content = content.replace(old_res_path, new_res_path)
						modified = true
						
				if modified:
					var write_file = FileAccess.open(new_file_path, FileAccess.WRITE)
					if write_file:
						write_file.store_string(content)
						write_file.close()
						print("Rewrote paths inside packaged file: ", new_file_path)

	# Generate the standalone preview scene
	_export_preview_scene(target_dir, new_theme_path)

func _export_preview_scene(target_dir: String, packaged_theme_path: String) -> void:
	print("Generating standalone preview scene at: ", target_dir)
	var loaded_theme = ResourceLoader.load(packaged_theme_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not loaded_theme:
		printerr("Failed to load packaged theme for preview scene generation: ", packaged_theme_path)
		return
		
	# 1. Create root nodes
	var root = PanelContainer.new()
	root.name = "ThemePreview"
	root.theme = loaded_theme
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var scroll = ScrollContainer.new()
	scroll.name = "PreviewScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	
	var margin = MarginContainer.new()
	margin.name = "PreviewMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	
	var grid = GridContainer.new()
	grid.name = "PreviewGrid"
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(grid)
	
	# Load metadata to retrieve component design width/height (exactly as in _on_apply_preview_pressed)
	var metadata = {}
	if FileAccess.file_exists(metadata_file):
		var file = FileAccess.open(metadata_file, FileAccess.READ)
		if file:
			var json = JSON.new()
			var err = json.parse(file.get_as_text())
			file.close()
			if err == OK:
				var data = json.get_data()
				if data is Dictionary:
					metadata = data
					
	if theme_parts.is_empty():
		var placeholder = Label.new()
		placeholder.name = "Placeholder"
		placeholder.text = "No theme parts configured yet. Add them in the Parts Builder to preview."
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		placeholder.add_theme_font_size_override("font_size", preview_font_size)
		grid.add_child(placeholder)
	else:
		for ctrl_type in theme_parts.keys():
			if ctrl_type == "PanelContainer":
				continue
				
			var section_box = VBoxContainer.new()
			section_box.name = ctrl_type + "_Section"
			section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			section_box.add_theme_constant_override("separation", 10)
			
			var header_box = VBoxContainer.new()
			header_box.name = "HeaderBox"
			header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var header_lbl = Label.new()
			header_lbl.name = "HeaderLabel"
			var type_display = ctrl_type
			if theme_variations.has(ctrl_type) and theme_variations[ctrl_type] != "":
				type_display += " (Variation of " + theme_variations[ctrl_type] + ")"
			header_lbl.text = type_display
			header_lbl.add_theme_font_size_override("font_size", preview_font_size + 4)
			header_lbl.add_theme_color_override("font_color", Color(0.26, 0.95, 1.0, 1.0)) # Neon Cyan
			
			var separator = HSeparator.new()
			separator.name = "Separator"
			separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			header_box.add_child(header_lbl)
			header_box.add_child(separator)
			section_box.add_child(header_box)
			
			var sub_grid = GridContainer.new()
			sub_grid.name = "SubGrid"
			sub_grid.columns = preview_columns
			sub_grid.add_theme_constant_override("h_separation", 15)
			sub_grid.add_theme_constant_override("v_separation", 15)
			
			if preview_item_width > 0:
				sub_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			else:
				sub_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
			section_box.add_child(sub_grid)
			grid.add_child(section_box)
			
			var spacer = Control.new()
			spacer.name = ctrl_type + "_Spacer"
			spacer.custom_minimum_size = Vector2(0, 15)
			grid.add_child(spacer)
			
			var states = _get_configured_states(ctrl_type)
			
			# Find a common design size from any state of this control type to use as fallback
			var common_width = 0.0
			var common_height = 0.0
			for s in states:
				if theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has("styleboxes"):
					var sboxes = theme_parts[ctrl_type]["styleboxes"]
					var rec = null
					for key in sboxes.keys():
						if _get_base_prop_name(key) == s:
							rec = sboxes[key]
							break
					
					if rec != null:
						var svg_key = ""
						var val_path = _get_part_value(rec)
						if val_path is String and val_path != "" and ResourceLoader.exists(val_path):
							var sb = ResourceLoader.load(val_path)
							if sb is StyleBoxTexture and sb.texture:
								svg_key = sb.texture.resource_path.get_file()
						
						if svg_key == "":
							var record_id = _get_part_id(rec)
							record_id = _get_base_prop_name(record_id)
							if record_id != "":
								svg_key = record_id + ".svg"
						
						if svg_key == "" and val_path is String and val_path != "":
							var filename = val_path.get_file().replace("_stylebox.tres", "")
							filename = _get_base_prop_name(filename)
							svg_key = filename + ".svg"
						
						if svg_key != "":
							var meta_entry = null
							if metadata.has(svg_key):
								meta_entry = metadata[svg_key]
							else:
								var lower_key = svg_key.to_lower()
								for m_key in metadata.keys():
									if m_key.to_lower() == lower_key or m_key.to_lower().replace(".svg", "") == lower_key.replace(".svg", ""):
										meta_entry = metadata[m_key]
										break
							
							if meta_entry != null:
								common_width = float(meta_entry.get("width", 0.0))
								common_height = float(meta_entry.get("height", 0.0))
								if common_width > 0.0:
									break
									
			for state in states:
				var inst: Control = null
				var display_name = ctrl_type
				
				if theme_variations.has(ctrl_type) and theme_variations[ctrl_type] != "":
					var base_type = theme_variations[ctrl_type]
					inst = instantiate_class_by_name(base_type)
					if inst:
						inst.theme_type_variation = ctrl_type
						display_name = ctrl_type + " (" + base_type + ")"
				else:
					inst = instantiate_class_by_name(ctrl_type)
					
				if inst:
					var active_stylebox: StyleBox = null
					if state == "disabled" and "disabled" in inst:
						inst.disabled = true
						display_name += " (Disabled)"
					elif state == "pressed" and "button_pressed" in inst:
						if "toggle_mode" in inst:
							inst.toggle_mode = true
						inst.button_pressed = true
						display_name += " (Pressed)"
					elif state == "read_only":
						if "editable" in inst:
							inst.editable = false
						elif "read_only" in inst:
							inst.read_only = true
						display_name += " (Read Only)"
					elif state == "focus":
						display_name += " (Focus)"
						
					var text_key = ctrl_type + "_" + state
					var item_text = display_name
					if preview_texts.has(text_key):
						item_text = preview_texts[text_key]
						
					var design_width = 0.0
					var design_height = 0.0
					if theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has("styleboxes"):
						var sboxes = theme_parts[ctrl_type]["styleboxes"]
						var record = null
						for key in sboxes.keys():
							if _get_base_prop_name(key) == state:
								record = sboxes[key]
								break
						
						if record != null:
							var svg_key = ""
							var val_path = _get_part_value(record)
							if val_path is String and val_path != "" and ResourceLoader.exists(val_path):
								var sb = ResourceLoader.load(val_path)
								if sb is StyleBox:
									active_stylebox = sb
									if sb is StyleBoxTexture and sb.texture:
										svg_key = sb.texture.resource_path.get_file()
							
							if svg_key == "":
								var record_id = _get_part_id(record)
								record_id = _get_base_prop_name(record_id)
								if record_id != "":
									svg_key = record_id + ".svg"
							
							if svg_key == "" and val_path is String and val_path != "":
								var filename = val_path.get_file().replace("_stylebox.tres", "")
								filename = _get_base_prop_name(filename)
								svg_key = filename + ".svg"
							
							if svg_key != "":
								if metadata.has(svg_key):
									var meta_entry = metadata[svg_key]
									design_width = float(meta_entry.get("width", 0.0))
									design_height = float(meta_entry.get("height", 0.0))
								else:
									var lower_key = svg_key.to_lower()
									for m_key in metadata.keys():
										if m_key.to_lower() == lower_key or m_key.to_lower().replace(".svg", "") == lower_key.replace(".svg", ""):
											var meta_entry = metadata[m_key]
											design_width = float(meta_entry.get("width", 0.0))
											design_height = float(meta_entry.get("height", 0.0))
											break
					
					if design_width == 0.0 and common_width > 0.0:
						design_width = common_width
						design_height = common_height
						
					setup_preview_node(inst, item_text, loaded_theme)
					
					if preview_item_width > 0:
						inst.custom_minimum_size = Vector2(preview_item_width, design_height if design_height > 0 else 40.0)
						inst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
						inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
						if "clip_text" in inst:
							inst.clip_text = true
					else:
						if design_width > 0 and design_height > 0:
							inst.custom_minimum_size = Vector2(design_width, design_height)
							inst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
							inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
							if "clip_text" in inst:
								inst.clip_text = true
						else:
							inst.custom_minimum_size = Vector2(0, 40.0)
							inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					
					inst.name = ctrl_type + "_" + state
					sub_grid.add_child(inst)

	_set_owner_recursive(root, root)
	
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root)
	if pack_err == OK:
		var target_scene_path = target_dir.path_join("theme_preview.tscn")
		var save_err = ResourceSaver.save(packed_scene, target_scene_path)
		if save_err == OK:
			print("Preview scene generated successfully at: ", target_scene_path)
		else:
			printerr("Failed to save preview scene at: ", target_scene_path, " Error: ", save_err)
	else:
		printerr("Failed to pack preview scene: ", pack_err)
		
	root.queue_free()

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)

func _on_h_split_resized() -> void:
	h_split.split_offset = int(h_split.size.x * 0.4) - int(h_split.size.x * 0.5)

func _on_tree_item_selected() -> void:
	var item = parts_tree.get_selected()
	if not item:
		return
		
	var meta = item.get_metadata(0)
	if meta is Dictionary and meta.has("control_type"):
		var ctrl_type = meta["control_type"]
		var sec_name = meta["sec_name"]
		var prop_name = meta["prop_name"]
		
		_active_prop_key = prop_name
		_creating_new_override = false
		if metadata_build_check:
			metadata_build_check.button_pressed = false
		
		# 1. Update Control Type and Custom Checkboxes
		if theme_variations.has(ctrl_type):
			control_type_edit.text = theme_variations[ctrl_type]
			custom_type_check.button_pressed = true
			custom_type_name_edit.editable = true
			custom_type_name_edit.text = ctrl_type
		else:
			control_type_edit.text = ctrl_type
			custom_type_check.button_pressed = false
			custom_type_name_edit.editable = false
			custom_type_name_edit.text = ""
			
		# 2. Populate and select Property Type
		update_property_types()
		
		var sec_to_display = {
			"colors": "Color",
			"constants": "Constant",
			"fonts": "Font",
			"font_sizes": "Font Size",
			"icons": "Icon",
			"styleboxes": "StyleBox"
		}
		var display_type = sec_to_display.get(sec_name, "")
		if display_type != "":
			for i in range(prop_type_option.item_count):
				if prop_type_option.get_item_text(i) == display_type:
					prop_type_option.selected = i
					break
					
		# 3. Populate and select Property Name
		update_property_names()
		
		var base_prop_name = _get_base_prop_name(prop_name)
		for i in range(prop_name_option.item_count):
			if prop_name_option.get_item_text(i) == base_prop_name:
				prop_name_option.selected = i
				break
				
		# 4. Update the input widgets and Name/ID
		update_value_input_control()

func _on_override_name_changed(new_text: String) -> void:
	if not _config_loaded:
		if is_inside_tree() and Engine.is_editor_hint():
			load_config()
		else:
			return
	var control_type = control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = custom_type_check.button_pressed
	if is_custom:
		var custom_type = custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type

	if prop_type_option.selected == -1 or prop_name_option.selected == -1:
		return
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = prop_name_option.get_item_text(prop_name_option.selected)
	var prop_key = prop_name
	if _active_prop_key != "" and _get_base_prop_name(_active_prop_key) == prop_name:
		prop_key = _active_prop_key
	
	var section_map = {
		"color": "colors",
		"constant": "constants",
		"font": "fonts",
		"font_size": "font_sizes",
		"icon": "icons",
		"stylebox": "styleboxes"
	}
	var sec = section_map.get(prop_type, "")
	if sec == "":
		return

	if theme_parts.has(control_type) and theme_parts[control_type].has(sec) and theme_parts[control_type][sec].has(prop_key):
		var entry = theme_parts[control_type][sec][prop_key]
		if entry is Dictionary:
			entry["id"] = new_text.strip_edges()
		else:
			theme_parts[control_type][sec][prop_key] = {
				"value": entry,
				"id": new_text.strip_edges()
			}
		save_config()
		refresh_parts_tree()

func _on_color_picker_changed(color: Color) -> void:
	if not _config_loaded:
		if is_inside_tree() and Engine.is_editor_hint():
			load_config()
		else:
			return
	var control_type = control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = custom_type_check.button_pressed
	if is_custom:
		var custom_type = custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type
			theme_variations[custom_type] = control_type_edit.text.strip_edges()

	if prop_type_option.selected == -1 or prop_name_option.selected == -1:
		return
	var prop_name = prop_name_option.get_item_text(prop_name_option.selected)
	var prop_key = prop_name
	if _active_prop_key != "" and _get_base_prop_name(_active_prop_key) == prop_name:
		prop_key = _active_prop_key
	var override_id = override_name_edit.text.strip_edges()

	if not theme_parts.has(control_type):
		theme_parts[control_type] = {}
	if not theme_parts[control_type].has("colors"):
		theme_parts[control_type]["colors"] = {}

	var prop_val = "#" + color.to_html(true)
	theme_parts[control_type]["colors"][prop_key] = {
		"value": prop_val,
		"id": override_id
	}

	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func _on_spin_box_changed(value: float) -> void:
	if not _config_loaded:
		if is_inside_tree() and Engine.is_editor_hint():
			load_config()
		else:
			return
	var control_type = control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = custom_type_check.button_pressed
	if is_custom:
		var custom_type = custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type
			theme_variations[custom_type] = control_type_edit.text.strip_edges()

	if prop_type_option.selected == -1 or prop_name_option.selected == -1:
		return
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = prop_name_option.get_item_text(prop_name_option.selected)
	var prop_key = prop_name
	if _active_prop_key != "" and _get_base_prop_name(_active_prop_key) == prop_name:
		prop_key = _active_prop_key
	var override_id = override_name_edit.text.strip_edges()

	var sec = "constants" if prop_type == "constant" else "font_sizes"

	if not theme_parts.has(control_type):
		theme_parts[control_type] = {}
	if not theme_parts[control_type].has(sec):
		theme_parts[control_type][sec] = {}

	theme_parts[control_type][sec][prop_key] = {
		"value": int(value),
		"id": override_id
	}

	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func _on_resource_picker_changed(res: Resource) -> void:
	if not _config_loaded:
		if is_inside_tree() and Engine.is_editor_hint():
			load_config()
		else:
			return
	var control_type = control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = custom_type_check.button_pressed
	if is_custom:
		var custom_type = custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type
			theme_variations[custom_type] = control_type_edit.text.strip_edges()

	if prop_type_option.selected == -1 or prop_name_option.selected == -1:
		return
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = prop_name_option.get_item_text(prop_name_option.selected)
	var prop_key = prop_name
	if _active_prop_key != "" and _get_base_prop_name(_active_prop_key) == prop_name:
		prop_key = _active_prop_key
	var override_id = override_name_edit.text.strip_edges()
	
	var section_map = {
		"font": "fonts",
		"icon": "icons",
		"stylebox": "styleboxes"
	}
	var sec = section_map.get(prop_type, "")
	if sec == "":
		return

	if res == null:
		if theme_parts.has(control_type) and theme_parts[control_type].has(sec) and theme_parts[control_type][sec].has(prop_key):
			theme_parts[control_type][sec].erase(prop_key)
			if theme_parts[control_type][sec].is_empty():
				theme_parts[control_type].erase(sec)
			if theme_parts[control_type].is_empty():
				theme_parts.erase(control_type)
				if theme_variations.has(control_type):
					theme_variations.erase(control_type)
	else:
		var prop_val = res.resource_path.strip_edges()
		if prop_val != "":
			if not theme_parts.has(control_type):
				theme_parts[control_type] = {}
			if not theme_parts[control_type].has(sec):
				theme_parts[control_type][sec] = {}
			theme_parts[control_type][sec][prop_key] = {
				"value": prop_val,
				"id": override_id
			}
		else:
			printerr("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			push_warning("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			_show_warning_dialog("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			
	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func _show_warning_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _on_browse_dir(line_edit: LineEdit, title: String) -> void:
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = title
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_dir = current_path
		else:
			dialog.current_dir = "res://"
		dialog.dir_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = title
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_dir = current_path
		else:
			dialog.current_dir = "res://"
		dialog.dir_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _on_browse_file(line_edit: LineEdit, filter: String, title: String, is_save: bool = false) -> void:
	var filters = filter.split(",")
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if is_save else EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = title
		for f in filters:
			dialog.add_filter(f)
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_path = current_path
		else:
			dialog.current_dir = "res://"
		dialog.file_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if is_save else FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = title
		for f in filters:
			dialog.add_filter(f)
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_path = current_path
		else:
			dialog.current_dir = "res://"
		dialog.file_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _scan_for_svgs(dir_path: String, out_files: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					_scan_for_svgs(dir_path.path_join(file_name), out_files)
			else:
				if file_name.ends_with(".svg"):
					out_files.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()

var _pending_modified_files: Array[String] = []

func _reimport_svgs_as_dpi_textures(dir_path: String) -> void:
	if not Engine.is_editor_hint():
		return
	if dir_path.strip_edges() == "":
		return
		
	var files_to_reimport: Array[String] = []
	_scan_for_svgs(dir_path, files_to_reimport)
	
	if files_to_reimport.is_empty():
		return
		
	var modified_files: Array[String] = []
	for file_path in files_to_reimport:
		_clean_svg_filters(file_path)
		var import_path = file_path + ".import"
		var needs_modify = true
		var config = ConfigFile.new()
		
		if FileAccess.file_exists(import_path):
			var err = config.load(import_path)
			if err == OK:
				var current_importer = config.get_value("remap", "importer", "")
				var current_type = config.get_value("remap", "type", "")
				if current_importer == "svg" and current_type == "DPITexture":
					needs_modify = false
					
		if needs_modify:
			config.set_value("remap", "importer", "svg")
			config.set_value("remap", "type", "DPITexture")
			config.set_value("deps", "source_file", file_path)
			
			if config.has_section_key("remap", "path"):
				config.erase_section_key("remap", "path")
			if config.has_section_key("deps", "dest_files"):
				config.erase_section_key("deps", "dest_files")
				
			if config.has_section("params"):
				config.erase_section("params")
			config.set_value("params", "base_scale", 1.0)
			config.set_value("params", "saturation", 1.0)
			config.set_value("params", "color_map", {})
			config.set_value("params", "compress", true)
			
			var save_err = config.save(import_path)
			if save_err == OK:
				modified_files.append(file_path)
			else:
				printerr("Failed to save import file: ", import_path, " Error: ", save_err)

	if not modified_files.is_empty():
		_pending_modified_files = modified_files
		print("Reimporting ", _pending_modified_files.size(), " SVGs as DPITextures...")
		var file_system = EditorInterface.get_resource_filesystem()
		if file_system:
			var root = EditorInterface.get_base_control()
			if root:
				root.get_tree().process_frame.connect(_on_process_frame_reimport, CONNECT_ONE_SHOT)
			else:
				file_system.reimport_files(_pending_modified_files)

func _on_process_frame_reimport() -> void:
	var file_system = EditorInterface.get_resource_filesystem()
	if file_system and not _pending_modified_files.is_empty():
		file_system.reimport_files(_pending_modified_files)
		print("Reimport completed.")
		_pending_modified_files.clear()

func _clean_svg_filters(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	var err = regex.compile("filter=[\"']url\\(#[^\"']*\\)[\"']")
	if err != OK:
		return
		
	var new_content = regex.sub(content, "", true)
	if new_content != content:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(new_content)
			write_file.close()
			print("Cleaned unsupported filters from SVG: ", file_path)

# Signal callbacks to avoid lambdas and prevent Engine Stack Underflow Bug
func _on_prop_type_selected(index: int) -> void:
	_active_prop_key = ""
	_creating_new_override = true
	if metadata_build_check:
		metadata_build_check.button_pressed = false
	update_property_names()

func _on_prop_name_selected(index: int) -> void:
	var selected_name = prop_name_option.get_item_text(index)
	
	if _active_prop_key != "":
		var base_active = _get_base_prop_name(_active_prop_key)
		if base_active != selected_name:
			if _active_prop_key.contains("_copy"):
				var ctrl_type = control_type_edit.text.strip_edges()
				if custom_type_check.button_pressed and custom_type_name_edit.text.strip_edges() != "":
					ctrl_type = custom_type_name_edit.text.strip_edges()
					
				var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
				var section_map = {
					"color": "colors",
					"constant": "constants",
					"font": "fonts",
					"font_size": "font_sizes",
					"icon": "icons",
					"stylebox": "styleboxes"
				}
				var sec = section_map.get(prop_type, "")
				
				if sec != "" and theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has(sec) and theme_parts[ctrl_type][sec].has(_active_prop_key):
					var existing_record = theme_parts[ctrl_type][sec][_active_prop_key]
					var new_key = selected_name + "_copy"
					var counter = 1
					while theme_parts[ctrl_type][sec].has(new_key):
						counter += 1
						new_key = selected_name + "_copy_" + str(counter)
						
					theme_parts[ctrl_type][sec].erase(_active_prop_key)
					theme_parts[ctrl_type][sec][new_key] = existing_record
					_active_prop_key = new_key
					
					_target_select_meta = {
						"control_type": ctrl_type,
						"sec_name": sec,
						"prop_name": new_key
					}
					
					save_config()
					refresh_parts_tree()
					_on_apply_preview_pressed()
					return
			else:
				_active_prop_key = ""
				_creating_new_override = true
				
	if _active_prop_key == "" or _creating_new_override:
		var ctrl_type = control_type_edit.text.strip_edges()
		if custom_type_check.button_pressed and custom_type_name_edit.text.strip_edges() != "":
			ctrl_type = custom_type_name_edit.text.strip_edges()
			
		var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
		var section_map = {
			"color": "colors",
			"constant": "constants",
			"font": "fonts",
			"font_size": "font_sizes",
			"icon": "icons",
			"stylebox": "styleboxes"
		}
		var sec = section_map.get(prop_type, "")
		
		var check_key = selected_name
		if sec != "" and theme_parts.has(ctrl_type) and theme_parts[ctrl_type].has(sec):
			if theme_parts[ctrl_type][sec].has(check_key):
				var counter = 1
				check_key = selected_name + "_copy"
				while theme_parts[ctrl_type][sec].has(check_key):
					counter += 1
					check_key = selected_name + "_copy_" + str(counter)
		
		_active_prop_key = check_key
		_creating_new_override = false

	update_value_input_control()

func _on_custom_type_toggled(pressed: bool) -> void:
	custom_type_name_edit.editable = pressed
	if not pressed:
		custom_type_name_edit.text = ""

func _on_images_edit_changed(new_text: String) -> void:
	image_folder = new_text.strip_edges()
	save_config()
	_reimport_svgs_as_dpi_textures(image_folder)

func _on_fonts_edit_changed(new_text: String) -> void:
	fonts_folder = new_text.strip_edges()
	save_config()

func _on_metadata_edit_changed(new_text: String) -> void:
	metadata_file = new_text.strip_edges()
	save_config()

func _on_output_edit_changed(new_text: String) -> void:
	output_file = new_text.strip_edges()
	save_config()

func _on_images_browse_pressed() -> void:
	_on_browse_dir(images_edit, "Select Images Folder")

func _on_fonts_browse_pressed() -> void:
	_on_browse_dir(fonts_edit, "Select Fonts Folder")

func _on_metadata_browse_pressed() -> void:
	_on_browse_file(metadata_edit, "*.json", "Select Metadata File")

func _on_output_browse_pressed() -> void:
	_on_browse_file(output_edit, "*.tres,*.theme", "Select Output Theme File", true)

func _on_settings_header_toggled(pressed: bool) -> void:
	settings_content.visible = pressed
	settings_header_btn.text = "▼ Export Settings" if pressed else "▶ Export Settings"

func _on_parts_builder_header_toggled(pressed: bool) -> void:
	parts_builder_content.visible = pressed
	parts_builder_header_btn.text = "▼ Theme Parts Builder" if pressed else "▶ Theme Parts Builder"

func _on_preview_columns_changed(value: float) -> void:
	preview_columns = int(value)
	save_config()
	if preview_grid and not theme_parts.is_empty():
		preview_grid.columns = preview_columns

func _on_preview_item_width_changed(value: float) -> void:
	preview_item_width = int(value)
	save_config()
	_on_apply_preview_pressed()

func _on_preview_font_size_changed(value: float) -> void:
	preview_font_size = int(value)
	save_config()
	_on_apply_preview_pressed()

func _on_preview_item_gui_input(event: InputEvent, inst: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		# Double click detected! Create in-place LineEdit
		var current_text = ""
		
		if "text" in inst:
			current_text = inst.text
		elif "placeholder_text" in inst:
			current_text = inst.placeholder_text
		else:
			# Check if there is a Label child we added
			for child in inst.get_children():
				if child is Label:
					current_text = child.text
					break
					
		# Create the LineEdit overlay
		var le = LineEdit.new()
		le.text = current_text
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Set flat/borderless style overrides
		var empty_sb = StyleBoxEmpty.new()
		le.add_theme_stylebox_override("normal", empty_sb)
		le.add_theme_stylebox_override("focus", empty_sb)
		
		# Inherit font and size from the control if possible
		if inst.has_theme_font("font"):
			le.add_theme_font_override("font", inst.get_theme_font("font"))
		if inst.has_theme_font_size("font_size"):
			le.add_theme_font_size_override("font_size", inst.get_theme_font_size("font_size"))
		if inst.has_theme_color("font_color"):
			le.add_theme_color_override("font_color", inst.get_theme_color("font_color"))
			
		inst.add_child(le)
		le.size = inst.size
		le.position = Vector2.ZERO
		le.grab_focus()
		le.select_all()
		
		var called = false
		var on_finish = func(new_text: String, save: bool):
			if called:
				return
			called = true
			if is_instance_valid(le):
				if save:
					var c_type = inst.get_meta("ctrl_type", "")
					var s_name = inst.get_meta("state", "")
					if c_type != "" and s_name != "":
						var t_key = c_type + "_" + s_name
						var clean_text = new_text.to_lower().strip_edges()
						if clean_text in ["default", "reset", "[default]", "[reset]"]:
							if preview_texts.has(t_key):
								preview_texts.erase(t_key)
							
							# Reset control text to default
							var default_text = c_type
							if s_name == "disabled":
								default_text += " (Disabled)"
							elif s_name == "pressed":
								default_text += " (Pressed)"
							elif s_name == "read_only":
								default_text += " (Read Only)"
							
							new_text = default_text
						else:
							preview_texts[t_key] = new_text
							
						save_config()
						
					if "text" in inst:
						inst.text = new_text
					elif "placeholder_text" in inst:
						inst.placeholder_text = new_text
					else:
						# Update the Label child
						for child in inst.get_children():
							if child is Label and child != le:
								child.text = new_text
								break
				le.queue_free()
				
		le.text_submitted.connect(func(t): on_finish.call(t, true))
		le.focus_exited.connect(func(): on_finish.call(le.text, true))

func _on_erp_resource_changed(res: Resource) -> void:
	if res and Engine.is_editor_hint():
		EditorInterface.edit_resource(res)
	_on_resource_picker_changed(res)

func _on_erp_resource_selected(res: Resource, inspect: bool) -> void:
	if res and Engine.is_editor_hint():
		EditorInterface.edit_resource(res)

func _on_browse_path_selected(path: String, line_edit: LineEdit, dialog: Node) -> void:
	line_edit.text = path
	line_edit.text_changed.emit(path)
	dialog.queue_free()

func _on_build_stylebox_pressed(dropdown: OptionButton) -> void:
	if dropdown.selected == -1:
		printerr("No SVG file selected in metadata dropdown.")
		return
	
	var svg_key = dropdown.get_item_text(dropdown.selected)
	var base_svg_name = svg_key.replace(".svg", "")
	var default_filename = base_svg_name + "_stylebox.tres"
	var default_dir = "res://addons/anomalyAcesThemeGenerator/working/ResourceFiles"
	var default_path = default_dir.path_join(default_filename)
	
	# Make sure default directory exists
	_ensure_dir_exists(default_dir)
	
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = "Save StyleBox Resource"
		dialog.add_filter("*.tres", "StyleBox Resource")
		dialog.current_path = default_path
		dialog.file_selected.connect(_on_stylebox_save_path_selected.bind(svg_key, dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = "Save StyleBox Resource"
		dialog.add_filter("*.tres", "StyleBox Resource")
		dialog.current_path = default_path
		dialog.file_selected.connect(_on_stylebox_save_path_selected.bind(svg_key, dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _on_stylebox_save_path_selected(save_path: String, svg_key: String, dialog: Node) -> void:
	dialog.queue_free()
	
	# Guard: Only build/replace if build checkbox is checked
	if metadata_build_check and not metadata_build_check.button_pressed:
		printerr("Build from Metadata checkbox is not checked. Aborting generation.")
		return
	
	# 1. Parse metadata.json
	var metadata = {}
	if FileAccess.file_exists(metadata_file):
		var file = FileAccess.open(metadata_file, FileAccess.READ)
		if file:
			var json = JSON.new()
			var err = json.parse(file.get_as_text())
			file.close()
			if err == OK:
				var data = json.get_data()
				if data is Dictionary:
					metadata = data
					
	# 2. Get entry for svg_key
	var entry = metadata.get(svg_key, {})
	var effects = entry.get("effects", [])
	
	# 3. Find active DROP_SHADOW effect
	var shadow_effect = null
	for effect in effects:
		if effect is Dictionary and effect.get("type") == "DROP_SHADOW" and effect.get("visible", false):
			shadow_effect = effect
			break
			
	var new_stylebox: StyleBox = null
	
	# Check if this is an icon, arrow, or toggle which must retain its texture shape
	var is_icon_or_custom_shape = false
	var name_lower = svg_key.to_lower()
	for keyword in ["arrow", "knob", "toggle", "icon", "decrease", "increase", "slider", "subtract", "back", "left", "right"]:
		if keyword in name_lower:
			is_icon_or_custom_shape = true
			break
			
	if shadow_effect != null and not is_icon_or_custom_shape:
		# Build programmatically styled StyleBoxFlat
		var flat_sb = StyleBoxFlat.new()
		
		# Set border/corner radius (try to extract from SVG rect rx first, fall back to capsule corner)
		var h = entry.get("height", 60.0)
		var radius = -1
		var svg_path = image_folder.path_join(svg_key)
		if FileAccess.file_exists(svg_path):
			var file = FileAccess.open(svg_path, FileAccess.READ)
			if file:
				var svg_content = file.get_as_text()
				file.close()
				
				var regex = RegEx.new()
				regex.compile("<rect[^>]+rx=\"([0-9.]+)\"")
				var result = regex.search(svg_content)
				if result:
					radius = int(float(result.get_string(1)))
					
		if radius < 0:
			radius = int(float(h) / 2.0)
			
		flat_sb.corner_radius_top_left = radius
		flat_sb.corner_radius_top_right = radius
		flat_sb.corner_radius_bottom_right = radius
		flat_sb.corner_radius_bottom_left = radius
		
		# Enable corner details so the capsule looks perfect/smooth
		flat_sb.corner_detail = 12
		
		# Background color & Border width/color:
		var shadow_col_dict = shadow_effect.get("color", {})
		var r = float(shadow_col_dict.get("r", 0.0))
		var g = float(shadow_col_dict.get("g", 0.0))
		var b = float(shadow_col_dict.get("b", 0.0))
		var a = float(shadow_col_dict.get("a", 1.0))
		var neon_color = Color(r, g, b, a)
		
		# Background color from Figma fills or childFills:
		var fill_color = Color(0.08, 0.08, 0.1, 0.6) # Fallback bg_color
		var fills = entry.get("fills", [])
		if fills.is_empty():
			fills = entry.get("childFills", [])
			
		var solid_fill = null
		for fill in fills:
			if fill is Dictionary and fill.get("type") == "SOLID":
				var node_name = fill.get("nodeName", "")
				if node_name == "Text" or node_name.to_lower() == "text":
					continue
				solid_fill = fill
				break
				
		if solid_fill != null:
			var fill_col_dict = solid_fill.get("color", {})
			var fr = float(fill_col_dict.get("r", 0.0))
			var fg = float(fill_col_dict.get("g", 0.0))
			var fb = float(fill_col_dict.get("b", 0.0))
			var fopacity = float(solid_fill.get("opacity", 1.0))
			var fa = float(fill_col_dict.get("a", fopacity))
			fill_color = Color(fr, fg, fb, fa)
		
		flat_sb.bg_color = fill_color
		
		# Border width
		flat_sb.border_width_left = 2
		flat_sb.border_width_top = 2
		flat_sb.border_width_right = 2
		flat_sb.border_width_bottom = 2
		flat_sb.border_color = neon_color
		
		# Shadow parameters from Figma:
		var offset_dict = shadow_effect.get("offset", {})
		var ox = float(offset_dict.get("x", 0.0))
		var oy = float(offset_dict.get("y", 0.0))
		flat_sb.shadow_offset = Vector2(ox, oy)
		
		var shadow_radius = float(shadow_effect.get("radius", 40.0))
		# Scale down Figma's blur radius by 0.25 to translate it to a clean Godot shadow size
		flat_sb.shadow_size = int(shadow_radius * 0.25)
		
		# Dynamically calculate shadow opacity scale based on Figma blur radius (wider blur = softer start density)
		var shadow_alpha_scale = clamp(12.0 / shadow_radius, 0.15, 1.0) if shadow_radius > 0.0 else 1.0
		flat_sb.shadow_color = Color(r, g, b, a * shadow_alpha_scale)
		
		# Set content margins to Godot default buttons margins (L=6, R=6, T=4, B=4)
		flat_sb.content_margin_left = 6.0
		flat_sb.content_margin_right = 6.0
		flat_sb.content_margin_top = 4.0
		flat_sb.content_margin_bottom = 4.0
		
		new_stylebox = flat_sb
	else:
		# Build StyleBoxTexture using the SVG path
		var tex_sb = StyleBoxTexture.new()
		var svg_path = image_folder.path_join(svg_key)
		var svg_modified = false
		
		# Load textures sizes to calculate expansion padding margins
		var tex_w = 200.0
		var tex_h = 60.0
		var temp_tex = null
		if ResourceLoader.exists(svg_path):
			temp_tex = ResourceLoader.load(svg_path)
			if temp_tex:
				var size = temp_tex.get_size()
				tex_w = size.x
				tex_h = size.y
				
		var design_w = float(entry.get("width", tex_w))
		var design_h = float(entry.get("height", tex_h))
		var pad_x = max(0.0, (tex_w - design_w) / 2.0)
		var pad_y = max(0.0, (tex_h - design_h) / 2.0)
		
		# Inject designed solid background color fills programmatically directly into the SVG
		var fills = entry.get("fills", [])
		if fills.is_empty():
			fills = entry.get("childFills", [])
			
		var solid_fill = null
		for fill in fills:
			if fill is Dictionary and fill.get("type") == "SOLID":
				var node_name = fill.get("nodeName", "")
				if node_name == "Text" or node_name.to_lower() == "text":
					continue
				solid_fill = fill
				break
				
		# Clean any old figma_bg_inject rect first, and inject the new one if solid_fill is not null
		if FileAccess.file_exists(svg_path):
			var file = FileAccess.open(svg_path, FileAccess.READ)
			if file:
				var svg_text = file.get_as_text()
				file.close()
				
				# Remove any existing injected background rect
				var regex = RegEx.new()
				regex.compile("<rect\\s+id=\"figma_bg_inject\"[^>]+>")
				var cleaned_svg = regex.sub(svg_text, "", true)
				
				var changed = (cleaned_svg != svg_text)
				svg_text = cleaned_svg
				
				if solid_fill != null:
					var fill_col_dict = solid_fill.get("color", {})
					var fr = float(fill_col_dict.get("r", 0.0))
					var fg = float(fill_col_dict.get("g", 0.0))
					var fb = float(fill_col_dict.get("b", 0.0))
					var fill_opacity = float(solid_fill.get("opacity", 1.0))
					var col = Color(fr, fg, fb)
					var fill_color = "#" + col.to_html(false)
					# Try to parse corner radius (rx) from the SVG's remaining elements first, fallback to half height
					var rx = design_h / 2.0
					var r_regex = RegEx.new()
					r_regex.compile("<rect[^>]+rx=\"([0-9.]+)\"")
					var r_result = r_regex.search(svg_text)
					if r_result:
						rx = float(r_result.get_string(1))
						
					var rect_svg = '<rect id="figma_bg_inject" x="%f" y="%f" width="%f" height="%f" rx="%f" ry="%f" fill="%s" fill-opacity="%f"/>' % [pad_x, pad_y, design_w, design_h, rx, rx, fill_color, fill_opacity]
					
					var svg_tag_end = svg_text.find(">", svg_text.find("<svg"))
					if svg_tag_end != -1:
						svg_text = svg_text.insert(svg_tag_end + 1, "\n" + rect_svg)
						changed = true
						print("Injected Figma solid background fill into SVG: ", svg_path)
						
				if changed:
					var write_file = FileAccess.open(svg_path, FileAccess.WRITE)
					if write_file:
						write_file.store_string(svg_text)
						write_file.close()
						svg_modified = true
		
		# Clean SVG filters (this also might modify the file)
		var old_content = ""
		if FileAccess.file_exists(svg_path):
			var file = FileAccess.open(svg_path, FileAccess.READ)
			if file:
				old_content = file.get_as_text()
				file.close()
				
		_clean_svg_filters(svg_path)
		
		# Check if clean_svg_filters actually modified it
		if not svg_modified and FileAccess.file_exists(svg_path):
			var file = FileAccess.open(svg_path, FileAccess.READ)
			if file:
				var new_content = file.get_as_text()
				file.close()
				if new_content != old_content:
					svg_modified = true
					
		# If the SVG file was modified, force Godot to re-import it so the texture updates in memory
		if svg_modified and Engine.is_editor_hint():
			var file_system = EditorInterface.get_resource_filesystem()
			if file_system:
				file_system.reimport_files([svg_path])
		
		var tex = null
		if ResourceLoader.exists(svg_path):
			tex = ResourceLoader.load(svg_path)
			if tex:
				tex_sb.texture = tex
		
		# Apply expand margins to draw the shadow padding glow outside the button boundaries
		if pad_x > 0.0:
			tex_sb.expand_margin_left = pad_x
			tex_sb.expand_margin_right = pad_x
		if pad_y > 0.0:
			tex_sb.expand_margin_top = pad_y
			tex_sb.expand_margin_bottom = pad_y
			
		# Set content margins to Godot default buttons margins (L=6, R=6, T=4, B=4)
		tex_sb.content_margin_left = 6.0
		tex_sb.content_margin_right = 6.0
		tex_sb.content_margin_top = 4.0
		tex_sb.content_margin_bottom = 4.0
		
		new_stylebox = tex_sb
		
	# 4. Save stylebox resource
	var err = ResourceSaver.save(new_stylebox, save_path)
	if err == OK:
		print("Successfully saved stylebox to: ", save_path)
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
			
		# Automatically load and assign it to the resource picker and update config override
		if ResourceLoader.exists(save_path):
			var loaded_res = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_REPLACE)
			if loaded_res:
				# Find resource picker and assign it
				var rp = value_container.find_child("ResourcePicker", true, false)
				if rp:
					if "edited_resource" in rp:
						rp.edited_resource = loaded_res
					elif rp is Button:
						rp.text = save_path
					
				# Also save to config theme_parts and preview it
				_on_resource_picker_changed(loaded_res)
	else:
		printerr("Failed to save StyleBox resource: ", err)

func _on_metadata_build_check_toggled(pressed: bool) -> void:
	if metadata_file_label:
		metadata_file_label.visible = pressed
	if metadata_builder_box:
		metadata_builder_box.visible = pressed

func _refresh_metadata_dropdown() -> void:
	if not metadata_dropdown:
		return
	metadata_dropdown.clear()
	var svg_keys: Array = []
	if FileAccess.file_exists(metadata_file):
		var file = FileAccess.open(metadata_file, FileAccess.READ)
		if file:
			var json = JSON.new()
			var err = json.parse(file.get_as_text())
			file.close()
			if err == OK:
				var data = json.get_data()
				if data is Dictionary:
					for key in data.keys():
						if key.ends_with(".svg"):
							svg_keys.append(key)
	svg_keys.sort()
	for k in svg_keys:
		metadata_dropdown.add_item(k)

func _ensure_metadata_controls() -> void:
	var grid = override_name_edit.get_parent()
	if not grid:
		return
		
	# Check if they already exist in the grid to recover references
	metadata_build_check = grid.get_node_or_null("MetadataBuildCheckbox") as CheckBox
	metadata_builder_box = grid.get_node_or_null("MetadataBuilderBox") as HBoxContainer
	
	for child in grid.get_children():
		if child is Label:
			if child.text == "Build from Metadata:":
				metadata_build_label = child
			elif child.text == "Metadata SVG:":
				metadata_file_label = child
				
	if metadata_builder_box:
		metadata_dropdown = metadata_builder_box.get_node_or_null("MetadataDropdown") as OptionButton
		metadata_build_btn = metadata_builder_box.get_node_or_null("BuildBtn") as Button

	# If any element is missing, clean up what exists and recreate them fresh
	if not (metadata_build_check and metadata_build_label and metadata_file_label and metadata_builder_box and metadata_dropdown and metadata_build_btn):
		if metadata_build_check: metadata_build_check.queue_free()
		if metadata_build_label: metadata_build_label.queue_free()
		if metadata_file_label: metadata_file_label.queue_free()
		if metadata_builder_box: metadata_builder_box.queue_free()
		
		metadata_build_label = Label.new()
		metadata_build_label.text = "Build from Metadata:"
		grid.add_child(metadata_build_label)
		
		metadata_build_check = CheckBox.new()
		metadata_build_check.name = "MetadataBuildCheckbox"
		metadata_build_check.text = "Build from Metadata"
		metadata_build_check.button_pressed = false
		grid.add_child(metadata_build_check)
		
		metadata_file_label = Label.new()
		metadata_file_label.text = "Metadata SVG:"
		grid.add_child(metadata_file_label)
		
		metadata_builder_box = HBoxContainer.new()
		metadata_builder_box.name = "MetadataBuilderBox"
		metadata_builder_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		metadata_dropdown = OptionButton.new()
		metadata_dropdown.name = "MetadataDropdown"
		metadata_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metadata_builder_box.add_child(metadata_dropdown)
		
		metadata_build_btn = Button.new()
		metadata_build_btn.name = "BuildBtn"
		metadata_build_btn.text = "Build..."
		metadata_builder_box.add_child(metadata_build_btn)
		
		grid.add_child(metadata_builder_box)
		
		# Move them to come right after PropertyTypeOption dynamically
		var prop_type_idx = grid.get_children().find(prop_type_option)
		if prop_type_idx != -1:
			grid.move_child(metadata_build_label, prop_type_idx + 1)
			grid.move_child(metadata_build_check, prop_type_idx + 2)
			grid.move_child(metadata_file_label, prop_type_idx + 3)
			grid.move_child(metadata_builder_box, prop_type_idx + 4)
			
		# Set initial visibility to false
		metadata_build_label.visible = false
		metadata_build_check.visible = false
		metadata_file_label.visible = false
		metadata_builder_box.visible = false
		
		# Wire toggled signal
		metadata_build_check.toggled.connect(_on_metadata_build_check_toggled)
		# Wire build button
		metadata_build_btn.pressed.connect(_on_build_stylebox_pressed.bind(metadata_dropdown))

func _on_import_config_pressed() -> void:
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = "Select Theme Configuration (config.json)"
		dialog.add_filter("*.json", "JSON Config File")
		dialog.file_selected.connect(_on_import_config_selected.bind(dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = "Select Theme Configuration (config.json)"
		dialog.add_filter("*.json", "JSON Config File")
		dialog.file_selected.connect(_on_import_config_selected.bind(dialog))
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _on_import_config_selected(file_path: String, dialog: Node) -> void:
	dialog.queue_free()
	
	if not FileAccess.file_exists(file_path):
		printerr("Configuration file does not exist: ", file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("Failed to open configuration file for reading: ", file_path)
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		printerr("Failed to parse imported configuration: ", json.get_error_message())
		return
		
	var data = json.get_data()
	if not data is Dictionary:
		printerr("Imported configuration data is invalid (must be a JSON Dictionary)")
		return
		
	print("Importing configuration from: ", file_path)
	
	# Load variables
	image_folder = data.get("image_folder", "")
	fonts_folder = data.get("fonts_folder", "")
	metadata_file = data.get("metadata_file", "")
	output_file = data.get("output_file", "")
	theme_parts = data.get("theme_parts", {})
	theme_variations = data.get("theme_variations", {})
	preview_columns = int(data.get("preview_columns", 3))
	preview_item_width = int(data.get("preview_item_width", 200))
	preview_font_size = int(data.get("preview_font_size", 16))
	preview_texts = data.get("preview_texts", {})
	
	# Update UI inputs
	if images_edit:
		images_edit.text = image_folder
	if fonts_edit:
		fonts_edit.text = fonts_folder
	if metadata_edit:
		metadata_edit.text = metadata_file
	if output_edit:
		output_edit.text = output_file
		
	if preview_columns_spin:
		preview_columns_spin.value = preview_columns
	if preview_item_width_spin:
		preview_item_width_spin.value = preview_item_width
	if preview_font_size_spin:
		preview_font_size_spin.value = preview_font_size
		
	# Save this configuration to our active local config file so it persists
	save_config()
	
	# Refresh Parts Builder Tree and Preview Grid
	refresh_parts_tree()
	_on_apply_preview_pressed()
	
	print("Imported theme configuration successfully.")