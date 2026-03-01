class_name FoldGraphSimulation3D

var graph: FoldGraph
var fold_percent: float = 1.0
var axial_stiffness: float = 20.0
var fold_stiffness: float = 0.7
var join_stiffness: float = 0.7
var face_stiffness: float = 0.2
var damping_ratio: float = 0.45
var delta_ratio: float = 0.9

var _delta_time: float
var _vertices_velocity: PackedVector3Array
var _vertices_mass: PackedFloat32Array
var _edges_length: PackedFloat32Array
var _edges_triangles: Dictionary
var _edges_fold_angle: PackedFloat32Array
var _last_edges_fold_angle: PackedFloat32Array
var _triangles_angles: Array[Dictionary]
var _k_axial: PackedFloat32Array
var _k_crease: PackedFloat32Array
var _k_damping: PackedFloat32Array

@warning_ignore("shadowed_variable")
func _init(graph: FoldGraph) -> void:
	self.graph = graph


func begin() -> void:
	if not graph.is_VC3(): return
	if not graph.EA.size(): return
	if not graph.EFA.size():
		FoldGraphBuilder.Edges.EFA_from_EA(graph)
	FoldGraphBuilder.Edges.EL_from_EVC(graph)

	_vertices_velocity.resize(graph.VC.size())
	_vertices_velocity.fill(Vector3.ZERO)
	_vertices_mass.resize(graph.VC.size())
	_vertices_mass.fill(1.0)

	_edges_length = graph.EL.duplicate(true)
	_edges_triangles = _get_edges_triangles(graph)
	_edges_fold_angle.resize(graph.EFA.size())
	for index in range(graph.EFA.size()):
		_edges_fold_angle[index] = deg_to_rad(graph.EFA[index])
	_triangles_angles = _get_triangles_angles(graph)

	_delta_time = 0.0
	_k_axial.resize(_edges_length.size())
	for index in range(_edges_length.size()):
		_k_axial[index] = axial_stiffness / _edges_length[index]
		_delta_time = maxf(_delta_time, sqrt(_k_axial[index]))
	_delta_time = delta_ratio / (2.0 * PI * _delta_time)

	_k_crease.resize(_edges_length.size())
	for index in range(_edges_length.size()):
		match graph.EA[index]:
			FoldGraph.EdgeAssignment.CUT: _k_crease[index] = 0.0
			FoldGraph.EdgeAssignment.BOUNDARY: _k_crease[index] = 0.0
			FoldGraph.EdgeAssignment.JOIN:
				_k_crease[index] = face_stiffness * _edges_length[index]
			_: _k_crease[index] = fold_stiffness * _edges_length[index]

	_k_damping.resize(graph.EV.size())
	for index in range(graph.EV.size()):
		var ev: Array = graph.EV[index]
		_k_damping[index] = minf(_vertices_mass[ev[0]], _vertices_mass[ev[1]])
		_k_damping[index] = sqrt(_k_axial[index] * _k_damping[index])
		_k_damping[index] *= 2.0 * damping_ratio

	_last_edges_fold_angle.resize(graph.EV.size())
	_last_edges_fold_angle.fill(0.0)


