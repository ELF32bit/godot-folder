const FILE_KEYS: Dictionary = {
	"file_spec": 1.2,
	"file_creator": "",
	"file_author": "",
	"file_title": "",
	"file_description": "",
	"file_classes": [],
	"file_frames": [],
}

const FRAME_KEYS: Dictionary = {
	"frame_author": "",
	"frame_title": "",
	"frame_description": "",
	"frame_classes": [],
	"frame_attributes": [],
	"frame_unit": "",
	"frame_parent": -1.0,
	"frame_inherit": false,
}

const GRAPH_KEYS: Dictionary = {
	"vertices_coords": [],
	"vertices_vertices": [],
	"vertices_edges": [],
	"vertices_faces": [],
	"edges_vertices": [],
	"edges_faces": [],
	"edges_assignment": [],
	"edges_foldAngle": [],
	"edges_length": [],
	"edgeOrders": [],
	"faces_vertices": [],
	"faces_edges": [],
	"faces_faces": [],
	"faceOrders": [],
	# support for FOLD versions 1.0 -> 1.1
	"edges_foldAngles": [],
	"edges_lengths": [],
}

const _METADATA_KEYS: Dictionary = {
	"vertices_color": [], # VP
	"normals_coords": [], # NC
	"uvs_coords": [], # TC
	"faces_normals": [], # FN
	"faces_uvs": [], # FT
	"faces_material": [], # FM
	"faces_smoothGroup": [], # FSG
}


static func validate_file_types(dictionary: Dictionary) -> bool:
	for key in FILE_KEYS:
		var default: Variant = FILE_KEYS[key]
		if typeof(dictionary.get(key, default)) != typeof(default):
			return false
	for item in dictionary.get("file_classes", []):
		if typeof(item) != TYPE_STRING: return false
	return true


static func validate_frame_types(dictionary: Dictionary) -> bool:
	for key in FRAME_KEYS:
		var default: Variant = FRAME_KEYS[key]
		if typeof(dictionary.get(key, default)) != typeof(default):
			return false
	for item in dictionary.get("frame_classes", []):
		if typeof(item) != TYPE_STRING: return false
	for item in dictionary.get("frame_attributes", []):
		if typeof(item) != TYPE_STRING: return false
	if dictionary.has("frame_parent"):
		var frame_parent: float = dictionary["frame_parent"]
		dictionary["frame_parent"] = int(frame_parent)
	if not _validate_frame_metadata_types(dictionary):
		return false
	return true


static func validate_graph_types(dictionary: Dictionary) -> bool:
	for key in GRAPH_KEYS:
		var default: Variant = GRAPH_KEYS[key]
		if typeof(dictionary.get(key, default)) != typeof(default):
			return false

	# support for some incorrectly encoded files
	var efa: Array = dictionary.get("edges_foldAngle", [])
	for index in range(efa.size()):
		if typeof(efa[index]) == TYPE_NIL:
			efa[index] = 0.0

	for item in dictionary.get("edges_assignment", []):
		if typeof(item) != TYPE_STRING: return false
	for item in dictionary.get("edges_foldAngle", []):
		if typeof(item) != TYPE_FLOAT: return false
	for item in dictionary.get("edges_length", []):
		if typeof(item) != TYPE_FLOAT: return false

	# support for FOLD versions 1.0 -> 1.1
	for item in dictionary.get("edges_foldAngles", []):
		if typeof(item) != TYPE_FLOAT: return false
	for item in dictionary.get("edges_lengths", []):
		if typeof(item) != TYPE_FLOAT: return false

	if not __validate(dictionary, "vertices_coords", TYPE_FLOAT): return false
	if not __validate(dictionary, "vertices_vertices", TYPE_INT): return false
	if not __validate(dictionary, "vertices_edges", TYPE_INT): return false
	if not __validate(dictionary, "vertices_faces", -TYPE_INT): return false
	if not __validate(dictionary, "edges_vertices", TYPE_INT): return false
	if not __validate(dictionary, "edges_faces", -TYPE_INT): return false
	if not __validate(dictionary, "edgeOrders", TYPE_INT): return false
	if not __validate(dictionary, "faces_vertices", TYPE_INT): return false
	if not __validate(dictionary, "faces_edges", TYPE_INT): return false
	if not __validate(dictionary, "faces_faces", -TYPE_INT): return false
	if not __validate(dictionary, "faceOrders", TYPE_INT): return false
	return true


static func _validate_frame_metadata_types(dictionary: Dictionary) -> bool:
	for key in _METADATA_KEYS:
		var default: Variant = _METADATA_KEYS[key]
		if typeof(dictionary.get(key, default)) != typeof(default):
			return false

	for item in dictionary.get("vertices_color", []):
		if not typeof(item) == TYPE_STRING: return false
	for item in dictionary.get("faces_material", []):
		if not typeof(item) in [TYPE_STRING, TYPE_NIL]: return false
	for item in dictionary.get("faces_smoothGroup", []):
		if typeof(item) != TYPE_INT: return false

	if not __validate(dictionary, "normals_coords", TYPE_FLOAT): return false
	if not __validate(dictionary, "uvs_coords", TYPE_FLOAT): return false
	if not __validate(dictionary, "faces_normals", TYPE_INT): return false
	if not __validate(dictionary, "faces_uvs", TYPE_INT): return false
	return true


static func __validate(dictionary: Dictionary, array: StringName, type: int) -> bool:
	var has_null := bool(type < 0); type = absi(type);
	var should_convert := bool(type == TYPE_INT)
	for item in dictionary.get(array, []):
		if not item is Array: return false
		for index in range(item.size()):
			var element: Variant = item[index]
			if has_null and element == null: continue
			if typeof(element) != TYPE_FLOAT: return false
			if should_convert: item[index] = int(element)
	return true


static func __to_map1(array: Array) -> Array[Dictionary]:
	var map: Array[Dictionary] = []
	map.resize(array.size())
	for index in range(array.size()):
		for u in array[index]:
			if u == null: continue
			map[index][u] = true
	return map


static func __to_map2(array: Array) -> Array[Dictionary]:
	var map: Array[Dictionary] = []
	map.resize(array.size())
	for index in range(array.size()):
		var item: Array = array[index]
		var d := item.size()
		for i in range(d):
			var u: int = item[i]
			var v: int = item[(i + 1) % d]
			map[index][[u, v]] = true
			map[index][[v, u]] = true
	return map


static func __to_map3(array: Array) -> Array[Dictionary]:
	var map: Array[Dictionary] = []
	map.resize(array.size())
	for index in range(array.size()):
		var item: Array = array[index]
		var d := item.size()
		for i in range(d):
			var u: int = item[i]
			var v: int = item[(i + 1) % d]
			var w: int = item[(i + 2) % d]
			map[index][[u, v, w]] = true
			map[index][[w, v, u]] = true
	return map


static func __get(array: Array, index: int) -> Variant:
	if index >= array.size() or index < 0: return null
	return array[index]
