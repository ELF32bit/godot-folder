extends "utilities.gd"


static func validate_frame_parents(fold: Fold, frame_index: int) -> bool:
	var frame_parents: Dictionary = {}
	var frame_parent := fold.get_frame_parent(frame_index)
	while frame_parent:
		if frame_parent in frame_parents:
			return false
		frame_parents[frame_parent] = true
		frame_parent = fold.get_frame(frame_parent.parent)
	return true


static func validate_VC_sizes(graph: FoldGraph) -> bool:
	if graph.VC.size() == 0: return true
	if not graph.VC[0] is Array: return true
	var expected_size: int = graph.VC[0].size()
	if not expected_size >= 2: return false
	for vc in graph.VC:
		if vc.size() != expected_size:
			return false
	return true


static func validate_EV_sizes(graph: FoldGraph) -> bool:
	for ev in graph.EV:
		if ev.size() != 2:
			return false
	return true


static func validate_EA_values(graph: FoldGraph) -> bool:
	for ea in graph.EA:
		if not ea.length() == 1: return false
		if not ea in FoldGraph.EdgeAssignment.ANY:
			return false
	return true


static func validate_EA_with_EFA(graph: FoldGraph) -> bool:
	if graph.EA.size() == 0: return true
	if graph.EFA.size() == 0: return true
	for index in range(graph.EA.size()):
		var ea: String = graph.EA[index]
		var efa: float = graph.EFA[index]
		match ea:
			"M": if efa > 0.0: return false
			"V": if efa < 0.0: return false
			_: if efa != 0.0: return false
	return true


static func validate_EL_values(graph: FoldGraph) -> bool:
	for el in graph.EL:
		if el < 0.0: return false
	return true


static func validate_FV_sizes(graph: FoldGraph) -> bool:
	for fv in graph.FV:
		if fv.size() < 3: return false
	return true


static func validate_orders(orders_array: Array) -> bool:
	var pairs := {}
	for order in orders_array:
		if not order.size() == 3: return false
		if not order[2] in [-1, 0, 1]: return false
		var u: int = order[0]; var v: int = order[1];
		if u == v: return false
		if pairs.has([u, v]): return false
		pairs[[u, v]] = true; pairs[[v, u]] = true;
	return true


static func validate_equal_sizes(arrays: Array[Array], offset: int) -> Array:
	var errors: Array = []
	var K := GRAPH_KEYS.keys()
	for i in range(arrays.size()):
		var s1 := arrays[i].size()
		if s1 == 0: continue
		for j in range(i + 1, arrays.size()):
			var s2 := arrays[j].size()
			if s2 == 0: continue
			if s1 != s2:
				errors.append([K[j + offset], K[i + offset]])
	return errors


static func validate_references(array1: Array, array2: Array) -> bool:
	var max_index := array2.size()
	for indices in array1:
		for index in indices:
			if index != null and index >= max_index:
				return false
	return true


static func validate_reflexive(array1: Array, array2: Array) -> bool:
	if array1.size() == 0: return true
	if array2.size() == 0: return true

	var _validate := func(array: Array, map: Array[Dictionary]) -> bool:
		for index in range(array.size()):
			for u in array[index]:
				if u == null: continue
				if not map[u].has(index):
					return false
		return true

	if is_same(array1, array2):
		if not _validate.call(array1, __to_map1(array2)): return false
	else:
		if not _validate.call(array1, __to_map1(array2)): return false
		if not _validate.call(array2, __to_map1(array1)): return false
	return true


static func validate_VV_VE_winding(graph: FoldGraph) -> bool:
	if graph.VV.size() == 0: return true
	if graph.VE.size() == 0: return true
	if graph.EV.size() == 0: return true

	for vi in range(graph.VV.size()):
		var vv: Array = graph.VV[vi]
		var ve: Array = graph.VE[vi]
		for i in range(vv.size()):
			var vvi: int = vv[i]
			var vei: int = ve[i]
			var ve_u: int = graph.EV[vei][0]
			var ve_v: int = graph.EV[vei][1]

			if ve_u == vi and ve_v == vvi: continue
			elif ve_u == vvi and ve_v == vi: continue
			else: return false
	return true


static func validate_VV_VF_winding(graph: FoldGraph) -> bool:
	if graph.VV.size() == 0: return true
	if graph.VF.size() == 0: return true
	if graph.FV.size() == 0: return true

	var FV_map := __to_map3(graph.FV)
	for vi in range(graph.VV.size()):
		var vv: Array = graph.VV[vi]
		var d := vv.size()
		for i in range(d):
			var vvi: int = vv[i]
			var vnvi: int = vv[(i + 1) % d]
			var vfi = __get(graph.VF[vi], i)
			if vfi == null: continue

			var vfi_map := FV_map[vfi]
			if vfi_map.has([vvi, vi, vnvi]): continue
			elif vfi_map.has([vnvi, vi, vvi]): continue
			else: return false
	return true


