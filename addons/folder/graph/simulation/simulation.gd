#class_name FoldGraphSimulation3D

var graph: FoldGraph
var axial_stiffness: float = 20.0
var fold_stiffness: float = 0.7
var join_stiffness: float = 0.7
var face_stiffness: float = 0.2
var damping_ratio: float = 0.45
var delta_ratio: float = 0.9

var _dt: float
var _fv: PackedFloat32Array
var _fp: PackedFloat32Array
var _k: PackedFloat32Array
var _fvn: PackedFloat32Array
var _fvni: PackedFloat32Array
var _fvnii: PackedFloat32Array
var _fva: PackedFloat32Array
var _fvv: PackedFloat32Array
var _center: Vector3

var _rd: RenderingDevice
var _simulation_shader: RID
var _simulation_pipeline: RID
var _integration_shader: RID
var _integration_pipeline: RID

@warning_ignore("shadowed_variable")
func _init(graph: FoldGraph) -> void:
	self.graph = graph


func begin() -> void:
	if not graph.is_VC3(): return
	if not graph.EV.size(): return

	# preparing to find vertices vertices
	var vvi: Array = []
	var vvii: Array = []
	vvi.resize(graph.VC.size())
	vvii.resize(graph.VC.size())
	for index in range(vvi.size()):
		vvii[index] = {}
		vvi[index] = {}

	# finding edges faces and vertices vertices
	var ef: Dictionary = {}
	for face_index in range(graph.FV.size()):
		var face: Array = graph.FV[face_index]
		var d: int = face.size()
		for index in range(d):
			var ii: int = face_index * 3
			var ui: int = index
			var vi: int = (index + 1) % d
			var wi: int = (index + 2) % d
			var u: int = face[ui]
			var v: int = face[vi]
			var w: int = face[wi]
			ef.get_or_add([u, v], []).append([face_index, wi])
			ef.get_or_add([v, u], []).append([face_index, wi])
			vvii[u][v] = ii + index; vvii[v][u] = ii + index;
			vvi[u][v] = ii + vi; vvi[v][u] = ii + ui;

	_fvn.clear(); _fvni.clear(); _fvnii.clear();
	for index in range(graph.VC.size()):
		var i: Array = vvi[index].values()
		var ii: Array = vvii[index].values()
		_fvn.append(_fvni.size())
		_fvni.append_array(i)
		_fvnii.append_array(ii)
		_fvn.append(_fvni.size())

	_dt = 0.0
	_center = Vector3.ZERO
	_fv.resize(graph.FV.size() * 12)
	_fva.resize(graph.FV.size() * 12); _fva.fill(0.0);
	_fp.resize(graph.FV.size() * 12); _fp.fill(-1.0);
	_k.resize(graph.FV.size() * 12); _k.fill(0.0);

	# calculating vertices mass
	_fvv.resize(graph.FV.size() * 12); _fvv.fill(0.0);
	for index in range(3, _fvv.size(), 4):
		_fvv[index] = 1.0

	var ev := graph.get_EV_map()
	for face_index in range(graph.FV.size()):
		var face: Array = graph.FV[face_index]
		var d := face.size()
		for index in range(d):
			var u: int = face[index]
			var v: int = face[(index + 1) % d]
			var w: int = face[(index + 2) % d]
			var uu: Vector3 = graph.VC[u]
			var vv: Vector3 = graph.VC[v]
			var ww: Vector3 = graph.VC[w]

			# finding faces vertices coordinates
			var i := face_index * 12 + index * 4
			_fv[i + 0] = uu.x
			_fv[i + 1] = uu.y
			_fv[i + 2] = uu.z
			_fv[i + 3] = float(u)

			# calculating faces parameters
			var edge_index: int = ev[[u, v]]
			_fp[i + 0] = uu.distance_to(vv)
			_fp[i + 1] = (vv - uu).angle_to(ww - uu)
			_fp[i + 2] = deg_to_rad(graph.EFA[edge_index])
			for edge_face in ef[[u, v]]:
				var efi: int = edge_face[0]
				var efwi: int = edge_face[1]
				if efi == face_index: continue
				_fp[i + 3] = float(efi * 3 + efwi)
				break

			# calculating faces coefficients
			var ii := face_index * 12 + ((index + 1) % d) * 4
			var edge_mass := minf(_fvv[i + 3], _fvv[ii + 3])
			_k[i + 0] = axial_stiffness / _fp[i]
			match graph.EA[edge_index]:
				FoldGraph.EdgeAssignment.MOUNTAIN:
					_k[i + 1] = fold_stiffness * _fp[i]
				FoldGraph.EdgeAssignment.VALLEY:
					_k[i + 1] = fold_stiffness * _fp[i]
				FoldGraph.EdgeAssignment.JOIN:
					_k[i + 1] = join_stiffness * _fp[i]
			_k[i + 2] = 2.0 * damping_ratio * sqrt(_k[i] * edge_mass)
			_k[i + 3] = face_stiffness

			# calculating delta time for the simulation
			_dt = maxf(_dt, sqrt(_k[i] / edge_mass));
	_dt = (delta_ratio / (2.0 * PI * _dt) if _dt != 0.0 else 0.0)

	# creating local rendering device
	_rd = RenderingServer.create_local_rendering_device()
	const simulation_shader: RDShaderFile = preload("simulation.glsl")
	const integration_shader: RDShaderFile = preload("integration.glsl")
	_simulation_shader = _rd.shader_create_from_spirv(simulation_shader.get_spirv())
	_integration_shader = _rd.shader_create_from_spirv(integration_shader.get_spirv())


