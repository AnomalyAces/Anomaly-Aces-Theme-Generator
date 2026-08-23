@tool
extends RefCounted
## CRUD operations on the theme_parts dictionary, property key management,
## and Parts Builder UI interactions.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

func cleanup_unique_properties() -> void:
	for ctrl_type in _owner.theme_parts.keys():
		var sections = _owner.theme_parts[ctrl_type]
		for sec_name in sections.keys():
			var overrides = sections[sec_name]
			
			# Group keys by their base property name
			var groups = {}
			for prop_name in overrides.keys():
				var base_name = _owner.get_base_prop_name(prop_name)
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
						if k == _owner._active_prop_key and k.contains("_copy"):
							has_active_copy = true
							break
					
					if has_active_copy:
						# Keep both the base key and the active copy, erase any other inactive copies.
						for k in keys:
							if k != base_name and k != _owner._active_prop_key:
								overrides.erase(k)
						# Skip renaming of keep_key since we want to keep it as _copy for now
						continue
					else:
						# No active copy being edited, deduplicate: keep base name or first key
						keep_key = base_name if keys.has(base_name) else keys[0]
						for k in keys:
							if k != keep_key:
								overrides.erase(k)
								if _owner._active_prop_key == k:
									_owner._active_prop_key = keep_key
								if _owner._target_select_meta is Dictionary and _owner._target_select_meta.get("prop_name") == k:
									_owner._target_select_meta["prop_name"] = keep_key
				else:
					keep_key = keys[0]
				
				# If the remaining key is a copy, rename it to the base name
				if keep_key != base_name:
					var record = overrides[keep_key]
					overrides.erase(keep_key)
					overrides[base_name] = record
					
					if _owner._active_prop_key == keep_key:
						_owner._active_prop_key = base_name
					if _owner._target_select_meta is Dictionary and _owner._target_select_meta.get("prop_name") == keep_key:
						_owner._target_select_meta["prop_name"] = base_name

func update_property_types() -> void:
	var previous_type_text = ""
	if _owner.prop_type_option.selected != -1:
		previous_type_text = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected)

	_owner.prop_type_option.clear()
	_owner.prop_name_option.clear()
	
	var selected_type = _owner.control_type_edit.text.strip_edges()
	if selected_type == "":
		return
		
	# Resolve base class if it's a custom variation
	var base_class = selected_type
	if _owner.theme_variations.has(base_class):
		base_class = _owner.theme_variations[base_class]
		
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
		_owner.prop_type_option.add_item("Color")
	if has_constants:
		_owner.prop_type_option.add_item("Constant")
	if has_fonts:
		_owner.prop_type_option.add_item("Font")
	if has_font_sizes:
		_owner.prop_type_option.add_item("Font Size")
	if has_icons:
		_owner.prop_type_option.add_item("Icon")
	if has_styleboxes:
		_owner.prop_type_option.add_item("StyleBox")
		
	var reselected = false
	if previous_type_text != "":
		for i in range(_owner.prop_type_option.item_count):
			if _owner.prop_type_option.get_item_text(i) == previous_type_text:
				_owner.prop_type_option.selected = i
				reselected = true
				break
				
	if not reselected and _owner.prop_type_option.item_count > 0:
		_owner.prop_type_option.selected = 0
		
	if _owner.prop_type_option.selected != -1:
		update_property_names()

func update_property_names() -> void:
	var previous_name_text = ""
	if _owner.prop_name_option.selected != -1:
		previous_name_text = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)

	_owner.prop_name_option.clear()
	
	var selected_type = _owner.control_type_edit.text.strip_edges()
	if selected_type == "" or _owner.prop_type_option.selected == -1:
		update_value_input_control()
		return
		
	# Resolve base class if it's a custom variation
	var base_class = selected_type
	if _owner.theme_variations.has(base_class):
		base_class = _owner.theme_variations[base_class]
		
	if not ClassDB.class_exists(base_class):
		base_class = "Control"
		
	var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
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
		_owner.prop_name_option.add_item(n)
		
	var reselected = false
	if previous_name_text != "":
		for i in range(_owner.prop_name_option.item_count):
			if _owner.prop_name_option.get_item_text(i) == previous_name_text:
				_owner.prop_name_option.selected = i
				reselected = true
				break
				
	if not reselected:
		_owner.prop_name_option.selected = -1

	update_value_input_control()

