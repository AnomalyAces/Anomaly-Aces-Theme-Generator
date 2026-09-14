@tool
extends RefCounted
## Live preview panel rendering — instantiates control nodes, applies states, sizes from metadata.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

func get_configured_states(ctrl_type: String) -> Array[String]:
	var states: Array[String] = []
	if not _owner.theme_parts.has(ctrl_type):
		return ["normal"]
		
	var section = _owner.theme_parts[ctrl_type]
	var has_normal_configs = false
	
	for sec_name in section.keys():
		var overrides = section[sec_name]
		for prop_name in overrides.keys():
			var base_name = _owner.get_base_prop_name(prop_name)
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
			var base_type = _owner.theme_variations.get(theme_type, "")
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
				var base_type = _owner.theme_variations.get(theme_type, "")
				if base_type != "" and theme_ref.has_font_size("normal_font_size", base_type):
					has_rt_size = true
				elif theme_ref.has_font_size("normal_font_size", inst.get_class()):
					has_rt_size = true
		if not has_rt_size:
			inst.add_theme_font_size_override("normal_font_size", _owner.preview_font_size)
	elif "placeholder_text" in inst:
		inst.placeholder_text = display_name
		if not has_theme_size:
			inst.add_theme_font_size_override("font_size", _owner.preview_font_size)
	elif "text" in inst:
		inst.text = display_name
		if not has_theme_size:
			inst.add_theme_font_size_override("font_size", _owner.preview_font_size)
	elif not (inst is Tree):
		var lbl = Label.new()
		lbl.text = display_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not has_theme_size:
			lbl.add_theme_font_size_override("font_size", _owner.preview_font_size)
		inst.add_child(lbl)
		
	if inst is Tree:
		var root = inst.create_item()
		inst.hide_root = true
		var item1 = inst.create_item(root)
		item1.set_text(0, "Sample Tree Item 1")
		var item2 = inst.create_item(root)
		item2.set_text(0, "Sample Tree Item 2")

# Load StyleBox resource with full cache invalidation for both the stylebox and its underlying texture
func load_stylebox_uncached(val_path: String) -> StyleBox:
	if val_path == "" or not ResourceLoader.exists(val_path):
		return null
		
	var sb = ResourceLoader.load(val_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if sb is StyleBoxTexture:
		var tex_sb = sb as StyleBoxTexture
		if tex_sb.texture and tex_sb.texture.resource_path != "":
			var tex_path = tex_sb.texture.resource_path
			if ResourceLoader.exists(tex_path):
				var fresh_tex = ResourceLoader.load(tex_path, "", ResourceLoader.CACHE_MODE_REPLACE)
				if fresh_tex:
					tex_sb.texture = fresh_tex
	return sb

# Resolve the SVG key from a stylebox record for metadata dimension lookup
func _resolve_svg_key(record, val_path: String) -> String:
	var svg_key = ""
	if val_path is String and val_path != "" and ResourceLoader.exists(val_path):
		var sb = load_stylebox_uncached(val_path)
		if sb is StyleBoxTexture and sb.texture:
			svg_key = sb.texture.resource_path.get_file()
	
	if svg_key == "":
		var record_id = _owner.get_part_id(record)
		record_id = _owner.get_base_prop_name(record_id)
		if record_id != "":
			svg_key = record_id + ".svg"
	
	if svg_key == "" and val_path is String and val_path != "":
		var filename = val_path.get_file().get_basename().replace("_stylebox", "")
		filename = _owner.get_base_prop_name(filename)
		svg_key = filename + ".svg"
	
	return svg_key

# Look up design dimensions from metadata using an SVG key with fuzzy suffix stripping and word matching
func _lookup_metadata_dimensions(svg_key: String, metadata: Dictionary) -> Vector2:
	if svg_key == "":
		return Vector2.ZERO
	
	# 1. Exact match
	if metadata.has(svg_key):
		var meta_entry = metadata[svg_key]
		return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))
		
	var lower_key = svg_key.to_lower().replace(".svg", "")
	
	# 2. Case-insensitive exact stem match
	for m_key in metadata.keys():
		var m_lower = m_key.to_lower().replace(".svg", "")
		if m_lower == lower_key:
			var meta_entry = metadata[m_key]
			return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))
			
	# 3. Fuzzy match by stripping state/variation suffixes from svg_key
	# e.g., "Gender_Toggle_-_Female_Regular.svg" -> "Gender_Toggle_-_Female.svg"
	var base_stem = lower_key
	var suffixes = ["_regular", "_hover", "_pressed", "_disabled", "_normal", "_focus", "_read_only", "_stylebox", "_copy"]
	for s in suffixes:
		if base_stem.ends_with(s):
			base_stem = base_stem.substr(0, base_stem.length() - s.length())
			break
			
	var candidate_key = base_stem + ".svg"
	if metadata.has(candidate_key):
		var meta_entry = metadata[candidate_key]
		return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))
		
	for m_key in metadata.keys():
		var m_lower = m_key.to_lower().replace(".svg", "")
		if m_lower == candidate_key.to_lower().replace(".svg", "") or m_lower == base_stem:
			var meta_entry = metadata[m_key]
			return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))

	# 4. Word-component match (e.g. "pressed_button" -> "Button_-_Pressed.svg", "color_selection_button_hover" -> "Color_Selection_-_Hover.svg")
	var clean_words = lower_key.replace("-", "_").replace(" ", "_").split("_", false)
	if clean_words.size() > 0:
		for m_key in metadata.keys():
			var m_lower = m_key.to_lower().replace("-", "_").replace(" ", "_").replace(".svg", "")
			var all_match = true
			for w in clean_words:
				if not w in ["stylebox", "tres", "copy", "button", "panel"] and not w in m_lower:
					all_match = false
					break
			if all_match:
				var meta_entry = metadata[m_key]
				return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))
			
	return Vector2.ZERO

