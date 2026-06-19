static func VC_merge(graph: FoldGraph, distance: float) -> void:
	if not graph.is_VC23(): return
	var is_VC2 := graph.is_VC2()
	var has_EA := bool(graph.EA.size() > 0)
	var has_EFA := bool(graph.EFA.size() > 0)

	var new_VC: Array = []
	var VC_buckets: Dictionary = {}
	var VC_remap: PackedInt64Array = []
	var VC_degree: PackedInt32Array = []

	VC_remap.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc = graph.VC[index]
		var vcs = vc.snappedf(distance) / distance
		var vcb = (Vector2i(vcs) if is_VC2 else Vector3i(vcs))
		if not VC_buckets.has(vcb):
			var new_index := new_VC.size()
			VC_buckets[vcb] = new_index
			VC_remap[index] = new_index
			new_VC.append(Vector2.ZERO if is_VC2 else Vector3.ZERO)
		else: VC_remap[index] = VC_buckets[vcb]

	VC_degree.resize(new_VC.size())
	for index in range(graph.VC.size()):
		var index_remap: int = VC_remap[index]
		new_VC[index_remap] += graph.VC[index]
		VC_degree[index_remap] += 1
	for index in range(new_VC.size()):
		new_VC[index] /= VC_degree[index]

	var new_EV: Array = []
	var new_EA: Array = []
	var new_EFA: Array = []
	for ei in range(graph.EV.size()):
		var ev: Array = graph.EV[ei]
		var u: int = VC_remap[ev[0]]
		var v: int = VC_remap[ev[1]]
		if u == v: continue
		new_EV.append([u, v])
		if has_EA: new_EA.append(graph.EA[ei])
		if has_EFA: new_EFA.append(graph.EFA[ei])

	var new_FV: Array = []
	for index in range(graph.FV.size()):
		var vertices: Dictionary = {}
		for i in graph.FV[index]:
			vertices[VC_remap[i]] = true
		if vertices.size() < 3: continue
		new_FV.append(vertices.keys())

	# TODO: merge metadata arrays
	graph.clear()
	graph.VC = new_VC
	graph.EV = new_EV
	graph.EA = new_EA
	graph.EFA = new_EFA
	graph.FV = new_FV


