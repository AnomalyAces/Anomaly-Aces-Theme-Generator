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

# Data model for custom theme overrides (Theme Parts)
# Structure: { "Button": { "colors": { "font_color": { "value": Color, "id": String } } } }
var theme_parts: Dictionary = {}
var theme_variations: Dictionary = {}
var _config_loaded: bool = false
var preview_columns: int = 3
var _target_select_meta = null
var _active_prop_key: String = ""

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

	# Connect actions
	%AddPartBtn.pressed.connect(_on_add_part_pressed)
	%NewOverrideBtn.pressed.connect(_on_new_override_pressed)
	%DuplicateOverrideBtn.pressed.connect(_on_duplicate_override_pressed)
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
		
	# Scale minimum sizes of specific controls to match DPI scaling
	if parts_tree:
		parts_tree.custom_minimum_size = Vector2(0, int(150 * scale))

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
		update_property_types()

func update_property_types() -> void:
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
		
	if prop_type_option.item_count > 0:
		prop_type_option.selected = 0
		update_property_names()

func update_property_names() -> void:
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
			_refresh_metadata_dropdown()
		else:
			metadata_build_label.visible = false
			metadata_build_check.visible = false
			metadata_file_label.visible = false
			metadata_builder_box.visible = false
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
		"preview_columns": preview_columns
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
		"preview_columns": preview_columns
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
			else:
				has_normal_configs = true
				
	if has_normal_configs or states.is_empty():
		states.insert(0, "normal")
		
	return states

# Build Native Theme Object & Preview it
func _on_apply_preview_pressed() -> void:
	var temp_theme = build_theme()
	preview_area.theme = temp_theme
 
	# Update the preview nodes dynamically
	if preview_grid:
		# Clear existing children
		for child in preview_grid.get_children():
			child.queue_free()
 
		if theme_parts.is_empty():
			preview_grid.columns = 1
			var placeholder = Label.new()
			placeholder.text = "No theme parts configured yet. Add them in the Parts Builder to preview."
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			preview_grid.add_child(placeholder)
		else:
			preview_grid.columns = preview_columns
			# Instantiate and add nodes that are defined in theme_parts
			for ctrl_type in theme_parts.keys():
				if ctrl_type == "PanelContainer":
					continue
				var states = _get_configured_states(ctrl_type)
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
							
						setup_preview_node(inst, display_name)
						inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						preview_grid.add_child(inst)

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

func setup_preview_node(inst: Control, display_name: String) -> void:
	if inst is Panel or inst is PanelContainer or inst is ColorRect or inst is TextureRect or inst is Container or inst is Tree:
		inst.custom_minimum_size = Vector2(0, 40)
		
	if inst is RichTextLabel:
		inst.text = "[color=magenta]Sample[/color] " + display_name
		inst.fit_content = true
	elif "placeholder_text" in inst:
		inst.placeholder_text = display_name
	elif "text" in inst:
		inst.text = display_name
	elif not (inst is Tree):
		var lbl = Label.new()
		lbl.text = display_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	var theme = build_theme()
	var err = ResourceSaver.save(theme, out_path)
	if err == OK:
		print("Theme Resource generated successfully at: ", out_path)
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("Failed to save Theme Resource at: ", out_path, " Error: ", err)

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

# Signal callbacks to avoid lambdas and prevent Engine Stack Underflow Bug
func _on_prop_type_selected(index: int) -> void:
	_active_prop_key = ""
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
	
	if shadow_effect != null:
		# Build programmatically styled StyleBoxFlat
		var flat_sb = StyleBoxFlat.new()
		
		# Set border/corner radius (capsule corner, using half the height if height exists, otherwise a default of 30)
		var h = entry.get("height", 60.0)
		var radius = int(float(h) / 2.0)
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
		
		# Background color from Figma fills:
		var fill_color = Color(0.08, 0.08, 0.1, 0.6) # Fallback bg_color
		var fills = entry.get("fills", [])
		if fills.size() > 0:
			var first_fill = fills[0]
			if first_fill is Dictionary and first_fill.get("type") == "SOLID":
				var fill_col_dict = first_fill.get("color", {})
				var fr = float(fill_col_dict.get("r", 0.0))
				var fg = float(fill_col_dict.get("g", 0.0))
				var fb = float(fill_col_dict.get("b", 0.0))
				var fopacity = float(first_fill.get("opacity", 1.0))
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
		if ResourceLoader.exists(svg_path):
			var tex = ResourceLoader.load(svg_path)
			if tex:
				tex_sb.texture = tex
		
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