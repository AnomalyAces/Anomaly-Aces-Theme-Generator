@tool
extends RefCounted
## File/directory browse dialogs and warning popups.

var _owner  # Reference to AceThemeGenerator

func _init(owner) -> void:
	_owner = owner

func show_warning_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	_owner.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func browse_dir(line_edit: LineEdit, title: String) -> void:
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = title
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_dir = current_path
		else:
			dialog.current_dir = "res://"
		dialog.dir_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = title
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_dir = current_path
		else:
			dialog.current_dir = "res://"
		dialog.dir_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func browse_file(line_edit: LineEdit, filter: String, title: String, is_save: bool = false) -> void:
	var filters = filter.split(",")
	if Engine.is_editor_hint():
		var dialog = EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if is_save else EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.title = title
		for f in filters:
			dialog.add_filter(f)
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_path = current_path
		else:
			dialog.current_dir = "res://"
		dialog.file_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if is_save else FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.title = title
		for f in filters:
			dialog.add_filter(f)
		var current_path = line_edit.text.strip_edges()
		if current_path.begins_with("res://"):
			dialog.current_path = current_path
		else:
			dialog.current_dir = "res://"
		dialog.file_selected.connect(_on_browse_path_selected.bind(line_edit, dialog))
		dialog.canceled.connect(dialog.queue_free)
		_owner.add_child(dialog)
		dialog.popup_centered_ratio(0.4)

func _on_browse_path_selected(path: String, line_edit: LineEdit, dialog: Node) -> void:
	line_edit.text = path
	line_edit.text_changed.emit(path)
	dialog.queue_free()
