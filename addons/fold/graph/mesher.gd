const FRONT_MATERIAL := preload("materials/paper.tres")
const BACK_MATERIAL := preload("materials/paper.tres")


static func to_mesh(graph: FoldGraph, is_triangular: bool = true) -> ArrayMesh:
	if not graph.is_VC23(): return null
	var mesh := ArrayMesh.new()

	var FVC_CCW := graph.get_FVC()
	var FVC_CW := FVC_CCW.duplicate(true)
	for index in range(FVC_CW.size()):
		FVC_CW[index].reverse()

	var FC_CW: Array = []
	var FC_CCW: Array = []
	if is_triangular: FC_CCW = _encode_colors3(graph)
	var has_colors := bool(FC_CCW.size() > 0)
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
		FC_CW = _encode_colors3(graph)
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
		var fc: Array = (FC_CW[index] if has_colors else [])
		var bc: Array = (FC_CCW[index] if has_colors else [])
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
	var has_efa := bool(graph.EFA.size() > 0)

	const EA_TABLE: Dictionary = {
		FoldGraph.EdgeAssignment.BOUNDARY: 7,
		FoldGraph.EdgeAssignment.MOUNTAIN: 6,
		FoldGraph.EdgeAssignment.VALLEY: 5,
		FoldGraph.EdgeAssignment.FLAT: 4,
		FoldGraph.EdgeAssignment.UNKNOWN: 3,
		FoldGraph.EdgeAssignment.CUT: 2,
		FoldGraph.EdgeAssignment.JOIN: 1,
	}

	var FC: Array = []
	FC.resize(graph.FE.size())
	for fi in range(graph.FE.size()):
		var fv: Array = graph.FV[fi]
		var fe: Array = graph.FE[fi]
		var d: int = fe.size()

		var rgb: Array = []
		var colors: Array = []
		FC[fi] = colors
		colors.resize(d)
		colors.fill(Color.BLACK)
		rgb = colors.duplicate()

		for i in range(d):
			var ei: int = fe[i]
			var efa: float = 180.0
			if has_efa: efa = graph.EFA[ei]
			var ea: String = graph.EA[ei]

			var fvi: int = fv[i]
			var ve: Array = graph.VE[fvi]
			var vei: int = ve.find(ei)
			var vee_code: int = 0
			if not vei < 0:
				var vei_ccw := vei; var vei_cw := vei;
				for index in range(1, ve.size()):
					var ei_ccw: int = ve[posmod(vei + index, ve.size())]
					if not graph.EA[ei_ccw] == FoldGraph.EdgeAssignment.JOIN:
						vei_ccw = ei_ccw; break;
				for index in range(ve.size()):
					var ei_cw: int = ve[posmod(vei - index, ve.size())]
					if not graph.EA[ei_cw] == FoldGraph.EdgeAssignment.JOIN:
						vei_cw = ei_cw; break;
				var a: int = EA_TABLE[graph.EA[vei_ccw]] - 1
				var b: int = EA_TABLE[graph.EA[vei_cw]] - 1
				var x := mini(a, b); var y := maxi(a, b)

				vee_code = (7 * x + y) - x * (x + 1) / 2
			var ea_code: int = EA_TABLE[ea] << 5
			rgb[i] = float(ea_code | vee_code) / 255.0

		for i in range(d):
			var fvi: int = fv[i]
			colors[i].r = rgb[i]
			colors[i].g = rgb[(i + 1) % d]
			colors[i].b = rgb[(i + 2) % d]
			var bc_code: int = (1 + (i + 1) % d) * 64
			colors[i].a = bc_code / 255.0

	return FC
