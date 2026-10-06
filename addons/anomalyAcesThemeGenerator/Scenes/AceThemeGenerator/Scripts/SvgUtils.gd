@tool
extends RefCounted
## SVG file operations — scanning directories, cleaning filters, DPI reimport.

var _owner  # Reference to AceThemeGenerator

var _pending_modified_files: Array[String] = []

func _init(owner) -> void:
	_owner = owner

func scan_for_svgs(dir_path: String, out_files: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					scan_for_svgs(dir_path.path_join(file_name), out_files)
			else:
				if file_name.ends_with(".svg"):
					out_files.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()

func reimport_svgs_as_dpi_textures(dir_path: String) -> void:
	if not Engine.is_editor_hint():
		return
	if dir_path.strip_edges() == "":
		return
		
	var files_to_reimport: Array[String] = []
	scan_for_svgs(dir_path, files_to_reimport)
	
	if files_to_reimport.is_empty():
		return
		
	var modified_files: Array[String] = []
	for file_path in files_to_reimport:
		clean_svg_filters(file_path)
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
				root.get_tree().process_frame.connect(on_process_frame_reimport, CONNECT_ONE_SHOT)
			else:
				file_system.reimport_files(_pending_modified_files)

func on_process_frame_reimport() -> void:
	var file_system = EditorInterface.get_resource_filesystem()
	if file_system and not _pending_modified_files.is_empty():
		file_system.reimport_files(_pending_modified_files)
		print("Reimport completed.")
		_pending_modified_files.clear()

func clean_svg_filters(file_path: String) -> void:
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
	
	# Automatically un-crop SVGs exported from Figma with cropped viewBoxes
	var filter_regex = RegEx.new()
	filter_regex.compile("<filter[^>]+width=\"([0-9.]+)\"[^>]+height=\"([0-9.]+)\"")
	var f_match = filter_regex.search(content)
	if f_match:
		var fw = int(round(float(f_match.get_string(1))))
		var fh = int(round(float(f_match.get_string(2))))
		var svg_tag_regex = RegEx.new()
		svg_tag_regex.compile("<svg\\s+width=\"([0-9.]+)\"\\s+height=\"([0-9.]+)\"\\s+viewBox=\"([0-9.]+)\\s+([0-9.]+)\\s+([0-9.]+)\\s+([0-9.]+)\"")
		var s_match = svg_tag_regex.search(content)
		if s_match:
			var sw = float(s_match.get_string(1))
			var sh = float(s_match.get_string(2))
			var vx = float(s_match.get_string(3))
			var vy = float(s_match.get_string(4))
			if fw > sw and fh > sh and (vx > 0.0 or vy > 0.0):
				var new_tag = '<svg width="%d" height="%d" viewBox="0 0 %d %d"' % [fw, fh, fw, fh]
				new_content = svg_tag_regex.sub(new_content, new_tag)

	if file_path.to_lower().contains("color_selection") or file_path.to_lower().contains("circle"):
		var circle_regex = RegEx.new()
		circle_regex.compile("<circle[^>]+r=\"([0-9.]+)\"[^>]+stroke-width=\"([0-9.]+)\"")
		var c_match = circle_regex.search(content)
		if c_match:
			var cr = float(c_match.get_string(1))
			var csw = float(c_match.get_string(2))
			var full_dim = int(round((cr + csw / 2.0) * 2.0))
			var svg_tag_regex2 = RegEx.new()
			svg_tag_regex2.compile("<svg\\s+width=\"([0-9.]+)\"\\s+height=\"([0-9.]+)\"\\s+viewBox=\"([0-9.]+)\\s+([0-9.]+)\\s+([0-9.]+)\\s+([0-9.]+)\"")
			var s_match2 = svg_tag_regex2.search(content)
			if s_match2:
				var sw2 = float(s_match2.get_string(1))
				var vx2 = float(s_match2.get_string(3))
				if full_dim > sw2 and vx2 > 0.0:
					var new_tag = '<svg width="%d" height="%d" viewBox="0 0 %d %d"' % [full_dim, full_dim, full_dim, full_dim]
					new_content = svg_tag_regex2.sub(new_content, new_tag)
					
	if new_content != content:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(new_content)
			write_file.close()
			print("Cleaned unsupported filters / uncropped SVG: ", file_path)
