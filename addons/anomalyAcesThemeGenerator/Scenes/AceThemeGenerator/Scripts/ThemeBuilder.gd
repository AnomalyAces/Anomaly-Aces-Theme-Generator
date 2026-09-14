@tool
extends RefCounted
## Construct a native Godot Theme resource from theme_parts data.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

# Build Native Theme Object from configuration parts and variations
func build_theme() -> Theme:
	var temp_theme = Theme.new()

	# Set Type Variations first so custom types inherit base properties
	for custom_type in _owner.theme_variations.keys():
		var base_type = _owner.theme_variations[custom_type]
		if base_type != "":
			temp_theme.set_type_variation(custom_type, base_type)

	for ctrl_type in _owner.theme_parts.keys():
		var section = _owner.theme_parts[ctrl_type]

		# Apply Colors
		if section.has("colors"):
			for col_name in section["colors"].keys():
				var base_name = _owner.get_base_prop_name(col_name)
				var raw_color = _owner.get_part_value(section["colors"][col_name])
				var color_val = Color.from_string(raw_color, Color.WHITE)
				temp_theme.set_color(base_name, ctrl_type, color_val)

		# Apply Constants
		if section.has("constants"):
			for const_name in section["constants"].keys():
				var base_name = _owner.get_base_prop_name(const_name)
				var raw_const = _owner.get_part_value(section["constants"][const_name])
				temp_theme.set_constant(base_name, ctrl_type, int(raw_const))

		# Apply Fonts
		if section.has("fonts"):
			for font_name in section["fonts"].keys():
				var base_name = _owner.get_base_prop_name(font_name)
				var font_path = _owner.get_part_value(section["fonts"][font_name])
				if font_path != "" and ResourceLoader.exists(font_path):
					var loaded_font = ResourceLoader.load(font_path, "", ResourceLoader.CACHE_MODE_REPLACE)
					if loaded_font is Font:
						temp_theme.set_font(base_name, ctrl_type, loaded_font)

		# Apply Font Sizes
		if section.has("font_sizes"):
			for fs_name in section["font_sizes"].keys():
				var base_name = _owner.get_base_prop_name(fs_name)
				var raw_fs = _owner.get_part_value(section["font_sizes"][fs_name])
				temp_theme.set_font_size(base_name, ctrl_type, int(raw_fs))

		# Apply Icons
		if section.has("icons"):
			for icon_name in section["icons"].keys():
				var base_name = _owner.get_base_prop_name(icon_name)
				var icon_path = _owner.get_part_value(section["icons"][icon_name])
				if icon_path != "" and ResourceLoader.exists(icon_path):
					var loaded_icon = ResourceLoader.load(icon_path, "", ResourceLoader.CACHE_MODE_REPLACE)
					if loaded_icon is Texture2D:
						temp_theme.set_icon(base_name, ctrl_type, loaded_icon)

		# Apply StyleBoxes
		if section.has("styleboxes"):
			for sb_name in section["styleboxes"].keys():
				var base_name = _owner.get_base_prop_name(sb_name)
				var sb_path = _owner.get_part_value(section["styleboxes"][sb_name])
				if sb_path != "" and ResourceLoader.exists(sb_path):
					var loaded_sb = _owner._preview.load_stylebox_uncached(sb_path)
					if loaded_sb is StyleBox:
						temp_theme.set_stylebox(base_name, ctrl_type, loaded_sb)

	# In-memory alignment pass for slider grabber areas to match slider track margins
	for ctrl_type in _owner.theme_parts.keys():
		if temp_theme.has_stylebox("slider", ctrl_type):
			var slider_sb = temp_theme.get_stylebox("slider", ctrl_type)
			for fill_name in ["grabber_area", "grabber_area_highlight"]:
				if temp_theme.has_stylebox(fill_name, ctrl_type):
					var fill_sb = temp_theme.get_stylebox(fill_name, ctrl_type)
					if (slider_sb is StyleBoxTexture or slider_sb is StyleBoxFlat) and (fill_sb is StyleBoxTexture or fill_sb is StyleBoxFlat):
						fill_sb.expand_margin_left = slider_sb.expand_margin_left
						fill_sb.expand_margin_right = slider_sb.expand_margin_right
						fill_sb.expand_margin_top = slider_sb.expand_margin_top
						fill_sb.expand_margin_bottom = slider_sb.expand_margin_bottom

	# Keep every button state anchored to the normal state's geometry.
	_align_button_state_margins(temp_theme)

	return temp_theme

func _align_button_state_margins(theme: Theme) -> void:
	for ctrl_type in _owner.theme_parts.keys():
		if not theme.has_stylebox("normal", ctrl_type):
			continue

		var normal_sb = theme.get_stylebox("normal", ctrl_type)
		if not normal_sb is StyleBox:
			continue

		for state in ["hover", "pressed", "disabled"]:
			if not theme.has_stylebox(state, ctrl_type):
				continue
			var state_sb = theme.get_stylebox(state, ctrl_type)
			if not state_sb is StyleBox:
				continue

			state_sb.content_margin_left = normal_sb.content_margin_left
			state_sb.content_margin_top = normal_sb.content_margin_top
			state_sb.content_margin_right = normal_sb.content_margin_right
			state_sb.content_margin_bottom = normal_sb.content_margin_bottom
			state_sb.expand_margin_left = normal_sb.expand_margin_left
			state_sb.expand_margin_top = normal_sb.expand_margin_top
			state_sb.expand_margin_right = normal_sb.expand_margin_right
			state_sb.expand_margin_bottom = normal_sb.expand_margin_bottom
