static func FV_to_E(graph: FoldGraph) -> void:
	var EV_map := graph.get_EV_map()
	var has_EA := bool(graph.EA.size() > 0)
	var has_EFA := bool(graph.EFA.size() > 0)
	var has_EL := bool(graph.EL.size() > 0)

	for ev in EV_map:
		var ei: int = EV_map[ev]
		var ev_data: Array = [null, null, null]
		if has_EA: ev_data[0] = graph.EA[ei]
		if has_EFA: ev_data[1] = graph.EFA[ei]
		if has_EL: ev_data[2] = graph.EL[ei]
		EV_map[ev] = ev_data

	var FE_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d: int = fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			if FE_map.has([u, v]): continue
			elif FE_map.has([v, u]): continue
			else: FE_map[[u, v]] = true
	var FE_keys := FE_map.keys()

	var new_EV: Array = []
	var new_EA: Array = []
	var new_EFA: Array = []
	var new_EL: Array = []
	new_EV.resize(FE_keys.size())
	if has_EA:
		new_EA.resize(FE_keys.size())
		new_EA.fill(FoldGraph.EdgeAssignment.JOIN)
	if has_EFA:
		new_EFA.resize(FE_keys.size())
		new_EFA.fill(0.0)
	if has_EL:
		new_EL.resize(FE_keys.size())
		new_EL.fill(0.0)

	for ei in range(FE_keys.size()):
		var ev: Array = FE_keys[ei]
		new_EV[ei] = ev
		if not EV_map.has(ev): continue
		var ev_data: Array = EV_map[ev]
		if has_EA: new_EA[ei] = ev_data[0]
		if has_EFA: new_EFA[ei] = ev_data[1]
		if has_EL: new_EL[ei] = ev_data[2]

	graph.clear("VE;EO;FE")
	graph.EV = new_EV
	graph.EA = new_EA
	graph.EFA = new_EFA
	graph.EL = new_EL


static func FV_to_VV(graph: FoldGraph) -> void:
	if not graph.is_VC23(): return
	var is_VC2 := graph.is_VC2()

	var VV_p: Dictionary = {}
	var VV_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			var w: int = fv[posmod(i - 1, d)]
			VV_map.get_or_add(u, {})[v] = true
			VV_map.get_or_add(u, {})[w] = true

			var uu = graph.VC[u]
			var vv = graph.VC[v]
			var ww = graph.VC[w]
			if is_VC2:
				uu = Vector3(uu.x, uu.y, 0.0)
				vv = Vector3(vv.x, vv.y, 0.0)
				ww = Vector3(ww.x, ww.y, 0.0)
			if not VV_p.has(u): VV_p[u] = Vector3.ZERO
			VV_p[u] = VV_p[u] + Plane(vv, uu, ww).normal
	for vertex in VV_p:
		VV_p[vertex] = Plane(VV_p[vertex].normalized())

	var new_VV: Array[Array] = []
	new_VV.resize(graph.VC.size())
	for vertex in VV_map:
		new_VV[vertex] = VV_map[vertex].keys()

	for vi in range(new_VV.size()):
		var vv: Array = new_VV[vi]
		if not VV_p.has(vi): continue

		var center = graph.VC[vi]
		if is_VC2: center = Vector3(center.x, center.y, 0.0)
		var plane: Plane = VV_p[vi]
		var x := Vector3.ZERO
		for vvi in vv:
			var v = graph.VC[vvi]
			if is_VC2: v = Vector3(v.x, v.y, 0.0)
			x = (v - center).normalized()
			if not x.is_zero_approx(): break
		if x.is_zero_approx(): continue
		var y := x.cross(plane.normal).normalized()
		if y.is_zero_approx(): continue

		var winding: Array = []
		winding.resize(vv.size())
		for i in range(vv.size()):
			var vvi: int = vv[i]
			var v = graph.VC[vvi]
			if is_VC2: v = Vector3(v.x, v.y, 0.0)
			var v_p := plane.project(v - center)
			var xy := Vector2(-v_p.dot(x), v_p.dot(y))
			winding[i] = [vvi, xy.angle()]
		winding.sort_custom(func(a, b): return a[1] < b[1])
		for i in range(vv.size()):
			vv[i] = winding[i][0]

	graph.clear("VE;VF")
	graph.VV = new_VV


static func FV_to_EF(graph: FoldGraph) -> void:
	var EV_map := graph.get_EV_map()
	var EF_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			if not EV_map.has([u, v]): continue
			var ei: int = EV_map[[u, v]]
			EF_map.get_or_add(ei, {})[fi] = true

	var new_EF: Array[Array] = []
	new_EF.resize(graph.EV.size())
	for ei in range(graph.EV.size()):
		var ef: Array = new_EF[ei]
		ef.append_array(EF_map.get(ei, {}).keys())

	# TODO: sort edges faces
	graph.EF = new_EF


static func FE_from_FV(graph: FoldGraph) -> bool:
	var EV_map := graph.get_EV_map()
	var new_FE: Array[Array] = []
	new_FE.resize(graph.FV.size())
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var fe: Array = new_FE[fi]
		var d := fv.size()
		fe.resize(d)
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			if not EV_map.has([u, v]): return false
			fe[i] = EV_map[[u, v]]

	graph.FE = new_FE
	return true


