@tool
extends EditorPlugin

var fold_import_plugin = null
var svg_import_plugin = null
var obj_import_plugin = null


func _enter_tree() -> void:
	fold_import_plugin = preload("importers/fold.gd").new()
	svg_import_plugin = preload("importers/svg.gd").new()
	obj_import_plugin = preload("importers/obj.gd").new()

	add_import_plugin(fold_import_plugin)
	add_import_plugin(svg_import_plugin)
	add_import_plugin(obj_import_plugin)


func _exit_tree() -> void:
	remove_import_plugin(fold_import_plugin)
	remove_import_plugin(svg_import_plugin)
	remove_import_plugin(obj_import_plugin)

	fold_import_plugin = null
	svg_import_plugin = null
	obj_import_plugin = null
