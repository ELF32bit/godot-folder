class_name FoldSvgParser
## This parser does not yet support full SVG spec
## TODO: Replace with NanoSVG and also use GNU-GTS for CDT
## Follow with Vector3.cubic_interpolate (De Casteljau algorithm)


static func parse(path: String) -> Fold:
	var svg_data := _parse_svg(path)
	if svg_data.is_empty(): return null

	var fold := Fold.new()
	fold.title = path.get_file().get_basename()
	fold.creator = "Godot Folder .SVG parser"

	fold.classes.append(Fold.Class.SINGLE_MODEL)
	fold.key_frame.classes.append(FoldFrame.Class.CREASE_PATTERN)
	fold.key_frame.attributes.append(FoldFrame.Attribute.TWO_DIMENSIONAL)

	var graph := fold.key_frame.graph
	for edge in svg_data["edges"]:
		var i := graph.VC.size()
		var u: Vector2 = edge[0]
		var v: Vector2 = edge[1]
		var stroke: Array = edge[2]
		graph.VC.append([u.x, u.y])
		graph.VC.append([v.x, v.y])
		graph.EV.append([i, i + 1])
		graph.EA.append(stroke[0])
		graph.EFA.append(stroke[1])

	return fold


static func _parse_svg(path: String) -> Dictionary:
	var xml_parser := XMLParser.new()
	if xml_parser.open(path) != OK:
		return {}

	var edges: Array = []
	while xml_parser.read() != ERR_FILE_EOF:
		if xml_parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue

		var attributes := {}
		var node_name := xml_parser.get_node_name()
		for index in range(xml_parser.get_attribute_count()):
			var attribute_name := xml_parser.get_attribute_name(index)
			var attribute_value := xml_parser.get_attribute_value(index)
			attributes[attribute_name] = attribute_value

		match node_name:
			"line": edges.append_array(_parse_line(attributes))
			"polyline": edges.append_array(_parse_polyline(attributes))
			"polygon": edges.append_array(_parse_polygon(attributes))
			"path": edges.append_array(_parse_path(attributes))
			"rect": edges.append_array(_parse_rect(attributes))
			"circle": edges.append_array(_parse_circle(attributes))
			"ellipse": edges.append_array(_parse_ellipse(attributes))

	var data: Dictionary = {}
	data["edges"] = edges
	return data


static func _parse_stroke(attributes: Dictionary) -> Variant:
	var style_attributes: Dictionary = {}
	var style: String = attributes.get("style", "")
	for split in style.split(";", false):
		var key_value := split.split(":", false, 1)
		if not key_value.size() == 2: continue
		var key := key_value[0].strip_edges()
		var value := key_value[1].strip_edges()
		style_attributes[key] = value
	style_attributes.merge(attributes, true)

	var stroke = style_attributes.get("stroke", "").strip_edges()
	var stroke_width = style_attributes.get("stroke-width", "").strip_edges()
	var _stroke_linecap = style_attributes.get("stroke-linecap", "").strip_edges()
	var stroke_opacity = style_attributes.get("stroke-opacity", "").strip_edges()
	var opacity = style_attributes.get("opacity", "").strip_edges()

	stroke_width = (float(stroke_width) if stroke_width.is_valid_float() else 0.0)
	stroke_opacity = (float(stroke_opacity) if stroke_opacity.is_valid_float() else 1.0)
	stroke_opacity *= (float(opacity) if opacity.is_valid_float() else 1.0)

	var a := float(stroke_opacity)
	var color = __parse_color_html(stroke)
	if color == null: color = __parse_color_rgb(stroke)
	if color == null: color = stroke.to_lower()
	else:
		a *= float(color.a)
		color.a = 1.0

	match color:
		"black", Color.BLACK:
			return [FoldGraph.EdgeAssignment.BOUNDARY, 0.0, stroke_width]
		"red", Color.RED:
			return [FoldGraph.EdgeAssignment.MOUNTAIN, -180.0 * a, stroke_width]
		"blue", Color.BLUE:
			return [FoldGraph.EdgeAssignment.VALLEY, 180.0 * a, stroke_width]
		"yellow", Color.YELLOW:
			return [FoldGraph.EdgeAssignment.UNKNOWN, 0.0, stroke_width]
		"green", Color.GREEN:
			return [FoldGraph.EdgeAssignment.CUT, 0.0, stroke_width]
	return [FoldGraph.EdgeAssignment.UNKNOWN, 0.0, stroke_width]