# Resolve design dimensions with primary ground truth from StyleBoxTexture inner body size, followed by metadata.json, then minimum size
func resolve_design_dimensions(active_stylebox: StyleBox, record, val_path: String, metadata: Dictionary) -> Vector2:
	# 1. Primary Ground Truth for textures: The actual SVG Texture2D size minus expand margins is the exact inner component body size!
	if active_stylebox is StyleBoxTexture and active_stylebox.texture:
		var tex_sb = active_stylebox as StyleBoxTexture
		var tex_size = tex_sb.texture.get_size()
		if tex_size.x >= 20.0 and tex_size.y >= 20.0:
			var body_w = tex_size.x - (tex_sb.expand_margin_left + tex_sb.expand_margin_right)
			var body_h = tex_size.y - (tex_sb.expand_margin_top + tex_sb.expand_margin_bottom)
			if body_w >= 20.0 and body_h >= 20.0:
				return Vector2(body_w, body_h)
			return tex_size

	# 2. Secondary Lookup: Look up metadata.json for procedural shapes / StyleBoxFlat
	var svg_key = _resolve_svg_key(record, val_path)
	var dims = _lookup_metadata_dimensions(svg_key, metadata)
	if dims.x >= 20.0 and dims.y >= 20.0:
		return dims
			
	# 3. Fallback: Stylebox minimum size if >= 20x20
	if active_stylebox != null:
		var min_size = active_stylebox.get_minimum_size()
		if min_size.x >= 20.0 and min_size.y >= 20.0:
			return min_size
			
	return Vector2.ZERO

# Apply preview sizing to node, maintaining aspect ratio
func apply_node_preview_sizing(inst: Control, active_stylebox: StyleBox, design_width: float, design_height: float, item_width: int) -> void:
	var final_width = design_width
	var final_height = design_height

	if item_width > 0:
		var calc_height = 40.0
		if final_height > 0.0:
			if final_width > 0.0:
				calc_height = final_height * (float(item_width) / final_width)
			else:
				calc_height = final_height
		inst.custom_minimum_size = Vector2(item_width, calc_height)
		inst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if "clip_text" in inst:
			inst.clip_text = true
	else:
		if final_width > 0.0 and final_height > 0.0:
			inst.custom_minimum_size = Vector2(final_width, final_height)
			inst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if "clip_text" in inst:
				inst.clip_text = true
		else:
			inst.custom_minimum_size = Vector2(0, 40.0)
			inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER

