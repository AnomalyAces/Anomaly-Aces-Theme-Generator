@tool
extends Control

# Configuration file paths
const CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/working/config.json"
const OLD_CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/config.json"

# Export properties for Inspector tab
@export_group("Export Settings")
@export_dir var image_folder: String = "res://addons/anomalyAcesThemeGenerator/working/Images":
	set(val):
		image_folder = val
		save_config()

@export_dir var fonts_folder: String = "res://addons/anomalyAcesThemeGenerator/working/Fonts":
	set(val):
		fonts_folder = val
		save_config()

@export_file("*.json") var metadata_file: String = "res://addons/anomalyAcesThemeGenerator/working/Metadata/metadata.json":
	set(val):
		metadata_file = val
		save_config()

@export_file("*.tres", "*.theme") var output_file: String = "res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres":
	set(val):
		output_file = val
		save_config()

# UI References via Unique Names
@onready var control_type_edit: LineEdit = %ControlTypeNameEdit
@onready var select_control_type_btn: Button = %SelectControlTypeBtn
@onready var prop_type_option: OptionButton = %PropertyTypeOption
@onready var prop_name_option: OptionButton = %PropertyNameOption
@onready var value_container: HBoxContainer = %PropertyValueContainer
@onready var parts_tree: Tree = %PartsTree

@onready var preview_area: PanelContainer = %PreviewArea
@onready var h_split: HSplitContainer = %MainPanel/HSplit

@onready var custom_type_check: CheckBox = %CustomTypeCheck
@onready var custom_type_name_edit: LineEdit = %CustomTypeNameEdit
@onready var override_name_edit: LineEdit = %OverrideNameEdit

# Data model for custom theme overrides (Theme Parts)
# Structure: { "Button": { "colors": { "font_color": { "value": Color, "id": String } } } }
var theme_parts: Dictionary = {}
var theme_variations: Dictionary = {}
var _config_loaded: bool = false

func _get_part_value(entry) -> Variant:
	if entry is Dictionary and entry.has("value"):
		return entry["value"]
	return entry

func _get_part_id(entry) -> String:
	if entry is Dictionary and entry.has("id"):
		return entry["id"]
	return ""

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
	prop_type_option.item_selected.connect(func(_index):
		update_property_names()
	)
	prop_name_option.item_selected.connect(func(_index):
		update_value_input_control()
	)

	# Wire the custom type checkbox toggle
	custom_type_check.toggled.connect(func(pressed):
		custom_type_name_edit.editable = pressed
		if not pressed:
			custom_type_name_edit.text = ""
	)

	# Connect actions
	%AddPartBtn.pressed.connect(_on_add_part_pressed)
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
	# Clear previous children in the container
	for child in value_container.get_children():
		child.queue_free()
		
	if prop_type_option.selected == -1:
		return
		
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower().replace(" ", "_")
	
	# Attempt to load existing value
	var existing_val = null
	var current_control = control_type_edit.text.strip_edges()
	var current_prop_name = ""
	if prop_name_option.selected != -1:
		current_prop_name = prop_name_option.get_item_text(prop_name_option.selected)
		
	var section_map = {
		"color": "colors",
		"constant": "constants",
		"font": "fonts",
		"font_size": "font_sizes",
		"icon": "icons",
		"stylebox": "styleboxes"
	}
	var sec = section_map.get(prop_type, "")
	if sec != "" and current_control != "" and current_prop_name != "":
		if theme_parts.has(current_control) and theme_parts[current_control].has(sec) and theme_parts[current_control][sec].has(current_prop_name):
			existing_val = theme_parts[current_control][sec][current_prop_name]

	var raw_val = null
	if existing_val != null:
		var ext_id = _get_part_id(existing_val)
		if ext_id != "":
			override_name_edit.text = ext_id
		raw_val = _get_part_value(existing_val)

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
			# Add an EditorResourcePicker
			var erp = EditorResourcePicker.new()
			erp.name = "ResourcePicker"
			erp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
						erp.edited_resource = res
			
			erp.resource_changed.connect(func(res: Resource):
				if res and Engine.is_editor_hint():
					EditorInterface.edit_resource(res)
				_on_resource_picker_changed(res)
			)
			erp.resource_selected.connect(func(res: Resource, inspect: bool):
				if res and Engine.is_editor_hint():
					EditorInterface.edit_resource(res)
			)
			
			value_container.add_child(erp)

