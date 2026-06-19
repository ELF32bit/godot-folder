@tool
class_name FoldGraph
extends Resource

@export var VC: Array # vertices_coords
@export var VV: Array # vertices_vertices
@export var VE: Array # vertices_edges
@export var VF: Array # vertices_faces
@export var EV: Array # edges_vertices
@export var EF: Array # edges_faces
@export var EA: Array # edges_assignment
@export var EFA: Array # edges_foldAngle
@export var EL: Array # edges_length
@export var EO: Array # edgeOrders
@export var FV: Array # faces_vertices
@export var FE: Array # faces_edges
@export var FF: Array # faces_faces
@export var FO: Array # faceOrders
var frame_metadata: Dictionary

class EdgeAssignment:
	const BOUNDARY: String = "B"
	const MOUNTAIN: String = "M"
	const VALLEY: String = "V"
	const FLAT: String = "F"
	const UNKNOWN: String = "U"
	const CUT: String = "C"
	const JOIN: String = "J"
	const ANY: String = "BMVFUCJ"

class EdgeOrder:
	const LEFT: int = 1
	const RIGHT: int = -1
	const UNKNOWN: int = 0

class FaceOrder:
	const ABOVE: int = 1
	const BELOW: int = -1
	const UNKNOWN: int = 0


func to_dictionary() -> Dictionary:
	var dictionary: Dictionary = {}
	if VC.size(): dictionary["vertices_coords"] = VC
	if VV.size(): dictionary["vertices_vertices"] = VV
	if VE.size(): dictionary["vertices_edges"] = VE
	if VF.size(): dictionary["vertices_faces"] = VF
	if EV.size(): dictionary["edges_vertices"] = EV
	if EF.size(): dictionary["edges_faces"] = EF
	if EA.size(): dictionary["edges_assignment"] = EA
	if EFA.size(): dictionary["edges_foldAngle"] = EFA
	if EL.size(): dictionary["edges_length"] = EL
	if EO.size(): dictionary["edgeOrders"] = EO
	if FV.size(): dictionary["faces_vertices"] = FV
	if FE.size(): dictionary["faces_edges"] = FE
	if FF.size(): dictionary["faces_faces"] = FF
	if FO.size(): dictionary["faceOrders"] = FO
	return dictionary


static func from_dictionary(dictionary: Dictionary) -> FoldGraph:
	var graph := FoldGraph.new()
	const VALIDATION := preload("validation.gd")
	if not VALIDATION.validate_graph_types(dictionary):
		return null

	graph.VC = dictionary.get("vertices_coords", [])
	graph.VV = dictionary.get("vertices_vertices", [])
	graph.VE = dictionary.get("vertices_edges", [])
	graph.VF = dictionary.get("vertices_faces", [])
	graph.EV = dictionary.get("edges_vertices", [])
	graph.EF = dictionary.get("edges_faces", [])
	graph.EA = dictionary.get("edges_assignment", [])
	graph.EFA = dictionary.get("edges_foldAngle", [])
	graph.EL = dictionary.get("edges_length", [])
	graph.EO = dictionary.get("edgeOrders", [])
	graph.FV = dictionary.get("faces_vertices", [])
	graph.FE = dictionary.get("faces_edges", [])
	graph.FF = dictionary.get("faces_faces", [])
	graph.FO = dictionary.get("faceOrders", [])

	# support for FOLD versions 1.0 -> 1.1
	if dictionary.has("edges_foldAngles") and graph.EFA.is_empty():
		graph.EFA = dictionary.get("edges_foldAngles", [])
	if dictionary.has("edges_lengths") and graph.EL.is_empty():
		graph.EL = dictionary.get("edges_lengths", [])

	return graph


