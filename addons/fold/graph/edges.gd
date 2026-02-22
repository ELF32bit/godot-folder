static func EL_from_EVC(graph: FoldGraph) -> void:
	if not graph.is_VC23(): return
	var EVC := graph.get_EVC()
	graph.EL.resize(graph.EV.size())
	for ei in range(graph.EV.size()):
		var evc: Array = EVC[ei]
		graph.EL[ei] = evc[0].distance_to(evc[1])


static func EFA_from_EA(graph: FoldGraph) -> void:
	graph.EFA.resize(graph.EA.size())
	for ei in range(graph.EA.size()):
		var ea: String = graph.EA[ei]
		match ea:
			FoldGraph.EdgeAssignment.MOUNTAIN: graph.EFA[ei] = -180.0
			FoldGraph.EdgeAssignment.VALLEY: graph.EFA[ei] = -180.0
			_: graph.EFA[ei] = 0.0


static func EA_from_EFA(graph: FoldGraph) -> void:
	var has_EF := bool(graph.EF.size() > 0)
	graph.EA.resize(graph.EFA.size())
	for ei in range(graph.EFA.size()):
		var efa: float = graph.EFA[ei]
		if efa < 0.0: graph.EA[ei] = FoldGraph.EdgeAssignment.MOUNTAIN
		elif efa > 0.0: graph.EA[ei] = FoldGraph.EdgeAssignment.VALLEY
		else: graph.EA[ei] = FoldGraph.EdgeAssignment.JOIN
		if not has_EF: continue
		if graph.EF[ei].filter(func(f): return f != null).size() == 1:
			graph.EA[ei] = FoldGraph.EdgeAssignment.BOUNDARY


static func EV_grid_intersect(graph: FoldGraph, grid_step: float) -> Array:
	const Utilities := preload("utilities.gd")
	if not graph.is_VC23(): return []
	if not grid_step > 0.0: return []
	var is_VC2 := graph.is_VC2()
	var EVC := graph.get_EVC()

	var grid: Dictionary = {}
	for ei in range(EVC.size()):
		var evc: Array = EVC[ei]; var cells: Array = [];
		if is_VC2: cells = Utilities.segment2_to_grid(evc[0], evc[1], grid_step)
		else: cells = Utilities.segment3_to_grid(evc[0], evc[1], grid_step)
		for cell in cells:
			grid.get_or_add(cell, []).append(ei)

	var intersection: Array = []
	intersection.resize(EVC.size())
	for index in range(EVC.size()):
		intersection[index] = {}

	for edges in grid.values():
		var d: int = edges.size()
		for index1 in range(d):
			for index2 in range(index1 + 1, d):
				var e1: int = edges[index1]
				var e2: int = edges[index2]
				intersection[e1][e2] = true
				intersection[e2][e1] = true

	for index in range(intersection.size()):
		intersection[index] = intersection[index].keys()
	return intersection


static func EVC2_intersect(graph: FoldGraph, grid_step: float, quantization: float = 0.0) -> void:
	if not graph.is_VC2(): return
	if not graph.EV.size(): return
	if not grid_step > 0.0: return
	if not quantization >= 0.0: return
	var has_EA := bool(graph.EA.size() > 0)
	var has_EFA := bool(graph.EFA.size() > 0)
	var is_quantized := bool(quantization != 0.0)
	var _q := sqrt(2.0) / 2.0 + 0.000001
	var EVC2 := graph.get_EVC()

	var new_VC: Array = []
	var new_EV: Array = []
	var new_EA: Array = []
	var new_EFA: Array = []

	var EVC2_expanded: Array = []
	if is_quantized:
		EVC2_expanded = EVC2.duplicate(true)
		for evc in EVC2_expanded:
			var direction: Vector2 = (evc[1] - evc[0]).normalized()
			var expansion := direction * quantization * _q
			evc[0] -= expansion; evc[1] += expansion;

	var grid_intersection := EV_grid_intersect(graph, grid_step)
	for ei in range(EVC2.size()):
		var e: Array = EVC2[ei]
		var from: Vector2 = e[0]
		var to: Vector2 = e[1]

		var segments: Array = [[from, 0.0]]
		for index in grid_intersection[ei]:
			var ee: Array = EVC2[index]
			var u: Vector2 = ee[0]; var v: Vector2 = ee[1];
			var p = Geometry2D.segment_intersects_segment(from, to, u, v)
			if p != null:
				if not from.is_equal_approx(p):
					if not to.is_equal_approx(p):
						segments.append([p, from.distance_squared_to(p)])
						continue
			if not is_quantized: continue
			var ee_expanded: Array = EVC2_expanded[index]
			u = ee_expanded[0]; v = ee_expanded[1];
			p = Geometry2D.segment_intersects_segment(from, to, u, v)
			if p != null:
				if not from.is_equal_approx(p):
					if not to.is_equal_approx(p):
						segments.append([p, from.distance_squared_to(p)])
						continue
		segments.sort_custom(func(a, uu): return a[1] < uu[1])
		for index in range(segments.size()):
			segments[index] = segments[index][0]
		segments.append(to)

		for index in range(segments.size() - 1):
			var i := new_VC.size()
			new_VC.append(segments[index])
			new_VC.append(segments[index + 1])
			new_EV.append([i, i + 1])
			if has_EA: new_EA.append(graph.EA[ei])
			if has_EFA: new_EFA.append(graph.EFA[ei])

	graph.clear("VV;VE;VF;EL;EO;FV;FE;FF;FO")
	graph.VC = new_VC
	graph.EV = new_EV
	graph.EA = new_EA
	graph.EFA = new_EFA