static func _parse_line(attributes: Dictionary) -> Array:
	var transform = __parse_transforms(attributes.get("transform", ""))
	if transform == null: return []
	var stroke = _parse_stroke(attributes)
	if stroke == null: return []

	var x1 = attributes.get("x1", "0.0").strip_edges()
	var y1 = attributes.get("y1", "0.0").strip_edges()
	var x2 = attributes.get("x2", "0.0").strip_edges()
	var y2 = attributes.get("y2", "0.0").strip_edges()
	for number in [x1, y1, x2, y2]:
		if not number.is_valid_float():
			return []

	var xy1 := Vector2(float(x1), float(y1))
	var xy2 := Vector2(float(x2), float(y2))
	return [[transform * xy1, transform * xy2, stroke]]


static func _parse_polyline(attributes: Dictionary, close: bool = false) -> Array:
	var transform = __parse_transforms(attributes.get("transform", ""))
	if transform == null: return []
	var stroke = _parse_stroke(attributes)
	if stroke == null: return []

	var p = __parse_numbers(attributes.get("points", ""))
	if p == null or p.size() % 2 != 0: return []
	var points: PackedVector2Array = []
	for index in range(0, p.size(), 2):
		points.append(Vector2(p[index], p[index + 1]))

	var edges: Array = []
	for index in range(points.size() - 1):
		edges.append([points[index], points[index + 1], stroke])
	if points.size() >= 2 and close:
		edges.append([points[points.size() - 1], points[0], stroke])

	for edge in edges:
		for index in range(2):
			edge[index] = transform * edge[index]
	return edges


static func _parse_polygon(attributes: Dictionary) -> Array:
	return _parse_polyline(attributes, true)


static func _parse_path(attributes: Dictionary) -> Array:
	var transform = __parse_transforms(attributes.get("transform", ""))
	if transform == null: return []
	var stroke = _parse_stroke(attributes)
	if stroke == null: return []

	var d = __parse_d(attributes.get("d", ""))
	if d == null: return []
	var commands: PackedStringArray = d[0]
	var numbers: Array = d[1]

	var edges: Array = []
	var last_z_index: int = 0
	var position := Vector2.ZERO
	for index in range(commands.size()):
		var p: Array = numbers[index]
		match commands[index]:
			"M":
				position = Vector2(p[0], p[1])
				continue
			"m":
				position += Vector2(p[0], p[1])
				continue
			"L": edges.append([position, Vector2(p[0], p[1]), stroke])
			"l": edges.append([position, position + Vector2(p[0], p[1]), stroke])
			"H": edges.append([position, Vector2(p[0], position.y), stroke])
			"h": edges.append([position, position + Vector2(p[0], 0.0), stroke])
			"V": edges.append([position, Vector2(position.x, p[0]), stroke])
			"v": edges.append([position, position + Vector2(0.0, p[0]), stroke])
			"C", "c":
				var start := position
				var is_relative := float(commands[index] == "c")
				var end := position * is_relative + Vector2(p[4], p[5])
				var c_start := position * is_relative + Vector2(p[0], p[1])
				var c_end := position * is_relative + Vector2(p[2], p[3])

				var step = 0.10
				var previous_point = start
				for i in range(1, 1 + int(1.0 / step)):
					var n = start.bezier_interpolate(c_start, c_end, end, step * i)
					edges.append([previous_point, n, stroke])
					previous_point = n
			"Z", "z":
				if not last_z_index < edges.size(): continue
				var start_position = edges[last_z_index][0]
				var end_position = edges[-1][1]
				if not end_position.is_equal_approx(start_position):
					edges.append([end_position, start_position, stroke])
				last_z_index = edges.size()
				position = start_position
		position = edges[-1][1]

	for edge in edges:
		for index in range(2):
			edge[index] = transform * edge[index]
	return edges


static func _parse_rect(attributes: Dictionary) -> Array:
	var transform = __parse_transforms(attributes.get("transform", ""))
	if transform == null: return []
	var stroke = _parse_stroke(attributes)
	if stroke == null: return []

	var x = attributes.get("x", "0.0").strip_edges()
	var y = attributes.get("y", "0.0").strip_edges()
	var width = attributes.get("width", "0.0").strip_edges()
	var height = attributes.get("height", "0.0").strip_edges()
	for number in [x, y, width, height]:
		if not number.is_valid_float():
			return []

	x = float(x); y = float(y);
	width = float(width); height = float(height);
	var a = [Vector2(x, y), Vector2(x + width, y), stroke]
	var b = [Vector2(x + width, y), Vector2(x + width, y + height), stroke]
	var c = [Vector2(x + width, y + height), Vector2(x, y + height), stroke]
	var d = [Vector2(x, y + height), Vector2(x, y), stroke]

	for edge in [a, b, c, d]:
		for index in range(2):
			edge[index] = transform * edge[index]
	return [a, b, c, d]


