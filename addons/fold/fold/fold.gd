@tool
class_name Fold
extends Resource

@export var version: float
@export var creator: String
@export var author: String
@export var title: String
@export var description: String
@export var classes: PackedStringArray
@export var key_frame: FoldFrame
@export var frames: Array[FoldFrame]

class Class:
	const SINGLE_MODEL: String = "singleModel"
	const MULTI_MODEL: String = "multiModel"
	const ANIMATION: String = "animation"
	const DIAGRAMS: String = "diagrams"


func _init() -> void:
	version = 1.2
	key_frame = FoldFrame.new()


func to_dictionary() -> Dictionary:
	var dictionary := {}
	dictionary["file_spec"] = version
	if len(creator): dictionary["file_creator"] = creator
	if len(author): dictionary["file_author"] = author
	if len(title): dictionary["file_title"] = title
	if len(description): dictionary["file_description"] = description
	if len(classes): dictionary["file_classes"] = classes
	dictionary.merge(key_frame.to_dictionary(), false)
	if len(frames): dictionary["file_frames"] = []
	for frame in frames:
		dictionary["file_frames"].append(frame.to_dictionary())
	return dictionary


static func from_dictionary(dictionary: Dictionary) -> Fold:
	var fold := Fold.new()
	const X := preload("validation.gd")
	if not X.validate_file_types(dictionary):
		return null

	fold.version = dictionary.get("file_spec", 1.2)
	fold.creator = dictionary.get("file_creator", "")
	fold.author = dictionary.get("file_author", "")
	fold.title = dictionary.get("file_title", "")
	fold.description = dictionary.get("file_description", "")
	fold.classes = dictionary.get("file_classes", [])
	fold.key_frame = FoldFrame.from_dictionary(dictionary)
	for file_frame in dictionary.get("file_frames", []):
		var frame := FoldFrame.from_dictionary(file_frame)
		if frame == null: return null
		fold.frames.append(frame)

	return fold


static func from_json_file(path: String) -> Fold:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return null

	var json := JSON.new()
	var file_text := file.get_as_text()
	var json_error := json.parse(file_text, false)
	if json_error != OK: return null

	return from_dictionary(json.data)


func get_frame(frame_index: int) -> FoldFrame:
	if frame_index == 0: return key_frame
	elif frame_index > 0 and frame_index - 1 < frames.size():
		return frames[frame_index - 1]
	return null


func get_frame_parent(frame_index: int) -> FoldFrame:
	var frame := get_frame(frame_index)
	if not frame: return null
	return get_frame(frame.parent)


func get_inherited_frame(frame_index: int, force_new: bool = false) -> FoldFrame:
	var frame := get_frame(frame_index)
	if not frame: return null

	if not frame.inherit:
		return (frame.duplicate(true) if force_new else frame)

	var frame_parent := get_frame(frame.parent)
	if not frame_parent:
		return (frame.duplicate(true) if force_new else frame)

	var inherited_frame := frame.duplicate(true)
	while frame_parent:
		inherited_frame.inherit_properties(frame_parent)
		if frame_parent.inherit:
			frame_parent = get_frame(frame_parent.parent)
		else:
			break

	return inherited_frame


func get_inherited_frames(force_new: bool = false) -> Array[FoldFrame]:
	var inherited_frames: Array[FoldFrame] = []
	inherited_frames.resize(frames.size() + 1)

	inherited_frames[0] = get_inherited_frame(0, force_new)
	for frame_index in range(1, frames.size() + 1):
		inherited_frames[frame_index] = get_inherited_frame(frame_index, force_new)

	return inherited_frames


func validate() -> String:
	const X := preload("validation.gd")
	var is_valid := true
	var e: String = ""

	# validating parents before trying to inherit frames
	for frame_index in range(frames.size() + 1):
		if not X.validate_frame_parents(self, frame_index):
			e += "ERROR: frame %s has bad parents.\n" % frame_index
	if e.length(): return "INVALID\n" + e

	# validating inherited frames
	var inherited_frames := get_inherited_frames(false)
	for frame_index in range(inherited_frames.size()):
		var frame := inherited_frames[frame_index]
		var frame_info := frame.validate()

		if frame_info.begins_with("VALID\n"):
			frame_info = frame_info.trim_prefix("VALID\n")
		elif frame_info.begins_with("INVALID\n"):
			frame_info = frame_info.trim_prefix("INVALID\n")
			is_valid = false
		if frame_info.length():
			e += "FRAME: %s\n" % frame_index
			e += frame_info

	return ("VALID\n" if is_valid else "INVALID\n") + e
