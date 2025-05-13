@tool
class_name FolderFoldResource
extends Resource

@export var source_file_name: String

@export var version: String
@export var creator: String
@export var author: String
@export var title: String
@export var description: String
@export var classes: PackedStringArray
@export var key_frame: FolderFrameResource
@export var frames: Array[FolderFrameResource]


static func from_dictionary(dictionary: Dictionary) -> FolderFoldResource:
	var fold := FolderFoldResource.new()

	var version = dictionary.get("file_spec", "1.2")
	if typeof(version) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		fold.version = str(version)

	var creator = dictionary.get("file_creator", "")
	if creator is String:
		fold.creator = creator
	else:
		return null

	var author = dictionary.get("file_author", "")
	if author is String:
		fold.author = author
	else:
		return null

	var title = dictionary.get("file_title", "")
	if title is String:
		fold.title = title
	else:
		return null

	var description = dictionary.get("file_description", "")
	if description is String:
		fold.description = description
	else:
		return null

	var classes = dictionary.get("file_classes", [])
	if classes is Array:
		for class_string in classes:
			if class_string is String:
				fold.classes.append(class_string)
			else:
				return null
	else:
		return null

	fold.key_frame = FolderFrameResource.from_dictionary(dictionary)
	if fold.key_frame == null:
		return null

	var frames = dictionary.get("file_frames", [])
	if frames is Array:
		for frame in frames:
			if frame is Dictionary:
				var frame_resource := FolderFrameResource.from_dictionary(frame)
				if frame_resource == null:
					return null
				fold.frames.append(frame_resource)
			else:
				return null
	else:
		return null

	return fold


static func from_json_file(path: String) -> FolderFoldResource:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json := JSON.new()
	var file_text := file.get_as_text(false)
	var json_error := json.parse(file_text, false)
	if json_error != OK:
		return null

	return from_dictionary(json.data)


static func from_xml_file(path: String) -> FolderFoldResource:
	var xml_parser := XMLParser.new()
	if xml_parser.open(path) != OK:
		return null

	var fold := FolderFoldResource.new()
	fold.key_frame = FolderFrameResource.new()
	fold.key_frame.graph = FolderGraphResource.new()

	while xml_parser.read() != ERR_FILE_EOF:
		if xml_parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := xml_parser.get_node_name()
			var attributes := {}
			for index in range(xml_parser.get_attribute_count()):
				var attribute_name := xml_parser.get_attribute_name(index)
				var attribute_value := xml_parser.get_attribute_value(index)
				attributes[attribute_name] = attribute_value
			fold.key_frame.graph.insert_svg_element(node_name, attributes)

	return fold


func get_frame(frame_index: int) -> FolderFrameResource:
	if frame_index == 0:
		return self.key_frame
	elif frame_index > 0 and frame_index - 1 < self.frames.size():
		return self.frames[frame_index - 1]
	else:
		return null


func get_frame_parent(frame_index: int) -> FolderFrameResource:
	var frame := self.get_frame(frame_index)
	if frame:
		return self.get_frame(frame.parent)
	return null


func get_inherited_frame(frame_index: int, force_duplicate: bool = false) -> FolderFrameResource:
	var frame := self.get_frame(frame_index)
	if not frame:
		return null

	if not frame.inherit:
		return (frame.duplicate(true) if force_duplicate else frame)
	var frame_parent = self.get_frame(frame.parent)
	if not frame_parent:
		return (frame.duplicate(true) if force_duplicate else frame)

	var inherited_frame := frame.duplicate(true)
	while frame_parent:
		inherited_frame.inherit_properties(frame_parent)
		if frame_parent.inherit:
			frame_parent = self.get_frame(frame_parent.parent)
		else:
			break

	return inherited_frame


func get_inherited_frames(force_duplicate: bool = false) -> Array[FolderFrameResource]:
	var array: Array[FolderFrameResource] = []
	array.append(self.get_inherited_frame(0, force_duplicate))
	for frame_index in range(1, self.frames.size() + 1):
		array.append(self.get_inherited_frame(frame_index, force_duplicate))
	return array


func validate() -> bool:
	for frame_index in range(frames.size() + 1):
		var frame_parents: Array[FolderFrameResource] = []
		var frame_parent := self.get_frame_parent(frame_index)
		while frame_parent:
			if frame_parent in frame_parents:
				return false
			frame_parents.append(frame_parent)
			frame_parent = self.get_frame(frame_parent.parent)
	for frame in self.get_inherited_frames(false):
		if not frame.validate():
			return false
	return true
