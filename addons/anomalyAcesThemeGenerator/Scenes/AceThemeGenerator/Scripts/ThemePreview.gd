@tool
extends RefCounted
## Live preview panel rendering — instantiates control nodes, applies states, sizes from metadata.

var _owner  # Reference to AceThemeGenerator
var _pass_sb_cache: Dictionary = {}
var _cached_metadata: Dictionary = {}
var _cached_metadata_mtime: int = 0

func _init(owner) -> void:
	_owner = owner

func get_configured_states(ctrl_type: String) -> Array[String]:
	var states: Array[String] = []
	if not _owner.theme_parts.has(ctrl_type):
		return ["normal"]
		
	var section = _owner.theme_parts[ctrl_type]
	var has_normal_configs = false
	
	var is_btn = ctrl_type == "Button" or _owner.theme_variations.get(ctrl_type, "") == "Button"
	var is_tab = ctrl_type == "TabBar" or _owner.theme_variations.get(ctrl_type, "") == "TabBar" or ctrl_type == "TabContainer" or _owner.theme_variations.get(ctrl_type, "") == "TabContainer"

	# TabBar and TabContainer inherently display all states simultaneously within a single instance across its tabs
	if is_tab:
		return ["normal"]

	# If control defines styleboxes, multi-state preview cards (pressed, disabled, etc.)
	# are strictly determined by the styleboxes configured for this control.
	if section.has("styleboxes") and not section["styleboxes"].is_empty():
		var sboxes = section["styleboxes"]
		for sb_name in sboxes.keys():
			var base_name = _owner.get_base_prop_name(sb_name).to_lower()
			if "disabled" in base_name:
				if not states.has("disabled"): states.append("disabled")
			elif "pressed" in base_name or (("selected" in base_name) and not ("unselected" in base_name)):
				if not states.has("pressed"): states.append("pressed")
			elif "read_only" in base_name:
				if not states.has("read_only"): states.append("read_only")
			elif "focus" in base_name:
				if not states.has("focus"): states.append("focus")
			elif "hover" in base_name and not is_btn:
				if not states.has("hover"): states.append("hover")
			else:
				has_normal_configs = true
	else:
		for sec_name in section.keys():
			var overrides = section[sec_name]
			for prop_name in overrides.keys():
				var base_name = _owner.get_base_prop_name(prop_name).to_lower()
				# Icon tint colors should not trigger state previews
				if base_name.begins_with("icon_"):
					continue
				if "disabled" in base_name:
					if not states.has("disabled"): states.append("disabled")
				elif "pressed" in base_name or (("selected" in base_name) and not ("unselected" in base_name)):
					if not states.has("pressed"): states.append("pressed")
				elif "read_only" in base_name:
					if not states.has("read_only"): states.append("read_only")
				elif "focus" in base_name:
					if not states.has("focus"): states.append("focus")
				elif "hover" in base_name and not is_btn:
					if not states.has("hover"): states.append("hover")
				else:
					has_normal_configs = true
				
	# Button hover does not need its own preview card — it is previewed by hovering over the normal state
	if is_btn:
		states.erase("hover")

	if has_normal_configs or states.is_empty():
		if not states.has("normal"):
			states.insert(0, "normal")
			
	var state_order = ["normal", "pressed", "disabled", "focus", "read_only"]
	states.sort_custom(func(a, b):
		var ia = state_order.find(a)
		var ib = state_order.find(b)
		if ia == -1: ia = 99
		if ib == -1: ib = 99
		return ia < ib
	)
		
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

func _get_tab_stylebox(sb_prop: String, theme_type: String, inst: Control, theme_ref: Theme) -> StyleBox:
	if theme_ref != null:
		if theme_ref.has_stylebox(sb_prop, theme_type):
			return theme_ref.get_stylebox(sb_prop, theme_type)
		elif theme_ref.has_stylebox(sb_prop, inst.get_class()):
			return theme_ref.get_stylebox(sb_prop, inst.get_class())
	if _owner.theme_parts.has(theme_type) and _owner.theme_parts[theme_type].has("styleboxes"):
		var sboxes = _owner.theme_parts[theme_type]["styleboxes"]
		if sboxes.has(sb_prop):
			var v_p = _owner.get_part_value(sboxes[sb_prop])
			return load_stylebox_uncached(str(v_p))
	return null

