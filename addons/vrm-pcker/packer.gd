extends Object

const VERSION := "1.0.0"
const SUCCESS := "Success"
const TRY_AGAIN := "Try again"

const WORK_DIR := "res://__work/"
const MODEL_RENAME_PATH := "%s/model.vrm" % WORK_DIR
const DESCRIPTOR_PATH := "%s/descriptor.json" % WORK_DIR
const SCENE_PATH := "%s/model.tscn" % WORK_DIR

const PCK_DEST_DIR := "res://packer-import/"
const PCK_MODEL_PATH := "%s/model.vrm" % PCK_DEST_DIR
const PCK_DESCRIPTOR_PATH := "%s/descriptor.json" % PCK_DEST_DIR
const DESCRIPTOR_JSON := {
	"name": "",
	"descriptor_version": VERSION,
	"files": []
}
const PCK_SCENE_PATH := "%s/model.tscn" % PCK_DEST_DIR

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

static func _auto_press_new_inherited(dialog: ConfirmationDialog) -> bool:
	var ok: Button = dialog.get_ok_button()
	var cancel: Button = dialog.get_cancel_button()
	
	var target: Button = null
	for i in dialog.get_children(true)[2].get_children():
		if not i is Button:
			continue
		if i == ok or i == cancel:
			continue
		target = i
		break
	
	if target == null:
		return false
	
	target.pressed.emit()
	return true

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

static func pack(editor: EditorInterface, model_path: String, save_path: String, trying_again: bool = false) -> String:
	if not editor.get_open_scenes().is_empty():
		return "Please close all open scenes before packing"
	
	var editor_fs: EditorFileSystem = editor.get_resource_filesystem()
	
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
	
	var auto_press := func(dialog: ConfirmationDialog) -> void:
		if dialog.visible:
			if not _auto_press_new_inherited(dialog):
				printerr("Unable to automatically create new scene")
	
	for i in editor.get_base_control().get_children():
		if i is ConfirmationDialog:
			i.visibility_changed.connect(auto_press.bind(i))
	
	editor.open_scene_from_path(MODEL_RENAME_PATH)
	
	for i in editor.get_base_control().get_children():
		if i is ConfirmationDialog:
			i.visibility_changed.disconnect(auto_press)
	
	# TODO Godot will not properly import the first time around for some reason
	var new_scene: Node = editor.get_edited_scene_root()
	if new_scene == null:
		if trying_again:
			return "Edited scene root is null, aborting"
		else:
			return TRY_AGAIN
	
	editor.save_scene_as(SCENE_PATH)
	
	var saved_scene: Resource = load(SCENE_PATH)
	if saved_scene == null:
		return "Unable to load saved scene from %s" % SCENE_PATH

	var pck_scene := PackedScene.new()
	if pck_scene.pack(saved_scene.instantiate()) != OK:
		return "Unable to pack model %s" % model_path

	if ResourceSaver.save(pck_scene, SCENE_PATH, ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		return "Unable to save PackedScene at path %s" % SCENE_PATH
	
	var packer := PCKPacker.new()
	if packer.pck_start(save_path) != OK:
		return "Unable to initialize pck"
	
	var dir := DirAccess.open(WORK_DIR)
	if dir == null:
		return "Unable to open work directory after import"
	
	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin()
	
	var descriptor := DESCRIPTOR_JSON.duplicate(true)
	descriptor.name = model_path.get_file()
	
	var file: String = dir.get_next()
	while not file.is_empty():
		var pck_path := "%s/%s" % [PCK_DEST_DIR, file]
		if packer.add_file(pck_path, "%s/%s" % [WORK_DIR, file]) != OK:
			dir.list_dir_end()
			return "Unable to add %s to pck" % file
		
		descriptor.files.append(pck_path)
		
		file = dir.get_next()
	
	dir.list_dir_end()
	
	descriptor.files.append(PCK_DESCRIPTOR_PATH)
	
	var descriptor_file := FileAccess.open(DESCRIPTOR_PATH, FileAccess.WRITE)
	if descriptor_file == null:
		return "Unable to write file descriptor at %s" % DESCRIPTOR_PATH
	
	descriptor_file.store_string(JSON.stringify(descriptor))
	
	descriptor_file.close()
	
	if packer.add_file(PCK_DESCRIPTOR_PATH, DESCRIPTOR_PATH) != OK:
		return "Unable to add descriptor.json to pck"
	
	if packer.flush(true) != OK:
		return "Unable to create pck"
	
	if _remove_dir_recursive(WORK_DIR) != OK:
		return "Unable to cleanup work directory at %s" % WORK_DIR
	
	return SUCCESS
