@tool
extends RefCounted
## Build StyleBoxFlat / StyleBoxTexture from Figma metadata + SVG.
## Manages the metadata builder UI controls.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

func on_metadata_build_check_toggled(pressed: bool) -> void:
	if _owner.metadata_file_label:
		_owner.metadata_file_label.visible = pressed
	if _owner.metadata_builder_box:
		_owner.metadata_builder_box.visible = pressed

func refresh_metadata_dropdown() -> void:
	if not _owner.metadata_dropdown:
		return
	_owner.metadata_dropdown.clear()
	var svg_keys: Array = []
	if FileAccess.file_exists(_owner.metadata_file):
		var file = FileAccess.open(_owner.metadata_file, FileAccess.READ)
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
		_owner.metadata_dropdown.add_item(k)

func ensure_metadata_controls() -> void:
	var grid = _owner.override_name_edit.get_parent()
	if not grid:
		return
		
	# Check if they already exist in the grid to recover references
	_owner.metadata_build_check = grid.get_node_or_null("MetadataBuildCheckbox") as CheckBox
	_owner.metadata_builder_box = grid.get_node_or_null("MetadataBuilderBox") as HBoxContainer
	
	for child in grid.get_children():
		if child is Label:
			if child.text == "Build from Metadata:":
				_owner.metadata_build_label = child
			elif child.text == "Metadata SVG:":
				_owner.metadata_file_label = child
				
	if _owner.metadata_builder_box:
		_owner.metadata_dropdown = _owner.metadata_builder_box.get_node_or_null("MetadataDropdown") as OptionButton
		_owner.metadata_build_btn = _owner.metadata_builder_box.get_node_or_null("BuildBtn") as Button

	# If any element is missing, clean up what exists and recreate them fresh
	if not (_owner.metadata_build_check and _owner.metadata_build_label and _owner.metadata_file_label and _owner.metadata_builder_box and _owner.metadata_dropdown and _owner.metadata_build_btn):
		if _owner.metadata_build_check: _owner.metadata_build_check.queue_free()
		if _owner.metadata_build_label: _owner.metadata_build_label.queue_free()
		if _owner.metadata_file_label: _owner.metadata_file_label.queue_free()
		if _owner.metadata_builder_box: _owner.metadata_builder_box.queue_free()
		
		_owner.metadata_build_label = Label.new()
		_owner.metadata_build_label.text = "Build from Metadata:"
		grid.add_child(_owner.metadata_build_label)
		
		_owner.metadata_build_check = CheckBox.new()
		_owner.metadata_build_check.name = "MetadataBuildCheckbox"
		_owner.metadata_build_check.text = "Build from Metadata"
		_owner.metadata_build_check.button_pressed = false
		grid.add_child(_owner.metadata_build_check)
		
		_owner.metadata_file_label = Label.new()
		_owner.metadata_file_label.text = "Metadata SVG:"
		grid.add_child(_owner.metadata_file_label)
		
		_owner.metadata_builder_box = HBoxContainer.new()
		_owner.metadata_builder_box.name = "MetadataBuilderBox"
		_owner.metadata_builder_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		_owner.metadata_dropdown = OptionButton.new()
		_owner.metadata_dropdown.name = "MetadataDropdown"
		_owner.metadata_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_owner.metadata_builder_box.add_child(_owner.metadata_dropdown)
		
		_owner.metadata_build_btn = Button.new()
		_owner.metadata_build_btn.name = "BuildBtn"
		_owner.metadata_build_btn.text = "Build..."
		_owner.metadata_builder_box.add_child(_owner.metadata_build_btn)
		
		grid.add_child(_owner.metadata_builder_box)
		
		# Move them to come right after PropertyTypeOption dynamically
		var prop_type_idx = grid.get_children().find(_owner.prop_type_option)
		if prop_type_idx != -1:
			grid.move_child(_owner.metadata_build_label, prop_type_idx + 1)
			grid.move_child(_owner.metadata_build_check, prop_type_idx + 2)
			grid.move_child(_owner.metadata_file_label, prop_type_idx + 3)
			grid.move_child(_owner.metadata_builder_box, prop_type_idx + 4)
			
		# Set initial visibility to false
		_owner.metadata_build_label.visible = false
		_owner.metadata_build_check.visible = false
		_owner.metadata_file_label.visible = false
		_owner.metadata_builder_box.visible = false
		
		# Wire toggled signal
		_owner.metadata_build_check.toggled.connect(on_metadata_build_check_toggled)
		# Wire build button
		_owner.metadata_build_btn.pressed.connect(on_build_stylebox_pressed.bind(_owner.metadata_dropdown))

