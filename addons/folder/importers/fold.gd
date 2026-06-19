@tool
extends EditorImportPlugin

enum { PRESET_DEFAULT }


func _get_importer_name() -> String:
	return "fold.json"


func _get_visible_name() -> String:
	return "FOLD"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["fold", "json"])


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
				{
					"name": "validate",
					"default_value": true,
				},
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
	var fold := Fold.from_json_file(source_file)
	if not fold: return ERR_PARSE_ERROR

	if options.get("validate", true):
		if not validate(fold, source_file):
			return ERR_PARSE_ERROR

	return ResourceSaver.save(fold, "%s.%s" % [save_path, _get_save_extension()])


static func validate(fold: Fold, source_file: String) -> bool:
	var fold_info := fold.validate()
	var current_frame: String = ""
	var is_valid := true

	if fold_info.begins_with("VALID\n"):
		fold_info = fold_info.trim_prefix("VALID\n")
	elif fold_info.begins_with("INVALID\n"):
		fold_info = fold_info.trim_prefix("INVALID\n")
		is_valid = false

	var lines := fold_info.split("\n", false)
	if lines.size():
		print_rich("[b]FOLD[/b]: \"%s\"" % source_file)
	for line in lines:
		if line.begins_with("FRAME: "):
			line = line.trim_prefix("FRAME: ")
			current_frame = line
		elif line.begins_with("ERROR: "):
			line = line.trim_prefix("ERROR: ")
			print_rich("[color=green]%s[/color]: [color=red]%s[/color]" %
				[current_frame, line])
		elif line.begins_with("WARNING:"):
			line = line.trim_prefix("WARNING: ")
			print_rich("[color=green]%s[/color]: [color=yellow]%s[/color]" %
				[current_frame, line])

	return is_valid