func inherit_properties(graph: FoldGraph) -> void:
	if VC.is_empty(): VC = graph.VC.duplicate(true)
	if VV.is_empty(): VV = graph.VV.duplicate(true)
	if VE.is_empty(): VE = graph.VE.duplicate(true)
	if VF.is_empty(): VF = graph.VF.duplicate(true)
	if EV.is_empty(): EV = graph.EV.duplicate(true)
	if EF.is_empty(): EF = graph.EF.duplicate(true)
	if EA.is_empty(): EA = graph.EA.duplicate(true)
	if EFA.is_empty(): EFA = graph.EFA.duplicate(true)
	if EL.is_empty(): EL = graph.EL.duplicate(true)
	if EO.is_empty(): EO = graph.EO.duplicate(true)
	if FV.is_empty(): FV = graph.FV.duplicate(true)
	if FE.is_empty(): FE = graph.FE.duplicate(true)
	if FF.is_empty(): FF = graph.FF.duplicate(true)
	if FO.is_empty(): FO = graph.FO.duplicate(true)


func validate() -> String:
	const VALIDATION := preload("validation.gd")
	var errors: String = ""

	var e_length := errors.length()
	if not VALIDATION.validate_VC_sizes(self):
		errors += "ERROR: vertices_coords have unexpected sizes\n"
	if not VALIDATION.validate_EV_sizes(self):
		errors += "ERROR: edges_vertices have unexpected sizes\n"
	if not VALIDATION.validate_FV_sizes(self):
		errors += "ERROR: faces_vertices have unexpected sizes\n"
	if errors.length() != e_length: return "INVALID\n" + errors

	if not VALIDATION.validate_EA_values(self):
		errors += "WARNING: edges_assignment has unexpected values\n"
	if not VALIDATION.validate_EL_values(self):
		errors += "WARNING: edges_length has unexpected values\n"
	if not VALIDATION.validate_orders(EO):
		errors += "WARNING: edgeOrders have incorrect format\n"
	if not VALIDATION.validate_orders(FO):
		errors += "WARNING: faceOrders have incorrect format\n"
	if errors.length() != e_length: return "INVALID\n" + errors

	e_length = errors.length()
	var e_V := VALIDATION.validate_equal_sizes([VC, VV, VE, VF], 0)
	var e_E := VALIDATION.validate_equal_sizes([EV, EF, EA, EFA, EL], 4)
	var e_F := VALIDATION.validate_equal_sizes([FV, FE, FF], 10)
	for e in (e_V + e_E + e_F):
		errors += "ERROR: %s and %s sizes are different\n" % [e[0], e[1]]
	if errors.length() != e_length: return "INVALID\n" + errors

	if not VALIDATION.validate_EA_with_EFA(self):
		errors += "WARNING: edges_assignment and edges_foldAngle mismatching\n"

	e_length = errors.length()
	if VC.size() and not VALIDATION.validate_references(VV, VC):
		errors += "ERROR: vertices_vertices references missing in vertices_coords\n"
	if not VALIDATION.validate_references(VE, EV):
		errors += "ERROR: vertices_edges references missing in edges_vertices\n"
	if not VALIDATION.validate_references(VF, FV):
		errors += "ERROR: vertices_faces references missing in faces_vertices\n"
	if VC.size() and not VALIDATION.validate_references(EV, VC):
		errors += "ERROR: edges_vertices references missing in vertices_coords\n"
	if not VALIDATION.validate_references(EF, FV):
		errors += "ERROR: edges_faces references missing in faces_vertices\n"
	if not VALIDATION.validate_references(EO, EV):
		errors += "ERROR: edgeOrders references missing in edges_vertices\n"
	if VC.size() and not VALIDATION.validate_references(FV, VC):
		errors += "ERROR: faces_vertices references missing in vertices_coords\n"
	if not VALIDATION.validate_references(FE, EV):
		errors += "ERROR: faces_edges references missing in edges_vertices\n"
	if not VALIDATION.validate_references(FF, FV):
		errors += "ERROR: faces_faces references missing in faces_vertices\n"
	if not VALIDATION.validate_references(FO, FV):
		errors += "ERROR: faceOrders references missing in faces_vertices\n"
	if errors.length() != e_length: return "INVALID\n" + errors

	e_length = errors.length()
	if not VALIDATION.validate_reflexive(VV, VV):
		errors += "ERROR: vertices_vertices and vertices_vertices mismatching\n"
	if not VALIDATION.validate_reflexive(VE, EV):
		errors += "ERROR: vertices_edges and edges_vertices mismatching\n"
	if not VALIDATION.validate_reflexive(VF, FV):
		errors += "ERROR: vertices_faces and faces_vertices mismatching\n"
	if not VALIDATION.validate_reflexive(EF, FE):
		errors += "ERROR: edges_faces and faces_edges mismatching\n"
	if not VALIDATION.validate_reflexive(FF, FF):
		errors += "ERROR: faces_faces and faces_faces mismatching\n"
	if errors.length() != e_length: return "INVALID\n" + errors

	e_length = errors.length()
	if not VALIDATION.validate_VV_VE_winding(self):
		errors += "WARNING: vertices_vertices and vertices_edges mismatching winding\n"
	if not VALIDATION.validate_VV_VF_winding(self):
		errors += "WARNING: vertices_vertices and vertices_faces mismatching winding\n"
	if not VALIDATION.validate_VE_VF_winding(self):
		errors += "WARNING: vertices_edges and vertices_faces mismatching winding\n"
	if not VALIDATION.validate_FV_FE_winding(self):
		errors += "WARNING: faces_vertices and faces_edges mismatching winding\n"
	if not VALIDATION.validate_FV_FF_winding(self):
		errors += "WARNING: faces_vertices and faces_faces mismatching winding\n"
	if not VALIDATION.validate_FE_FF_winding(self):
		errors += "WARNING: faces_edges and faces_faces mismatching winding\n"
	if errors.length() != e_length: return "INVALID\n" + errors

	return "VALID\n" + errors


