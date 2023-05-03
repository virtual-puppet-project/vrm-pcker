@tool
extends EditorPlugin

const VRM_IMPORT_PLUGIN := "vrm"
var _initial_vrm_import_plugin_state := false
const VRM_SHADER_PLUGIN := "Godot-MToon-Shader"
var _initial_vrm_shader_plugin_state := false

const PLUGIN_NAME := "VRM PCKer"
var gui: Control = null

func _enter_tree() -> void:
	var editor := get_editor_interface()
	
	gui = preload("res://addons/vrm-pcker/gui.tscn").instantiate()
	var gui_script: GDScript = gui.get_script().duplicate()
	gui_script.source_code = "@tool\n%s" % gui_script.source_code
	if not gui_script.reload() == OK:
		printerr("Unable to reload gui script")
		gui.queue_free()
		return
	gui.set_script(gui_script)
	gui.editor_fs = editor.get_resource_filesystem()
	
	add_control_to_bottom_panel(gui, PLUGIN_NAME)
	
	if not editor.is_plugin_enabled(VRM_IMPORT_PLUGIN):
		printerr("%s needs to be enabled in order for %s to work" % [VRM_IMPORT_PLUGIN, PLUGIN_NAME])
	
	if not editor.is_plugin_enabled(VRM_SHADER_PLUGIN):
		printerr("%s needs to be enabled in order for %s to work" % [VRM_SHADER_PLUGIN, PLUGIN_NAME])

func _exit_tree() -> void:
	if gui != null:
		remove_control_from_bottom_panel(gui)
		gui.queue_free()
