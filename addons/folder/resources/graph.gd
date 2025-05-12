@tool
class_name FolderGraphResource
extends Resource

@export var vertices_coordinates: Array[PackedFloat64Array]
@export var vertices_vertices: Array[PackedInt64Array]
@export var vertices_edges: Array[PackedInt64Array]
@export var vertices_faces: Array[Array]

@export var edges_vertices: Array[PackedInt64Array]
@export var edges_faces: Array[Array]
@export var edges_assignment: Array[StringName]
@export var edges_fold_angle: PackedFloat64Array
@export var edges_length: PackedFloat64Array

@export var faces_vertices: Array[PackedInt64Array]
@export var faces_edges: Array[PackedInt64Array]
@export var faces_faces: Array[Array]

@export var edge_orders: Array[Array]
@export var face_orders: Array[Array]


static func from_dictionary(dictionary: Dictionary) -> FolderGraphResource:
	var graph := FolderGraphResource.new()

	var vertex_coordinates_size := -1
	var vertices_coordinates = dictionary.get("vertices_coords", [])
	if vertices_coordinates is Array:
		for vertex_coordinates in vertices_coordinates:
			if vertex_coordinates is Array:
				graph.vertices_coordinates.append(PackedFloat64Array())

				# making sure that vertex coordinates are the same
				if vertex_coordinates_size == -1:
					vertex_coordinates_size = vertex_coordinates.size()
				elif vertex_coordinates_size != vertex_coordinates.size():
					return null

				for vertex_coordinate in vertex_coordinates:
					if typeof(vertex_coordinate) in [TYPE_INT, TYPE_FLOAT]:
						graph.vertices_coordinates[-1].append(float(vertex_coordinate))
					else:
						return null
			else:
				return null
	else:
		return null

	var vertices_vertices = dictionary.get("vertices_vertices", [])
	if vertices_vertices is Array:
		for vertex_vertices in vertices_vertices:
			if vertex_vertices is Array:
				graph.vertices_vertices.append(PackedInt64Array())
				for vertex_vertex in vertex_vertices:
					if typeof(vertex_vertex) in [TYPE_INT, TYPE_FLOAT]:
						graph.vertices_vertices[-1].append(int(vertex_vertex))
					else:
						return null
			else:
				return null
	else:
		return null

	var vertices_edges = dictionary.get("vertices_edges", [])
	if vertices_edges is Array:
		for vertex_edges in vertices_edges:
			if vertex_edges is Array:
				graph.vertices_edges.append(PackedInt64Array())
				for vertex_edge in vertex_edges:
					if typeof(vertex_edge) in [TYPE_INT, TYPE_FLOAT]:
						graph.vertices_edges[-1].append(int(vertex_edge))
					else:
						return null
			else:
				return null
	else:
		return null

	var vertices_faces = dictionary.get("vertices_faces", [])
	if vertices_faces is Array:
		for vertex_faces in vertices_faces:
			if vertex_faces is Array:
				graph.vertices_faces.append([])
				for vertex_face in vertex_faces:
					if typeof(vertex_face) in [TYPE_INT, TYPE_FLOAT]:
						graph.vertices_faces[-1].append(int(vertex_face))
					elif vertex_face == null:
						graph.vertices_faces[-1].append(null)
					else:
						return null
			else:
				return null
	else:
		return null

	var edges_vertices = dictionary.get("edges_vertices", [])
	if edges_vertices is Array:
		for edge_vertices in edges_vertices:
			if edge_vertices is Array and edge_vertices.size() == 2:
				graph.edges_vertices.append(PackedInt64Array())
				for edge_vertex in edge_vertices:
					if typeof(edge_vertex) in [TYPE_INT, TYPE_FLOAT]:
						graph.edges_vertices[-1].append(int(edge_vertex))
					else:
						return null
			else:
				return null
	else:
		return null

	var edges_faces = dictionary.get("edges_faces", [])
	if edges_faces is Array:
		for edge_faces in edges_faces:
			if edge_faces is Array:
				graph.edges_faces.append([])
				for edge_face in edge_faces:
					if typeof(edge_face) in [TYPE_INT, TYPE_FLOAT]:
						graph.edges_faces[-1].append(int(edge_face))
					elif edge_face == null:
						graph.edges_faces[-1].append(null)
					else:
						return null
			else:
				return null
	else:
		return null

	var edges_assignment = dictionary.get("edges_assignment", [])
	if edges_assignment is Array:
		for edge_assignment in edges_assignment:
			if edge_assignment is String:
				graph.edges_assignment.append(StringName(edge_assignment))
			else:
				return null
	else:
		return null

	var edges_fold_angle = dictionary.get("edges_foldAngle", [])
	if edges_fold_angle.is_empty(): # to support version 1.1
		edges_fold_angle = dictionary.get("edges_foldAngles", [])
	if edges_fold_angle is Array:
		for edge_fold_angle in edges_fold_angle:
			if typeof(edge_fold_angle) in [TYPE_INT, TYPE_FLOAT]:
				graph.edges_fold_angle.append(float(edge_fold_angle))
			else:
				return null
	else:
		return null

	var edges_length = dictionary.get("edges_length", [])
	if edges_length.is_empty(): # to support version 1.1
		edges_length = dictionary.get("edges_lengths", [])
	if edges_length is Array:
		for edge_length in edges_length:
			if typeof(edge_length) in [TYPE_INT, TYPE_FLOAT]:
				graph.edges_length.append(float(edge_length))
			else:
				return null
	else:
		return null

	var faces_vertices = dictionary.get("faces_vertices", [])
	if faces_vertices is Array:
		for face_vertices in faces_vertices:
			if face_vertices is Array:
				graph.faces_vertices.append(PackedInt64Array())
				for face_vertex in face_vertices:
					if typeof(face_vertex) in [TYPE_INT, TYPE_FLOAT]:
						graph.faces_vertices[-1].append(int(face_vertex))
					else:
						return null
			else:
				return null
	else:
		return null

	var faces_edges = dictionary.get("faces_edges", [])
	if faces_edges is Array:
		for face_edges in faces_edges:
			if face_edges is Array:
				graph.faces_edges.append(PackedInt64Array())
				for face_edge in face_edges:
					if typeof(face_edge) in [TYPE_INT, TYPE_FLOAT]:
						graph.faces_edges[-1].append(int(face_edge))
					else:
						return null
			else:
				return null
	else:
		return null

	var faces_faces = dictionary.get("faces_faces", [])
	if faces_faces is Array:
		for face_faces in faces_faces:
			if face_faces is Array:
				graph.faces_faces.append([])
				for face_face in face_faces:
					if typeof(face_face) in [TYPE_INT, TYPE_FLOAT]:
						graph.faces_faces[-1].append(int(face_face))
					elif face_face == null:
						graph.faces_faces[-1].append(null)
					else:
						return null
			else:
				return null
	else:
		return null

	var edge_orders = dictionary.get("edgeOrders", [])
	if edge_orders is Array:
		for edge_order in edge_orders:
			if edge_order is Array and edge_order.size() == 3:
				graph.edge_orders.append([])
				for index in range(3):
					if typeof(edge_order[index]) in [TYPE_INT, TYPE_FLOAT]:
						# checking that edge order value is corrent
						if index == 2 and not int(edge_order[index]) in [-1, 0, 1]:
							return null
						graph.edge_orders[-1].append(int(edge_order[index]))
					else:
						return null
			else:
				return null
	else:
		return null

	var face_orders = dictionary.get("faceOrders", [])
	if face_orders is Array:
		for face_order in face_orders:
			if face_order is Array and face_order.size() == 3:
				graph.face_orders.append([])
				for index in range(3):
					if typeof(face_order[index]) in [TYPE_INT, TYPE_FLOAT]:
						# checking that face order value is corrent
						if index == 2 and not int(face_order[index]) in [-1, 0, 1]:
							return null
						graph.face_orders[-1].append(int(face_order[index]))
					else:
						return null
			else:
				return null
	else:
		return null

	return graph


