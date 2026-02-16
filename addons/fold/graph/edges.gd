static func EV_grid_intersect(graph: FoldGraph, grid_step: float) -> Array:
	const Utilities := preload("utilities.gd")
	if not graph.is_VC23(): return []
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
