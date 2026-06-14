@tool
extends EditorPlugin

const PluginManagerScene = preload("./scenes/AcePluginManager.tscn")

var window: Window
var plugin_manager: AcePluginManager



func _enter_tree() -> void:
	if Engine.is_editor_hint():
		plugin_manager = PluginManagerScene.instantiate()
		plugin_manager.assignEditorInterface(get_editor_interface())

		add_tool_menu_item("Ace Add-On Manager", _on_addon_manager_clicked)
		window = Window.new()
		window.title = "Ace Add-On Manager"
		window.add_child(plugin_manager)
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = Vector2i(2048, 1152)
		window.size = Vector2i(1600 ,720)
		window.set_unparent_when_invisible(true)
		window.close_requested.connect(func(): window.hide())
		window.about_to_popup.connect(_on_about_to_popup)

		AddonManagerUtil.enable_addons() # Automatically enable all addons in the res://addons/ directory on plugin activation.

		
		# add_control_to_container(CONTAINER_TOOLBAR, custom_menu_button)






func _exit_tree() -> void:
	# remove_control_from_bottom_panel(plugin_manager)
	remove_tool_menu_item("Ace Add-On Manager")
	window.queue_free()

	if is_instance_valid(plugin_manager):
		plugin_manager.queue_free()
	
	# Clean up when the plugin is deactivated
	# remove_control_from_container(CONTAINER_TOOLBAR, custom_menu_button)
	# custom_menu_button.free()

# func _has_main_screen():
# 	return true


# func _make_visible(visible):
# 	if is_instance_valid(plugin_manager):
# 		plugin_manager.visible = visible


# func _get_plugin_name():
# 	return "AceAddonManager"


# func _get_plugin_icon():
# 	return preload("res://addons/anomalyAcesAddonManager/AceAddonManager.svg")
# func _on_custom_menu_item_pressed(id: int):
# 	match id:
# 		0:
# 			print("Option 1 selected!")
# 			# Implement functionality for Option 1
# 		1:
# 			print("Option 2 selected!")
# 			# Implement functionality for Option 2
func _on_addon_manager_clicked():
	if window.get_parent():
		AceLog.printLog(["Show Addon Window Please"])
		window.mode = Window.MODE_WINDOWED
	else:
		AceLog.printLog(["Open Addon Window Please"])
		EditorInterface.popup_dialog_centered(window)
	pass

func _on_about_to_popup():
	plugin_manager.main_view.getAddons()