func inherit_properties(graph: FolderGraphResource) -> void:
	if self.vertices_coordinates.is_empty():
		self.vertices_coordinates = graph.vertices_coordinates.duplicate()

	if self.vertices_vertices.is_empty():
		self.vertices_vertices = graph.vertices_vertices.duplicate()

	if self.vertices_edges.is_empty():
		self.vertices_edges = graph.vertices_edges.duplicate()

	if self.vertices_faces.is_empty():
		self.vertices_faces = graph.vertices_faces.duplicate()

	if self.edges_vertices.is_empty():
		self.edges_vertices = graph.edges_vertices.duplicate()

	if self.edges_faces.is_empty():
		self.edges_faces = graph.edges_faces.duplicate()

	if self.edges_assignment.is_empty():
		self.edges_assignment = graph.edges_assignment.duplicate()

	if self.edges_fold_angle.is_empty():
		self.edges_fold_angle = graph.edges_fold_angle.duplicate()

	if self.edges_length.is_empty():
		self.edges_length = graph.edges_length.duplicate()

	if self.faces_vertices.is_empty():
		self.faces_vertices = graph.faces_vertices.duplicate()

	if self.faces_edges.is_empty():
		self.faces_edges = graph.faces_edges.duplicate()

	if self.faces_faces.is_empty():
		self.faces_faces = graph.faces_faces.duplicate()

	if self.edge_orders.is_empty():
		self.edge_orders = graph.edge_orders.duplicate()

	if self.face_orders.is_empty():
		self.face_orders = graph.face_orders.duplicate()


