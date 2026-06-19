const FRONT_MATERIAL := preload("material.tres")
const BACK_MATERIAL := preload("material.tres")

const EA_DISPLAY_PRIORITY_TABLE: Dictionary = {
	FoldGraph.EdgeAssignment.BOUNDARY: 6,
	FoldGraph.EdgeAssignment.MOUNTAIN: 5,
	FoldGraph.EdgeAssignment.VALLEY: 4,
	FoldGraph.EdgeAssignment.FLAT: 3,
	FoldGraph.EdgeAssignment.UNKNOWN: 2,
	FoldGraph.EdgeAssignment.CUT: 7,
	FoldGraph.EdgeAssignment.JOIN: 1,
}

const V4EAC_TABLE: Dictionary = {
	[0, 0, 0, 0]: 0, [0, 0, 0, 1]: 1, [0, 0, 0, 2]: 2, [0, 0, 0, 3]: 3,
	[0, 0, 0, 4]: 4, [0, 0, 1, 0]: 5, [0, 0, 1, 1]: 6, [0, 0, 1, 2]: 7,
	[0, 0, 1, 3]: 8, [0, 0, 2, 0]: 9, [0, 0, 2, 1]: 10, [0, 0, 2, 2]: 11,
	[0, 0, 3, 0]: 12, [0, 0, 3, 1]: 13, [0, 0, 4, 0]: 14, [0, 1, 0, 0]: 15,
	[0, 1, 0, 1]: 16, [0, 1, 0, 2]: 17, [0, 1, 0, 3]: 18, [0, 1, 1, 0]: 19,
	[0, 1, 1, 1]: 20, [0, 1, 1, 2]: 21, [0, 1, 2, 0]: 22, [0, 1, 2, 1]: 23,
	[0, 1, 3, 0]: 24, [0, 2, 0, 0]: 25, [0, 2, 0, 1]: 26, [0, 2, 0, 2]: 27,
	[0, 2, 1, 0]: 28, [0, 2, 1, 1]: 29, [0, 2, 2, 0]: 30, [0, 3, 0, 0]: 31,
	[0, 3, 0, 1]: 32, [0, 3, 1, 0]: 33, [0, 4, 0, 0]: 34, [1, 0, 0, 0]: 35,
	[1, 0, 0, 1]: 36, [1, 0, 0, 2]: 37, [1, 0, 0, 3]: 38, [1, 0, 1, 0]: 39,
	[1, 0, 1, 1]: 40, [1, 0, 1, 2]: 41, [1, 0, 2, 0]: 42, [1, 0, 2, 1]: 43,
	[1, 0, 3, 0]: 44, [1, 1, 0, 0]: 45, [1, 1, 0, 1]: 46, [1, 1, 0, 2]: 47,
	[1, 1, 1, 0]: 48, [1, 1, 1, 1]: 49, [1, 1, 2, 0]: 50, [1, 2, 0, 0]: 51,
	[1, 2, 0, 1]: 52, [1, 2, 1, 0]: 53, [1, 3, 0, 0]: 54, [2, 0, 0, 0]: 55,
	[2, 0, 0, 1]: 56, [2, 0, 0, 2]: 57, [2, 0, 1, 0]: 58, [2, 0, 1, 1]: 59,
	[2, 0, 2, 0]: 60, [2, 1, 0, 0]: 61, [2, 1, 0, 1]: 62, [2, 1, 1, 0]: 63,
	[2, 2, 0, 0]: 64, [3, 0, 0, 0]: 65, [3, 0, 0, 1]: 66, [3, 0, 1, 0]: 67,
	[3, 1, 0, 0]: 68, [4, 0, 0, 0]: 69,
}


