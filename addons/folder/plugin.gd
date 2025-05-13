@tool
extends EditorPlugin

var fold_import_plugin: Variant = null
var fold_scene_import_plugin: Variant = null
var svg_import_plugin: Variant = null
var svg_scene_import_plugin: Variant = null


func _enter_tree() -> void:
	fold_import_plugin = preload("importers/fold.gd").new()
	fold_scene_import_plugin = preload("importers/fold-scene.gd").new()
	svg_import_plugin = preload("importers/svg.gd").new()
	svg_scene_import_plugin = preload("importers/svg-scene.gd").new()

	add_import_plugin(fold_import_plugin)
	add_import_plugin(fold_scene_import_plugin)
	add_import_plugin(svg_import_plugin)
	add_import_plugin(svg_scene_import_plugin)


func _exit_tree() -> void:
	remove_import_plugin(fold_import_plugin)
	remove_import_plugin(fold_scene_import_plugin)
	remove_import_plugin(svg_import_plugin)
	remove_import_plugin(svg_scene_import_plugin)

	fold_import_plugin = null
	fold_scene_import_plugin = null
	svg_import_plugin = null
	svg_scene_import_plugin = null