static func VC2_triangulate(graph: FoldGraph, grid_step: float) -> bool:
	const UTILITIES := preload("utilities.gd")
	if not graph.is_VC2(): return false

	# delaunay triangulating vertices coordinates
	var triangles := Geometry2D.triangulate_delaunay(graph.VC)
	if triangles.is_empty(): return false

	# creating graph faces from triangles
	graph.FV.resize(triangles.size() / 3)
	for index in range(0, triangles.size(), 3):
		graph.FV[index / 3] = [
			triangles[index],
			triangles[index + 1],
			triangles[index + 2]]

	# returning oriented faces if graph edges are missing
	if not graph.EA.size():
		var FVC := graph.get_FVC()
		for index in range(graph.FV.size()):
			var fvc: Array = FVC[index]
			if Geometry2D.is_polygon_clockwise(fvc):
				graph.FV[index].reverse()
		graph.clear("VV;VE;VF;EF;FE;FF;FO")
		return true

	# finding edges faces and cells in triangulation
	var grid: Dictionary = {}
	var EF_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d: int = fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			var w: int = fv[(i + 2) % d]
			EF_map.get_or_add([u, v], {})[[fi, w]] = true
			EF_map.get_or_add([v, u], {})[[fi, w]] = true
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			for cell in UTILITIES.segment2_to_grid(uu, vv, grid_step):
				grid.get_or_add(cell, {})[[u, v]] = true
				grid.get_or_add(cell, {})[[v, u]] = true

	# constraining delaunay triangulation to graph edges
	var is_valid := true
	var old_FV := graph.FV.duplicate(true)
	for constrained_edge in graph.EV:
		if constrained_edge in EF_map: continue
		var from_u: int = constrained_edge[0]
		var to_v: int = constrained_edge[1]
		var from: Vector2 = graph.VC[from_u]
		var to: Vector2 = graph.VC[to_v]

		# finding nearby edges for the constrained edge
		var grid_edges: Dictionary = {}
		for cell in UTILITIES.segment2_to_grid(from, to, grid_step):
			for edge in grid.get(cell, []):
				var u: int = edge[0]; var v: int = edge[1];
				grid_edges[[u, v]] = true
				grid_edges[[v, u]] = true

		# finding nearby edges crossing the constrained edge
		var _i: int = -1
		var crossing_edges: Array = []
		for edge in grid_edges:
			_i += 1; if _i % 2 == 1: continue;
			var u: int = edge[0]; var v: int = edge[1];
			if from_u == u or to_v == v: continue
			if from_u == v or to_v == u: continue
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			if Geometry2D.segment_intersects_segment(from, to, uu, vv):
				crossing_edges.append([u, v])

		# swapping crossing faces diagonals until the edge is constrained
		var new_edges: Array = []
		var max_attempts: int = 250
		while crossing_edges.size() and max_attempts > 0:
			var edge: Array = crossing_edges.pop_back()
			var u: int = edge[0]; var v: int = edge[1];

			var faces: Array = EF_map.get([u, v], {}).keys()
			if not faces.size() >= 2: is_valid = false
			if max_attempts == 1: is_valid = false
			if not is_valid: break
			max_attempts -= 1

			# checking if faces form a convex quadrilateral
			var f1: int = faces[0][0]; var f2: int = faces[1][0];
			var w1: int = faces[0][1]; var w2: int = faces[1][1];
			var ww1: Vector2 = graph.VC[w1]; var ww2: Vector2 = graph.VC[w2];
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			if not Geometry2D.segment_intersects_segment(ww1, ww2, uu, vv):
				if crossing_edges.size() == 0: is_valid = false
				crossing_edges.push_front(edge)
				continue

			# swapping quadrilateral diagonals and updating grid cells
			EF_map.erase([u, v]); EF_map.erase([v, u]);
			EF_map[[w1, w2]] = {[f1, u]: true, [f2, v]: true}
			EF_map[[w2, w1]] = {[f1, u]: true, [f2, v]: true}
			EF_map.get([u, w1], {}).erase([f1, v])
			EF_map.get([w1, u], {}).erase([f1, v])
			EF_map.get([v, w1], {}).erase([f1, u])
			EF_map.get([w1, v], {}).erase([f1, u])
			EF_map.get([u, w2], {}).erase([f2, v])
			EF_map.get([w2, u], {}).erase([f2, v])
			EF_map.get([v, w2], {}).erase([f2, u])
			EF_map.get([w2, v], {}).erase([f2, u])
			EF_map.get_or_add([u, w1], {})[[f1, w2]] = true
			EF_map.get_or_add([v, w1], {})[[f2, w2]] = true
			EF_map.get_or_add([u, w2], {})[[f1, w1]] = true
			EF_map.get_or_add([v, w2], {})[[f2, w1]] = true
			EF_map.get_or_add([w1, u], {})[[f1, w2]] = true
			EF_map.get_or_add([w1, v], {})[[f2, w2]] = true
			EF_map.get_or_add([w2, u], {})[[f1, w1]] = true
			EF_map.get_or_add([w2, v], {})[[f2, w1]] = true
			for cell in UTILITIES.segment2_to_grid(uu, vv, grid_step):
				grid.get_or_add(cell, {}).erase([u, v])
				grid.get_or_add(cell, {}).erase([v, u])
			for cell in UTILITIES.segment2_to_grid(ww1, ww2, grid_step):
				grid.get_or_add(cell, {})[[w1, w2]] = true
				grid.get_or_add(cell, {})[[w2, w1]] = true
			graph.FV[f1] = [w1, u, w2]
			graph.FV[f2] = [w1, v, w2]

			# checking if the new diagonal is still crossing the edge
			var is_crossing := false
			if from_u == w1 or from_u == w2: is_crossing = false
			elif to_v == w1 or to_v == w2: is_crossing = false
			elif Geometry2D.segment_intersects_segment(from, to, ww1, ww2):
				is_crossing = true
			if is_crossing: crossing_edges.push_front([w1, w2])
			else: new_edges.append([w1, w2])
		if not is_valid: break

		# balancing new edges to satisfy the delaunay condition
		for edge in new_edges:
			var u: int = edge[0]; var v: int = edge[1];
			if from_u == u and to_v == v: continue
			if from_u == v and to_v == u: continue

			var faces: Array = EF_map.get([u, v], {}).keys()
			if not faces.size() >= 2:
				is_valid = false
				break

			# checking if faces form a convex quadrilateral
			var f1: int = faces[0][0]; var f2: int = faces[1][0];
			var w1: int = faces[0][1]; var w2: int = faces[1][1];
			var ww1: Vector2 = graph.VC[w1]; var ww2: Vector2 = graph.VC[w2];
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			if not Geometry2D.segment_intersects_segment(ww1, ww2, uu, vv):
				continue

			# checking if quadrilateral satisfies the delaunay condition
			var angle1: float = absf((uu - ww1).angle_to(vv - ww1))
			var angle2: float = absf((uu - ww2).angle_to(vv - ww2))
			if angle1 + angle2 <= PI: continue

			# swapping quadrilateral diagonals exactly like before
			EF_map.erase([u, v]); EF_map.erase([v, u]);
			EF_map[[w1, w2]] = {[f1, u]: true, [f2, v]: true}
			EF_map[[w2, w1]] = {[f1, u]: true, [f2, v]: true}
			EF_map.get([u, w1], {}).erase([f1, v])
			EF_map.get([w1, u], {}).erase([f1, v])
			EF_map.get([v, w1], {}).erase([f1, u])
			EF_map.get([w1, v], {}).erase([f1, u])
			EF_map.get([u, w2], {}).erase([f2, v])
			EF_map.get([w2, u], {}).erase([f2, v])
			EF_map.get([v, w2], {}).erase([f2, u])
			EF_map.get([w2, v], {}).erase([f2, u])
			EF_map.get_or_add([u, w1], {})[[f1, w2]] = true
			EF_map.get_or_add([v, w1], {})[[f2, w2]] = true
			EF_map.get_or_add([u, w2], {})[[f1, w1]] = true
			EF_map.get_or_add([v, w2], {})[[f2, w1]] = true
			EF_map.get_or_add([w1, u], {})[[f1, w2]] = true
			EF_map.get_or_add([w1, v], {})[[f2, w2]] = true
			EF_map.get_or_add([w2, u], {})[[f1, w1]] = true
			EF_map.get_or_add([w2, v], {})[[f2, w1]] = true
			for cell in UTILITIES.segment2_to_grid(uu, vv, grid_step):
				grid.get_or_add(cell, {}).erase([u, v])
				grid.get_or_add(cell, {}).erase([v, u])
			for cell in UTILITIES.segment2_to_grid(ww1, ww2, grid_step):
				grid.get_or_add(cell, {})[[w1, w2]] = true
				grid.get_or_add(cell, {})[[w2, w1]] = true
			graph.FV[f1] = [w1, u, w2]
			graph.FV[f2] = [w1, v, w2]
		if not is_valid: break
	if not is_valid:
		graph.FV = old_FV
		return false

	# preparing to remove additional faces and create holes
	var EV_map := graph.get_EV_map()
	var _J_ := FoldGraph.EdgeAssignment.JOIN
	var _B_ := FoldGraph.EdgeAssignment.BOUNDARY
	var _C_ := FoldGraph.EdgeAssignment.CUT
	var _BCJ_ := _B_ + _C_ + _J_
	var _BC_ := _B_ + _C_

	var g_sign: int = 0
	var faces_queue: Array = []
	var faces_signs: Array = []
	faces_signs.resize(graph.FV.size())
	faces_signs.fill(-1)

	var sign_has_crease: Dictionary = {}
	var sign_has_open_boundary: Dictionary = {}
	var sign_has_boundary: Dictionary = {}
	var sign_neighbors: Dictionary = {}

	if graph.FV.size() > 0:
		faces_queue.append(0)
	while faces_queue.size():
		var fi: int = faces_queue.pop_back()
		var fv: Array = graph.FV[fi]
		var d: int = fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			var ei = EV_map.get([u, v], null)
			var ea: String = (graph.EA[ei] if ei != null else _J_)

			# trying to grow faces area and signing nearby faces
			var f: int = -1
			for ff in EF_map.get([u, v], []): if ff[0] != fi: f = ff[0];
			if not ea in _BC_ and (f >= 0 and faces_signs[f] < 0):
				faces_signs[f] = g_sign; faces_queue.append(f);

			# determining useful properties of the signed area
			if not ea in _BCJ_: sign_has_crease[g_sign] = true
			if f < 0 and ea in _J_: sign_has_open_boundary[g_sign] = true
			if f < 0 and ea in _BC_: sign_has_boundary[g_sign] = true
			elif ea in _BC_: sign_neighbors.get_or_add(g_sign, {})[f] = true

		# incrementing the sign when exhausted faces area
		if not faces_queue.size():
			var index := faces_signs.find(-1)
			if index < 0: break
			g_sign += 1
			faces_signs[index] = g_sign
			faces_queue.append(index)

	# trying to remove faces areas that have open boundary
	for sign in sign_neighbors:
		for neighbor in sign_neighbors[sign]:
			var neighbor_sign: int = faces_signs[neighbor]
			if sign_has_open_boundary.get(neighbor_sign, false):
				sign_neighbors[sign] = null
				break

	# removing additional faces and creating holes
	var new_FV: Array = []
	for index in range(graph.FV.size()):
		var sign: int = faces_signs[index]
		if sign_has_crease.get(sign, false):
			new_FV.append(graph.FV[index])
			continue
		if sign_has_open_boundary.get(sign, false):
			continue
		if sign_has_boundary.get(sign, false):
			new_FV.append(graph.FV[index])
			continue
		if sign_neighbors[sign] == null:
			new_FV.append(graph.FV[index])
	graph.FV = new_FV

	# TODO: splitting edges marked as cut

	# orienting new graph faces
	var FVC := graph.get_FVC()
	for index in range(graph.FV.size()):
		var fvc: Array = FVC[index]
		if Geometry2D.is_polygon_clockwise(fvc):
			graph.FV[index].reverse()
	graph.clear("VV;VE;VF;EF;FE;FF;FO")

	return is_valid


static func VE_from_VV(graph: FoldGraph) -> bool:
	var EV_map := graph.get_EV_map()
	var new_VE: Array[Array] = []
	new_VE.resize(graph.VV.size())
	for vi in range(graph.VV.size()):
		var vv: Array = graph.VV[vi]
		var ve: Array = new_VE[vi]
		var d := vv.size()
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

	var new_VF: Array[Array] = []
	new_VF.resize(graph.VV.size())
	for vi in range(graph.VV.size()):
		var vv: Array = graph.VV[vi]
		var vf: Array = new_VF[vi]
		var d := vv.size()
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
