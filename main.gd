@tool
extends Node3D

@export var fold: Resource = null
@export var test := false:
	set(value):
		if test != value:
			_activate()
		test = value


func _activate() -> void:
	var graph: FoldGraph = fold.key_frame.graph.duplicate(true)
	var s := Transform3D.IDENTITY.scaled(Vector3.ONE * 10.0)

	FoldGraphBuilder.Coordinates.VC_to_VC3(graph)
	FoldGraphBuilder.Coordinates.VC3_transform(graph, s)
	FoldGraphBuilder.Coordinates.VC3_center(graph)
	FoldGraphBuilder.Faces.FV_triangulate(graph)
	FoldGraphBuilder.Faces.FV_to_E(graph)
	FoldGraphBuilder.Faces.FV_to_EF(graph)
	FoldGraphBuilder.Faces.FE_from_FV(graph)
	FoldGraphBuilder.Faces.FV_to_VV(graph)
	FoldGraphBuilder.Vertices.VE_from_VV(graph)
	FoldGraphBuilder.Vertices.VF_from_VV(graph)

	var back_graph := graph.duplicate(true)
	FoldGraphBuilder.Faces.FV_flip(back_graph)
	var mesh := FoldGraphBuilder.Mesher.FV3_to_mesh(graph, back_graph)
	$MeshInstance3D.mesh = mesh


func _ready() -> void:
	_activate()
