extends PanelContainer

const WORK_DIR := "res://__work"

const DESCRIPTOR_JSON := {
	"name": "",
	"descriptor_version": ""
}

var editor_fs: EditorFileSystem = null

@onready
var _status := %Status
@onready
var _model := %Model

#-----------------------------------------------------------------------------#
# Builtin functions
#-----------------------------------------------------------------------------#

func _ready() -> void:
	var pack := %Pack
	pack.pressed.connect(func() -> void:
		var path: Variant = await _create_file_dialog(FileDialog.FILE_MODE_SAVE_FILE).close_requested
		if not _valid_path(path):
			return
		
		await get_tree().process_frame
		
		var confirm_dialog := ConfirmationDialog.new()
		confirm_dialog.dialog_text = "pck: %s\nModel: %s" % [path, _model.text]
		confirm_dialog.dialog_autowrap = true
		
		confirm_dialog.confirmed.connect(func() -> void:
			confirm_dialog.close_requested.emit(true)
		)
		confirm_dialog.canceled.connect(func() -> void:
			confirm_dialog.close_requested.emit(false)
		)
		confirm_dialog.close_requested.connect(func(_choice: bool = false) -> void:
			confirm_dialog.queue_free()
		)
		add_child(confirm_dialog)
		confirm_dialog.popup_centered(DisplayServer.screen_get_size() * 0.2)
		
		var should_continue: bool = await confirm_dialog.close_requested
		if not should_continue:
			return
		
		# Done like this for hot reloading
		var Packer = ResourceLoader.load("res://addons/vrm-pcker/packer.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
		
		var err: String = Packer.pack(editor_fs, _model.text, path)
		if err != Packer.SUCCESS:
			_status.text = err
			return
		
		_status.text = "Successfully created pck at %s" % path
	)
	
	_model.text_changed.connect(func(text: String) -> void:
		if text.is_empty() or not FileAccess.file_exists(text):
			pack.disabled = true
			_status.text = "Invalid model path"
		else:
			pack.disabled = false
			_status.text = ""
	)
	var set_model_text := func(text: String) -> void:
		_model.text = text
		_model.text_changed.emit(text)
	
	%SelectModel.pressed.connect(func() -> void:
		var path: Variant = await _create_file_dialog(FileDialog.FILE_MODE_OPEN_FILE).close_requested
		if not _valid_path(path):
			return
		
		set_model_text.call(path)
	)
	
	%Reset.pressed.connect(func() -> void:
		set_model_text.call("")
		_status.text = ""
	)

#-----------------------------------------------------------------------------#
# Private functions
#-----------------------------------------------------------------------------#

func _create_file_dialog(file_mode: int) -> FileDialog:
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = file_mode
	
	fd.file_selected.connect(func(path: String) -> void:
		fd.close_requested.emit(path)
	)
	
	fd.visibility_changed.connect(func() -> void:
		if not fd.visible:
			fd.close_requested.emit()
	)
	
	fd.close_requested.connect(func(path: String = "") -> void:
		fd.queue_free()
	)
	
	add_child(fd)
	fd.popup_centered_ratio()
	
	return fd

static func _valid_path(path: Variant) -> bool:
	return path is String and not path.is_empty()

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

