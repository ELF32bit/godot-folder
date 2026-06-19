@tool
extends Node3D
## TESTING: Click on buttons to see something

@export var fold: Resource = null
@export var crease_pattern := false:
	set(value):
		if value: _build_crease_pattern()
@export var simulation := false:
	set(value):
		simulation = value
		set_process(value)

var graph: FoldGraph = null
var simulated_graph: FoldGraph = null
var graph_simulation: FoldGraphSimulation3D = null


func _build_crease_pattern() -> void:
	graph = fold.key_frame.graph.duplicate(true)

	FoldGraphBuilder.Coordinates.VC_to_VC3(graph)
	FoldGraphBuilder.Coordinates.VC3_center(graph)
	FoldGraphBuilder.Faces.FV_triangulate(graph)
	FoldGraphBuilder.Faces.FV_to_E(graph)
	FoldGraphBuilder.Faces.FV_to_EF(graph)
	FoldGraphBuilder.Faces.FE_from_FV(graph)
	FoldGraphBuilder.Faces.FV_to_VV(graph)
	FoldGraphBuilder.Vertices.VE_from_VV(graph)
	FoldGraphBuilder.Vertices.VF_from_VV(graph)

	simulated_graph = graph
	var graph_flipped := graph.duplicate(true)
	FoldGraphBuilder.Faces.FV_flip(graph_flipped)
	var mesh := FoldGraphBuilder.Mesher.FV3_to_mesh(graph, graph_flipped)
	$CreasePattern.mesh = mesh


func _ready() -> void:
	$CreasePattern.mesh = null
	$Simulation.mesh = null
	_build_crease_pattern()
	if Engine.is_editor_hint():
		set_process(false)


func _process(_delta: float) -> void:
	if not simulated_graph:
		return

	if not graph_simulation:
		graph_simulation = FoldGraphSimulation3D.new(simulated_graph)
		graph_simulation.fold_percent = 0.85
		graph_simulation.begin()
	for index in range(10):
		graph_simulation.simulate()

	var graph_flipped := simulated_graph.duplicate(true)
	FoldGraphBuilder.Faces.FV_flip(graph_flipped)
	var mesh := FoldGraphBuilder.Mesher.FV3_to_mesh(simulated_graph, graph_flipped)
	$Simulation.mesh = mesh
