@tool
class_name FoldFrame
extends Resource

@export var author: String
@export var title: String
@export var description: String
@export var classes: PackedStringArray
@export var attributes: PackedStringArray
@export var unit: String
@export var graph: FoldGraph
@export var parent: int = -1
@export var inherit: bool = false
@export var metadata: Dictionary

class Class:
	const CREASE_PATTERN: String = "creasePattern"
	const FOLDED_FORM: String = "foldedForm"
	const GRAPH: String = "graph"
	const LINKAGE: String = "linkage"

class Attribute:
	const TWO_DIMENSIONAL: String = "2D"
	const THREE_DIMENSIONAL: String = "3D"
	const ABSTRACT: String = "abstract"
	const MANIFOLD: String = "manifold"
	const NON_MANIFOLD: String = "nonManifold"
	const ORIENTABLE: String = "orientable"
	const NON_ORIENTABLE: String = "nonOrientable"
	const SELF_TOUCHING: String = "selfTouching"
	const NON_SELF_TOUCHING: String = "nonSelfTouching"
	const SELF_INTERSECTING: String = "selfIntersecting"
	const NON_SELF_INTERSECTING: String = "nonSelfIntersecting"
	const CUTS: String = "cuts"
	const NO_CUTS: String = "noCuts"
	const JOINS: String = "joins"
	const NO_JOINS: String = "noJoins"
	const CONVEX_FACES: String = "convexFaces"
	const NON_CONVEX_FACES: String = "nonConvexFaces"

class Unit:
	const UNIT: String = "unit"
	const INCH: String = "in"
	const POST_SCRIPT_POINTS: String = "pt"
	const METERS: String = "m"
	const CENTIMETERS: String = "cm"
	const MILLIMETERS: String = "mm"
	const MICRONS: String = "um"
	const NANOMETERS: String = "nm"


func _init() -> void:
	graph = FoldGraph.new()
	graph.frame_metadata = metadata


func to_dictionary() -> Dictionary:
	var dictionary := {}
	if len(author): dictionary["frame_author"] = author
	if len(title): dictionary["frame_title"] = title
	if len(description): dictionary["frame_description"] = description
	if len(classes): dictionary["frame_classes"] = classes
	if len(attributes): dictionary["frame_attributes"] = attributes
	if len(unit): dictionary["frame_unit"] = unit
	dictionary.merge(graph.to_dictionary(), false)
	if parent >= 0: dictionary["frame_parent"] = parent
	if inherit: dictionary["frame_inherit"] = inherit
	dictionary.merge(metadata, false)
	return dictionary


static func from_dictionary(dictionary: Dictionary) -> FoldFrame:
	var frame := FoldFrame.new()
	const X := preload("validation.gd")
	if not X.validate_frame_types(dictionary):
		return null

	frame.author = dictionary.get("frame_author", "")
	frame.title = dictionary.get("frame_title", "")
	frame.description = dictionary.get("frame_description", "")
	frame.classes = dictionary.get("frame_classes", [])
	frame.attributes = dictionary.get("frame_attributes", [])
	frame.unit = dictionary.get("frame_unit", "")
	frame.graph = FoldGraph.from_dictionary(dictionary)
	frame.parent = dictionary.get("frame_parent", -1)
	frame.inherit = dictionary.get("frame_inherit", false)

	# handling frame custom data
	var skip_keys := {}
	skip_keys.merge(X.FILE_KEYS)
	skip_keys.merge(X.FRAME_KEYS)
	skip_keys.merge(X.GRAPH_KEYS)
	for key in dictionary:
		if not key in skip_keys:
			frame.metadata[key] = dictionary[key]

	if frame.graph == null:
		return null
	return frame


func inherit_properties(frame: FoldFrame) -> void:
	if author.is_empty(): author = String(frame.author)
	if title.is_empty(): title = String(frame.title)
	if description.is_empty(): description = String(frame.description)
	if classes.is_empty(): classes = frame.classes.duplicate()
	if attributes.is_empty(): attributes = frame.attributes.duplicate()
	if unit.is_empty(): unit = String(frame.unit)
	graph.inherit_properties(frame.graph)
	parent = int(frame.parent)
	inherit = bool(frame.inherit)
	metadata.merge(frame.metadata, false)


func validate() -> String:
	const X := preload("validation.gd")
	var e := graph.validate()
	if not X._validate_frame_metadata(self):
		e += "WARNING: frame metadata is invalid\n"
	return e
