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

	var new_VV: Array = []
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
	pass


static func FE_from_FV(graph: FoldGraph) -> bool:
	var EV_map := graph.get_EV_map()
	var new_FE: Array[Array] = []
	new_FE.resize(graph.FV.size())
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()

		var fe: Array = []
		new_FE[fi] = fe
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

	var new_FF: Array = []
	new_FF.resize(graph.FV.size())
	for fi in range(graph.FE.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()

		var ff: Array = []
		new_FF[fi] = ff
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