func validate() -> bool:
	var vertices_count := self.vertices_coordinates.size()
	var edges_count := self.edges_vertices.size()

	if not self.edges_assignment.size() == edges_count:
		return false

	for edge_vertices in self.edges_vertices:
		for index in range(2):
			var id := edge_vertices[index]
			if not (id >= 0 and id < vertices_count):
				return false

	for face_vertices in faces_vertices:
		for face_vertex in face_vertices:
			var id := face_vertex
			if not (id >= 0 and id < vertices_count):
				return false

	return true


func get_packed_vertices_coordinates() -> PackedVector3Array:
	var packed_vertices_coordinates := PackedVector3Array()
	for vertex_coordinates in self.vertices_coordinates:
		var coordinates := Vector3.ZERO
		for index in range(mini(vertex_coordinates.size(), 3)):
			coordinates[index] = vertex_coordinates[index]
		packed_vertices_coordinates.append(coordinates)
	return packed_vertices_coordinates


func get_faces_vertices_coordinates(packed_vertices_coordinates: PackedVector3Array, counterclockwise: bool = true) -> Array[PackedVector3Array]:
	var faces_vertices_coordinates: Array[PackedVector3Array] = []
	if packed_vertices_coordinates.size() == 0:
		return faces_vertices_coordinates

	for face_vertices in self.faces_vertices:
		var face_vertices_coordinates := PackedVector3Array()
		for face_vertex in face_vertices:
			var coordinates := packed_vertices_coordinates[face_vertex]
			face_vertices_coordinates.append(coordinates)
		if not counterclockwise:
			face_vertices_coordinates.reverse()
		faces_vertices_coordinates.append(face_vertices_coordinates)

	return faces_vertices_coordinates


func get_edges_vertices_coordinates(packed_vertices_coordinates: PackedVector3Array, assignment: StringName = "BMVFUCJ") -> Array[PackedVector3Array]:
	var edges_vertices_coordinates: Array[PackedVector3Array] = []
	if packed_vertices_coordinates.size() == 0:
		return edges_vertices_coordinates

	for edge_index in range(self.edges_vertices.size()):
		if self.edges_assignment.size() > 0:
			if not self.edges_assignment[edge_index] in assignment:
				continue
		var edge_vertices_coordinates := PackedVector3Array()
		for edge_vertex in self.edges_vertices[edge_index]:
			var coordinates := packed_vertices_coordinates[edge_vertex]
			edge_vertices_coordinates.append(coordinates)
		edges_vertices_coordinates.append(edge_vertices_coordinates)

	return edges_vertices_coordinates


func get_faces_surface_tool(packed_vertices_coordinates: PackedVector3Array, counterclockwise: bool = false, material: Material = null) -> SurfaceTool:
	var faces_vertices_coordinates := self.get_faces_vertices_coordinates(packed_vertices_coordinates, counterclockwise)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(material)
	for face_vertices_coordinates in faces_vertices_coordinates:
		surface_tool.add_triangle_fan(face_vertices_coordinates)
	surface_tool.generate_normals(false)
	surface_tool.index()
	return surface_tool


func get_edges_surface_tool(packed_vertices_coordinates: PackedVector3Array, assignment: StringName = "BMVFUCJ", material: Material = null) -> SurfaceTool:
	var edges_vertices_coordinates := self.get_edges_vertices_coordinates(packed_vertices_coordinates, assignment)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	surface_tool.set_material(material)
	for edge_vertices_coordinates in edges_vertices_coordinates:
		surface_tool.add_vertex(edge_vertices_coordinates[0])
		surface_tool.add_vertex(edge_vertices_coordinates[1])
	surface_tool.index()
	return surface_tool