# Config Load/Save
func save_config() -> void:
	if not _config_loaded:
		return
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
		"theme_variations": theme_variations
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

	_config_loaded = true

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
func _on_add_part_pressed() -> void:
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
	elif value_container.has_node("ResourcePicker"):
		var rp = value_container.get_node("ResourcePicker") as EditorResourcePicker
		if rp.edited_resource == null:
			is_cleared = true
		else:
			prop_val = rp.edited_resource.resource_path.strip_edges()
			if prop_val == "":
				printerr("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
				push_warning("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
				_show_warning_dialog("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
				return

	if is_cleared:
		if theme_parts.has(control_type) and theme_parts[control_type].has(sec) and theme_parts[control_type][sec].has(prop_name):
			theme_parts[control_type][sec].erase(prop_name)
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

	if prop_name == "" or prop_val == "":
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
			theme_parts[control_type]["colors"][prop_name] = new_entry
		"constant":
			theme_parts[control_type]["constants"][prop_name] = {
				"value": prop_val.to_int(),
				"id": override_id
			}
		"font":
			theme_parts[control_type]["fonts"][prop_name] = new_entry
		"font_size":
			theme_parts[control_type]["font_sizes"][prop_name] = {
				"value": prop_val.to_int(),
				"id": override_id
			}
		"icon":
			theme_parts[control_type]["icons"][prop_name] = new_entry
		"stylebox":
			theme_parts[control_type]["styleboxes"][prop_name] = new_entry

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
				val_item.set_metadata(0, {
					"control_type": ctrl_type,
					"sec_name": sec_name,
					"prop_name": prop_name
				})

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
				var raw_color = _get_part_value(section["colors"][col_name])
				var color_val = Color.from_string(raw_color, Color.WHITE)
				temp_theme.set_color(col_name, ctrl_type, color_val)

		# Apply Constants
		if section.has("constants"):
			for const_name in section["constants"].keys():
				var raw_const = _get_part_value(section["constants"][const_name])
				temp_theme.set_constant(const_name, ctrl_type, int(raw_const))

		# Apply Fonts
		if section.has("fonts"):
			for font_name in section["fonts"].keys():
				var font_path = _get_part_value(section["fonts"][font_name])
				if font_path != "" and ResourceLoader.exists(font_path):
					var loaded_font = ResourceLoader.load(font_path)
					if loaded_font is Font:
						temp_theme.set_font(font_name, ctrl_type, loaded_font)

		# Apply Font Sizes
		if section.has("font_sizes"):
			for fs_name in section["font_sizes"].keys():
				var raw_fs = _get_part_value(section["font_sizes"][fs_name])
				temp_theme.set_font_size(fs_name, ctrl_type, int(raw_fs))

		# Apply Icons
		if section.has("icons"):
			for icon_name in section["icons"].keys():
				var icon_path = _get_part_value(section["icons"][icon_name])
				if icon_path != "" and ResourceLoader.exists(icon_path):
					var loaded_icon = ResourceLoader.load(icon_path)
					if loaded_icon is Texture2D:
						temp_theme.set_icon(icon_name, ctrl_type, loaded_icon)

		# Apply StyleBoxes
		if section.has("styleboxes"):
			for sb_name in section["styleboxes"].keys():
				var sb_path = _get_part_value(section["styleboxes"][sb_name])
				if sb_path != "" and ResourceLoader.exists(sb_path):
					var loaded_sb = ResourceLoader.load(sb_path)
					if loaded_sb is StyleBox:
						temp_theme.set_stylebox(sb_name, ctrl_type, loaded_sb)

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
			var prop_lower = prop_name.to_lower()
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
	var preview_vbox = preview_area.get_node("PreviewVBox")
	if preview_vbox:
		# Clear existing children
		for child in preview_vbox.get_children():
			child.queue_free()
 
		if theme_parts.is_empty():
			var placeholder = Label.new()
			placeholder.text = "No theme parts configured yet. Add them in the Parts Builder to preview."
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			preview_vbox.add_child(placeholder)
		else:
			# Instantiate and add nodes that are defined in theme_parts
			for ctrl_type in theme_parts.keys():
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
						preview_vbox.add_child(inst)

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
	h_split.split_offset = int(h_split.size.x * 0.3) - int(h_split.size.x * 0.5)

func _on_tree_item_selected() -> void:
	var item = parts_tree.get_selected()
	if not item:
		return
		
	var meta = item.get_metadata(0)
	if meta is Dictionary and meta.has("control_type"):
		var ctrl_type = meta["control_type"]
		var sec_name = meta["sec_name"]
		var prop_name = meta["prop_name"]
		
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
		
		for i in range(prop_name_option.item_count):
			if prop_name_option.get_item_text(i) == prop_name:
				prop_name_option.selected = i
				break
				
		# 4. Update the input widgets and Name/ID
		update_value_input_control()

func _on_override_name_changed(new_text: String) -> void:
	if not _config_loaded:
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

	if theme_parts.has(control_type) and theme_parts[control_type].has(sec) and theme_parts[control_type][sec].has(prop_name):
		var entry = theme_parts[control_type][sec][prop_name]
		if entry is Dictionary:
			entry["id"] = new_text.strip_edges()
		else:
			theme_parts[control_type][sec][prop_name] = {
				"value": entry,
				"id": new_text.strip_edges()
			}
		save_config()
		refresh_parts_tree()

func _on_color_picker_changed(color: Color) -> void:
	if not _config_loaded:
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
	var override_id = override_name_edit.text.strip_edges()

	if not theme_parts.has(control_type):
		theme_parts[control_type] = {}
	if not theme_parts[control_type].has("colors"):
		theme_parts[control_type]["colors"] = {}

	var prop_val = "#" + color.to_html(true)
	theme_parts[control_type]["colors"][prop_name] = {
		"value": prop_val,
		"id": override_id
	}

	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func _on_spin_box_changed(value: float) -> void:
	if not _config_loaded:
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
	var override_id = override_name_edit.text.strip_edges()

	var sec = "constants" if prop_type == "constant" else "font_sizes"

	if not theme_parts.has(control_type):
		theme_parts[control_type] = {}
	if not theme_parts[control_type].has(sec):
		theme_parts[control_type][sec] = {}

	theme_parts[control_type][sec][prop_name] = {
		"value": int(value),
		"id": override_id
	}

	save_config()
	refresh_parts_tree()
	_on_apply_preview_pressed()

func _on_resource_picker_changed(res: Resource) -> void:
	if not _config_loaded:
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
		if theme_parts.has(control_type) and theme_parts[control_type].has(sec) and theme_parts[control_type][sec].has(prop_name):
			theme_parts[control_type][sec].erase(prop_name)
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
			theme_parts[control_type][sec][prop_name] = {
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