func _begin_storage_buffer(bytes: PackedByteArray) -> RID:
	return _rd.storage_buffer_create(bytes.size(), bytes)


func _begin_uniform(storage_buffer: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(storage_buffer)
	return uniform


func simulate(delta: float) -> void:
	if not _rd: return
	_simulation_pipeline = _rd.compute_pipeline_create(_simulation_shader)
	_integration_pipeline = _rd.compute_pipeline_create(_integration_shader)

	var p := PackedFloat32Array([float(graph.FV.size()), _dt,
		_center.x, _center.y, _center.z, 0.0])
	var p_buffer := _begin_storage_buffer(p.to_byte_array())
	var fv_buffer := _begin_storage_buffer(_fv.to_byte_array())
	var fp_buffer := _begin_storage_buffer(_fp.to_byte_array())
	var k_buffer := _begin_storage_buffer(_k.to_byte_array())
	var fvn_buffer := _begin_storage_buffer(_fvn.to_byte_array())
	var fvni_buffer := _begin_storage_buffer(_fvni.to_byte_array())
	var fvnii_buffer := _begin_storage_buffer(_fvnii.to_byte_array())
	var fva_buffer := _begin_storage_buffer(_fva.to_byte_array())
	var fvv_buffer := _begin_storage_buffer(_fvv.to_byte_array())

	var p_uniform := _begin_uniform(p_buffer, 0)
	var fv_uniform := _begin_uniform(fv_buffer, 1)
	var fp_uniform := _begin_uniform(fp_buffer, 2)
	var k_uniform := _begin_uniform(k_buffer, 3)
	var fvn_uniform := _begin_uniform(fvn_buffer, 4)
	var fvni_uniform := _begin_uniform(fvni_buffer, 5)
	var fvnii_uniform := _begin_uniform(fvnii_buffer, 6)
	var fva_uniform := _begin_uniform(fva_buffer, 7)
	var fvv_uniform := _begin_uniform(fvv_buffer, 8)

	var simulation_set := _rd.uniform_set_create([
		p_uniform,
		fv_uniform,
		fp_uniform,
		k_uniform,
		fvn_uniform,
		fvni_uniform,
		fvnii_uniform,
		fva_uniform,
		fvv_uniform,
	], _simulation_shader, 0)

	var integration_set := _rd.uniform_set_create([
		p_uniform,
		fv_uniform,
		fva_uniform,
		fvv_uniform,
	], _integration_shader, 1)

	var compute_list := _rd.compute_list_begin()
	for index in range(1):
		_rd.compute_list_bind_compute_pipeline(compute_list, _simulation_pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, simulation_set, 0)
		_rd.compute_list_dispatch(compute_list, graph.FV.size(), 1, 1)
		_rd.compute_list_add_barrier(compute_list)
		_rd.compute_list_bind_compute_pipeline(compute_list, _integration_pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, integration_set, 1)
		_rd.compute_list_dispatch(compute_list, graph.FV.size(), 1, 1)
		_rd.compute_list_add_barrier(compute_list)
	_rd.compute_list_end()
	_rd.submit()
	_rd.sync()

	_fv = _rd.buffer_get_data(fv_buffer).to_float32_array()
	_fva = _rd.buffer_get_data(fva_buffer).to_float32_array()
	_fvv = _rd.buffer_get_data(fvv_buffer).to_float32_array()

	var aabb := AABB()
	for face_index in range(graph.FV.size()):
		var face: Array = graph.FV[face_index]
		for index in range(face.size()):
			var ii: int = face[index]
			var i := face_index * 12 + index * 4
			aabb = aabb.expand(Vector3(_fv[i], _fv[i + 1], _fv[i + 2]))
	_center = aabb.get_center()

	for face_index in range(graph.FV.size()):
		var face: Array = graph.FV[face_index]
		for index in range(face.size()):
			var ii: int = face[index]
			var i := face_index * 12 + index * 4
			graph.VC[ii] = Vector3(_fv[i], _fv[i + 1], _fv[i + 2]) - _center
			_fv[i] -= _center.x
			_fv[i + 1] -= _center.y
			_fv[i + 2] -= _center.z

	_rd.free_rid(p_buffer)
	_rd.free_rid(fv_buffer)
	_rd.free_rid(fp_buffer)
	_rd.free_rid(k_buffer)
	_rd.free_rid(fvn_buffer)
	_rd.free_rid(fvni_buffer)
	_rd.free_rid(fvnii_buffer)
	_rd.free_rid(fva_buffer)
	_rd.free_rid(fvv_buffer)
	_rd.free_rid(_simulation_pipeline)
	_rd.free_rid(_integration_pipeline)