func update_value_input_control() -> void:
	_owner._stylebox_builder.ensure_metadata_controls()
	
	# Clear previous children in the container
	for child in _owner.value_container.get_children():
		child.queue_free()
		
	if _owner.prop_type_option.selected == -1:
		# Hide metadata builder options if no property is selected
		if _owner.metadata_build_check and _owner.metadata_build_label:
			_owner.metadata_build_label.visible = false
			_owner.metadata_build_check.visible = false
			_owner.metadata_file_label.visible = false
			_owner.metadata_builder_box.visible = false
			_owner.metadata_build_check.button_pressed = false
		return
		
	var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
	
	# Attempt to load existing value
	var existing_val = null
	var current_control = _owner.control_type_edit.text.strip_edges()
	if _owner.custom_type_check and _owner.custom_type_check.button_pressed:
		var custom_name = _owner.custom_type_name_edit.text.strip_edges()
		if custom_name != "":
			current_control = custom_name
	var current_prop_name = ""
	if _owner.prop_name_option.selected != -1:
		current_prop_name = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)
		
	var prop_key = current_prop_name
	if _owner._active_prop_key != "" and _owner.get_base_prop_name(_owner._active_prop_key) == current_prop_name:
		prop_key = _owner._active_prop_key
		
	var sec = _owner.SECTION_MAP.get(prop_type, "")
	if sec != "" and current_control != "" and prop_key != "":
		if _owner.theme_parts.has(current_control) and _owner.theme_parts[current_control].has(sec) and _owner.theme_parts[current_control][sec].has(prop_key):
			existing_val = _owner.theme_parts[current_control][sec][prop_key]

	var raw_val = null
	if existing_val != null:
		var ext_id = _owner.get_part_id(existing_val)
		_owner.override_name_edit.text = ext_id
		raw_val = _owner.get_part_value(existing_val)
	else:
		# Preserve the custom override name/ID if creating a new override from scratch
		if _owner.parts_tree == null or _owner.parts_tree.get_selected() != null:
			_owner.override_name_edit.text = ""

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
			cp.color_changed.connect(on_color_picker_changed)
			_owner.value_container.add_child(cp)
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
			sb.value_changed.connect(on_spin_box_changed)
			_owner.value_container.add_child(sb)
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
				erp.resource_changed.connect(on_erp_resource_changed)
			if erp.has_signal("resource_selected"):
				erp.resource_selected.connect(on_erp_resource_selected)
			
			_owner.value_container.add_child(erp)

	# Update visibility of Build from Metadata options (opt-in, right after Custom Name in Grid)
	if _owner.metadata_build_check and _owner.metadata_build_label:
		if prop_type == "stylebox" or prop_type == "icon":
			_owner.metadata_build_label.visible = true
			_owner.metadata_build_check.visible = true
			var pressed = _owner.metadata_build_check.button_pressed
			if _owner.metadata_file_label: _owner.metadata_file_label.visible = pressed
			if _owner.metadata_builder_box: _owner.metadata_builder_box.visible = pressed
			_owner._stylebox_builder.refresh_metadata_dropdown()
			if _owner.metadata_build_btn:
				_owner.metadata_build_btn.text = "Build..."
		else:
			_owner.metadata_build_label.visible = false
			_owner.metadata_build_check.visible = false
			if _owner.metadata_file_label: _owner.metadata_file_label.visible = false
			if _owner.metadata_builder_box: _owner.metadata_builder_box.visible = false
			_owner.metadata_build_check.button_pressed = false

