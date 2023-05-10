extends Object

const VERSION := "1.0.0"
const SUCCESS := "Success"

const WORK_DIR := "res://__work/"
const MODEL_RENAME_PATH := "%s/model.vrm" % WORK_DIR
const DESCRIPTOR_PATH := "%s/descriptor.json" % WORK_DIR
const DESCRIPTOR_JSON := {
	"name": "",
	"descriptor_version": VERSION
}

#-----------------------------------------------------------------------------#
# Builtin functions
#-----------------------------------------------------------------------------#

func _init() -> void:
	pass

#-----------------------------------------------------------------------------#
# Private functions
#-----------------------------------------------------------------------------#

static func _get_files_recursive(original_path: String, current_path: String) -> Dictionary:
	var r := {}

	var dir := DirAccess.open(current_path)
	if dir == null:
		printerr("Failed to open directory at %s" % current_path)
		return r

	dir.list_dir_begin()

	var file_name := dir.get_next()
	while not file_name.is_empty():
		var full_path := "%s/%s" % [dir.get_current_dir(), file_name]
		if dir.current_is_dir():
			var relative_path := "%s/%s" % [current_path.replace(original_path, ""), file_name]
			r[relative_path] = _get_files_recursive(original_path, current_path)
		else:
			r[file_name] = full_path

		file_name = dir.get_next()

	return r

static func _remove_dir_recursive(
	path: String,
	remove_base_dir: bool = true,
	file_dict: Dictionary = {}
) -> int:
	path = ProjectSettings.globalize_path(path)

	var files := _get_files_recursive(path, path) if file_dict.is_empty() else file_dict

	for key in files.keys():
		var file_path := "%s/%s" % [path, key]
		var val = files[key]

		if val is Dictionary:
			if _remove_dir_recursive(file_path, false, val) != OK:
				printerr("Unable to remove directories recursively for %s" % path)
				return ERR_BUG

		if OS.move_to_trash(file_path) != OK:
			printerr("Unable to remove file at path %s" % file_path)
			return ERR_BUG

	if remove_base_dir and OS.move_to_trash(path) != OK:
		printerr("Unable to remove base directory at path %s" % path)
		return ERR_BUG

	return OK

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

static func pack(editor_fs: EditorFileSystem, model_path: String, save_path: String) -> String:
	save_path = "%s.pck" % save_path.rstrip(save_path.get_extension()).rstrip(".")
	
	if DirAccess.dir_exists_absolute(WORK_DIR):
		if _remove_dir_recursive(WORK_DIR) != OK:
			return "Unable to delete work directory, please manually delete the %s directory" % WORK_DIR
	if not DirAccess.make_dir_absolute(WORK_DIR) == OK:
		return "Unable to create work directory at %s" % ProjectSettings.globalize_path(WORK_DIR)
	
	var work_model_path := "%s/%s" % [WORK_DIR, model_path.get_file()]
	if DirAccess.copy_absolute(model_path, work_model_path) != OK:
		return "Unable to copy model to %s" % work_model_path
	
	if DirAccess.rename_absolute(work_model_path, MODEL_RENAME_PATH) != OK:
		return "Unable to rename work model"
	
	if not Engine.is_editor_hint():
		return "Unable to import VRM in standalone mode"
	
	editor_fs.scan()
	editor_fs.reimport_files([MODEL_RENAME_PATH])
	
	var descriptor := DESCRIPTOR_JSON.duplicate()
	descriptor.name = model_path.get_file()
	
	var descriptor_file := FileAccess.open(DESCRIPTOR_PATH, FileAccess.WRITE)
	if descriptor_file == null:
		return "Unable to write file descriptor at %s" % DESCRIPTOR_PATH
	
	descriptor_file.store_string(JSON.stringify(descriptor))
	
	descriptor_file.close()
	
	var packer := PCKPacker.new()
	if packer.pck_start(save_path) != OK:
		return "Unable to initialize pck"
	
	var dir := DirAccess.open(WORK_DIR)
	if dir == null:
		return "Unable to open work directory after import"
	
	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin()
	
	var file: String = dir.get_next()
	while not file.is_empty():
		if packer.add_file("res://imported-models/%s" % file, "%s/%s" % [WORK_DIR, file]) != OK:
			dir.list_dir_end()
			return "Unable to add %s to pck" % file
		
		file = dir.get_next()
	
	dir.list_dir_end()
	
	if packer.flush(true) != OK:
		return "Unable to create pck"
	
	if _remove_dir_recursive(WORK_DIR) != OK:
		return "Unable to cleanup work directory at %s" % WORK_DIR
	
	return SUCCESS
