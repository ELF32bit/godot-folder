@tool
class_name FolderFrameResource
extends Resource

@export var author: String
@export var title: String
@export var description: String
@export var classes: PackedStringArray
@export var attributes: PackedStringArray
@export var unit: String
@export var graph: FolderGraphResource
@export var parent: int
@export var inherit: bool
@export var custom_data: Dictionary


static func from_dictionary(dictionary: Dictionary) -> FolderFrameResource:
	var frame := FolderFrameResource.new()

	var author = dictionary.get("frame_author", "")
	if author is String:
		frame.author = author
	else:
		return null

	var title = dictionary.get("frame_title", "")
	if title is String:
		frame.title = title
	else:
		return null

	var description = dictionary.get("frame_description", "")
	if description is String:
		frame.description = description
	else:
		return null

	var classes = dictionary.get("frame_classes", [])
	if classes is Array:
		for class_string in classes:
			if class_string is String:
				frame.classes.append(class_string)
			else:
				return null
	else:
		return null

	var attributes = dictionary.get("frame_attributes", [])
	if attributes is Array:
		for attribute_string in attributes:
			if attribute_string is String:
				frame.attributes.append(attribute_string)
			else:
				return null
	else:
		return null

	var unit = dictionary.get("frame_unit", "")
	if unit is String:
		frame.unit = unit
	else:
		return null

	frame.graph = FolderGraphResource.from_dictionary(dictionary)
	if frame.graph == null:
		return null

	var parent = dictionary.get("frame_parent", -1)
	if typeof(parent) in [TYPE_INT, TYPE_FLOAT]:
		frame.parent = int(parent)
	else:
		return null

	var inherit = dictionary.get("frame_inherit", false)
	if inherit is bool:
		frame.inherit = inherit
	else:
		return null

	const custom_data_skip_keys := {
		"file_spec": 0,
		"file_creator": 0,
		"file_author": 0,
		"file_title": 0,
		"file_description": 0,
		"file_classes": 0,
		"file_frames": 0,
		"frame_author": 0,
		"frame_title": 0,
		"frame_description": 0,
		"frame_classes": 0,
		"frame_attributes": 0,
		"frame_unit": 0,
		"frame_parent": 0,
		"frame_inherit": 0,
		"vertices_coords": 0,
		"vertices_vertices": 0,
		"vertices_edges": 0,
		"vertices_faces": 0,
		"edges_vertices": 0,
		"edges_faces": 0,
		"edges_assignment": 0,
		"edges_foldAngle": 0,
		"edges_foldAngles": 0, # version 1.1
		"edges_length": 0,
		"edges_lengths": 0, # version 1.1
		"faces_vertices": 0,
		"faces_edges": 0,
		"faces_faces": 0,
		"edgeOrders": 0,
		"faceOrders": 0,
	}

	for key in dictionary:
		if not key in custom_data_skip_keys:
			frame.custom_data[key] = dictionary[key]

	return frame


func inherit_properties(frame: FolderFrameResource) -> void:
	if self.author.is_empty():
		self.author = String(frame.author)

	if self.title.is_empty():
		self.title = String(frame.title)

	if self.description.is_empty():
		self.description = String(frame.description)

	if self.classes.is_empty():
		self.classes = frame.classes.duplicate()

	if self.attributes.is_empty():
		self.attributes = frame.attributes.duplicate()

	if self.unit.is_empty():
		self.unit = String(frame.unit)

	self.graph.inherit_properties(frame.graph)

	self.parent = frame.parent
	self.inherit = frame.inherit
	self.custom_data.merge(frame.custom_data, false)


func validate() -> bool:
	if not self.graph.validate():
		return false
	return true
