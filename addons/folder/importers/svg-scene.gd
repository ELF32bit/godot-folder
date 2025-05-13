@tool
extends EditorImportPlugin

enum { PRESET_DEFAULT }


func _get_importer_name() -> String:
	return "folder.svg.scene"


func _get_visible_name() -> String:
	return "FOLD Scene"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["svg"])


func _get_save_extension() -> String:
	return "scn"


func _get_resource_type() -> String:
	return "PackedScene"


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

	if not fold.validate():
		return ERR_PARSE_ERROR

	var fold_name := source_file.get_file().get_basename()
	var fold_scene := FolderFoldFactory.build_fold(fold, fold_name)

	var save_flags: int = ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES
	return ResourceSaver.save(fold_scene, "%s.%s" % [save_path, _get_save_extension()], save_flags)