func setup_preview_node(inst: Control, display_name: String, theme_ref: Theme = null, design_size: Vector2 = Vector2.ZERO) -> void:
	if inst is Panel or inst is PanelContainer or inst is ColorRect or inst is TextureRect or inst is Container or inst is Tree or inst is TabBar:
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
	elif inst is TabBar:
		inst.clip_tabs = false
		
		var tab_design_w = design_size.x
		var tab_design_h = design_size.y
		if tab_design_w < 20.0 and _owner.preview_item_width > 0:
			tab_design_w = float(_owner.preview_item_width)
		elif tab_design_w < 20.0:
			tab_design_w = 200.0
			
		if tab_design_h < 20.0:
			tab_design_h = 40.0
			
		inst.custom_minimum_size = Vector2(0, tab_design_h)
		
		# Inspect tab styleboxes to determine maximum expand margins and configured states
		var max_expand_x = 0.0
		var max_expand_y = 0.0
		var has_disabled_style = false
		
		var tab_sb_names = ["tab_selected", "tab_hovered", "tab_unselected", "tab_disabled"]
		for sb_prop in tab_sb_names:
			var sb: StyleBox = _get_tab_stylebox(sb_prop, theme_type, inst, theme_ref)
			if sb is StyleBox:
				if sb_prop == "tab_disabled":
					has_disabled_style = true
				max_expand_x = max(max_expand_x, sb.expand_margin_left, sb.expand_margin_right)
				max_expand_y = max(max_expand_y, sb.expand_margin_top, sb.expand_margin_bottom)
				if sb is StyleBoxFlat and sb.shadow_size > 0:
					max_expand_x = max(max_expand_x, float(sb.shadow_size))
					max_expand_y = max(max_expand_y, float(sb.shadow_size))
		
		# 1. User-configured constants: user values take priority so users have complete freedom
		var user_h_sep = -1
		if _owner.theme_parts.has(theme_type) and _owner.theme_parts[theme_type].has("constants"):
			var consts = _owner.theme_parts[theme_type]["constants"]
			if consts.has("h_separation"):
				user_h_sep = int(_owner.get_part_value(consts["h_separation"]))
		if user_h_sep == -1 and theme_ref != null:
			if theme_ref.has_constant("h_separation", theme_type):
				user_h_sep = theme_ref.get_constant("h_separation", theme_type)
			elif theme_ref.has_constant("h_separation", inst.get_class()):
				user_h_sep = theme_ref.get_constant("h_separation", inst.get_class())
		
		var safe_h_sep = 16
		if max_expand_x > 0.0:
			safe_h_sep = int(ceil(max_expand_x * 2.0 + 16.0))
		var final_h_sep = user_h_sep if user_h_sep >= 0 else safe_h_sep
		inst.add_theme_constant_override("h_separation", final_h_sep)
		
		var user_side_margin = -1
		if _owner.theme_parts.has(theme_type) and _owner.theme_parts[theme_type].has("constants"):
			var consts = _owner.theme_parts[theme_type]["constants"]
			if consts.has("side_margin"):
				user_side_margin = int(_owner.get_part_value(consts["side_margin"]))
		if user_side_margin == -1 and theme_ref != null:
			if theme_ref.has_constant("side_margin", theme_type):
				user_side_margin = theme_ref.get_constant("side_margin", theme_type)
			elif theme_ref.has_constant("side_margin", inst.get_class()):
				user_side_margin = theme_ref.get_constant("side_margin", inst.get_class())
				
		var safe_side_margin = 16
		if max_expand_x > 0.0:
			safe_side_margin = int(ceil(max_expand_x + 16.0))
		var final_side_margin = user_side_margin if user_side_margin >= 0 else safe_side_margin
		inst.add_theme_constant_override("side_margin", final_side_margin)
		
		# 2. Add tabs representing states
		var t0 = "Tab 1 (Unselected)"
		var t1 = "Tab 2 (Selected)"
		inst.add_tab(t0)
		inst.add_tab(t1)
		if has_disabled_style:
			inst.add_tab("Tab 3 (Disabled)")
			inst.set_tab_disabled(2, true)
			
		inst.current_tab = 1 # Tab 1 is Selected; Tab 0 is Unselected!
		
		# 3. Dynamic Interactive Title Updating on click
		inst.tab_changed.connect(func(new_idx):
			for i in range(inst.get_tab_count()):
				if inst.is_tab_disabled(i):
					continue
				var base_tab_title = "Tab " + str(i + 1)
				if i == new_idx:
					inst.set_tab_title(i, base_tab_title + " (Selected)")
				else:
					inst.set_tab_title(i, base_tab_title + " (Unselected)")
		)
		
		# 4. Equalize Tab Sizes: ensure unselected, selected, and hover states have identical sizes
		var font: Font = null
		if theme_ref != null and theme_ref.has_font("font", theme_type):
			font = theme_ref.get_font("font", theme_type)
		elif theme_ref != null and theme_ref.has_font("font", inst.get_class()):
			font = theme_ref.get_font("font", inst.get_class())
		else:
			font = ThemeDB.get_default_theme().get_font("font", "TabBar")
			
		var fsize = _owner.preview_font_size
		if theme_ref != null:
			if theme_ref.has_font_size("font_size", theme_type):
				fsize = theme_ref.get_font_size("font_size", theme_type)
			elif theme_ref.has_font_size("font_size", inst.get_class()):
				fsize = theme_ref.get_font_size("font_size", inst.get_class())
				
		var target_tab_w = tab_design_w
		if _owner.preview_item_width > 0:
			target_tab_w = float(_owner.preview_item_width)
			
		var w0 = font.get_string_size(t0, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x if font else 100.0
		var w1 = font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x if font else 100.0
		var max_tw = max(w0, w1)
		if target_tab_w < max_tw + 20.0:
			target_tab_w = max_tw + 20.0
			
		# Create duplicated stylebox overrides with balanced content margins so total tab width is identical
		var sb_unselected = _get_tab_stylebox("tab_unselected", theme_type, inst, theme_ref)
		if sb_unselected is StyleBox:
			var sb_u_dup = sb_unselected.duplicate()
			var pad0 = max(6.0, (target_tab_w - w0) / 2.0)
			sb_u_dup.content_margin_left = pad0
			sb_u_dup.content_margin_right = pad0
			inst.add_theme_stylebox_override("tab_unselected", sb_u_dup)
			
		var sb_selected = _get_tab_stylebox("tab_selected", theme_type, inst, theme_ref)
		if sb_selected is StyleBox:
			var sb_s_dup = sb_selected.duplicate()
			var pad1 = max(6.0, (target_tab_w - w1) / 2.0)
			sb_s_dup.content_margin_left = pad1
			sb_s_dup.content_margin_right = pad1
			inst.add_theme_stylebox_override("tab_selected", sb_s_dup)
			
		var sb_hovered = _get_tab_stylebox("tab_hovered", theme_type, inst, theme_ref)
		if sb_hovered is StyleBox:
			var sb_h_dup = sb_hovered.duplicate()
			var pad0 = max(6.0, (target_tab_w - w0) / 2.0)
			sb_h_dup.content_margin_left = pad0
			sb_h_dup.content_margin_right = pad0
			inst.add_theme_stylebox_override("tab_hovered", sb_h_dup)
			
		if has_disabled_style:
			var sb_disabled = _get_tab_stylebox("tab_disabled", theme_type, inst, theme_ref)
			if sb_disabled is StyleBox:
				var sb_d_dup = sb_disabled.duplicate()
				var w2 = font.get_string_size("Tab 3 (Disabled)", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x if font else 100.0
				var pad2 = max(6.0, (target_tab_w - w2) / 2.0)
				sb_d_dup.content_margin_left = pad2
				sb_d_dup.content_margin_right = pad2
				inst.add_theme_stylebox_override("tab_disabled", sb_d_dup)
				
		if not has_theme_size:
			inst.add_theme_font_size_override("font_size", _owner.preview_font_size)
		if theme_ref != null:
			var tab_icon = null
			if theme_ref.has_icon("icon", theme_type):
				tab_icon = theme_ref.get_icon("icon", theme_type)
			elif theme_ref.has_icon("icon", inst.get_class()):
				tab_icon = theme_ref.get_icon("icon", inst.get_class())
			if tab_icon != null and inst.get_tab_count() > 0:
				inst.set_tab_icon(0, tab_icon)
				inst.set_tab_icon(1, tab_icon)
	elif inst is TabContainer:
		var c1 = Control.new()
		c1.name = display_name
		inst.add_child(c1)
		var c2 = Control.new()
		c2.name = "Tab 2"
		inst.add_child(c2)
		if inst.has_method("get_tab_bar"):
			var internal_bar = inst.get_tab_bar()
			if internal_bar is TabBar:
				internal_bar.clip_tabs = false
	elif "text" in inst:
		inst.text = display_name
		if not has_theme_size:
			inst.add_theme_font_size_override("font_size", _owner.preview_font_size)
		if inst is Button and theme_ref != null:
			var btn_icon = null
			if theme_ref.has_icon("icon", theme_type):
				btn_icon = theme_ref.get_icon("icon", theme_type)
			elif theme_ref.has_icon("icon", inst.get_class()):
				btn_icon = theme_ref.get_icon("icon", inst.get_class())
			if btn_icon != null:
				inst.icon = btn_icon
				inst.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				inst.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
				inst.text = ""
				# Ensure Godot's editor theme does not tint button icon colors
				for ic_name in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color"]:
					var c_val = Color.WHITE
					if theme_ref.has_color(ic_name, theme_type):
						c_val = theme_ref.get_color(ic_name, theme_type)
					elif theme_ref.has_color(ic_name, inst.get_class()):
						c_val = theme_ref.get_color(ic_name, inst.get_class())
					inst.add_theme_color_override(ic_name, c_val)
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
	if _pass_sb_cache.has(val_path):
		return _pass_sb_cache[val_path]
		
	var sb = ResourceLoader.load(val_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if sb is StyleBoxTexture:
		var tex_sb = sb as StyleBoxTexture
		if tex_sb.texture and tex_sb.texture.resource_path != "":
			var tex_path = tex_sb.texture.resource_path
			if ResourceLoader.exists(tex_path):
				var fresh_tex = ResourceLoader.load(tex_path, "", ResourceLoader.CACHE_MODE_REPLACE)
				if fresh_tex:
					tex_sb.texture = fresh_tex
	_pass_sb_cache[val_path] = sb
	return sb

func _are_styleboxes_identical(path_a: String, path_b: String) -> bool:
	if path_a == "" or path_b == "":
		return false
	if path_a == path_b:
		return true
	var sb_a = load_stylebox_uncached(path_a)
	var sb_b = load_stylebox_uncached(path_b)
	if sb_a == null or sb_b == null:
		return false
	if sb_a is StyleBoxTexture and sb_b is StyleBoxTexture:
		var tex_a = (sb_a as StyleBoxTexture).texture
		var tex_b = (sb_b as StyleBoxTexture).texture
		if tex_a != null and tex_b != null:
			return tex_a.resource_path == tex_b.resource_path
	elif sb_a is StyleBoxFlat and sb_b is StyleBoxFlat:
		var f_a = sb_a as StyleBoxFlat
		var f_b = sb_b as StyleBoxFlat
		return f_a.bg_color == f_b.bg_color and f_a.border_color == f_b.border_color and f_a.shadow_color == f_b.shadow_color and f_a.shadow_size == f_b.shadow_size
	return false

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
func _lookup_metadata_dimensions(svg_key: String, metadata: Dictionary, ctrl_type: String = "") -> Vector2:
	if metadata.is_empty():
		return Vector2.ZERO

	# 1. Primary check using ctrl_type (e.g. "Button", "IncreaseButton", "SubmitButtonLong", "LoginButton")
	if ctrl_type != "":
		var snake_type = ""
		for i in range(ctrl_type.length()):
			var ch = ctrl_type[i]
			if i > 0 and ch >= "A" and ch <= "Z":
				snake_type += "_" + ch
			else:
				snake_type += ch
				
		var candidates = [
			ctrl_type + "_-_Regular.svg",
			ctrl_type + "_Regular.svg",
			ctrl_type + "_-_Normal.svg",
			ctrl_type + ".svg",
			snake_type + "_-_Regular.svg",
			snake_type + "_Regular.svg",
			snake_type + "_-_Normal.svg",
			snake_type + ".svg"
		]
		if ctrl_type.ends_with("Button") and ctrl_type != "Button":
			var no_btn = ctrl_type.substr(0, ctrl_type.length() - 6)
			var snake_no_btn = snake_type.substr(0, snake_type.length() - 7) if snake_type.ends_with("_Button") else no_btn
			candidates.append(no_btn + "_-_Regular.svg")
			candidates.append(no_btn + ".svg")
			candidates.append(snake_no_btn + "_-_Regular.svg")
			candidates.append(snake_no_btn + ".svg")
			
		if "back" in ctrl_type.to_lower():
			candidates.append("Left_Arrow_-_Regular.svg")
			candidates.append("Left_Arrow.svg")
		elif "forward" in ctrl_type.to_lower():
			candidates.append("Right_Arrow_-_Regular.svg")
			candidates.append("Right_Arrow.svg")

		for cand in candidates:
			if metadata.has(cand):
				var meta_entry = metadata[cand]
				return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))
			for m_key in metadata.keys():
				if m_key.to_lower() == cand.to_lower():
					var meta_entry = metadata[m_key]
					return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))

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
				if not w in ["stylebox", "tres", "copy", "panel", "button"] and not w in m_lower:
					all_match = false
					break
			if all_match:
				var meta_entry = metadata[m_key]
				return Vector2(float(meta_entry.get("width", 0.0)), float(meta_entry.get("height", 0.0)))
			
	return Vector2.ZERO