func clear(arrays: String = "VC;VV;VE;VF;EV;EF;EA;EFA;EL;EO;FV;FE;FF;FO") -> void:
	for array in arrays.split(";", false):
		get(array).clear()


func is_VC() -> int:
	if VC.size() and VC[0] is Array:
		return VC[0].size()
	return 0


func is_VC2() -> bool:
	if VC.size() and VC[0] is Vector2:
		return true
	return false


func is_VC3() -> bool:
	if VC.size() and VC[0] is Vector3:
		return true
	return false


func is_VC23() -> bool:
	return bool(is_VC2() or is_VC3())


func get_rect2() -> Rect2:
	var rect := Rect2()
	if VC.size():
		var vc = VC[0]
		rect.position = Vector2(vc[0], vc[1])
	for index in range(1, VC.size()):
		var vc = VC[index]
		rect = rect.expand(Vector2(vc[0], vc[1]))
	return rect.abs()


func get_aabb() -> AABB:
	var aabb := AABB()
	if is_VC3() or is_VC() >= 3:
		var vc = VC[0]
		aabb.position = Vector3(vc[0], vc[1], vc[2])
		for index in range(1, VC.size()):
			vc = VC[index]
			aabb = aabb.expand(Vector3(vc[0], vc[1], vc[2]))
	elif VC.size():
		var vc = VC[0]
		aabb.position = Vector3(vc[0], vc[1], 0.0)
		for index in range(1, VC.size()):
			vc = VC[index]
			aabb = aabb.expand(Vector3(vc[0], vc[1], 0.0))
	return aabb.abs()


func get_EVC() -> Array:
	if VC.is_empty(): return []
	var EVC: Array = []
	EVC.resize(EV.size())
	for ei in range(EV.size()):
		var ev: Array = EV[ei]
		EVC[ei] = [VC[ev[0]], VC[ev[1]]]
	return EVC


func get_EV_map() -> Dictionary:
	var EV_map: Dictionary = {}
	for ei in range(EV.size()):
		var ev: Array = EV[ei]
		var u: int = ev[0]
		var v: int = ev[1]
		EV_map[[u, v]] = ei
		EV_map[[v, u]] = ei
	return EV_map


func get_FVC() -> Array:
	if VC.is_empty(): return []
	var FVC: Array[Array] = []
	FVC.resize(FV.size())
	for fi in range(FV.size()):
		var fv: Array = FV[fi]
		var fvc: Array = FVC[fi]
		var d := fv.size()
		fvc.resize(d)
		for i in range(d):
			fvc[i] = VC[fv[i]]
	return FVC
