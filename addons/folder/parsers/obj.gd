class_name FoldObjParser


static func parse(path: String) -> Fold:
	var obj_data := _parse_obj(path)
	if not obj_data.size(): return null

	var fold := Fold.new()
	fold.title = obj_data["file_name"]
	fold.creator = "Godot Folder .OBJ parser"

	if obj_data["frame_objects"].size() == 1:
		fold.classes.append(Fold.Class.SINGLE_MODEL)
	else: fold.classes.append(Fold.Class.MULTI_MODEL)
	fold.key_frame.classes.append(FoldFrame.Class.FOLDED_FORM)
	fold.key_frame.attributes.append(FoldFrame.Attribute.THREE_DIMENSIONAL)

	for index in range(1, obj_data["frame_objects"].size()):
		fold.frames.append(FoldFrame.new())
	for frame_index in range(obj_data["frame_objects"].size()):
		_obj_data_to_frame(obj_data, fold, frame_index)

	return fold


static func _parse_obj(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {}

	var objects: Dictionary = {"": true}
	var materials: Dictionary = {"": true}
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var faces: Array[Dictionary] = []
	var lines: Array[Dictionary] = []

	var has_colors := false
	var current_object: String = ""
	var current_material: String = ""
	var current_smooth_group: int = 0
	while not file.eof_reached():
		var file_line := file.get_line()
		var split := file_line.split(" ", false)

		if split.size() == 2 and split[0] in ["o", "g"]:
			current_object = split[1]
			if not current_object in objects:
				objects[current_object] = true

		elif split.size() == 2 and split[0] == "usemtl":
			current_material = split[1]
			if not current_material in materials:
				materials[current_material] = true

		elif split.size() == 2 and split[0] == "s":
			if split[1] in ["0", "off"]:
				current_smooth_group = 0
			elif split[1].is_valid_int():
				current_smooth_group = int(split[1])

		elif split.size() in [4, 7] and split[0] == "v":
			if not split[1].is_valid_float(): continue
			if not split[2].is_valid_float(): continue
			if not split[3].is_valid_float(): continue

			var vertex := Vector3.ZERO
			vertex.x = float(split[1])
			vertex.y = float(split[2])
			vertex.z = float(split[3])
			vertices.append(vertex)

			var color := Color.WHITE
			if not split.size() == 7:
				colors.append(color)
				continue

			if split[4].is_valid_float(): color.r = float(split[4])
			if split[5].is_valid_float(): color.g = float(split[5])
			if split[6].is_valid_float(): color.b = float(split[6])
			colors.append(color)
			has_colors = true

		elif split.size() == 4 and split[0] == "vn":
			if not split[1].is_valid_float(): continue
			if not split[2].is_valid_float(): continue
			if not split[3].is_valid_float(): continue

			var normal := Vector3.ZERO
			normal.x = float(split[1])
			normal.y = float(split[2])
			normal.z = float(split[3])
			normals.append(normal)

		elif split.size() == 3 and split[0] == "vt":
			if not split[1].is_valid_float(): continue
			if not split[2].is_valid_float(): continue

			var uv := Vector2.ZERO
			uv.x = float(split[1])
			uv.y = float(split[2])
			uvs.append(uv)

		elif split.size() >= 4 and split[0] == "f":
			var face: Dictionary = {}
			face["object"] = current_object
			face["material"] = current_material
			face["smooth_group"] = current_smooth_group
			face["vertices"] = []
			face["normals"] = []
			face["uvs"] = []

			for index in range(1, split.size()):
				var data := split[index].split("/", true, 3)

				if data.size() >= 1:
					if not data[0].is_valid_int(): continue
					face["vertices"].append(int(data[0]) - 1)

				if data.size() >= 2:
					if data[1].is_empty(): continue
					if not data[1].is_valid_int(): continue
					face["uvs"].append(int(data[1]) - 1)

				if data.size() >= 3:
					if data[2].is_empty(): continue
					if not data[2].is_valid_int(): continue
					face["normals"].append(int(data[2]) - 1)

			if not face["vertices"].size() == split.size() - 1: continue
			if not face["normals"].size() in [0, split.size() - 1]: continue
			if not face["uvs"].size() in [0, split.size() - 1]: continue
			faces.append(face)

		elif split.size() >= 3 and split[0] == "l":
			var line: Dictionary = {}
			line["object"] = current_object
			line["material"] = current_material
			line["vertices"] = []

			for index in range(1, split.size()):
				if not split[index].is_valid_int(): continue
				line["vertices"].append(int(split[index]) - 1)
			if not line["vertices"].size() == split.size() - 1: continue
			lines.append(line)

	# validating mesh arrays
	if vertices.size() != 0:
		for face in faces:
			for index in face["vertices"]:
				if index >= vertices.size() or index < 0:
					return {}
		for line in lines:
			for index in line["vertices"]:
				if index >= vertices.size() or index < 0:
					return {}
	for face in faces:
		for index in face["normals"]:
			if index >= normals.size() or index < 0:
				return {}
		for index in face["uvs"]:
			if index >= uvs.size() or index < 0:
				return {}

	# creating additional convenience arrays
	var objects_faces: Dictionary = {}
	var objects_lines: Dictionary = {}
	for object in objects:
		objects_faces[object] = []
		objects_lines[object] = []
	for face in faces:
		objects_faces[face["object"]].append(face)
	for line in lines:
		objects_lines[line["object"]].append(line)

	# objects named like "crane->M->-90.0" will be parsed as creases
	# trying to parse edges assignment and fold angle from objects
	var creases_objects: Dictionary = {}
	var frame_objects: PackedStringArray = []
	for object in objects:
		var reg_ex := RegEx.new()
		reg_ex.compile("->[%s]{1}(->([+-]?[0-9]*.[0-9]*))?$" % FoldGraph.EdgeAssignment.ANY)
		var crease_pattern := reg_ex.search(object)
		if not crease_pattern:
			frame_objects.append(object)
			continue
		var suffix := crease_pattern.get_string()
		var split := suffix.split("->", false)
		var object_name: String = object.trim_suffix(suffix)
		if not object_name in creases_objects:
			creases_objects[object_name] = {}
		if split.size() == 1:
			var fold_angle: float = 0.0
			match split[0]:
				FoldGraph.EdgeAssignment.MOUNTAIN: fold_angle = -180.0
				FoldGraph.EdgeAssignment.VALLEY: fold_angle = 180.0
			creases_objects[object_name][[split[0], fold_angle]] = object
		else:
			creases_objects[object_name][[split[0], float(split[1])]] = object

	var data: Dictionary = {}
	data["file_name"] = path.get_file().get_basename()
	data["objects"] = objects.keys()
	data["objects_faces"] = objects_faces
	data["objects_lines"] = objects_lines
	data["creases_objects"] = creases_objects
	data["frame_objects"] = frame_objects
	data["materials"] = materials.keys()
	data["vertices"] = vertices
	data["colors"] = (colors if has_colors else [])
	data["normals"] = normals
	data["uvs"] = uvs
	data["faces"] = faces
	data["lines"] = lines
	return data


static func _obj_data_to_frame(obj_data: Dictionary, fold: Fold, frame_index: int) -> void:
	var object_name: String = obj_data["frame_objects"][frame_index]
	var frame := fold.get_frame(frame_index)
	var graph := frame.graph

	frame.title = object_name
	if frame_index > 0:
		frame.parent = 0
		frame.inherit = true

	if frame_index == 0:
		for v in obj_data["vertices"]:
			graph.VC.append([v.x, v.y, v.z])
		if obj_data["vertices"].size() == 0:
			frame.attributes.append(FoldFrame.Attribute.ABSTRACT)

	if frame_index == 0 and obj_data["colors"].size():
		var vertices_color: Array = []
		frame.metadata["vertices_color"] = vertices_color
		for c in obj_data["colors"]:
			var color := Color(c.r, c.g, c.b, c.a)
			var color_html = "#" + color.to_html(true)
			vertices_color.append(color_html.to_upper())

	for face in obj_data["objects_faces"][object_name]:
		graph.FV.append(face["vertices"])

	if obj_data["objects_faces"][object_name].size():
		var faces_material: Array = []
		var faces_smooth_group: Array = []
		frame.metadata["faces_material"] = faces_material
		frame.metadata["faces_smoothGroup"] = faces_smooth_group
		for face in obj_data["objects_faces"][object_name]:
			if face["material"].is_empty(): faces_material.append(null)
			else: faces_material.append(face["material"])
			faces_smooth_group.append(face["smooth_group"])

	if frame_index == 0 and obj_data["normals"].size():
		var normals_coords: Array = []
		frame.metadata["normals_coords"] = normals_coords
		for n in obj_data["normals"]:
			normals_coords.append([n.x, n.y, n.z])

	if obj_data["normals"].size():
		if obj_data["objects_faces"][object_name].size():
			var faces_normals: Array = []
			frame.metadata["faces_normals"] = faces_normals
			for face in obj_data["objects_faces"][object_name]:
				faces_normals.append(face["normals"])

	if frame_index == 0 and obj_data["uvs"].size():
		var uvs_coords: Array = []
		frame.metadata["uvs_coords"] = uvs_coords
		for t in obj_data["uvs"]:
			uvs_coords.append([t.x, t.y])

	if obj_data["uvs"].size():
		if obj_data["objects_faces"][object_name].size():
			var faces_uvs: Array = []
			frame.metadata["faces_uvs"] = faces_uvs
			for face in obj_data["objects_faces"][object_name]:
				faces_uvs.append(face["uvs"])

	for line in obj_data["objects_lines"][object_name]:
		var assignment: String = "U"
		var fold_angle: float = 0.0

		# line materials named like "M->-90.0" will be parsed as creases
		# trying to parse edge assignment and fold angle from line material
		var split: PackedStringArray = line["material"].split("->", true)
		if split.size():
			if len(split[0]) == 1 and split[0] in FoldGraph.EdgeAssignment.ANY:
				assignment = split[0]
				match assignment:
					FoldGraph.EdgeAssignment.MOUNTAIN: fold_angle = -180.0
					FoldGraph.EdgeAssignment.VALLEY: fold_angle = 180.0
			if split.size() == 2 and split[1].is_valid_float():
				fold_angle = float(split[1])

		var vertices: Array = line["vertices"]
		for index in range(vertices.size() - 1):
			graph.EV.append([vertices[index], vertices[index + 1]])
			graph.EA.append(assignment)
			graph.EFA.append(fold_angle)

	# adding creases from crease objects
	var creases_objects: Dictionary = obj_data["creases_objects"]
	var object_creases: Dictionary = creases_objects.get(object_name, {})
	for crease in object_creases:
		var crease_object_name: String = object_creases[crease]
		var assignment: String = crease[0]
		var fold_angle: float = crease[1]

		for face in obj_data["objects_faces"][crease_object_name]:
			var vertices: Array = face["vertices"]
			var d := vertices.size()
			for index in range(d):
				graph.EV.append([vertices[index], vertices[(index + 1) % d]])
				graph.EA.append(assignment)
				graph.EFA.append(fold_angle)

		for line in obj_data["objects_lines"][crease_object_name]:
			var vertices: Array = line["vertices"]
			for index in range(vertices.size() - 1):
				graph.EV.append([vertices[index], vertices[index + 1]])
				graph.EA.append(assignment)
				graph.EFA.append(fold_angle)