# Find common design size from any state's stylebox metadata or texture size
func _find_common_design_size(ctrl_type: String, states: Array[String], metadata: Dictionary) -> Vector2:
	for s in states:
		if _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has("styleboxes"):
			var sboxes = _owner.theme_parts[ctrl_type]["styleboxes"]
			var rec = null
			for key in sboxes.keys():
				if _owner.get_base_prop_name(key) == s:
					rec = sboxes[key]
					break
			
			if rec != null:
				var val_path = _owner.get_part_value(rec)
				var sb = load_stylebox_uncached(str(val_path))
				var dims = resolve_design_dimensions(sb, rec, str(val_path), metadata)
				if dims.x >= 20.0 and dims.y >= 20.0:
					return dims
	return Vector2.ZERO

# Build Native Theme Object & Preview it
func apply_preview() -> void:
	var temp_theme = _owner._builder.build_theme()
	_owner.preview_area.theme = temp_theme
 
	# Load metadata to retrieve component design width/height
	var metadata = _load_metadata()

	# Update the preview nodes dynamically
	if _owner.preview_grid:
		# Clear existing children
		for child in _owner.preview_grid.get_children():
			child.queue_free()
 
		if _owner.theme_parts.is_empty():
			_owner.preview_grid.columns = 1
			_owner.preview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var placeholder = Label.new()
			placeholder.text = "No theme parts configured yet. Add them in the Parts Builder to preview."
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			placeholder.add_theme_font_size_override("font_size", _owner.preview_font_size)
			_owner.preview_grid.add_child(placeholder)
		else:
			# Use columns = 1 to stack our sections vertically inside the main GridContainer
			_owner.preview_grid.columns = 1
			_owner.preview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Group control types by their Base Engine Class (e.g. Button + Button variations, HSlider + HSlider variations)
			var base_groups = {}
			var group_order = []
			
			for ctrl_type in _owner.theme_parts.keys():
				if ctrl_type == "PanelContainer":
					continue
					
				var base_class = ctrl_type
				if _owner.theme_variations.has(ctrl_type) and _owner.theme_variations[ctrl_type] != "":
					base_class = _owner.theme_variations[ctrl_type]
					
				if not base_groups.has(base_class):
					base_groups[base_class] = []
					group_order.append(base_class)
					
				base_groups[base_class].append(ctrl_type)
				
			group_order.sort()
			
			# Sort members inside each group: base class first, variations alphabetically
			for base_class in base_groups.keys():
				var members: Array = base_groups[base_class]
				members.sort_custom(func(a, b):
					if a == base_class:
						return true
					if b == base_class:
						return false
					return a < b
				)
				
			# Render sections grouped by base engine class family
			for base_class in group_order:
				var family_members: Array = base_groups[base_class]
				
				# Create a parent family group box
				var family_box = VBoxContainer.new()
				family_box.name = base_class + "_Family_Group"
				family_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				family_box.add_theme_constant_override("separation", 15)
				
				# Create family group header
				var family_header = VBoxContainer.new()
				family_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				var family_lbl = Label.new()
				var var_count = family_members.size() - (1 if family_members.has(base_class) else 0)
				var family_title = base_class.to_upper() + " CONTROLS"
				if var_count > 0:
					family_title += " (" + str(var_count) + " Variation" + ("s" if var_count > 1 else "") + ")"
				family_lbl.text = family_title
				family_lbl.add_theme_font_size_override("font_size", _owner.preview_font_size + 6)
				family_lbl.add_theme_color_override("font_color", Color(0.26, 0.95, 1.0, 1.0)) # Neon Cyan
				
				var family_sep = HSeparator.new()
				family_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				family_header.add_child(family_lbl)
				family_header.add_child(family_sep)
				family_box.add_child(family_header)
				
				# Render each member in this family group
				for ctrl_type in family_members:
					var section_box = VBoxContainer.new()
					section_box.name = ctrl_type + "_Section"
					section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					section_box.add_theme_constant_override("separation", 8)
					
					var header_box = VBoxContainer.new()
					header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					
					var header_lbl = Label.new()
					var type_display = ctrl_type
					if _owner.theme_variations.has(ctrl_type) and _owner.theme_variations[ctrl_type] != "":
						type_display += "  [Variation of " + _owner.theme_variations[ctrl_type] + "]"
					else:
						type_display += "  [Base Class]"
					header_lbl.text = type_display
					header_lbl.add_theme_font_size_override("font_size", _owner.preview_font_size + 2)
					header_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
					
					header_box.add_child(header_lbl)
					section_box.add_child(header_box)
					
					# Create the sub-grid for states
					var sub_grid = GridContainer.new()
					sub_grid.columns = _owner.preview_columns
					sub_grid.add_theme_constant_override("h_separation", 15)
					sub_grid.add_theme_constant_override("v_separation", 15)
					
					if _owner.preview_item_width > 0:
						sub_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					else:
						sub_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						
					section_box.add_child(sub_grid)
					family_box.add_child(section_box)
					
					var states = get_configured_states(ctrl_type)
					var common_size = _find_common_design_size(ctrl_type, states, metadata)
					
					for state in states:
						var inst: Control = null
						var display_name = ctrl_type
						
						# Check if this is a custom variation
						if _owner.theme_variations.has(ctrl_type) and _owner.theme_variations[ctrl_type] != "":
							var base_type = _owner.theme_variations[ctrl_type]
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
							if _owner.preview_texts.has(text_key):
								item_text = _owner.preview_texts[text_key]
								
							# Fetch design size from Figma metadata or StyleBox texture/minimum size
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
										var sb = load_stylebox_uncached(val_path)
										if sb is StyleBox:
											active_stylebox = sb
											
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
									var base_type = _owner.theme_variations.get(theme_type, "")
									if base_type != "" and temp_theme.has_stylebox(stylebox_prop_name, base_type):
										active_stylebox = temp_theme.get_stylebox(stylebox_prop_name, base_type)
									else:
										# Fallback to the class name itself (e.g. Button)
										var cls_name = inst.get_class()
										if temp_theme.has_stylebox(stylebox_prop_name, cls_name):
											active_stylebox = temp_theme.get_stylebox(stylebox_prop_name, cls_name)

							# Resolve design size using metadata + active_stylebox texture fallback
							if record != null:
								var dims = resolve_design_dimensions(active_stylebox, record, val_path, metadata)
								design_width = dims.x
								design_height = dims.y
							elif active_stylebox != null:
								if active_stylebox is StyleBoxTexture and active_stylebox.texture:
									var tex_sz = active_stylebox.texture.get_size()
									design_width = tex_sz.x
									design_height = tex_sz.y
							
							if inst is Button and common_size.x >= 20.0 and common_size.y >= 20.0:
								design_width = common_size.x
								design_height = common_size.y
							elif design_width < 20.0 and common_size.x >= 20.0:
								design_width = common_size.x
								design_height = common_size.y

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
									
								var theme_type2 = inst.theme_type_variation if inst.theme_type_variation != "" else inst.get_class()
								if temp_theme.has_color(active_color_name, theme_type2):
									var color_val = temp_theme.get_color(active_color_name, theme_type2)
									for c_name in color_names:
										inst.add_theme_color_override(c_name, color_val)
							
							# Apply sizing and shrink centering appropriately with aspect ratio preservation and shadow margin compensation
							apply_node_preview_sizing(inst, active_stylebox, design_width, design_height, _owner.preview_item_width)
							
							# Store metadata for editing and persistence
							inst.set_meta("ctrl_type", ctrl_type)
							inst.set_meta("state", state)
							
							inst.gui_input.connect(on_preview_item_gui_input.bind(inst))
							sub_grid.add_child(inst)

				# Add family box to main preview grid
				_owner.preview_grid.add_child(family_box)
				
				# Add padding spacing margin at the bottom of the family group section
				var family_spacer = Control.new()
				family_spacer.custom_minimum_size = Vector2(0, 20)
				_owner.preview_grid.add_child(family_spacer)

func on_preview_item_gui_input(event: InputEvent, inst: Control) -> void:
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
							if _owner.preview_texts.has(t_key):
								_owner.preview_texts.erase(t_key)
							
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
							_owner.preview_texts[t_key] = new_text
							
						_owner._config.save_config()
						
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

func _load_metadata() -> Dictionary:
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
	return metadata