# Parts Builder Management
func on_new_override_pressed() -> void:
	_owner._active_prop_key = ""
	_owner._creating_new_override = true
	if _owner.metadata_build_check:
		_owner.metadata_build_check.button_pressed = false
	if _owner.parts_tree:
		_owner.parts_tree.deselect_all()
	if _owner.override_name_edit:
		_owner.override_name_edit.text = ""
	if _owner.control_type_edit:
		_owner.control_type_edit.text = ""
	if _owner.custom_type_check:
		_owner.custom_type_check.button_pressed = false
	if _owner.custom_type_name_edit:
		_owner.custom_type_name_edit.text = ""
	if _owner.prop_type_option:
		_owner.prop_type_option.selected = -1
	if _owner.prop_name_option:
		_owner.prop_name_option.selected = -1
	update_value_input_control()

func on_duplicate_override_pressed() -> void:
	if not _owner._config_loaded:
		if _owner.is_inside_tree() and Engine.is_editor_hint():
			_owner._config.load_config()
		else:
			return
			
	var item = _owner.parts_tree.get_selected()
	if not item:
		return
		
	var meta = item.get_metadata(0)
	if not (meta is Dictionary and meta.has("control_type")):
		return
		
	var ctrl_type = meta["control_type"]
	var sec_name = meta["sec_name"]
	var prop_name = meta["prop_name"]
	
	if not (_owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has(sec_name) and _owner.theme_parts[ctrl_type][sec_name].has(prop_name)):
		return
		
	var existing_record = _owner.theme_parts[ctrl_type][sec_name][prop_name]
	
	var base_prop = _owner.get_base_prop_name(prop_name)
	var new_key = base_prop + "_copy"
	var counter = 1
	while _owner.theme_parts[ctrl_type][sec_name].has(new_key):
		counter += 1
		new_key = base_prop + "_copy_" + str(counter)
		
	var current_id = _owner.get_part_id(existing_record)
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
		
	_owner.theme_parts[ctrl_type][sec_name][new_key] = new_record
	
	_owner._target_select_meta = {
		"control_type": ctrl_type,
		"sec_name": sec_name,
		"prop_name": new_key
	}
	
	_owner._active_prop_key = new_key
	_owner._config.save_config()
	refresh_parts_tree()
	_owner._preview.apply_preview()

func on_delete_override_pressed() -> void:
	if not _owner._config_loaded:
		if _owner.is_inside_tree() and Engine.is_editor_hint():
			_owner._config.load_config()
		else:
			return

	var item = _owner.parts_tree.get_selected()
	if not item:
		return

	var meta = item.get_metadata(0)
	if not (meta is Dictionary and meta.has("control_type")):
		return

	var ctrl_type = meta["control_type"]
	var sec_name = meta["sec_name"]
	var prop_name = meta["prop_name"]

	if _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has(sec_name) and _owner.theme_parts[ctrl_type][sec_name].has(prop_name):
		_owner.theme_parts[ctrl_type][sec_name].erase(prop_name)
		if _owner.theme_parts[ctrl_type][sec_name].is_empty():
			_owner.theme_parts[ctrl_type].erase(sec_name)
		if _owner.theme_parts[ctrl_type].is_empty():
			_owner.theme_parts.erase(ctrl_type)
			if _owner.theme_variations.has(ctrl_type):
				_owner.theme_variations.erase(ctrl_type)

	_owner._active_prop_key = ""
	_owner._creating_new_override = true
	if _owner.override_name_edit:
		_owner.override_name_edit.text = ""

	update_value_input_control()
	_owner._config.save_config()
	refresh_parts_tree()
	_owner._preview.apply_preview()