# Resolve design dimensions with primary ground truth from StyleBoxTexture inner body size, followed by metadata.json, then minimum size
func resolve_design_dimensions(active_stylebox: StyleBox, record, val_path: String, metadata: Dictionary, ctrl_type: String = "") -> Vector2:
	# 1. Primary Ground Truth: Look up metadata.json for component design size
	var svg_key = _resolve_svg_key(record, val_path)
	var dims = _lookup_metadata_dimensions(svg_key, metadata, ctrl_type)
	if dims.x >= 20.0 and dims.y >= 20.0:
		return dims

	# 2. Secondary Lookup for textures: The actual SVG Texture2D size minus expand margins
	if active_stylebox is StyleBoxTexture and active_stylebox.texture:
		var tex_sb = active_stylebox as StyleBoxTexture
		var tex_size = tex_sb.texture.get_size()
		if tex_size.x >= 20.0 and tex_size.y >= 20.0:
			var body_w = tex_size.x - (tex_sb.expand_margin_left + tex_sb.expand_margin_right)
			var body_h = tex_size.y - (tex_sb.expand_margin_top + tex_sb.expand_margin_bottom)
			if body_w >= 20.0 and body_h >= 20.0:
				return Vector2(body_w, body_h)
			return tex_size
			
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

	if inst is TabBar:
		var tab_h = max(40.0, final_height)
		inst.custom_minimum_size = Vector2(0, tab_h)
		inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return

	if inst is TabContainer:
		var tab_h = max(80.0, final_height + 40.0)
		inst.custom_minimum_size = Vector2(0, tab_h)
		inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return

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
	var dims = _lookup_metadata_dimensions("", metadata, ctrl_type)
	if dims.x >= 20.0 and dims.y >= 20.0:
		return dims

	if _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has("styleboxes"):
		var sboxes = _owner.theme_parts[ctrl_type]["styleboxes"]
		for s in states:
			var rec = null
			for key in sboxes.keys():
				if _owner.get_base_prop_name(key) == s:
					rec = sboxes[key]
					break
			
			if rec != null:
				var val_path = _owner.get_part_value(rec)
				var sb = load_stylebox_uncached(str(val_path))
				var d = resolve_design_dimensions(sb, rec, str(val_path), metadata, ctrl_type)
				if d.x >= 20.0 and d.y >= 20.0:
					return d

		# Fallback: check any stylebox in sboxes (e.g. for TabBar with tab_unselected, or Slider with slider)
		for key in sboxes.keys():
			var rec = sboxes[key]
			var val_path = _owner.get_part_value(rec)
			var sb = load_stylebox_uncached(str(val_path))
			var d = resolve_design_dimensions(sb, rec, str(val_path), metadata, ctrl_type)
			if d.x >= 20.0 and d.y >= 20.0:
				return d

	return Vector2.ZERO

