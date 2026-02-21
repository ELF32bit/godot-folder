static func _mesh_VC3_to_VC(graph: FoldGraph) -> void:
	var metadata := graph.frame_metadata
	var VP: Array = metadata.get("vertices_color", [])
	for index in range(VP.size()):
		var vp4: Color = VP[index]
		VP[index] = "#" + vp4.to_html(true).to_upper()
	var NC: Array = metadata.get("normals_coords", [])
	for index in range(NC.size()):
		var nc3: Vector3 = NC[index]
		NC[index] = [nc3.x, nc3.y, nc3.z]
	var TC: Array = metadata.get("uvs_coords", [])
	for index in range(TC.size()):
		var tc2: Vector2 = TC[index]
		TC[index] = [tc2.x, tc2.y]


static func _mesh_VC_to_VC3(graph: FoldGraph) -> void:
	var metadata := graph.frame_metadata
	var VP: Array = metadata.get("vertices_color", [])
	for index in range(VP.size()):
		var vp: String = VP[index]
		VP[index] = Color.html(vp)
	var NC: Array = metadata.get("normals_coords", [])
	for index in range(NC.size()):
		var nc: Array = NC[index]
		NC[index] = Vector3(nc[0], nc[1], nc[2])
	var TC: Array = metadata.get("uvs_coords", [])
	for index in range(TC.size()):
		var tc: Array = TC[index]
		TC[index] = Vector2(tc[0], tc[1])


static func VC_to_VC2(graph: FoldGraph) -> void:
	for index in range(graph.VC.size()):
		var vc: Array = graph.VC[index]
		graph.VC[index] = Vector2(vc[0], vc[1])
	_mesh_VC_to_VC3(graph)


static func VC2_to_VC(graph: FoldGraph) -> void:
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		graph.VC[index] = [vc2.x, vc2.y]
	_mesh_VC3_to_VC(graph)


static func VC_to_VC3(graph: FoldGraph) -> void:
	if graph.is_VC() >= 3:
		for index in range(graph.VC.size()):
			var vc: Array = graph.VC[index]
			graph.VC[index] = Vector3(vc[0], vc[1], vc[2])
	else:
		for index in range(graph.VC.size()):
			var vc: Array = graph.VC[index]
			graph.VC[index] = Vector3(vc[0], vc[1], 0.0)
	_mesh_VC_to_VC3(graph)


static func VC3_to_VC(graph: FoldGraph) -> void:
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		graph.VC[index] = [vc3.x, vc3.y, vc3.z]
	_mesh_VC3_to_VC(graph)


static func VC2_to_VC3(graph: FoldGraph) -> void:
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		graph.VC[index] = Vector3(vc2.x, vc2.y, 0.0)


static func VC3_to_VC2(graph: FoldGraph) -> void:
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		graph.VC[index] = Vector2(vc3.x, vc3.y)


static func VC2_transform(graph: FoldGraph, transform: Transform2D) -> void:
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		graph.VC[index] = transform * vc2


static func VC3_transform(graph: FoldGraph, transform: Transform3D) -> void:
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		graph.VC[index] = transform * vc3


static func VC2_center(graph: FoldGraph) -> void:
	var center := graph.get_rect2().get_center()
	var transform := Transform2D.IDENTITY.translated(-center)
	VC2_transform(graph, transform)


static func VC3_center(graph: FoldGraph) -> void:
	var center := graph.get_aabb().get_center()
	var transform := Transform3D.IDENTITY.translated(-center)
	VC3_transform(graph, transform)


static func VC_snap(graph: FoldGraph, step: float) -> void:
	for index in range(graph.VC.size()):
		var vc: Array = graph.VC[index]
		for i in range(vc.size()):
			vc[i] = snappedf(vc[i], step)


static func VC2_snap(graph: FoldGraph, step: float) -> void:
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		graph.VC[index] = vc2.snappedf(step)


static func VC3_snap(graph: FoldGraph, step: float) -> void:
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		graph.VC[index] = vc3.snappedf(step)