# Parts Builder Management
func on_add_part_pressed() -> void:
	_owner._config.ensure_config_loaded()
	var control_type: String
	var is_custom = _owner.custom_type_check.button_pressed

	var selected_base = _owner.control_type_edit.text.strip_edges()
	if selected_base == "":
		printerr("Please select a base control type!")
		push_warning("Please select a base control type!")
		_owner._dialog_utils.show_warning_dialog("Please select a base control type!")
		return

	if is_custom:
		control_type = _owner.custom_type_name_edit.text.strip_edges()
		if control_type == "":
			return
		_owner.theme_variations[control_type] = selected_base
	else:
		control_type = selected_base
		if _owner.theme_variations.has(control_type):
			_owner.theme_variations.erase(control_type)

	if _owner.prop_type_option.selected == -1 or _owner.prop_name_option.selected == -1:
		return
	var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)
	var prop_key = prop_name
	if _owner._active_prop_key != "" and _owner.get_base_prop_name(_owner._active_prop_key) == prop_name:
		prop_key = _owner._active_prop_key
	var override_id = _owner.override_name_edit.text.strip_edges()
	
	var sec = _owner.SECTION_MAP.get(prop_type, "")
	if sec == "":
		return

	var is_cleared = false
	var prop_val = ""
	if _owner.value_container.has_node("ColorPicker"):
		var cp = _owner.value_container.get_node("ColorPicker") as ColorPickerButton
		prop_val = "#" + cp.color.to_html(true)
	elif _owner.value_container.has_node("SpinBox"):
		var sb = _owner.value_container.get_node("SpinBox") as SpinBox
		prop_val = str(int(sb.value))
	elif _owner.value_container.find_child("ResourcePicker", true, false):
		var rp = _owner.value_container.find_child("ResourcePicker", true, false)
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
			_owner._dialog_utils.show_warning_dialog("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			return

	if is_cleared:
		if _owner.theme_parts.has(control_type) and _owner.theme_parts[control_type].has(sec) and _owner.theme_parts[control_type][sec].has(prop_key):
			_owner.theme_parts[control_type][sec].erase(prop_key)
			if _owner.theme_parts[control_type][sec].is_empty():
				_owner.theme_parts[control_type].erase(sec)
			if _owner.theme_parts[control_type].is_empty():
				_owner.theme_parts.erase(control_type)
				if _owner.theme_variations.has(control_type):
					_owner.theme_variations.erase(control_type)
		update_value_input_control()
		_owner._config.save_config()
		refresh_parts_tree()
		_owner._preview.apply_preview()
		return

	if prop_key == "" or prop_val == "":
		return

	if not _owner.theme_parts.has(control_type):
		_owner.theme_parts[control_type] = {}

	# Ensure sections exist
	if not _owner.theme_parts[control_type].has(sec):
		_owner.theme_parts[control_type][sec] = {}

	# Assign values structured as dictionary
	var new_entry = {
		"value": prop_val,
		"id": override_id
	}
	
	match prop_type:
		"color":
			_owner.theme_parts[control_type]["colors"][prop_key] = new_entry
		"constant":
			_owner.theme_parts[control_type]["constants"][prop_key] = {
				"value": prop_val.to_int(),
				"id": override_id
			}
		"font":
			_owner.theme_parts[control_type]["fonts"][prop_key] = new_entry
		"font_size":
			_owner.theme_parts[control_type]["font_sizes"][prop_key] = {
				"value": prop_val.to_int(),
				"id": override_id
			}
		"icon":
			_owner.theme_parts[control_type]["icons"][prop_key] = new_entry
		"stylebox":
			_owner.theme_parts[control_type]["styleboxes"][prop_key] = new_entry

	_owner._target_select_meta = {
		"control_type": control_type,
		"sec_name": sec,
		"prop_name": prop_key
	}
	update_value_input_control()
	if is_custom:
		_owner.custom_type_name_edit.text = ""
		_owner.custom_type_check.button_pressed = false
	_owner._config.save_config()
	refresh_parts_tree()
	_owner._preview.apply_preview()

func refresh_parts_tree() -> void:
	_owner.parts_tree.clear()
	var root = _owner.parts_tree.create_item()
	_owner.parts_tree.hide_root = true

	for ctrl_type in _owner.theme_parts.keys():
		var ctrl_item = _owner.parts_tree.create_item(root)
		if _owner.theme_variations.has(ctrl_type) and _owner.theme_variations[ctrl_type] != "":
			ctrl_item.set_text(0, ctrl_type + " (" + _owner.theme_variations[ctrl_type] + ")")
		else:
			ctrl_item.set_text(0, ctrl_type)
		
		var sections = _owner.theme_parts[ctrl_type]
		for sec_name in sections.keys():
			var overrides = sections[sec_name]
			for prop_name in overrides.keys():
				var entry = overrides[prop_name]
				var val_item = _owner.parts_tree.create_item(ctrl_item)
				var entry_id = _owner.get_part_id(entry)
				var entry_val = _owner.get_part_value(entry)
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
				
				if _owner._target_select_meta is Dictionary:
					if _owner._target_select_meta["control_type"] == ctrl_type \
						and _owner._target_select_meta["sec_name"] == sec_name \
						and _owner._target_select_meta["prop_name"] == prop_name:
							val_item.select(0)
							_owner.parts_tree.scroll_to_item(val_item)
							on_tree_item_selected()

	_owner._target_select_meta = null

func on_tree_item_selected() -> void:
	var item = _owner.parts_tree.get_selected()
	if not item:
		return
		
	var meta = item.get_metadata(0)
	if meta is Dictionary and meta.has("control_type"):
		var ctrl_type = meta["control_type"]
		var sec_name = meta["sec_name"]
		var prop_name = meta["prop_name"]
		
		_owner._active_prop_key = prop_name
		_owner._creating_new_override = false
		if _owner.metadata_build_check:
			_owner.metadata_build_check.button_pressed = false
		
		# 1. Update Control Type and Custom Checkboxes
		if _owner.theme_variations.has(ctrl_type):
			_owner.control_type_edit.text = _owner.theme_variations[ctrl_type]
			_owner.custom_type_check.button_pressed = true
			_owner.custom_type_name_edit.editable = true
			_owner.custom_type_name_edit.text = ctrl_type
		else:
			_owner.control_type_edit.text = ctrl_type
			_owner.custom_type_check.button_pressed = false
			_owner.custom_type_name_edit.editable = false
			_owner.custom_type_name_edit.text = ""
			
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
			for i in range(_owner.prop_type_option.item_count):
				if _owner.prop_type_option.get_item_text(i) == display_type:
					_owner.prop_type_option.selected = i
					break
					
		# 3. Populate and select Property Name
		update_property_names()
		
		var base_prop_name = _owner.get_base_prop_name(prop_name)
		for i in range(_owner.prop_name_option.item_count):
			if _owner.prop_name_option.get_item_text(i) == base_prop_name:
				_owner.prop_name_option.selected = i
				break
				
		# 4. Update the input widgets and Name/ID
		update_value_input_control()

func on_override_name_changed(new_text: String) -> void:
	if not _owner._config_loaded:
		if _owner.is_inside_tree() and Engine.is_editor_hint():
			_owner._config.load_config()
		else:
			return
	var control_type = _owner.control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = _owner.custom_type_check.button_pressed
	if is_custom:
		var custom_type = _owner.custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type

	if _owner.prop_type_option.selected == -1 or _owner.prop_name_option.selected == -1:
		return
	var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)
	var prop_key = prop_name
	if _owner._active_prop_key != "" and _owner.get_base_prop_name(_owner._active_prop_key) == prop_name:
		prop_key = _owner._active_prop_key
	
	var sec = _owner.SECTION_MAP.get(prop_type, "")
	if sec == "":
		return

	if _owner.theme_parts.has(control_type) and _owner.theme_parts[control_type].has(sec) and _owner.theme_parts[control_type][sec].has(prop_key):
		var entry = _owner.theme_parts[control_type][sec][prop_key]
		if entry is Dictionary:
			entry["id"] = new_text.strip_edges()
		else:
			_owner.theme_parts[control_type][sec][prop_key] = {
				"value": entry,
				"id": new_text.strip_edges()
			}
		_owner._config.save_config()
		refresh_parts_tree()