func simulate() -> void:
	var vertices_force: PackedVector3Array = []
	vertices_force.resize(graph.VC.size())
	vertices_force.fill(Vector3.ZERO)

	var triangles_angles := _get_triangles_angles(graph)
	var triangles_normal := _get_triangles_normal(graph)
	var triangles_area := _get_triangles_area(graph)

	for index in range(graph.EV.size()):
		var edge: Array = graph.EV[index]
		var u: int = edge[0]; var v: int = edge[1];
		var uu: Vector3 = graph.VC[u]; var vv: Vector3 = graph.VC[v];

		var uv_velocity = _vertices_velocity[v] - _vertices_velocity[u];
		if absf(uv_velocity.x) < 0.0001: uv_velocity.x = 0.0
		if absf(uv_velocity.y) < 0.0001: uv_velocity.y = 0.0
		if absf(uv_velocity.z) < 0.0001: uv_velocity.z = 0.0
		vertices_force[u] += _k_damping[index] * uv_velocity
		vertices_force[v] -= _k_damping[index] * uv_velocity

		var axis := uu.direction_to(vv)
		var length := uu.distance_to(vv)
		var length0 := _edges_length[index]
		var f_axial := -_k_axial[index] * (length - length0) * axis
		if absf(length - length0) < 0.0001: f_axial = Vector3.ZERO
		vertices_force[u] -= f_axial; vertices_force[v] += f_axial;
		if _edges_triangles[edge].size() < 2: continue

		var triangles: Array = _edges_triangles[edge]
		var f1: int = triangles[0][0]; var f2: int = triangles[1][0];
		var w1: int = triangles[0][1]; var w2: int = triangles[1][1];
		var n1 := triangles_normal[f1]; var n2 := triangles_normal[f2];
		var fa1 := triangles_angles[f1]; var fa2 := triangles_angles[f2];

		var h1 := 2.0 * triangles_area[f1] / length
		var h2 := 2.0 * triangles_area[f2] / length
		var nh1 := n1 / h1; var nh2 := n2 / h2;
		if absf(h1) < 0.0001: nh1 = Vector3.ZERO
		if absf(h2) < 0.0001: nh2 = Vector3.ZERO

		var uc1: float = cos(fa1[[v, w1]]) / sin(fa1[[v, w1]])
		var uc2: float = cos(fa2[[v, w2]]) / sin(fa2[[v, w2]])
		var vc1: float = cos(fa1[[u, w1]]) / sin(fa1[[u, w1]])
		var vc2: float = cos(fa2[[u, w2]]) / sin(fa2[[u, w2]])
		var c1 := maxf(uc1 + vc1, 0.0001)
		var c2 := maxf(uc2 + vc2, 0.0001)

		var a0 := _edges_fold_angle[index]
		var a := atan2(n1.cross(-axis).dot(n2), clampf(n1.dot(n2), -1.0, 1.0))
		var a_delta := a - _last_edges_fold_angle[index]
		if a_delta < -5.0: a += 2.0 * PI
		elif a_delta > 5.0: a -= 2.0 * PI
		_last_edges_fold_angle[index] = a

		var f_crease = -_k_crease[index] * (a - a0 * fold_percent)
		if absf(a - a0 * fold_percent) < 0.0001: f_crease = 0.0
		vertices_force[w1] += f_crease * nh1
		vertices_force[w2] += f_crease * nh2
		vertices_force[u] += f_crease * (-vc1 * nh1 / c1 - vc2 * nh2 / c2)
		vertices_force[v] += f_crease * (-uc1 * nh1 / c1 - uc2 * nh2 / c2)

	for index in range(graph.FV.size()):
		var face: Array = graph.FV[index]
		var d := face.size()

		var n := triangles_normal[index]
		for i in range(d):
			var u: int = face[i]
			var v: int = face[(i + 1) % d]
			var w: int = face[(i + 2) % d]
			var uu: Vector3 = graph.VC[u]
			var vv: Vector3 = graph.VC[v]
			var ww: Vector3 = graph.VC[w]

			var c1 := (uu - vv); var c2 := (ww - vv);
			var cc1 := n * c1 / c1.length_squared()
			var cc2 := n * c2 / c2.length_squared()
			if c1.length() < 0.001: continue
			if c2.length() < 0.001: continue

			var a: float = triangles_angles[index][[u, w]]
			var a0: float = _triangles_angles[index][[u, w]]
			var f_face := -face_stiffness * (a - a0)
			if absf(a - a0) < 0.0001: f_face = 0.0
			vertices_force[u] += f_face * (cc1)
			vertices_force[v] += f_face * (-cc1 + cc2)
			vertices_force[w] += f_face * (-cc2)

	for index in range(graph.VC.size()):
		var acceleration := vertices_force[index] / _vertices_mass[index]
		_vertices_velocity[index] += acceleration * _delta_time
		graph.VC[index] += _vertices_velocity[index] * _delta_time

	FoldGraphBuilder.Coordinates.VC3_center(graph)


static func _get_edges_triangles(graph: FoldGraph) -> Dictionary:
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
	return EF_map


static func _get_triangles_angles(graph: FoldGraph) -> Array[Dictionary]:
	var FV_angles: Array[Dictionary] = []
	FV_angles.resize(graph.FV.size())
	for index in range(graph.FV.size()):
		var fv: Array = graph.FV[index]
		var angles := FV_angles[index]

		var u: int = fv[0]
		var v: int = fv[1]
		var w: int = fv[2]
		var uu: Vector3 = graph.VC[u]
		var vv: Vector3 = graph.VC[v]
		var ww: Vector3 = graph.VC[w]

		var ua := (ww - uu).angle_to(vv - uu)
		angles[[v, w]] = ua; angles[[w, v]] = ua;
		var va := (uu - vv).angle_to(ww - vv)
		angles[[u, w]] = va; angles[[w, u]] = va;
		var wa := (vv - ww).angle_to(uu - ww)
		angles[[u, v]] = wa; angles[[v, u]] = wa;
	return FV_angles


static func _get_triangles_normal(graph: FoldGraph) -> PackedVector3Array:
	var FV_normals: PackedVector3Array = []
	FV_normals.resize(graph.FV.size())
	for index in range(graph.FV.size()):
		var face: Array = graph.FV[index]
		var uu: Vector3 = graph.VC[face[0]]
		var vv: Vector3 = graph.VC[face[1]]
		var ww: Vector3 = graph.VC[face[2]]
		FV_normals[index] = Plane(uu, vv, ww).normal
	return FV_normals


static func _get_triangles_area(graph: FoldGraph) -> PackedFloat32Array:
	var FV_areas: PackedFloat32Array = []
	FV_areas.resize(graph.FV.size())
	for index in range(graph.FV.size()):
		var face: Array = graph.FV[index]
		var uu: Vector3 = graph.VC[face[0]]
		var vv: Vector3 = graph.VC[face[1]]
		var ww: Vector3 = graph.VC[face[2]]
		FV_areas[index] = (uu - ww).cross(vv - ww).length() * 0.5
	return FV_areas
