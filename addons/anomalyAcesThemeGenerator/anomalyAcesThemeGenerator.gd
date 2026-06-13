@tool
extends EditorPlugin

const ThemeGeneratorScene = preload("res://addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.tscn")
var theme_generator_instance: Control

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		theme_generator_instance = ThemeGeneratorScene.instantiate()
		theme_generator_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_generator_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		get_editor_interface().get_editor_main_screen().add_child(theme_generator_instance)
		_make_visible(false)
		print("Ace Theme Generator plugin initialized.")

func _exit_tree() -> void:
	if is_instance_valid(theme_generator_instance):
		theme_generator_instance.queue_free()
	print("Ace Theme Generator plugin disabled.")

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if is_instance_valid(theme_generator_instance) and not theme_generator_instance.is_queued_for_deletion():
		theme_generator_instance.visible = visible

func _get_plugin_name() -> String:
	return "Theme Gen"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Theme", "EditorIcons")