static func _parse_circle(attributes: Dictionary) -> Array:
	var transform = __parse_transforms(attributes.get("transform", ""))
	if transform == null: return []
	var stroke = _parse_stroke(attributes)
	if stroke == null: return []

	var cx = attributes.get("cx", "0.0").strip_edges()
	var cy = attributes.get("cy", "0.0").strip_edges()
	var r = attributes.get("r", "0.0").strip_edges()
	for number in [cx, cy, r]:
		if not number.is_valid_float():
			return []

	r = float(r)
	var cxy := Vector2(float(cx), float(cy))
	if r <= 0.0: return []

	var step: float = 2.0
	var edges: Array = []
	for index in range(int(360.0 / step)):
		var angle1 := deg_to_rad(index * step)
		var angle2 := deg_to_rad((index + 1) * step)
		var xy1 = cxy + Vector2(cos(angle1), sin(angle1)) * r
		var xy2 = cxy + Vector2(cos(angle2), sin(angle2)) * r
		edges.append([transform * xy1, transform * xy2, stroke])

	return edges


static func _parse_ellipse(attributes: Dictionary) -> Array:
	var transform = __parse_transforms(attributes.get("transform", ""))
	if transform == null: return []
	var stroke = _parse_stroke(attributes)
	if stroke == null: return []

	var cx = attributes.get("cx", "0.0").strip_edges()
	var cy = attributes.get("cy", "0.0").strip_edges()
	var rx = attributes.get("rx", "0.0").strip_edges()
	var ry = attributes.get("ry", "0.0").strip_edges()
	for number in [cx, cy, rx, ry]:
		if not number.is_valid_float():
			return []

	rx = float(rx); ry = float(ry);
	var cxy := Vector2(float(cx), float(cy))
	if rx <= 0.0 and ry <= 0.0: return []
	if rx <= 0.0 and ry > 0.0: rx = ry
	if rx > 0.0 and ry <= 0.0: ry = rx

	var step: float = 2.0
	var edges: Array = []
	for index in range(int(360.0 / step)):
		var angle1 := deg_to_rad(index * step)
		var angle2 := deg_to_rad((index + 1) * step)
		var xy1 := cxy + Vector2(cos(angle1) * rx, sin(angle1) * ry)
		var xy2 := cxy + Vector2(cos(angle2) * rx, sin(angle2) * ry)
		edges.append([transform * xy1, transform * xy2, stroke])

	return edges


static func __parse_color_html(string: String) -> Variant:
	var data := String(string).strip_edges()
	if not data.is_valid_html_color(): return null
	return Color.html(data)


static func __parse_color_rgb(string: String) -> Variant:
	var data := String(string).strip_edges()
	data = data.strip_edges()
	if not data.begins_with("rgb("): return null
	if not data.ends_with(")"): return null
	data = data.trim_suffix(")").trim_prefix("rgb(")
	var split := data.split(",", true)
	if not split.size() == 3: return null

	var numbers: PackedInt32Array = [0, 0, 0]
	for index in range(split.size()):
		var number := split[index].strip_edges()
		if not number.is_valid_int(): return null
		var n := int(number)
		if not (n >= 0 and n <= 255):
			return null
		numbers[index] = n

	return Color8(numbers[0], numbers[1], numbers[2], 255)


static func __parse_numbers(string: String) -> Variant:
	var data := String(string).strip_edges()
	var numbers: PackedFloat64Array = []
	for character in "\r\n\t,":
		data = data.replace(character, " ")
	data = data.replace("e+", "/!e!/").replace("e-", "/!ee!/")
	data = data.replace("E+", "/!E!/").replace("E-", "/!EE!/")
	data = data.replace("-", " -").replace("+", " +") # separating numbers
	data = data.replace("/!e!/", "e+").replace("/!ee!/", "e-")
	data = data.replace("/!E!/", "E+").replace("/!EE!/", "E-")
	for number in data.split(" ", false):
		if not number.is_valid_float(): return null
		numbers.append(float(number))
	return numbers