func on_build_stylebox_pressed(dropdown: OptionButton) -> void:
	if dropdown.selected == -1:
		printerr("No SVG file selected in metadata dropdown.")
		return
	
	var svg_key = dropdown.get_item_text(dropdown.selected)
	var base_svg_name = svg_key.replace(".svg", "")
	var default_filename = base_svg_name + "_stylebox.tres"
	var default_dir = "res://addons/anomalyAcesThemeGenerator/working/ResourceFiles"
	var default_path = default_dir.path_join(default_filename)
	
	# Make sure default directory exists
	_owner._config.ensure_dir_exists(default_dir)
	
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = "Save StyleBox Resource"
		dialog.add_filter("*.tres", "StyleBox Resource")
		dialog.current_path = default_path
		dialog.file_selected.connect(_on_stylebox_save_path_selected.bind(svg_key, dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
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
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _on_stylebox_save_path_selected(save_path: String, svg_key: String, dialog: Node) -> void:
	dialog.queue_free()
	
	# Guard: Only build/replace if build checkbox is checked
	if _owner.metadata_build_check and not _owner.metadata_build_check.button_pressed:
		printerr("Build from Metadata checkbox is not checked. Aborting generation.")
		return
	
	# 1. Parse metadata.json
	var metadata = {}
	if FileAccess.file_exists(_owner.metadata_file):
		var file = FileAccess.open(_owner.metadata_file, FileAccess.READ)
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
		new_stylebox = _build_stylebox_flat(entry, shadow_effect, svg_key)
	else:
		new_stylebox = _build_stylebox_texture(entry, svg_key)
		
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
				var rp = _owner.value_container.find_child("ResourcePicker", true, false)
				if rp:
					if "edited_resource" in rp:
						rp.edited_resource = loaded_res
					elif rp is Button:
						rp.text = save_path
					
				# Also save to config theme_parts and preview it
				_owner._parts_manager.on_resource_picker_changed(loaded_res)
	else:
		printerr("Failed to save StyleBox resource: ", err)

func _build_stylebox_flat(entry: Dictionary, shadow_effect: Dictionary, svg_key: String) -> StyleBoxFlat:
	# Build programmatically styled StyleBoxFlat
	var flat_sb = StyleBoxFlat.new()
	
	# Set border/corner radius (try to extract from SVG rect rx first, fall back to capsule corner)
	var h = entry.get("height", 60.0)
	var radius = -1
	var svg_path = _owner.image_folder.path_join(svg_key)
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
		
	var solid_fill = _find_solid_fill(fills)
		
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
	
	return flat_sb

func _build_stylebox_texture(entry: Dictionary, svg_key: String) -> StyleBoxTexture:
	# Build StyleBoxTexture using the SVG path
	var tex_sb = StyleBoxTexture.new()
	var svg_path = _owner.image_folder.path_join(svg_key)
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
		
	var solid_fill = _find_solid_fill(fills)
		
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
				var fill_color_hex = "#" + col.to_html(false)
				# Try to parse corner radius (rx) from the SVG's remaining elements first, fallback to half height
				var rx = design_h / 2.0
				var r_regex = RegEx.new()
				r_regex.compile("<rect[^>]+rx=\"([0-9.]+)\"")
				var r_result = r_regex.search(svg_text)
				if r_result:
					rx = float(r_result.get_string(1))
					
				var rect_svg = '<rect id="figma_bg_inject" x="%f" y="%f" width="%f" height="%f" rx="%f" ry="%f" fill="%s" fill-opacity="%f"/>' % [pad_x, pad_y, design_w, design_h, rx, rx, fill_color_hex, fill_opacity]
				
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
			
	_owner._svg_utils.clean_svg_filters(svg_path)
	
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
	
	return tex_sb

func _find_solid_fill(fills: Array) -> Variant:
	for fill in fills:
		if fill is Dictionary and fill.get("type") == "SOLID":
			var node_name = fill.get("nodeName", "").to_lower()
			if "text" in node_name or "label" in node_name or "vector" in node_name or "icon" in node_name or "path" in node_name:
				continue
			return fill
	return null
