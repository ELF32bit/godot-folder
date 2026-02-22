static func VC_merge(graph: FoldGraph, distance: float) -> void:
	if not graph.is_VC23(): return
	var is_VC2 := graph.is_VC2()
	var has_EA := bool(graph.EA.size() > 0)
	var has_EFA := bool(graph.EFA.size() > 0)

	var new_VC: Array = []
	var buckets: Dictionary = {}
	var VC_remap: PackedInt64Array = []
	var VC_degree: PackedInt32Array = []

	VC_remap.resize(graph.VC.size())
	for index in range(graph.VC.size()):
		var vc = graph.VC[index]
		var vcs = vc.snappedf(distance) / distance
		var vcb = (Vector2i(vcs) if is_VC2 else Vector3i(vcs))
		if not buckets.has(vcb):
			var new_index := new_VC.size()
			buckets[vcb] = new_index
			VC_remap[index] = new_index
			new_VC.append(Vector2.ZERO if is_VC2 else Vector3.ZERO)
		else: VC_remap[index] = buckets[vcb]

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
	const Utilities := preload("utilities.gd")
	if not graph.is_VC2(): return false
	if not graph.EA.size(): return false

	# delaunay triangulating vertices coordinates
	var triangles := Geometry2D.triangulate_delaunay(graph.VC)
	if not triangles.size(): return false
	var old_FV := graph.FV.duplicate(true)
	var is_valid := true

	graph.FV.resize(triangles.size() / 3)
	for index in range(0, triangles.size(), 3):
		graph.FV[index / 3] = [
			triangles[index],
			triangles[index + 1],
			triangles[index + 2]]

	# finding edges faces and cells
	var grid: Dictionary = {}
	var EF_map: Dictionary = {}
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d: int = fv.size()
		for i in range(d):
			var u: int = fv[i]
			var v: int = fv[(i + 1) % d]
			var w: int = fv[(i + 2) % d]
			EF_map.get_or_add([u, v], []).append([fi, w])
			EF_map.get_or_add([v, u], []).append([fi, w])
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			for cell in Utilities.segment2_to_grid(uu, vv, grid_step):
				grid.get_or_add(cell, {})[[u, v]] = true
				grid.get_or_add(cell, {})[[v, u]] = true

	# constraining delaunay triangulation to graph edges
	for constrained_edge in graph.EV:
		if constrained_edge in EF_map: continue
		var from_u: int = constrained_edge[0]
		var to_v: int = constrained_edge[1]
		var from: Vector2 = graph.VC[from_u]
		var to: Vector2 = graph.VC[to_v]

		var grid_edges: Dictionary = {}
		for cell in Utilities.segment2_to_grid(from, to, grid_step):
			for edge in grid.get(cell, []):
				var u: int = edge[0]; var v: int = edge[1];
				grid_edges[[u, v]] = true
				grid_edges[[v, u]] = true

		var _i: int = -1
		var crossing_edges: Array = []
		for edge in grid_edges:
			_i += 1; if _i % 2 == 1: continue
			var u: int = edge[0]; var v: int = edge[1];
			if from_u == u or to_v == v: continue
			if from_u == v or to_v == u: continue
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			if Geometry2D.segment_intersects_segment(from, to, uu, vv):
				crossing_edges.append([u, v])

		var new_edges: Array = []
		var max_attempts: int = 250
		while crossing_edges.size() and max_attempts > 0:
			var edge: Array = crossing_edges.pop_back()
			var u: int = edge[0]; var v: int = edge[1];

			var faces: Array = EF_map[[u, v]]
			if not faces.size() >= 2: is_valid = false
			if max_attempts == 1: is_valid = false
			if not is_valid: break
			max_attempts -= 1

			var f1: int = faces[0][0]; var f2: int = faces[1][0];
			var w1: int = faces[0][1]; var w2: int = faces[1][1];
			var ww1: Vector2 = graph.VC[w1]; var ww2: Vector2 = graph.VC[w2];
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			if not Geometry2D.segment_intersects_segment(ww1, ww2, uu, vv):
				if crossing_edges.size() == 0: is_valid = false
				crossing_edges.push_front(edge)
				continue

			EF_map.erase([u, v]); EF_map.erase([v, u]);
			EF_map[[w1, w2]] = [[f1, u], [f2, v]]
			EF_map[[w2, w1]] = [[f1, u], [f2, v]]
			EF_map[[u, w1]].erase([f1, v]); EF_map[[u, w1]].append([f1, w2]);
			EF_map[[v, w1]].erase([f1, u]); EF_map[[v, w1]].append([f2, w2]);
			EF_map[[u, w2]].erase([f2, v]); EF_map[[u, w2]].append([f1, w1]);
			EF_map[[v, w2]].erase([f2, u]); EF_map[[v, w2]].append([f2, w1]);
			EF_map[[w1, u]].erase([f1, v]); EF_map[[w1, u]].append([f1, w2]);
			EF_map[[w1, v]].erase([f1, u]); EF_map[[w1, v]].append([f2, w2]);
			EF_map[[w2, u]].erase([f2, v]); EF_map[[w2, u]].append([f1, w1]);
			EF_map[[w2, v]].erase([f2, u]); EF_map[[w2, v]].append([f2, w1]);
			for cell in Utilities.segment2_to_grid(uu, vv, grid_step):
				grid.get_or_add(cell, {}).erase([u, v])
				grid.get_or_add(cell, {}).erase([v, u])
			for cell in Utilities.segment2_to_grid(ww1, ww2, grid_step):
				grid.get_or_add(cell, {})[[w1, w2]] = true
				grid.get_or_add(cell, {})[[w2, w1]] = true
			graph.FV[f1] = [w1, u, w2]
			graph.FV[f2] = [w1, v, w2]

			var is_crossing := false
			if from_u == w1 or from_u == w2: is_crossing = false
			elif to_v == w1 or to_v == w2: is_crossing = false
			elif Geometry2D.segment_intersects_segment(from, to, ww1, ww2):
				is_crossing = true
			if is_crossing: crossing_edges.push_front([w1, w2])
			else: new_edges.append([w1, w2])
		if not is_valid: break

		for edge in new_edges:
			var u: int = edge[0]; var v: int = edge[1];
			if from_u == u and to_v == v: continue
			if from_u == v and to_v == u: continue

			var faces: Array = EF_map[[u, v]]
			if not faces.size() >= 2:
				is_valid = false
				break

			var f1: int = faces[0][0]; var f2: int = faces[1][0];
			var w1: int = faces[0][1]; var w2: int = faces[1][1];
			var ww1: Vector2 = graph.VC[w1]; var ww2: Vector2 = graph.VC[w2];
			var uu: Vector2 = graph.VC[u]; var vv: Vector2 = graph.VC[v];
			if not Geometry2D.segment_intersects_segment(ww1, ww2, uu, vv):
				continue

			var angle1: float = absf((uu - ww1).angle_to(vv - ww1))
			var angle2: float = absf((uu - ww2).angle_to(vv - ww2))
			if angle1 + angle2 <= PI: continue

			EF_map.erase([u, v]); EF_map.erase([v, u]);
			EF_map[[w1, w2]] = [[f1, u], [f2, v]]
			EF_map[[w2, w1]] = [[f1, u], [f2, v]]
			EF_map[[u, w1]].erase([f1, v]); EF_map[[u, w1]].append([f1, w2]);
			EF_map[[v, w1]].erase([f1, u]); EF_map[[v, w1]].append([f2, w2]);
			EF_map[[u, w2]].erase([f2, v]); EF_map[[u, w2]].append([f1, w1]);
			EF_map[[v, w2]].erase([f2, u]); EF_map[[v, w2]].append([f2, w1]);
			EF_map[[w1, u]].erase([f1, v]); EF_map[[w1, u]].append([f1, w2]);
			EF_map[[w1, v]].erase([f1, u]); EF_map[[w1, v]].append([f2, w2]);
			EF_map[[w2, u]].erase([f2, v]); EF_map[[w2, u]].append([f1, w1]);
			EF_map[[w2, v]].erase([f2, u]); EF_map[[w2, v]].append([f2, w1]);
			for cell in Utilities.segment2_to_grid(uu, vv, grid_step):
				grid.get_or_add(cell, {}).erase([u, v])
				grid.get_or_add(cell, {}).erase([v, u])
			for cell in Utilities.segment2_to_grid(ww1, ww2, grid_step):
				grid.get_or_add(cell, {})[[w1, w2]] = true
				grid.get_or_add(cell, {})[[w2, w1]] = true
			graph.FV[f1] = [w1, u, w2]
			graph.FV[f2] = [w1, v, w2]

		if not is_valid: break
	if not is_valid:
		graph.FV = old_FV
		return false

	# removing extra faces and creating holes
	var EV_map := graph.get_EV_map()
	var J := FoldGraph.EdgeAssignment.JOIN
	var B := FoldGraph.EdgeAssignment.BOUNDARY
	var C := FoldGraph.EdgeAssignment.CUT
	var BCJ := B + C + J
	var BC := B + C

	var g_sign: int = 0
	var faces_queue: Array = []
	var faces_signs: Array = []
	faces_signs.resize(graph.FV.size())
	faces_signs.fill(-1)

	var sign_has_crease: Dictionary = {}
	var sign_has_open_boundary: Dictionary = {}
	var sign_has_boundary: Dictionary = {}
	var sign_neighbours: Dictionary = {}

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
			var uv: String = (graph.EA[ei] if ei != null else J)

			var f: int = -1
			for ff in EF_map[[u, v]]: if ff[0] != fi: f = ff[0];
			if not uv in BC and (f >= 0 and faces_signs[f] < 0):
				faces_signs[f] = g_sign; faces_queue.append(f);

			if not uv in BCJ: sign_has_crease[g_sign] = true
			if f < 0 and uv in J: sign_has_open_boundary[g_sign] = true
			if f < 0 and uv in BC: sign_has_boundary[g_sign] = true
			elif uv in BC: sign_neighbours.get_or_add(g_sign, {})[f] = true

		if not faces_queue.size():
			var index := faces_signs.find(-1)
			if index < 0: break
			g_sign += 1
			faces_signs[index] = g_sign
			faces_queue.append(index)

	for sign in sign_neighbours:
		for neighbour in sign_neighbours[sign]:
			var neighbour_sign: int = faces_signs[neighbour]
			if sign_has_open_boundary.get(neighbour_sign, false):
				sign_neighbours[sign] = null
				break

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
		if sign_neighbours[sign] == null:
			new_FV.append(graph.FV[index])
	graph.FV = new_FV

	# TODO: splitting edges marked as cut

	# orienting new graph faces
	var FVC := graph.get_FVC()
	for index in range(graph.FV.size()):
		var fvc: Array = FVC[index]
		if Geometry2D.is_polygon_clockwise(fvc):
			graph.FV[index].reverse()

	return is_valid


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