static func __parse_transform(string: String) -> Variant:
	var data := String(string).strip_edges()
	if data.is_empty(): return Transform2D.IDENTITY

	var function: String = ""
	for f in ["translate", "scale", "rotate", "skewX", "skewY", "matrix"]:
		var prefix: String = f + "("
		if not data.begins_with(prefix): continue
		if not data.ends_with(")"): return null
		data = data.trim_prefix(prefix).trim_suffix(")")
		function = f
		break
	if function.is_empty(): return null
	var n = __parse_numbers(data)
	if n == null: return null

	var transform := Transform2D.IDENTITY
	match function:
		"translate":
			if n.size() != 2: return null
			transform = transform.translated(Vector2(n[0], n[1]))
		"scale":
			if n.size() != 2: return null
			transform = transform.scaled(Vector2(n[0], n[1]))
		"rotate":
			if n.size() != 1: return null
			transform = transform.rotated(n[0])
		"skewX":
			if n.size() != 1: return null
			transform.x = Vector2(n[0], 0.0)
		"skewY":
			if n.size() != 1: return null
			transform.y = Vector2(0.0, n[0])
		"matrix":
			if n.size() != 6: return null
			transform.x = Vector2(n[0], n[1])
			transform.y = Vector2(n[2], n[3])
			transform.origin = Vector2(n[4], n[5])
	return transform


static func __parse_transforms(string: String) -> Variant:
	var data := String(string).strip_edges()
	var transforms := Transform2D.IDENTITY
	for transform in data.split(")", false):
		var t = __parse_transform(transform + ")")
		if t == null: return null
		transforms = t * transforms
	return transforms


static func __parse_d(string: String) -> Variant:
	var data := String(string).strip_edges()
	var commands: PackedStringArray = []
	for index in range(data.length()):
		if data[index] in "MLHVCSQTAZmlhvcsqtaz":
			commands.append(data[index])
		elif not data[index] in "0.123456789Ee+- \r\n\t,":
			return null

	for character in "MLHVCSQTAZmlhvcsqtaz":
		data = data.replace(character, "|")
	var split := data.split("|", true)
	if split.size():
		if split[0] != "": return null
		split.remove_at(0)
	if commands.size() != split.size():
		return null

	var numbers: Array = []
	var all_commands: PackedStringArray = []
	for index in range(commands.size()):
		var c = __parse_numbers(split[index])
		if c == null: return null

		all_commands.append(commands[index])
		match commands[index]:
			"M", "L":
				if not (c.size() >= 2 and c.size() % 2 == 0): return null
				for i in range(0, c.size(), 2):
					if i != 0: all_commands.append("L")
					numbers.append([c[i], c[i + 1]])
			"m", "l":
				if not (c.size() >= 2 and c.size() % 2 == 0): return null
				for i in range(0, c.size(), 2):
					if i != 0: all_commands.append("l")
					numbers.append([c[i], c[i + 1]])
			"H", "h", "V", "v":
				if not (c.size() >= 1): return null
				for i in range(0, c.size(), 1):
					if i != 0: all_commands.append(commands[index])
					numbers.append([c[i]])
			"C", "c":
				if not (c.size() >= 6 and c.size() % 6 == 0): return null
				for i in range(0, c.size(), 6):
					if i != 0: all_commands.append(commands[index])
					numbers.append([c[i], c[i + 1], c[i + 2],
						c[i + 3], c[i + 4], c[i + 5]])
			"S", "s", "Q", "q":
				if not (c.size() >= 4 and c.size() % 4 == 0): return null
				for i in range(0, c.size(), 4):
					if i != 0: all_commands.append(commands[index])
					numbers.append([c[i], c[i + 1], c[i + 2], c[i + 3]])
			"T", "t":
				if not (c.size() >= 2 and c.size() % 2 == 0): return null
				for i in range(0, c.size(), 2):
					if i != 0: all_commands.append(commands[index])
					numbers.append([c[i], c[i + 1]])
			"A", "a":
				if not (c.size() >= 7 and c.size() % 7 == 0): return null
				for i in range(0, c.size(), 7):
					if i != 0: all_commands.append(commands[index])
					numbers.append([c[i], c[i + 1], c[i + 2],
						c[i + 3], c[i + 4], c[i + 5], c[i + 6]])
			"Z", "z":
				if not (c.size() == 0): return null
				numbers.append([])

	return [all_commands, numbers]
