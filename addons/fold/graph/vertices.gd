static func VE_from_VV(graph: FoldGraph) -> bool:
	var EV_map := graph.get_EV_map()
	var new_VE: Array = []
	new_VE.resize(graph.VV.size())
	for vi in range(graph.VV.size()):
		var vv: Array = graph.VV[vi]
		var d := vv.size()

		var ve: Array = []
		new_VE[vi] = ve
		ve.resize(d)
		for i in range(d):
			var vvi: int = vv[i]
			if not EV_map.has([vi, vvi]): return false
			ve[i] = EV_map[[vi, vvi]]
	graph.VE = new_VE
	return true


static func VF_from_VV(graph: FoldGraph) -> void:
	var FV_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			var w: int = fv[(i + 2) % d]
			FV_map.get_or_add([u, v, w], {})[fi] = true
			FV_map.get_or_add([w, v, u], {})[fi] = true

	var new_VF: Array = []
	new_VF.resize(graph.VV.size())
	for vi in range(graph.VV.size()):
		var vv: Array = graph.VV[vi]
		var d := vv.size()

		var vf: Array = []
		new_VF[vi] = vf
		vf.resize(d)
		for i in range(d):
			var vvi: int = vv[i]
			var vnvi: int = vv[(i + 1) % d]
			if FV_map.has([vvi, vi, vnvi]):
				vf.append_array(FV_map[[vvi, vi, vnvi]].keys())
			elif FV_map.has([vnvi, vi, vvi]):
				vf.append_array(FV_map[[vnvi, vi, vvi]].keys())
			else: vf.append(null)
	graph.VF = new_VF
