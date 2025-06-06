@tool
extends EditorImportPlugin

enum { PRESET_DEFAULT }


func _get_importer_name() -> String:
	return "folder.svg"


func _get_visible_name() -> String:
	return "FOLD"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["svg"])


func _get_save_extension() -> String:
	return "tres"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		PRESET_DEFAULT:
			return "Default"
		_:
			return "Unknown"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	match preset_index:
		PRESET_DEFAULT:
			return [
			]
		_:
			return []


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _get_import_order() -> int:
	return EditorImportPlugin.IMPORT_ORDER_DEFAULT


func _get_priority() -> float:
	return 1.0


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var fold := FolderFoldResource.from_xml_file(source_file)
	if not fold:
		return ERR_PARSE_ERROR

	return ResourceSaver.save(fold, "%s.%s" % [save_path, _get_save_extension()])