static func FF_from_FV(graph: FoldGraph) -> void:
	var FV_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			FV_map.get_or_add([u, v], {})[fi] = true
			FV_map.get_or_add([v, u], {})[fi] = true

	var new_FF: Array[Array] = []
	new_FF.resize(graph.FV.size())
	for fi in range(graph.FE.size()):
		var fv: Array = graph.FV[fi]
		var ff: Array = new_FF[fi]
		var d := fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			var has_ffi := false
			for ffi in FV_map[[u, v]]:
				if ffi == fi: continue
				has_ffi = true
				ff.append(ffi)
			if not has_ffi:
				ff.append(null)

	graph.FF = new_FF


static func FV_triangulate(graph: FoldGraph) -> void:
	if graph.FV.is_empty(): return
	var is_VC23 := graph.is_VC23()
	var is_VC2 := graph.is_VC2()

	var new_FV: Array = []
	var FO_remap: Array = []
	FO_remap.resize(graph.FV.size())
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d: int = fv.size()

		var fi_remap: Array = []
		FO_remap[fi] = fi_remap
		if d < 4:
			fi_remap.append(new_FV.size())
			new_FV.append(fv.duplicate())
			continue

		if d == 4 and is_VC23:
			fi_remap.append(new_FV.size())
			fi_remap.append(new_FV.size() + 1)
			var d1 = graph.VC[fv[2]] - graph.VC[fv[0]]
			var d2 = graph.VC[fv[3]] - graph.VC[fv[1]]
			if d1.length_squared() <= d2.length_squared():
				new_FV.append([fv[0], fv[1], fv[2]])
				new_FV.append([fv[0], fv[2], fv[3]])
			else:
				new_FV.append([fv[0], fv[1], fv[3]])
				new_FV.append([fv[2], fv[3], fv[1]])
			continue

		if d == 4 and not is_VC23:
			fi_remap.append(new_FV.size())
			fi_remap.append(new_FV.size() + 1)
			new_FV.append([fv[0], fv[1], fv[2]])
			new_FV.append([fv[0], fv[2], fv[3]])
			continue

		if d > 4 and is_VC23:
			var center = (Vector2.ZERO if is_VC2 else Vector3.ZERO)
			for i in range(d):
				center += graph.VC[fv[i]]
			center /= d
			var ii := graph.VC.size()
			graph.VC.append(center)
			for i in range(d):
				fi_remap.append(new_FV.size())
				new_FV.append([ii, fv[i], fv[(i + 1) % d]])
			continue

		for i in range(1, d - 1):
			fi_remap.append(new_FV.size())
			new_FV.append([0, i, i + 1])
		new_FV.append([0, d - 1, 1])

	var new_FO: Array = []
	for fo in graph.FO:
		var f1: int = fo[0]
		var f2: int = fo[1]
		var o: int = fo[2]
		for f1_remap in FO_remap[f1]:
			for f2_remap in FO_remap[f2]:
				new_FO.append([f1_remap, f2_remap, o])

	# TODO: triangulate metadata
	graph.clear("VV;VE;VF;EF;FE;FF")
	graph.FV = new_FV
	graph.FO = new_FO


static func FV_flip(graph: FoldGraph) -> void:
	for index in range(graph.VV.size()):
		graph.VV[index].reverse()
	for index in range(graph.VE.size()):
		graph.VE[index].reverse()

	var new_VF: Array = []
	new_VF = graph.VF.duplicate(true)
	for index in range(new_VF.size()):
		var vfi_ccw: Array = graph.VF[index]
		var vfi_cw: Array = new_VF[index]
		var d := vfi_ccw.size()
		for i in range(d):
			vfi_cw[i] = vfi_ccw[posmod(d - 2 - i, d)]

	for index in range(graph.EV.size()):
		graph.EV[index].reverse()
	for index in range(graph.EA.size()):
		match graph.EA[index]:
			FoldGraph.EdgeAssignment.MOUNTAIN:
				graph.EA[index] = FoldGraph.EdgeAssignment.VALLEY
			FoldGraph.EdgeAssignment.VALLEY:
				graph.EA[index] = FoldGraph.EdgeAssignment.MOUNTAIN
	for index in range(graph.EFA.size()):
		graph.EFA[index] *= -1
	for index in range(graph.FV.size()):
		graph.FV[index].reverse()

	var new_FE: Array = []
	new_FE = graph.FE.duplicate(true)
	for index in range(graph.FE.size()):
		var fei_ccw: Array = graph.FE[index]
		var fei_cw: Array = new_FE[index]
		var d := fei_ccw.size()
		for i in range(d):
			fei_cw[i] = fei_ccw[posmod(d - 2 - i, d)]

	var new_FF: Array = []
	new_FF = graph.FF.duplicate(true)
	for index in range(graph.FF.size()):
		var ffi_ccw: Array = graph.FF[index]
		var ffi_cw: Array = new_FF[index]
		var d := ffi_ccw.size()
		for i in range(d):
			ffi_cw[i] = ffi_ccw[posmod(d - 2 - i, d)]

	for index in range(graph.FO.size()):
		graph.FO[index][2] *= -1

	#TODO: flip metadata
	graph.VF = new_VF
	graph.FE = new_FE
	graph.FF = new_FF
