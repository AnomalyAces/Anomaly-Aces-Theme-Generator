@tool
extends RefCounted
## Compile final .tres Theme, package files, rewrite paths, export standalone preview scene.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

# Generate native Godot Theme resource
func on_compile_pressed() -> void:
	var out_path = _owner.output_file.strip_edges()
	if out_path == "":
		printerr("No output path specified!")
		return

	_owner._config.ensure_dir_exists(out_path.get_base_dir())

	var theme = _owner._builder.build_theme()
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
	
	_owner._config.ensure_dir_exists(target_dir)
	_owner._config.ensure_dir_exists(target_res_dir)
	_owner._config.ensure_dir_exists(target_img_dir)
	_owner._config.ensure_dir_exists(target_font_dir)
	
	var files_to_copy: Dictionary = {}
	var path_replacements: Dictionary = {}
	
	# Copy local configuration file as part of the package to make it round-trippable
	files_to_copy[_owner.CONFIG_FILE_PATH] = target_dir.path_join("config.json")
	path_replacements[_owner.CONFIG_FILE_PATH] = target_dir.path_join("config.json")
	
	# Add directory paths to path replacements so the exported config.json updates settings correctly
	path_replacements[_owner.image_folder] = target_img_dir
	path_replacements[_owner.fonts_folder] = target_font_dir
	
	# Copy metadata file if configured
	if _owner.metadata_file != "":
		var meta_filename = _owner.metadata_file.get_file()
		var source_meta_path = ""
		if FileAccess.file_exists("res://addons/anomalyAcesThemeGenerator/working/Metadata".path_join(meta_filename)):
			source_meta_path = "res://addons/anomalyAcesThemeGenerator/working/Metadata".path_join(meta_filename)
		elif FileAccess.file_exists(_owner.metadata_file):
			source_meta_path = _owner.metadata_file
			
		if source_meta_path != "":
			var target_meta_dir = target_dir.path_join("Metadata")
			_owner._config.ensure_dir_exists(target_meta_dir)
			var new_meta_path = target_meta_dir.path_join(meta_filename)
			files_to_copy[source_meta_path] = new_meta_path
			path_replacements[_owner.metadata_file] = new_meta_path
	
	for ctrl_type in _owner.theme_parts.keys():
		var section = _owner.theme_parts[ctrl_type]
		
		# 1. Scan styleboxes
		if section.has("styleboxes"):
			for sb_name in section["styleboxes"].keys():
				var sb_val = _owner.get_part_value(section["styleboxes"][sb_name])
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
								if FileAccess.file_exists(_owner.image_folder.path_join(img_filename)):
									source_img_path = _owner.image_folder.path_join(img_filename)
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
				var font_val = _owner.get_part_value(section["fonts"][font_name])
				if font_val is String and font_val.begins_with("res://"):
					var old_font_path = font_val
					var font_filename = old_font_path.get_file()
					
					var source_font_path = ""
					if FileAccess.file_exists(_owner.fonts_folder.path_join(font_filename)):
						source_font_path = _owner.fonts_folder.path_join(font_filename)
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
				var icon_val = _owner.get_part_value(section["icons"][icon_name])
				if icon_val is String and icon_val.begins_with("res://"):
					var old_icon_path = icon_val
					var icon_filename = old_icon_path.get_file()
					
					var source_icon_path = ""
					if FileAccess.file_exists(_owner.image_folder.path_join(icon_filename)):
						source_icon_path = _owner.image_folder.path_join(icon_filename)
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
	var old_theme_path = _owner.output_file
	var new_theme_path = target_dir.path_join(_owner.output_file.get_file())
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
	
	# Load metadata to retrieve component design width/height (exactly as in apply_preview)
	var metadata = _owner._preview._load_metadata()
				
	if _owner.theme_parts.is_empty():
		var placeholder = Label.new()
		placeholder.name = "Placeholder"
		placeholder.text = "No theme parts configured yet. Add them in the Parts Builder to preview."
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		placeholder.add_theme_font_size_override("font_size", _owner.preview_font_size)
		grid.add_child(placeholder)
	else:
		for ctrl_type in _owner.theme_parts.keys():
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
			if _owner.theme_variations.has(ctrl_type) and _owner.theme_variations[ctrl_type] != "":
				type_display += " (Variation of " + _owner.theme_variations[ctrl_type] + ")"
			header_lbl.text = type_display
			header_lbl.add_theme_font_size_override("font_size", _owner.preview_font_size + 4)
			header_lbl.add_theme_color_override("font_color", Color(0.26, 0.95, 1.0, 1.0)) # Neon Cyan
			
			var separator = HSeparator.new()
			separator.name = "Separator"
			separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			header_box.add_child(header_lbl)
			header_box.add_child(separator)
			section_box.add_child(header_box)
			
			var sub_grid = GridContainer.new()
			sub_grid.name = "SubGrid"
			sub_grid.columns = _owner.preview_columns
			sub_grid.add_theme_constant_override("h_separation", 15)
			sub_grid.add_theme_constant_override("v_separation", 15)
			
			if _owner.preview_item_width > 0:
				sub_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			else:
				sub_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
			section_box.add_child(sub_grid)
			grid.add_child(section_box)
			
			var spacer = Control.new()
			spacer.name = ctrl_type + "_Spacer"
			spacer.custom_minimum_size = Vector2(0, 15)
			grid.add_child(spacer)
			
			var states = _owner._preview.get_configured_states(ctrl_type)
			
			# Find a common design size from any state of this control type to use as fallback
			var common_size = _owner._preview._find_common_design_size(ctrl_type, states, metadata)
					
			for state in states:
				var inst: Control = null
				var display_name = ctrl_type
				
				if _owner.theme_variations.has(ctrl_type) and _owner.theme_variations[ctrl_type] != "":
					var base_type = _owner.theme_variations[ctrl_type]
					inst = _owner._preview.instantiate_class_by_name(base_type)
					if inst:
						inst.theme_type_variation = ctrl_type
						display_name = ctrl_type + " (" + base_type + ")"
				else:
					inst = _owner._preview.instantiate_class_by_name(ctrl_type)
					
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
					if _owner.preview_texts.has(text_key):
						item_text = _owner.preview_texts[text_key]
						
					var design_width = 0.0
					var design_height = 0.0
					var record = null
					var val_path = ""
					if _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has("styleboxes"):
						var sboxes = _owner.theme_parts[ctrl_type]["styleboxes"]
						for key in sboxes.keys():
							if _owner.get_base_prop_name(key) == state:
								record = sboxes[key]
								break
						
						if record != null:
							val_path = str(_owner.get_part_value(record))
							if val_path != "" and ResourceLoader.exists(val_path):
								var sb = _owner._preview.load_stylebox_uncached(val_path)
								if sb is StyleBox:
									active_stylebox = sb
							
					_owner._preview.setup_preview_node(inst, item_text, loaded_theme)

					if record != null:
						var dims = _owner._preview.resolve_design_dimensions(active_stylebox, record, val_path, metadata)
						design_width = dims.x
						design_height = dims.y
					elif active_stylebox != null:
						if active_stylebox is StyleBoxTexture and active_stylebox.texture:
							var tex_sz = active_stylebox.texture.get_size()
							design_width = tex_sz.x
							design_height = tex_sz.y
					
					if design_width < 20.0 and common_size.x >= 20.0:
						design_width = common_size.x
						design_height = common_size.y
						
					_owner._preview.apply_node_preview_sizing(inst, active_stylebox, design_width, design_height, _owner.preview_item_width)
					
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
