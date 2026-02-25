@tool
extends EditorImportPlugin

enum { PRESET_DEFAULT }


func _get_importer_name() -> String:
	return "fold.svg"


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
				{
					"name": "triangulate",
					"default_value": true,
				},
				{
					"name": "max_size",
					"default_value": 100.0,
				},
				{
					"name": "quantization",
					"default_value": 0.001,
				},
				{
					"name": "merge_distance",
					"default_value": 0.5,
				},
				{
					"name": "grid_step",
					"default_value": 1.0,
				},
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
	var fold := FoldSvgParser.parse(source_file)
	if not fold: return ERR_PARSE_ERROR
	var graph := fold.key_frame.graph

	if options["triangulate"]:
		FoldGraphBuilder.Coordinates.VC_to_VC2(graph)
		FoldGraphBuilder.Coordinates.VC2_center(graph)
		FoldGraphBuilder.Coordinates.VC2_to_size(graph, options["max_size"])
		FoldGraphBuilder.Coordinates.VC2_snap(graph, options["quantization"])
		FoldGraphBuilder.Edges.EVC2_intersect(graph, options["grid_step"], options["quantization"])
		FoldGraphBuilder.Vertices.VC_merge(graph, options["merge_distance"])
		FoldGraphBuilder.Coordinates.VC2_snap(graph, options["quantization"])
		var result = FoldGraphBuilder.Vertices.VC2_triangulate(graph, options["grid_step"])
		if result == false: return ERR_PARSE_ERROR
		FoldGraphBuilder.Faces.FV_to_E(graph)
		FoldGraphBuilder.Faces.FV_to_EF(graph)
		FoldGraphBuilder.Faces.FV_to_VV(graph)
		FoldGraphBuilder.Vertices.VE_from_VV(graph)
		FoldGraphBuilder.Vertices.VF_from_VV(graph)
		FoldGraphBuilder.Coordinates.VC2_to_VC(graph)

	if options.get("validate", true):
		if not preload("fold.gd").validate(fold, source_file):
			return ERR_PARSE_ERROR

	return ResourceSaver.save(fold, "%s.%s" % [save_path, _get_save_extension()])
