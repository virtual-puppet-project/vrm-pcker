extends PanelContainer

const WORK_DIR := "res://__work"

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
		path = "%s.pck" % path.replace(path.get_extension(), "").replace(".", "")
		
		if DirAccess.dir_exists_absolute(WORK_DIR):
			if OS.move_to_trash(WORK_DIR) != OK:
				_status.text = "Please manually delete the %s directory" % WORK_DIR
				return
		if not DirAccess.make_dir_absolute(WORK_DIR) == OK:
			_status.text = "Unable to create work directory at %s" % ProjectSettings.globalize_path(WORK_DIR)
			return
		
		var work_model_path := "%s/%s" % [WORK_DIR, _model.text.get_file()]
		if DirAccess.copy_absolute(_model.text, work_model_path) != OK:
			_status.text = "Unable to copy model to %s" % work_model_path
			return
		
		if not Engine.is_editor_hint():
			_status.text = "Unable to import VRM in standalone mode"
			return
		
		editor_fs.scan()
		editor_fs.reimport_files([work_model_path])
		
		var packer := PCKPacker.new()
		if packer.pck_start(path) != OK:
			_status.text = "Unable to initialize pck"
			return
		
		var dir := DirAccess.open(WORK_DIR)
		if dir == null:
			_status.text = "Unable to open work directory after import"
			return
		
		dir.include_hidden = false
		dir.include_navigational = false
		dir.list_dir_begin()
		
		var file: String = dir.get_next()
		while not file.is_empty():
			if packer.add_file("res://imported-models/%s" % file, "%s/%s" % [WORK_DIR, file]) != OK:
				_status.text = "Unable to add %s to pck" % file
				dir.list_dir_end()
				return
			
			file = dir.get_next()
		
		dir.list_dir_end()
		
		if packer.flush(true) != OK:
			_status.text = "Unable to create pck"
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
