@tool
extends Control

# Configuration file path
const CONFIG_FILE_PATH = "res://addons/anomalyAcesThemeGenerator/config.json"

# UI References via Unique Names
@onready var image_folder_edit: LineEdit = %ImageFolderEdit
@onready var fonts_folder_edit: LineEdit = %FontsFolderEdit
@onready var metadata_file_edit: LineEdit = %MetadataFileEdit
@onready var output_file_edit: LineEdit = %OutputFileEdit

@onready var type_option: OptionButton = %ControlTypeOption
@onready var prop_type_option: OptionButton = %PropertyTypeOption
@onready var prop_name_edit: LineEdit = %PropertyNameEdit
@onready var prop_val_edit: LineEdit = %PropertyValueEdit
@onready var parts_tree: Tree = %PartsTree

@onready var preview_area: PanelContainer = %PreviewArea

# Dialog for browsing files
var file_dialog: FileDialog
var current_browsing_target: LineEdit

# Data model for custom theme overrides (Theme Parts)
# Structure: { "Button": { "colors": { "font_color": Color(1,1,1) }, "constants": { "outline_size": 2 } } }
var theme_parts: Dictionary = {}

func _ready() -> void:
	setup_ui()
	load_config()
	refresh_parts_tree()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(file_dialog):
			file_dialog.queue_free()

func setup_ui() -> void:
	# FileDialog helper
	file_dialog = FileDialog.new()
	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_dir_selected)

	# Connect Browse buttons
	%ImageBrowseBtn.pressed.connect(func(): _on_browse_pressed(image_folder_edit, true, ""))
	%FontsBrowseBtn.pressed.connect(func(): _on_browse_pressed(fonts_folder_edit, true, ""))
	%MetadataBrowseBtn.pressed.connect(func(): _on_browse_pressed(metadata_file_edit, false, "*.json"))
	%OutputBrowseBtn.pressed.connect(func(): _on_browse_pressed(output_file_edit, false, "*.json"))

	# Populate Control Types dropdown
	type_option.clear()
	for type_name in ["Button", "Label", "LineEdit", "Panel", "CheckBox", "TextEdit"]:
		type_option.add_item(type_name)

	# Populate Property Types dropdown
	prop_type_option.clear()
	prop_type_option.add_item("Color")
	prop_type_option.add_item("Constant")
	prop_type_option.add_item("Font")

	# Connect actions
	%AddPartBtn.pressed.connect(_on_add_part_pressed)
	%ApplyPreviewBtn.pressed.connect(_on_apply_preview_pressed)
	%CompileBtn.pressed.connect(_on_compile_pressed)

	# Setup Parts Tree titles
	parts_tree.columns = 3
	parts_tree.set_column_title(0, "Control")
	parts_tree.set_column_title(1, "Property")
	parts_tree.set_column_title(2, "Value")
	parts_tree.column_titles_visible = true

	# Connect text submission to save config
	image_folder_edit.text_submitted.connect(func(_x): save_config())
	fonts_folder_edit.text_submitted.connect(func(_x): save_config())
	metadata_file_edit.text_submitted.connect(func(_x): save_config())
	output_file_edit.text_submitted.connect(func(_x): save_config())

# Browse Dialog Handling
func _on_browse_pressed(target_line_edit: LineEdit, is_dir: bool, filter: String) -> void:
	current_browsing_target = target_line_edit
	file_dialog.clear_filters()
	if is_dir:
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	else:
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		if filter != "":
			file_dialog.add_filter(filter)
	
	# Open relative to current project path
	file_dialog.current_dir = "res://"
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String) -> void:
	if is_instance_valid(current_browsing_target):
		current_browsing_target.text = path
		save_config()

func _on_dir_selected(dir: String) -> void:
	if is_instance_valid(current_browsing_target):
		current_browsing_target.text = dir
		save_config()

# Config Load/Save
func save_config() -> void:
	var config = {
		"image_folder": image_folder_edit.text,
		"fonts_folder": fonts_folder_edit.text,
		"metadata_file": metadata_file_edit.text,
		"output_file": output_file_edit.text,
		"theme_parts": theme_parts
	}
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()

func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		return
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				image_folder_edit.text = data.get("image_folder", "")
				fonts_folder_edit.text = data.get("fonts_folder", "")
				metadata_file_edit.text = data.get("metadata_file", "")
				output_file_edit.text = data.get("output_file", "")
				theme_parts = data.get("theme_parts", {})

