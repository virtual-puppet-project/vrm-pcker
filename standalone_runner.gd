extends CanvasLayer

const Packer := preload("res://addons/vrm-pcker/packer.gd")

#-----------------------------------------------------------------------------#
# Builtin functions
#-----------------------------------------------------------------------------#

func _init() -> void:
	pass

func _ready() -> void:
	get_tree().root.files_dropped.connect(func(files: PackedStringArray) -> void:
		for file in files:
			ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(file), true)

			var dir := DirAccess.open(Packer.PCK_DEST_DIR)

			dir.list_dir_begin()

			var file_name := dir.get_next()
			while not file_name.is_empty():
				print(file_name)

				file_name = dir.get_next()
			
			print(JSON.parse_string(FileAccess.get_file_as_string("%s/descriptor.json" % Packer.PCK_DEST_DIR)))
	)

#-----------------------------------------------------------------------------#
# Private functions
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

