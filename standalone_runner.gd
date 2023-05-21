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
			
			print(JSON.parse_string(FileAccess.get_file_as_string(Packer.PCK_DESCRIPTOR_PATH)))
			
			var r = load(Packer.PCK_SCENE_PATH)
			print(r)
	)

#-----------------------------------------------------------------------------#
# Private functions
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

