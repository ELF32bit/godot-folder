class_name FolderFactory


static func build_fold(fold: FolderFoldResource, name: String = "") -> PackedScene:
	var packed_scene := PackedScene.new()
	var scene_root = Node3D.new()
	scene_root.name = name

	var materials := [
		preload("materials/paper_front.tres").duplicate(),
		preload("materials/paper_back.tres").duplicate(),
		preload("materials/boundary_edge.tres").duplicate(),
		preload("materials/mountain_crease.tres").duplicate(),
		preload("materials/valley_crease.tres").duplicate(),
		preload("materials/flat_crease.tres").duplicate(),
		preload("materials/unassigned_crease.tres").duplicate(),
		preload("materials/cut_edge.tres").duplicate(),
		preload("materials/join_edge.tres").duplicate(),
	]

	var fold_inhertied_frames := fold.get_inherited_frames()
	for frame_index in range(fold_inhertied_frames.size()):
		var frame := fold_inhertied_frames[frame_index]
		var frame_graph := frame.graph

		var mesh: ArrayMesh = null
		var pvc := frame_graph.get_packed_vertices_coordinates()
		mesh = frame_graph.get_faces_surface_tool(pvc, false, materials[0]).commit(mesh)
		mesh = frame_graph.get_faces_surface_tool(pvc, true, materials[1]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "B", materials[2]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "M", materials[3]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "V", materials[4]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "F", materials[5]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "U", materials[6]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "C", materials[7]).commit(mesh)
		mesh = frame_graph.get_edges_surface_tool(pvc, "J", materials[8]).commit(mesh)

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = str(frame_index)
		mesh_instance.mesh = mesh

		scene_root.add_child(mesh_instance, true)
		mesh_instance.owner = scene_root

	packed_scene.pack(scene_root)
	scene_root.free()

	return packed_scene
