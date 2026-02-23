const FRONT_MATERIAL := preload("materials/paper.tres")
const BACK_MATERIAL := preload("materials/paper.tres")


static func to_mesh(graph: FoldGraph, is_triangular: bool = true) -> ArrayMesh:
	if not graph.is_VC23(): return null
	var mesh := ArrayMesh.new()

	var FVC_CCW := graph.get_FVC()
	var FVC_CW := FVC_CCW.duplicate(true)
	for index in range(FVC_CW.size()):
		FVC_CW[index].reverse()

	var FVP_CW: Array = []
	var FVP_CCW: Array = []
	if is_triangular: FVP_CCW = _encode_colors3(graph)
	var has_colors := bool(FVP_CCW.size() > 0)
	if has_colors:
		var FV_CCW := graph.FV
		var FE_CCW := graph.FE
		var VE_CCW := graph.VE
		var EA_CCW := graph.EA

		var FV_CW: Array = []
		FV_CW = graph.FV.duplicate(true)
		for index in range(FV_CW.size()):
			FV_CW[index].reverse()

		var FE_CW: Array = []
		FE_CW = graph.FE.duplicate(true)
		for index in range(FE_CW.size()):
			var fei_ccw: Array = FE_CCW[index]
			var fei_cw: Array = FE_CW[index]
			var d := fei_ccw.size()
			for i in range(d): # -1 for last element
				fei_cw[i] = fei_ccw[d - 2 - i]

		var VE_CW: Array = []
		VE_CW = graph.VE.duplicate(true)
		for index in range(VE_CW.size()):
			VE_CW[index].reverse()

		var EA_CW: Array = []
		EA_CW = graph.EA.duplicate(true)
		for index in range(EA_CW.size()):
			match EA_CW[index]:
				FoldGraph.EdgeAssignment.MOUNTAIN:
					EA_CW[index] = FoldGraph.EdgeAssignment.VALLEY
				FoldGraph.EdgeAssignment.VALLEY:
					EA_CW[index] = FoldGraph.EdgeAssignment.MOUNTAIN

		graph.FV = FV_CW
		graph.FE = FE_CW
		graph.VE = VE_CW
		graph.EA = EA_CW
		FVP_CW = _encode_colors3(graph)
		graph.FV = FV_CCW
		graph.FE = FE_CCW
		graph.VE = VE_CCW
		graph.EA = EA_CCW

	var front_surface := SurfaceTool.new()
	front_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	front_surface.set_material(FRONT_MATERIAL)
	front_surface.set_smooth_group(-1)

	var back_surface := SurfaceTool.new()
	back_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	back_surface.set_material(BACK_MATERIAL)
	back_surface.set_smooth_group(-1)

	for index in range(FVC_CCW.size()):
		var fvc: Array = FVC_CW[index]
		var bvc: Array = FVC_CCW[index]
		var fc: Array = (FVP_CW[index] if has_colors else [])
		var bc: Array = (FVP_CCW[index] if has_colors else [])
		front_surface.add_triangle_fan(fvc, [], fc, [])
		back_surface.add_triangle_fan(bvc, [], bc, [])

	for surface in [front_surface, back_surface]:
		surface.generate_normals()
		surface.index()
	front_surface.commit(mesh)
	back_surface.commit(mesh)

	mesh.surface_set_name(0, "FRONT")
	mesh.surface_set_name(1, "BACK")

	return mesh


static func _encode_colors3(graph: FoldGraph) -> Array:
	if not graph.FV.size() > 0: return []
	if not graph.FE.size() > 0: return []
	if not graph.VE.size() > 0: return []
	if not graph.EA.size() > 0: return []

	var FVP: Array = []
	FVP.resize(graph.FE.size())
	for fi in range(graph.FE.size()):
		var fv: Array = graph.FV[fi]
		var fe: Array = graph.FE[fi]
		var d: int = fe.size()

		var colors: Array = []
		FVP[fi] = colors
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
				var _i: int = 0  # walking vertices edges counterclockwise
				for index in range(1, ve.size()):
					var ei_ccw: int = ve[posmod(vei + index, ve.size())]
					var vea: String = graph.EA[ei_ccw]
					if vea == FoldGraph.EdgeAssignment.JOIN: continue
					elif _i < 2:
						_i += 1; v4ea[ei_ccw] = vea;
					else: break
				_i = 0 # walking vertices edges clockwise
				for index in range(ve.size()):
					var ei_cw: int = ve[posmod(vei - index, ve.size())]
					var vea: String = graph.EA[ei_cw]
					if vea == FoldGraph.EdgeAssignment.JOIN: continue
					elif _i < 2:
						_i += 1; v4ea[ei_cw] = vea;
					if vea == FoldGraph.EdgeAssignment.BOUNDARY: ve4bc |= 1
					elif vea == FoldGraph.EdgeAssignment.CUT: ve4bc |= 2
					if ve4bc == 3: break

			for assignment in v4ea.values():
				match assignment:
					FoldGraph.EdgeAssignment.MOUNTAIN: v4eac[0] += 1
					FoldGraph.EdgeAssignment.VALLEY: v4eac[1] += 1
					FoldGraph.EdgeAssignment.FLAT: v4eac[2] += 1
					FoldGraph.EdgeAssignment.UNKNOWN: v4eac[3] += 1
			rgb[i] = [__EA_TABLE[ea], __V4EAC_TABLE[v4eac], ve4bc]

		var c: int = 0
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


const __EA_TABLE: Dictionary = {
	FoldGraph.EdgeAssignment.BOUNDARY: 6,
	FoldGraph.EdgeAssignment.MOUNTAIN: 5,
	FoldGraph.EdgeAssignment.VALLEY: 4,
	FoldGraph.EdgeAssignment.FLAT: 3,
	FoldGraph.EdgeAssignment.UNKNOWN: 2,
	FoldGraph.EdgeAssignment.CUT: 7,
	FoldGraph.EdgeAssignment.JOIN: 1,
}


const __V4EAC_TABLE: Dictionary = {
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