static func FV3_to_mesh(front_graph: FoldGraph, back_graph: FoldGraph) -> ArrayMesh:
	if not front_graph.is_VC23(): return null
	if not back_graph.is_VC23(): return null
	var mesh := ArrayMesh.new()

	var FVC_cw := back_graph.get_FVC()
	var FVC_ccw := front_graph.get_FVC()
	var FVP_cw := _encode_colors3(back_graph)
	var FVP_ccw := _encode_colors3(front_graph)
	var has_colors := bool(FVP_ccw.size() > 0)
	# TODO: add support for metadata normals and UVs

	var front_surface := SurfaceTool.new()
	front_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	front_surface.set_material(FRONT_MATERIAL)
	front_surface.set_smooth_group(-1)

	var back_surface := SurfaceTool.new()
	back_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	back_surface.set_material(BACK_MATERIAL)
	back_surface.set_smooth_group(-1)

	for index in range(FVC_ccw.size()):
		var fvc_cw: Array = FVC_cw[index]
		var fvc_ccw: Array = FVC_ccw[index]
		var fvp_cw: Array = (FVP_cw[index] if has_colors else [])
		var fvp_ccw: Array = (FVP_ccw[index] if has_colors else [])
		front_surface.add_triangle_fan(fvc_cw, [], fvp_cw, [])
		back_surface.add_triangle_fan(fvc_ccw, [], fvp_ccw, [])

	for surface in [front_surface, back_surface]:
		surface.generate_normals()
		surface.index()
	front_surface.commit(mesh)
	back_surface.commit(mesh)

	mesh.surface_set_name(0, "FRONT")
	mesh.surface_set_name(1, "BACK")

	return mesh


static func _encode_colors3(graph: FoldGraph) -> Array:
	if graph.FV.is_empty(): return []
	if graph.FE.is_empty(): return []
	if graph.VE.is_empty(): return []
	if graph.EA.is_empty(): return []

	var FVP: Array[Array] = []
	FVP.resize(graph.FE.size())
	for fi in range(graph.FE.size()):
		var fv: Array = graph.FV[fi]
		var fe: Array = graph.FE[fi]
		var d: int = fe.size()

		var colors: Array = FVP[fi]
		colors.resize(d)
		colors.fill(Color.BLACK)
		var rgb: Array = []
		rgb.resize(d)

		for i in range(d):
			var ei: int = fe[i]
			var ea: String = graph.EA[ei]
			var v4eac: Array = [0, 0, 0, 0]
			var v4ea: Dictionary = {}
			var ve4bc: int = 0

			var fvi: int = fv[i]
			var ve: Array = graph.VE[fvi]
			var vei: int = ve.find(ei)
			if not vei < 0:
				var _i: int = 0 # walking vertices edges counterclockwise
				for index in range(1, ve.size()):
					var ei_ccw: int = ve[posmod(vei + index, ve.size())]
					var vea: String = graph.EA[ei_ccw]
					if vea == FoldGraph.EdgeAssignment.JOIN: continue
					elif _i < 2:
						v4ea[ei_ccw] = vea; _i += 1;
					else: break
				_i = 0 # walking vertices edges clockwise
				for index in range(ve.size()):
					var ei_cw: int = ve[posmod(vei - index, ve.size())]
					var vea: String = graph.EA[ei_cw]
					if vea == FoldGraph.EdgeAssignment.JOIN: continue
					elif _i < 2:
						v4ea[ei_cw] = vea; _i += 1;
					if vea == FoldGraph.EdgeAssignment.BOUNDARY: ve4bc |= 1
					elif vea == FoldGraph.EdgeAssignment.CUT: ve4bc |= 2
					if ve4bc == 3: break

			for assignment in v4ea.values():
				match assignment:
					FoldGraph.EdgeAssignment.MOUNTAIN: v4eac[0] += 1
					FoldGraph.EdgeAssignment.VALLEY: v4eac[1] += 1
					FoldGraph.EdgeAssignment.FLAT: v4eac[2] += 1
					FoldGraph.EdgeAssignment.UNKNOWN: v4eac[3] += 1
			rgb[i] = [EA_DISPLAY_PRIORITY_TABLE[ea], V4EAC_TABLE[v4eac], ve4bc]

		var c: int = 0 # packing data into 32 bit color
		c |= rgb[0][0] << 29; c |= rgb[1][0] << 26; c |= rgb[2][0] << 23;
		c |= (70 * 70 * rgb[2][1] + 70 * rgb[0][1] + rgb[1][1]) << 4;
		for i in range(d):
			var fvi: int = fv[i]
			var bc: int = ((1 + (i + 1) % d) << 2)
			colors[i].r = (c >> 24) / 255.0
			colors[i].g = ((c & (255 << 16)) >> 16) / 255.0
			colors[i].b = ((c & (255 << 8)) >> 8) / 255.0
			colors[i].a = ((c & 255) | bc | rgb[i][2]) / 255.0

	return FVP
