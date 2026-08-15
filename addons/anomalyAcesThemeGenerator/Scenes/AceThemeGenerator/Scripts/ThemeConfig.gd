@tool
extends RefCounted
## Config persistence — load, save, migrate, import.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

func ensure_config_loaded() -> void:
	if not _owner._config_loaded:
		load_config()

func ensure_dir_exists(path: String) -> void:
	if path == "":
		return
	if not DirAccess.dir_exists_absolute(path):
		var err = DirAccess.make_dir_recursive_absolute(path)
		if err == OK:
			print("Created directory: ", path)
		else:
			printerr("Failed to create directory: ", path, " Error: ", err)

# Config Load/Save
func save_config() -> void:
	ensure_config_loaded()
	_owner._parts_manager.cleanup_unique_properties()
	var dir_path = _owner.CONFIG_FILE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			printerr("Failed to create working directory: ", dir_path, " Error: ", err)
	var config = {
		"image_folder": _owner.image_folder,
		"fonts_folder": _owner.fonts_folder,
		"metadata_file": _owner.metadata_file,
		"output_file": _owner.output_file,
		"theme_parts": _owner.theme_parts,
		"theme_variations": _owner.theme_variations,
		"preview_columns": _owner.preview_columns,
		"preview_item_width": _owner.preview_item_width,
		"preview_font_size": _owner.preview_font_size,
		"preview_texts": _owner.preview_texts,
		"settings_split_ratio": _owner.settings_split_ratio
	}
	var file = FileAccess.open(_owner.CONFIG_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()

func load_config() -> void:
	_owner._config_loaded = false
	
	# Migrate old config.json to the new working directory if it exists
	if FileAccess.file_exists(_owner.OLD_CONFIG_FILE_PATH) and not FileAccess.file_exists(_owner.CONFIG_FILE_PATH):
		var new_dir = _owner.CONFIG_FILE_PATH.get_base_dir()
		if not DirAccess.dir_exists_absolute(new_dir):
			DirAccess.make_dir_recursive_absolute(new_dir)
		var err = DirAccess.copy_absolute(_owner.OLD_CONFIG_FILE_PATH, _owner.CONFIG_FILE_PATH)
		if err == OK:
			DirAccess.remove_absolute(_owner.OLD_CONFIG_FILE_PATH)
			print("Migrated old config.json to: ", _owner.CONFIG_FILE_PATH)
		else:
			printerr("Failed to migrate old config.json: ", err)

	# Initialize default paths
	var default_image_folder = "res://addons/anomalyAcesThemeGenerator/working/Images"
	var default_fonts_folder = "res://addons/anomalyAcesThemeGenerator/working/Fonts"
	var default_metadata_file = "res://addons/anomalyAcesThemeGenerator/working/Metadata/metadata.json"
	var default_output_file = "res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres"

	if FileAccess.file_exists(_owner.CONFIG_FILE_PATH):
		var file = FileAccess.open(_owner.CONFIG_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			var error = json.parse(json_string)
			if error == OK:
				var data = json.get_data()
				if data is Dictionary:
					_owner.image_folder = data.get("image_folder", "")
					_owner.fonts_folder = data.get("fonts_folder", "")
					_owner.metadata_file = data.get("metadata_file", "")
					_owner.output_file = data.get("output_file", "")
					_owner.theme_parts = data.get("theme_parts", {})
					_owner.theme_variations = data.get("theme_variations", {})
					_owner.preview_columns = int(data.get("preview_columns", 3))
					_owner.preview_item_width = int(data.get("preview_item_width", 200))
					_owner.preview_font_size = int(data.get("preview_font_size", 16))
					_owner.preview_texts = data.get("preview_texts", {})
					_owner.settings_split_ratio = float(data.get("settings_split_ratio", 0.5))
			else:
				printerr("Failed to parse config.json: ", json.get_error_message(), " at line ", json.get_error_line())

	# Apply fallbacks if empty
	if _owner.image_folder.strip_edges() == "":
		_owner.image_folder = default_image_folder
	if _owner.fonts_folder.strip_edges() == "":
		_owner.fonts_folder = default_fonts_folder
	if _owner.metadata_file.strip_edges() == "":
		_owner.metadata_file = default_metadata_file
	if _owner.output_file.strip_edges() == "":
		_owner.output_file = default_output_file

	# Ensure the subdirectories exist
	ensure_dir_exists(_owner.image_folder)
	ensure_dir_exists(_owner.fonts_folder)
	ensure_dir_exists(_owner.metadata_file.get_base_dir())
	ensure_dir_exists(_owner.output_file.get_base_dir())

	# Update UI inputs
	if _owner.images_edit:
		_owner.images_edit.text = _owner.image_folder
	if _owner.fonts_edit:
		_owner.fonts_edit.text = _owner.fonts_folder
	if _owner.metadata_edit:
		_owner.metadata_edit.text = _owner.metadata_file
	if _owner.output_edit:
		_owner.output_edit.text = _owner.output_file

	if _owner.preview_columns_spin:
		_owner.preview_columns_spin.value = _owner.preview_columns
	if _owner.preview_item_width_spin:
		_owner.preview_item_width_spin.value = _owner.preview_item_width
	if _owner.preview_font_size_spin:
		_owner.preview_font_size_spin.value = _owner.preview_font_size

	_owner._config_loaded = true
	_owner._parts_manager.cleanup_unique_properties()
	
	# Save the cleaned configuration to disk to repair any stale copy-suffixed unique entries
	var cleaned_config = {
		"image_folder": _owner.image_folder,
		"fonts_folder": _owner.fonts_folder,
		"metadata_file": _owner.metadata_file,
		"output_file": _owner.output_file,
		"theme_parts": _owner.theme_parts,
		"theme_variations": _owner.theme_variations,
		"preview_columns": _owner.preview_columns,
		"preview_item_width": _owner.preview_item_width,
		"preview_font_size": _owner.preview_font_size,
		"preview_texts": _owner.preview_texts
	}
	var save_file = FileAccess.open(_owner.CONFIG_FILE_PATH, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(cleaned_config, "\t"))
		save_file.close()
		print("Cleaned up and saved config on load.")
	
	_owner._svg_utils.reimport_svgs_as_dpi_textures(_owner.image_folder)

func import_config_from_file(file_path: String) -> void:
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
	_owner.image_folder = data.get("image_folder", "")
	_owner.fonts_folder = data.get("fonts_folder", "")
	_owner.metadata_file = data.get("metadata_file", "")
	_owner.output_file = data.get("output_file", "")
	_owner.theme_parts = data.get("theme_parts", {})
	_owner.theme_variations = data.get("theme_variations", {})
	_owner.preview_columns = int(data.get("preview_columns", 3))
	_owner.preview_item_width = int(data.get("preview_item_width", 200))
	_owner.preview_font_size = int(data.get("preview_font_size", 16))
	_owner.preview_texts = data.get("preview_texts", {})
	
	# Update UI inputs
	if _owner.images_edit:
		_owner.images_edit.text = _owner.image_folder
	if _owner.fonts_edit:
		_owner.fonts_edit.text = _owner.fonts_folder
	if _owner.metadata_edit:
		_owner.metadata_edit.text = _owner.metadata_file
	if _owner.output_edit:
		_owner.output_edit.text = _owner.output_file
		
	if _owner.preview_columns_spin:
		_owner.preview_columns_spin.value = _owner.preview_columns
	if _owner.preview_item_width_spin:
		_owner.preview_item_width_spin.value = _owner.preview_item_width
	if _owner.preview_font_size_spin:
		_owner.preview_font_size_spin.value = _owner.preview_font_size
		
	# Save this configuration to our active local config file so it persists
	save_config()
	
	# Refresh Parts Builder Tree and Preview Grid
	_owner._parts_manager.refresh_parts_tree()
	_owner._preview.apply_preview()
	
	print("Imported theme configuration successfully.")

func on_import_config_pressed() -> void:
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = "Select Theme Configuration (config.json)"
		dialog.add_filter("*.json", "JSON Config File")
		dialog.file_selected.connect(_on_import_config_selected.bind(dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = "Select Theme Configuration (config.json)"
		dialog.add_filter("*.json", "JSON Config File")
		dialog.file_selected.connect(_on_import_config_selected.bind(dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _on_import_config_selected(file_path: String, dialog: Node) -> void:
	dialog.queue_free()
	import_config_from_file(file_path)