func on_color_picker_changed(color: Color) -> void:
	if not _owner._config_loaded:
		if _owner.is_inside_tree() and Engine.is_editor_hint():
			_owner._config.load_config()
		else:
			return
	var control_type = _owner.control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = _owner.custom_type_check.button_pressed
	if is_custom:
		var custom_type = _owner.custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type
			_owner.theme_variations[custom_type] = _owner.control_type_edit.text.strip_edges()

	if _owner.prop_type_option.selected == -1 or _owner.prop_name_option.selected == -1:
		return
	var prop_name = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)
	var prop_key = prop_name
	if _owner._active_prop_key != "" and _owner.get_base_prop_name(_owner._active_prop_key) == prop_name:
		prop_key = _owner._active_prop_key
	var override_id = _owner.override_name_edit.text.strip_edges()

	if not _owner.theme_parts.has(control_type):
		_owner.theme_parts[control_type] = {}
	if not _owner.theme_parts[control_type].has("colors"):
		_owner.theme_parts[control_type]["colors"] = {}

	var prop_val = "#" + color.to_html(true)
	_owner.theme_parts[control_type]["colors"][prop_key] = {
		"value": prop_val,
		"id": override_id
	}

	_owner._config.save_config()
	refresh_parts_tree()
	_owner._preview.apply_preview()