static func validate_VE_VF_winding(graph: FoldGraph) -> bool:
	if graph.VE.size() == 0: return true
	if graph.VF.size() == 0: return true
	if graph.FE.size() == 0: return true

	var FE_map := __to_map2(graph.FE)
	for vi in range(graph.VE.size()):
		var ve: Array = graph.VE[vi]
		var d := ve.size()
		for i in range(d):
			var vei: int = ve[i]
			var vnei: int = ve[(i + 1) % d]
			var vfi = __get(graph.VF[vi], i)
			if vfi == null: continue

			var vfi_map := FE_map[vfi]
			if vfi_map.has([vei, vnei]): continue
			elif vfi_map.has([vnei, vei]): continue
			return false
	return true


static func validate_FV_FE_winding(graph: FoldGraph) -> bool:
	if graph.FV.size() == 0: return true
	if graph.FE.size() == 0: return true
	if graph.EV.size() == 0: return true

	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()
		for i in range(d):
			var fvi: int = fv[i]
			var fnvi: int = fv[(i + 1) % d]
			var fei: int = graph.FE[fi][i]
			var fe: Array = graph.EV[fei]
			var fe_u: int = fe[0]
			var fe_v: int = fe[1]

			if fe_u == fvi and fe_v == fnvi: continue
			elif fe_u == fnvi and fe_v == fvi: continue
			else: return false
	return true


static func validate_FV_FF_winding(graph: FoldGraph) -> bool:
	if graph.FV.size() == 0: return true
	if graph.FF.size() == 0: return true

	var FV_map := __to_map2(graph.FV)
	for fi in range(graph.FV.size()):
		var fv: Array = graph.FV[fi]
		var d := fv.size()
		for i in range(d):
			var fvi: int = fv[i]
			var fnvi: int = fv[(i + 1) % d]
			var ffi = __get(graph.FF[fi], i)
			if ffi == null: continue

			var ffi_map := FV_map[ffi]
			if ffi_map.has([fvi, fnvi]): continue
			elif ffi_map.has([fnvi, fvi]): continue
			else: return false
	return true


static func validate_FE_FF_winding(graph: FoldGraph) -> bool:
	if graph.FE.size() == 0: return true
	if graph.FF.size() == 0: return true
	if graph.EF.size() == 0: return true

	for fi in range(graph.FE.size()):
		var fe: Array = graph.FE[fi]
		var ff: Array = graph.FF[fi]

		var f_ef: Array = []
		for i in range(fe.size()):
			var fei: int = fe[i]
			var prev_size := f_ef.size()
			for ef_fei in graph.EF[fei]:
				if ef_fei == fi: continue
				f_ef.append(ef_fei)
			if prev_size == f_ef.size():
				f_ef.append(null)

		for i in range(maxi(ff.size(), f_ef.size())):
			if __get(ff, i) != __get(f_ef, i):
				return false
	return true


static func _validate_frame_metadata(frame: FoldFrame) -> bool:
	if not frame.graph: return true
	var metadata := frame.metadata
	var graph := frame.graph

	var VP: Array = metadata.get("vertices_color", [])
	var NC: Array = metadata.get("normals_coords", [])
	var TC: Array = metadata.get("uvs_coords", [])
	var FN: Array = metadata.get("faces_normals", [])
	var FT: Array = metadata.get("faces_uvs", [])
	var FM: Array = metadata.get("faces_material", [])
	var FSG: Array = metadata.get("faces_smoothGroup", [])

	if not VP.size() in [0, graph.VC.size()]: return false
	if not FN.size() in [0, graph.FV.size()]: return false
	if not FT.size() in [0, graph.FV.size()]: return false
	if not FM.size() in [0, graph.FV.size()]: return false
	if not FSG.size() in [0, graph.FV.size()]: return false

	for index in range(FN.size()):
		if FN[index].size() != graph.FV[index].size(): return false
	for index in range(FT.size()):
		if FT[index].size() != graph.FV[index].size(): return false

	for vp in VP:
		if not vp.is_valid_html_color(): return false
	for nc in NC:
		if nc.size() != 3: return false
	for tc in TC:
		if tc.size() != 2: return false

	var max_index := NC.size()
	for indices in FN:
		for index in indices:
			if index >= max_index or index < 0:
				return false

	max_index = TC.size()
	for indices in FT:
		for index in indices:
			if index >= max_index or index < 0:
				return false
	return true
