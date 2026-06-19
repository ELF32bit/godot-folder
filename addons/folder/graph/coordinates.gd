static func VC_to_VC2(graph: FoldGraph) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc: Array = graph.VC[index]
		new_VC[index] = Vector2(vc[0], vc[1])
	graph.VC = new_VC
	_mesh_VC_to_VC3(graph)


static func VC2_to_VC(graph: FoldGraph) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		new_VC[index] = [vc2.x, vc2.y]
	graph.VC = new_VC
	_mesh_VC3_to_VC(graph)


static func VC_to_VC3(graph: FoldGraph) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	if graph.is_VC() >= 3:
		for index in range(graph.VC.size()):
			var vc: Array = graph.VC[index]
			new_VC[index] = Vector3(vc[0], vc[1], vc[2])
	else:
		for index in range(graph.VC.size()):
			var vc: Array = graph.VC[index]
			new_VC[index] = Vector3(vc[0], vc[1], 0.0)
	graph.VC = new_VC
	_mesh_VC_to_VC3(graph)


static func VC3_to_VC(graph: FoldGraph) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		new_VC[index] = [vc3.x, vc3.y, vc3.z]
	graph.VC = new_VC
	_mesh_VC3_to_VC(graph)


static func VC2_to_VC3(graph: FoldGraph) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		new_VC[index] = Vector3(vc2.x, vc2.y, 0.0)
	graph.VC = new_VC


static func VC3_to_VC2(graph: FoldGraph) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		new_VC[index] = Vector2(vc3.x, vc3.y)
	graph.VC = new_VC


static func VC2_transform(graph: FoldGraph, transform: Transform2D) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		new_VC[index] = transform * vc2
	graph.VC = new_VC


static func VC3_transform(graph: FoldGraph, transform: Transform3D) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		new_VC[index] = transform * vc3
	graph.VC = new_VC


static func VC2_center(graph: FoldGraph) -> void:
	var center := graph.get_rect2().get_center()
	var transform := Transform2D.IDENTITY.translated(-center)
	VC2_transform(graph, transform)


static func VC3_center(graph: FoldGraph) -> void:
	var center := graph.get_aabb().get_center()
	var transform := Transform3D.IDENTITY.translated(-center)
	VC3_transform(graph, transform)


static func VC2_to_size(graph: FoldGraph, max_size: float) -> void:
	var rect := graph.get_rect2()
	var size := maxf(rect.size.x, rect.size.y)
	if is_zero_approx(size): return
	var scale := Vector2.ONE * max_size / size
	var transform := Transform2D.IDENTITY.scaled(scale)
	VC2_transform(graph, transform)


static func VC3_to_size(graph: FoldGraph, max_size: float) -> void:
	var aabb := graph.get_aabb()
	var size := aabb.get_longest_axis_size()
	if is_zero_approx(size): return
	var scale := Vector3.ONE * max_size / size
	var transform := Transform3D.IDENTITY.scaled(scale)
	VC3_transform(graph, transform)


static func VC_snap(graph: FoldGraph, step: float) -> void:
	var new_VC: Array = graph.VC.duplicate(true)
	for index in range(graph.VC.size()):
		var vc: Array = new_VC[index]
		for i in range(vc.size()):
			vc[i] = snappedf(vc[i], step)
	graph.VC = new_VC


static func VC2_snap(graph: FoldGraph, step: float) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc2: Vector2 = graph.VC[index]
		new_VC[index] = vc2.snappedf(step)
	graph.VC = new_VC


static func VC3_snap(graph: FoldGraph, step: float) -> void:
	var new_VC: Array = []
	new_VC.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc3: Vector3 = graph.VC[index]
		new_VC[index] = vc3.snappedf(step)
	graph.VC = new_VC


static func _mesh_VC3_to_VC(graph: FoldGraph) -> void:
	var metadata := graph.frame_metadata
	var VP: Array = metadata.get("vertices_color", [])
	var NC: Array = metadata.get("normals_coords", [])
	var TC: Array = metadata.get("uvs_coords", [])

	var new_VP: Array = []
	new_VP.resize(VP.size())
	for index in range(VP.size()):
		var vp4: Color = VP[index]
		new_VP[index] = "#" + vp4.to_html(true).to_upper()

	var new_NC: Array = []
	new_NC.resize(NC.size())
	for index in range(NC.size()):
		var nc3: Vector3 = NC[index]
		new_NC[index] = [nc3.x, nc3.y, nc3.z]

	var new_TC: Array = []
	new_TC.resize(TC.size())
	for index in range(TC.size()):
		var tc2: Vector2 = TC[index]
		new_TC[index] = [tc2.x, tc2.y]

	if metadata.has("vertices_color"): metadata["vertices_color"] = new_VP
	if metadata.has("normals_coords"): metadata["normals_coords"] = new_NC
	if metadata.has("uvs_coords"): metadata["uvs_coords"] = new_TC


static func _mesh_VC_to_VC3(graph: FoldGraph) -> void:
	var metadata := graph.frame_metadata
	var VP: Array = metadata.get("vertices_color", [])
	var NC: Array = metadata.get("normals_coords", [])
	var TC: Array = metadata.get("uvs_coords", [])

	var new_VP: Array = []
	new_VP.resize(VP.size())
	for index in range(VP.size()):
		var vp: String = VP[index]
		new_VP[index] = Color.html(vp)

	var new_NC: Array = []
	new_NC.resize(NC.size())
	for index in range(NC.size()):
		var nc: Array = NC[index]
		new_NC[index] = Vector3(nc[0], nc[1], nc[2])

	var new_TC: Array = []
	new_TC.resize(TC.size())
	for index in range(TC.size()):
		var tc: Array = TC[index]
		new_TC[index] = Vector2(tc[0], tc[1])

	if metadata.has("vertices_color"): metadata["vertices_color"] = new_VP
	if metadata.has("normals_coords"): metadata["normals_coords"] = new_NC
	if metadata.has("uvs_coords"): metadata["uvs_coords"] = new_TC