func on_spin_box_changed(value: float) -> void:
	if not _owner._config_loaded:
		if _owner.is_inside_tree() and Engine.is_editor_hint():
			_owner._config.load_config()
		else:
			return
	var control_type = _owner.control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = _owner.custom_type_check.button_pressed
	if is_custom:
		var custom_type = _owner.custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type
			_owner.theme_variations[custom_type] = _owner.control_type_edit.text.strip_edges()

	if _owner.prop_type_option.selected == -1 or _owner.prop_name_option.selected == -1:
		return
	var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)
	var prop_key = prop_name
	if _owner._active_prop_key != "" and _owner.get_base_prop_name(_owner._active_prop_key) == prop_name:
		prop_key = _owner._active_prop_key
	var override_id = _owner.override_name_edit.text.strip_edges()

	var sec = "constants" if prop_type == "constant" else "font_sizes"

	if not _owner.theme_parts.has(control_type):
		_owner.theme_parts[control_type] = {}
	if not _owner.theme_parts[control_type].has(sec):
		_owner.theme_parts[control_type][sec] = {}

	_owner.theme_parts[control_type][sec][prop_key] = {
		"value": int(value),
		"id": override_id
	}

	_owner._config.save_config()
	refresh_parts_tree()
	_owner._preview.apply_preview()