# Build Native Theme Object & Preview it
func apply_preview() -> void:
	_pass_sb_cache.clear()
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
					
					var states = get_configured_states(ctrl_type)
					var common_size = _find_common_design_size(ctrl_type, states, metadata)
					
					# Create the sub-grid for states
					var sub_grid = GridContainer.new()
					sub_grid.columns = _owner.preview_columns
					var base_sep = _owner.preview_separation if ("preview_separation" in _owner and _owner.preview_separation > 0) else 40
					
					# Scale base separation proportionally for smaller elements so compact controls remain grouped
					var elem_w = common_size.x if common_size.x >= 20.0 else 200.0
					var elem_h = common_size.y if common_size.y >= 20.0 else 40.0
					var size_ratio_x = clamp(elem_w / 200.0, 0.4, 1.0)
					var size_ratio_y = clamp(elem_h / 60.0, 0.4, 1.0)
					var h_sep = max(4, int(base_sep * size_ratio_x))
					var v_sep = max(4, int(base_sep * size_ratio_y))
					
					var is_tab_ctrl = ctrl_type == "TabBar" or _owner.theme_variations.get(ctrl_type, "") == "TabBar" or ctrl_type == "TabContainer" or _owner.theme_variations.get(ctrl_type, "") == "TabContainer"
					if is_tab_ctrl:
						sub_grid.columns = 1
					
					# Detect if any state has a glow shadow or expand margins and ensure spacing prevents overlap
					# Safety padding is scaled by element size so expand margins don't dwarf smaller buttons
					var max_ctrl_expand_y = 0.0
					if _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has("styleboxes"):
						var sboxes = _owner.theme_parts[ctrl_type]["styleboxes"]
						for key in sboxes.keys():
							var rec = sboxes[key]
							var val_path = _owner.get_part_value(rec)
							var sb = load_stylebox_uncached(str(val_path))
							if sb is StyleBoxFlat and sb.shadow_size > 0:
								var needed_sep = int(base_sep + sb.shadow_size)
								if common_size.x >= 20.0:
									needed_sep = min(needed_sep, int(max(base_sep, common_size.x * 0.75)))
								if h_sep < needed_sep:
									h_sep = needed_sep
								if v_sep < needed_sep:
									v_sep = needed_sep
								max_ctrl_expand_y = max(max_ctrl_expand_y, float(sb.shadow_size))
							elif sb is StyleBox:
								var exp_x = max(sb.expand_margin_left, sb.expand_margin_right)
								var exp_y = max(sb.expand_margin_top, sb.expand_margin_bottom)
								if exp_x > 0 or exp_y > 0:
									var needed_sep_h = int(base_sep + exp_x)
									var needed_sep_v = int(base_sep + exp_y)
									if common_size.x >= 20.0:
										needed_sep_h = min(needed_sep_h, int(max(base_sep, common_size.x * 0.75)))
									if common_size.y >= 20.0:
										needed_sep_v = min(needed_sep_v, int(max(base_sep, common_size.y * 0.75)))
									if h_sep < needed_sep_h:
										h_sep = needed_sep_h
									if v_sep < needed_sep_v:
										v_sep = needed_sep_v
									max_ctrl_expand_y = max(max_ctrl_expand_y, exp_y)
									
					sub_grid.add_theme_constant_override("h_separation", h_sep)
					sub_grid.add_theme_constant_override("v_separation", v_sep)
					if max_ctrl_expand_y > 0:
						var sec_sep = int(max(8, max_ctrl_expand_y + 8))
						if common_size.y >= 20.0:
							sec_sep = min(sec_sep, int(max(8, common_size.y * 0.75)))
						section_box.add_theme_constant_override("separation", sec_sep)
					
					if not is_tab_ctrl and _owner.preview_item_width > 0:
						sub_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					else:
						sub_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						
					section_box.add_child(sub_grid)
					family_box.add_child(section_box)
					
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
							elif state == "hover":
								display_name += " (Hover)"
							elif state == "read_only":
								if "editable" in inst:
									inst.editable = false
								elif "read_only" in inst:
									inst.read_only = true
								display_name += " (Read Only)"
							elif state == "focus":
								display_name += " (Focus)"
								
							if inst is TabBar and state == "disabled":
								for t_idx in range(inst.get_tab_count()):
									inst.set_tab_disabled(t_idx, true)
								
							var text_key = ctrl_type + "_" + state
							var item_text = display_name
							if _owner.preview_texts.has(text_key):
								item_text = _owner.preview_texts[text_key]
							elif state == "hover":
								if ctrl_type == "Button":
									item_text = "Hover"
								elif _owner.preview_texts.has(ctrl_type + "_normal") and _owner.preview_texts[ctrl_type + "_normal"] == "":
									item_text = ""
								
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
								
								if record == null:
									# Fallback matching for controls with non-standard stylebox names (e.g. TabBar, Slider, Panel)
									for key in sboxes.keys():
										var base_prop = _owner.get_base_prop_name(key).to_lower()
										if state == "disabled" and "disabled" in base_prop:
											record = sboxes[key]
											break
										elif state == "pressed" and ("pressed" in base_prop or "selected" in base_prop):
											record = sboxes[key]
											break
										elif state == "hover" and "hover" in base_prop:
											record = sboxes[key]
											break
										elif state == "focus" and "focus" in base_prop:
											record = sboxes[key]
											break
										elif state == "normal" and not ("disabled" in base_prop or "pressed" in base_prop or "hover" in base_prop):
											record = sboxes[key]
											break

								if record != null:
									val_path = str(_owner.get_part_value(record))
									if val_path != "" and ResourceLoader.exists(val_path):
										var sb = load_stylebox_uncached(val_path)
										if sb is StyleBox:
											active_stylebox = sb
											
							setup_preview_node(inst, item_text, temp_theme, common_size)
							
							# If stylebox wasn't directly loaded, look it up in the compiled theme
							if active_stylebox == null:
								var theme_type = inst.theme_type_variation if inst.theme_type_variation != "" else inst.get_class()
								var stylebox_prop_name = state
								if state == "read_only":
									stylebox_prop_name = "read_only"
									
								if temp_theme.has_stylebox(stylebox_prop_name, theme_type):
									active_stylebox = temp_theme.get_stylebox(stylebox_prop_name, theme_type)
								elif inst is TabBar:
									if state == "normal" and temp_theme.has_stylebox("tab_unselected", theme_type):
										active_stylebox = temp_theme.get_stylebox("tab_unselected", theme_type)
									elif (state == "pressed" or state == "normal") and temp_theme.has_stylebox("tab_selected", theme_type):
										active_stylebox = temp_theme.get_stylebox("tab_selected", theme_type)
									elif state == "hover" and temp_theme.has_stylebox("tab_hovered", theme_type):
										active_stylebox = temp_theme.get_stylebox("tab_hovered", theme_type)
									elif state == "disabled" and temp_theme.has_stylebox("tab_disabled", theme_type):
										active_stylebox = temp_theme.get_stylebox("tab_disabled", theme_type)
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
								var dims = resolve_design_dimensions(active_stylebox, record, val_path, metadata, ctrl_type)
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

								# Also freeze icon colors so pressed/hover/disabled state retains its intended icon color
								var icon_color_names = ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]
								var active_icon_color_name = "icon_normal_color"
								if state == "disabled":
									active_icon_color_name = "icon_disabled_color"
								elif state == "pressed":
									active_icon_color_name = "icon_pressed_color"
								elif state == "hover":
									active_icon_color_name = "icon_hover_color"
								
								var icon_color_val = Color.WHITE
								if temp_theme.has_color(active_icon_color_name, theme_type2):
									icon_color_val = temp_theme.get_color(active_icon_color_name, theme_type2)
								elif temp_theme.has_color("icon_normal_color", theme_type2):
									icon_color_val = temp_theme.get_color("icon_normal_color", theme_type2)
								elif temp_theme.has_color(active_icon_color_name, inst.get_class()):
									icon_color_val = temp_theme.get_color(active_icon_color_name, inst.get_class())
								
								for ic_name in icon_color_names:
									inst.add_theme_color_override(ic_name, icon_color_val)
							
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
							elif s_name == "hover":
								default_text += " (Hover)"
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
	if not FileAccess.file_exists(_owner.metadata_file):
		return {}
	var mtime = FileAccess.get_modified_time(_owner.metadata_file)
	if not _cached_metadata.is_empty() and _cached_metadata_mtime == mtime:
		return _cached_metadata
	var file = FileAccess.open(_owner.metadata_file, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err == OK:
			var data = json.get_data()
			if data is Dictionary:
				_cached_metadata = data
				_cached_metadata_mtime = mtime
				return _cached_metadata
	return _cached_metadata