# Parts Builder Management
func _on_add_part_pressed() -> void:
	var control_type = type_option.get_item_text(type_option.selected)
	var prop_type = prop_type_option.get_item_text(prop_type_option.selected).to_lower()
	var prop_name = prop_name_edit.text.strip_edges()
	var prop_val = prop_val_edit.text.strip_edges()

	if prop_name == "" or prop_val == "":
		return

	if not theme_parts.has(control_type):
		theme_parts[control_type] = {
			"colors": {},
			"constants": {},
			"fonts": {}
		}

	# Ensure sections exist
	if not theme_parts[control_type].has("colors"): theme_parts[control_type]["colors"] = {}
	if not theme_parts[control_type].has("constants"): theme_parts[control_type]["constants"] = {}
	if not theme_parts[control_type].has("fonts"): theme_parts[control_type]["fonts"] = {}

	# Assign values
	match prop_type:
		"color":
			theme_parts[control_type]["colors"][prop_name] = prop_val
		"constant":
			theme_parts[control_type]["constants"][prop_name] = prop_val.to_int()
		"font":
			theme_parts[control_type]["fonts"][prop_name] = prop_val

	prop_name_edit.text = ""
	prop_val_edit.text = ""
	save_config()
	refresh_parts_tree()

func refresh_parts_tree() -> void:
	parts_tree.clear()
	var root = parts_tree.create_item()
	parts_tree.hide_root = true

	for ctrl_type in theme_parts.keys():
		var ctrl_item = parts_tree.create_item(root)
		ctrl_item.set_text(0, ctrl_type)
		
		var sections = theme_parts[ctrl_type]
		for sec_name in sections.keys():
			var overrides = sections[sec_name]
			for prop_name in overrides.keys():
				var val_item = parts_tree.create_item(ctrl_item)
				val_item.set_text(0, "")
				val_item.set_text(1, sec_name.to_upper() + ": " + prop_name)
				val_item.set_text(2, str(overrides[prop_name]))

# Build Native Theme Object & Preview it
func _on_apply_preview_pressed() -> void:
	var temp_theme = Theme.new()

	for ctrl_type in theme_parts.keys():
		var section = theme_parts[ctrl_type]

		# Apply Colors
		if section.has("colors"):
			for col_name in section["colors"].keys():
				var color_val = Color.from_string(section["colors"][col_name], Color.WHITE)
				temp_theme.set_color(col_name, ctrl_type, color_val)

		# Apply Constants
		if section.has("constants"):
			for const_name in section["constants"].keys():
				temp_theme.set_constant(const_name, ctrl_type, int(section["constants"][const_name]))

		# Apply Fonts
		if section.has("fonts"):
			for font_name in section["fonts"].keys():
				var font_path = section["fonts"][font_name]
				if font_path != "" and ResourceLoader.exists(font_path):
					var loaded_font = ResourceLoader.load(font_path)
					if loaded_font is Font:
						temp_theme.set_font(font_name, ctrl_type, loaded_font)

	preview_area.theme = temp_theme

# Generate Theme JSON output
func _on_compile_pressed() -> void:
	var out_path = output_file_edit.text.strip_edges()
	if out_path == "":
		printerr("No output path specified!")
		return

	# Compile final json payload including the paths, current inputs metadata, and custom builder overrides
	var compiled_data = {
		"generator_config": {
			"image_folder": image_folder_edit.text,
			"fonts_folder": fonts_folder_edit.text,
			"metadata_file": metadata_file_edit.text
		},
		"theme_overrides": theme_parts
	}

	# If a metadata file was supplied, we try to load and merge/embed it
	var meta_path = metadata_file_edit.text.strip_edges()
	if meta_path != "" and FileAccess.file_exists(meta_path):
		var file = FileAccess.open(meta_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var parsed_meta = json.get_data()
				compiled_data["metadata_assets"] = parsed_meta

	# Write out compiled Theme JSON
	var out_file = FileAccess.open(out_path, FileAccess.WRITE)
	if out_file:
		out_file.store_string(JSON.stringify(compiled_data, "\t"))
		out_file.close()
		print("Theme JSON generated successfully at: ", out_path)