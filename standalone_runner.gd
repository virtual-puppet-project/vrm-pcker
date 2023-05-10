extends CanvasLayer

#-----------------------------------------------------------------------------#
# Builtin functions
#-----------------------------------------------------------------------------#

func _init() -> void:
	pass

func _ready() -> void:
	get_tree().root.files_dropped.connect(func(files: PackedStringArray) -> void:
		for file in files:
			ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(file), true)

			var dir := DirAccess.open("res://imported-models")

			dir.list_dir_begin()

			var file_name := dir.get_next()
			while not file_name.is_empty():
				print(file_name)

				file_name = dir.get_next()
			
			print(JSON.parse_string(FileAccess.get_file_as_string("res://imported-models/descriptor.json")))
	)

#-----------------------------------------------------------------------------#
# Private functions
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

