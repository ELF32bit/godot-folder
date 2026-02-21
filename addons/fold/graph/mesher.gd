const FRONT_MATERIAL := preload("materials/paper.tres")
const BACK_MATERIAL := preload("materials/paper.tres")


static func to_mesh(graph: FoldGraph, is_triangular: bool = true) -> ArrayMesh:
	if not graph.is_VC23(): return null
	var mesh := ArrayMesh.new()

	var FVC_CCW := graph.get_FVC()
	var FVC_CW := FVC_CCW.duplicate(true)
	for index in range(FVC_CW.size()):
		FVC_CW[index].reverse()

	var fc_ccw: Array = []
	if is_triangular: fc_ccw = _encode_colors(graph, false)
	var has_colors := bool(fc_ccw.size() > 0)

	var fv_ccw := graph.FV; var fe_ccw := graph.FE; var ea_ccw := graph.EA;
	var fv_cw: Array = []; var fe_cw: Array = []; var ea_cw: Array = [];
	var fc_cw: Array = []
	if has_colors:
		fv_cw = graph.FV.duplicate(true)
		for face_index in range(fv_cw.size()):
			fv_cw[face_index].reverse()

		fe_cw = graph.FE.duplicate(true)
		for face_index in range(fe_ccw.size()):
			var edges_ccw: Array = fe_ccw[face_index]
			var edges_cw: Array = fe_cw[face_index]
			var d := edges_ccw.size()
			for index in range(d):
				edges_cw[index] = edges_ccw[d - 2 - index]

		ea_cw = graph.EA.duplicate(true)
		for edge_index in range(ea_cw.size()):
			match ea_cw[edge_index]:
				"M": ea_cw[edge_index] = "V"
				"V": ea_cw[edge_index] = "M"

		graph.FV = fv_cw; graph.FE = fe_cw; graph.EA = ea_cw;
		fc_cw = _encode_colors(graph, false)
		graph.FV = fv_ccw; graph.FE = fe_ccw; graph.EA = ea_ccw;

	var front_surface := SurfaceTool.new()
	front_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	front_surface.set_material(FRONT_MATERIAL)
	front_surface.set_smooth_group(-1)

	var back_surface := SurfaceTool.new()
	back_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	back_surface.set_material(BACK_MATERIAL)
	back_surface.set_smooth_group(-1)

	for index in range(FVC_CCW.size()):
		var fv: Array = FVC_CW[index]
		var bv: Array = FVC_CCW[index]
		var fc = (fc_cw[index] if has_colors else [])
		var bc = (fc_ccw[index] if has_colors else [])
		front_surface.add_triangle_fan(fv, [], fc, [])
		back_surface.add_triangle_fan(bv, [], bc, [])

	for surface in [front_surface, back_surface]:
		surface.generate_normals()
		surface.index()
	front_surface.commit(mesh)
	back_surface.commit(mesh)

	mesh.surface_set_name(0, "FRONT")
	mesh.surface_set_name(1, "BACK")

	return mesh


static func _encode_colors(graph: FoldGraph, _validate: bool = true) -> Array:
	if not graph.FE.size() > 0: return []
	if not graph.EV.size() > 0: return []
	if not graph.EA.size() > 0: return []
	var has_efa := bool(graph.EFA.size() > 0)
	if _validate:
		for face in graph.FV:
			if face.size() != 3:
				return []

	var fc: Array = []
	var ve: Dictionary = {}
	for edge_index in range(graph.EV.size()):
		var edge: Array = graph.EV[edge_index]
		var u: int = edge[0]; var v: int = edge[1]
		var assignment: String = graph.EA[edge_index]
		if not ve.has(u): ve[u] = [0, 0, 0]
		if not ve.has(v): ve[v] = [0, 0, 0]
		match assignment:
			"B": ve[u][0] += 1; ve[v][0] += 1;
			"M": ve[u][1] += 1; ve[v][1] += 1;
			"V": ve[u][2] += 1; ve[v][2] += 1;

	fc.resize(graph.FE.size())
	for face_index in range(graph.FE.size()):
		var vertices: Array = graph.FV[face_index]
		var edges: Array = graph.FE[face_index]
		var d: int = edges.size()

		var colors: Array = []
		fc[face_index] = colors
		colors.resize(d)
		colors.fill(Color.BLACK)

		var rgb: Array = []
		rgb = colors.duplicate()
		var ea: Array = []
		ea.resize(d)

		for index in range(d):
			var edge: int = edges[index]
			var fold_angle: float = 180.0
			if has_efa: fold_angle = graph.EFA[edge]
			var fade := int((absf(fold_angle) / 180.0) * 31.0)
			var assignment: String = graph.EA[edge]
			ea[index] = assignment
			match assignment:
				"B": rgb[index] = float((7 << 5) | fade) / 255.0
				"M": rgb[index] = float((6 << 5) | fade) / 255.0
				"V": rgb[index] = float((5 << 5) | fade) / 255.0
				"F": rgb[index] = float((4 << 5) | fade) / 255.0
				"U": rgb[index] = float((3 << 5) | fade) / 255.0
				"C": rgb[index] = float((2 << 5) | fade) / 255.0
				"J": rgb[index] = float((1 << 5) | fade) / 255.0

		for index in range(d):
			var vertex: int = vertices[index]
			colors[index].r = rgb[index]
			colors[index].g = rgb[(index + 1) % d]
			colors[index].b = rgb[(index + 2) % d]
			var alpha: int = (1 + (index + 1) % d) * 64
			if ve.has(vertex):
				var ve_counts: Array = ve[vertex]
				if ve_counts[0] > 0: alpha |= 32
				var m: int = ve_counts[1]
				var v: int = ve_counts[2]
				if (m + v) == 0: alpha |= 31
				else: alpha |= int(roundf(30.0 * v / (m + v)))
			colors[index].a = alpha / 255.0

	return fc