func on_resource_picker_changed(res: Resource) -> void:
	if not _owner._config_loaded:
		if _owner.is_inside_tree() and Engine.is_editor_hint():
			_owner._config.load_config()
		else:
			return
	var control_type = _owner.control_type_edit.text.strip_edges()
	if control_type == "":
		return
	var is_custom = _owner.custom_type_check.button_pressed
	if is_custom:
		var custom_type = _owner.custom_type_name_edit.text.strip_edges()
		if custom_type != "":
			control_type = custom_type
			_owner.theme_variations[custom_type] = _owner.control_type_edit.text.strip_edges()

	if _owner.prop_type_option.selected == -1 or _owner.prop_name_option.selected == -1:
		return
	var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
	var prop_name = _owner.prop_name_option.get_item_text(_owner.prop_name_option.selected)
	var prop_key = prop_name
	if _owner._active_prop_key != "" and _owner.get_base_prop_name(_owner._active_prop_key) == prop_name:
		prop_key = _owner._active_prop_key
	var override_id = _owner.override_name_edit.text.strip_edges()
	if override_id == "" and res != null and res.resource_path != "":
		override_id = res.resource_path.get_file().get_basename()
		_owner.override_name_edit.text = override_id
		
	var sec = _owner.SECTION_MAP.get(prop_type, "")
	if sec == "":
		return

	if res == null:
		if _owner.theme_parts.has(control_type) and _owner.theme_parts[control_type].has(sec) and _owner.theme_parts[control_type][sec].has(prop_key):
			_owner.theme_parts[control_type][sec].erase(prop_key)
			if _owner.theme_parts[control_type][sec].is_empty():
				_owner.theme_parts[control_type].erase(sec)
			if _owner.theme_parts[control_type].is_empty():
				_owner.theme_parts.erase(control_type)
				if _owner.theme_variations.has(control_type):
					_owner.theme_variations.erase(control_type)
	else:
		var prop_val = res.resource_path.strip_edges()
		if prop_val != "":
			if not _owner.theme_parts.has(control_type):
				_owner.theme_parts[control_type] = {}
			if not _owner.theme_parts[control_type].has(sec):
				_owner.theme_parts[control_type][sec] = {}
			_owner.theme_parts[control_type][sec][prop_key] = {
				"value": prop_val,
				"id": override_id
			}
		else:
			printerr("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			push_warning("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			_owner._dialog_utils.show_warning_dialog("The assigned resource must be saved to a file first! Click the drop-down on the resource picker and select 'Save'.")
			
	_owner._config.save_config()
	refresh_parts_tree()
	_owner._preview.apply_preview()

# Signal callbacks to avoid lambdas and prevent Engine Stack Underflow Bug
func on_prop_type_selected(index: int) -> void:
	_owner._active_prop_key = ""
	_owner._creating_new_override = true
	if _owner.metadata_build_check:
		_owner.metadata_build_check.button_pressed = false
	update_property_names()

func on_prop_name_selected(index: int) -> void:
	var selected_name = _owner.prop_name_option.get_item_text(index)
	
	if _owner._active_prop_key != "":
		var base_active = _owner.get_base_prop_name(_owner._active_prop_key)
		if base_active != selected_name:
			if _owner._active_prop_key.contains("_copy"):
				var ctrl_type = _owner.control_type_edit.text.strip_edges()
				if _owner.custom_type_check.button_pressed and _owner.custom_type_name_edit.text.strip_edges() != "":
					ctrl_type = _owner.custom_type_name_edit.text.strip_edges()
					
				var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
				var sec = _owner.SECTION_MAP.get(prop_type, "")
				
				if sec != "" and _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has(sec) and _owner.theme_parts[ctrl_type][sec].has(_owner._active_prop_key):
					var existing_record = _owner.theme_parts[ctrl_type][sec][_owner._active_prop_key]
					var new_key = selected_name + "_copy"
					var counter = 1
					while _owner.theme_parts[ctrl_type][sec].has(new_key):
						counter += 1
						new_key = selected_name + "_copy_" + str(counter)
						
					_owner.theme_parts[ctrl_type][sec].erase(_owner._active_prop_key)
					_owner.theme_parts[ctrl_type][sec][new_key] = existing_record
					_owner._active_prop_key = new_key
					
					_owner._target_select_meta = {
						"control_type": ctrl_type,
						"sec_name": sec,
						"prop_name": new_key
					}
					
					_owner._config.save_config()
					refresh_parts_tree()
					_owner._preview.apply_preview()
					return
			else:
				_owner._active_prop_key = ""
				_owner._creating_new_override = true
				
	if _owner._active_prop_key == "" or _owner._creating_new_override:
		var ctrl_type = _owner.control_type_edit.text.strip_edges()
		if _owner.custom_type_check.button_pressed and _owner.custom_type_name_edit.text.strip_edges() != "":
			ctrl_type = _owner.custom_type_name_edit.text.strip_edges()
			
		var prop_type = _owner.prop_type_option.get_item_text(_owner.prop_type_option.selected).to_lower().replace(" ", "_")
		var sec = _owner.SECTION_MAP.get(prop_type, "")
		
		var check_key = selected_name
		if sec != "" and _owner.theme_parts.has(ctrl_type) and _owner.theme_parts[ctrl_type].has(sec):
			if _owner.theme_parts[ctrl_type][sec].has(check_key):
				var counter = 1
				check_key = selected_name + "_copy"
				while _owner.theme_parts[ctrl_type][sec].has(check_key):
					counter += 1
					check_key = selected_name + "_copy_" + str(counter)
		
		_owner._active_prop_key = check_key
		_owner._creating_new_override = false

	update_value_input_control()

func on_erp_resource_changed(res: Resource) -> void:
	if res and Engine.is_editor_hint():
		EditorInterface.edit_resource(res)
	on_resource_picker_changed(res)

func on_erp_resource_selected(res: Resource, inspect: bool) -> void:
	if res and Engine.is_editor_hint():
		EditorInterface.edit_resource(res)
