const EA_DISPLAY_PRIORITY_TABLE: Dictionary = {
	FoldGraph.EdgeAssignment.BOUNDARY: 6,
	FoldGraph.EdgeAssignment.MOUNTAIN: 5,
	FoldGraph.EdgeAssignment.VALLEY: 4,
	FoldGraph.EdgeAssignment.FLAT: 3,
	FoldGraph.EdgeAssignment.UNKNOWN: 2,
	FoldGraph.EdgeAssignment.CUT: 7,
	FoldGraph.EdgeAssignment.JOIN: 1,
}

const V4EAC_TABLE: Dictionary = {
	[0, 0, 0, 0]: 0, [0, 0, 0, 1]: 1, [0, 0, 0, 2]: 2, [0, 0, 0, 3]: 3,
	[0, 0, 0, 4]: 4, [0, 0, 1, 0]: 5, [0, 0, 1, 1]: 6, [0, 0, 1, 2]: 7,
	[0, 0, 1, 3]: 8, [0, 0, 2, 0]: 9, [0, 0, 2, 1]: 10, [0, 0, 2, 2]: 11,
	[0, 0, 3, 0]: 12, [0, 0, 3, 1]: 13, [0, 0, 4, 0]: 14, [0, 1, 0, 0]: 15,
	[0, 1, 0, 1]: 16, [0, 1, 0, 2]: 17, [0, 1, 0, 3]: 18, [0, 1, 1, 0]: 19,
	[0, 1, 1, 1]: 20, [0, 1, 1, 2]: 21, [0, 1, 2, 0]: 22, [0, 1, 2, 1]: 23,
	[0, 1, 3, 0]: 24, [0, 2, 0, 0]: 25, [0, 2, 0, 1]: 26, [0, 2, 0, 2]: 27,
	[0, 2, 1, 0]: 28, [0, 2, 1, 1]: 29, [0, 2, 2, 0]: 30, [0, 3, 0, 0]: 31,
	[0, 3, 0, 1]: 32, [0, 3, 1, 0]: 33, [0, 4, 0, 0]: 34, [1, 0, 0, 0]: 35,
	[1, 0, 0, 1]: 36, [1, 0, 0, 2]: 37, [1, 0, 0, 3]: 38, [1, 0, 1, 0]: 39,
	[1, 0, 1, 1]: 40, [1, 0, 1, 2]: 41, [1, 0, 2, 0]: 42, [1, 0, 2, 1]: 43,
	[1, 0, 3, 0]: 44, [1, 1, 0, 0]: 45, [1, 1, 0, 1]: 46, [1, 1, 0, 2]: 47,
	[1, 1, 1, 0]: 48, [1, 1, 1, 1]: 49, [1, 1, 2, 0]: 50, [1, 2, 0, 0]: 51,
	[1, 2, 0, 1]: 52, [1, 2, 1, 0]: 53, [1, 3, 0, 0]: 54, [2, 0, 0, 0]: 55,
	[2, 0, 0, 1]: 56, [2, 0, 0, 2]: 57, [2, 0, 1, 0]: 58, [2, 0, 1, 1]: 59,
	[2, 0, 2, 0]: 60, [2, 1, 0, 0]: 61, [2, 1, 0, 1]: 62, [2, 1, 1, 0]: 63,
	[2, 2, 0, 0]: 64, [3, 0, 0, 0]: 65, [3, 0, 0, 1]: 66, [3, 0, 1, 0]: 67,
	[3, 1, 0, 0]: 68, [4, 0, 0, 0]: 69,
}


static func segment2_to_grid(from: Vector2, to: Vector2, grid_step: float) -> Array[Vector2i]:
	var grid_cells: Array[Vector2i] = []
	from = from / grid_step; to = to / grid_step;
	var direction := (to - from).normalized()
	var distance := from.distance_to(to)

	var _fx := floorf(from.x)
	var _fy := floorf(from.y)
	var _fxx := floorf(from.x + 1.0)
	var _fyy := floorf(from.y + 1.0)

	var x := int(_fx)
	var y := int(_fy)
	var step_x: int = (1 if direction.x > 0.0 else -1)
	var step_y: int = (1 if direction.y > 0.0 else -1)
	var s_x = (absf(1.0 / direction.x) if direction.x != 0.0 else INF)
	var s_y = (absf(1.0 / direction.y) if direction.y != 0.0 else INF)

	var d_x: float = INF
	var d_y: float = INF
	if direction.x > 0.0: d_x = (_fxx - from.x) * s_x
	elif direction.x < 0.0: d_x = (from.x - _fx) * s_x
	if direction.y > 0.0: d_y = (_fyy - from.y) * s_y
	elif direction.y < 0.0: d_y = (from.y - _fy) * s_y

	var current_distance: float = 0.0
	while current_distance <= distance:
		grid_cells.append(Vector2i(x, y))
		if d_x < d_y:
			current_distance = d_x
			d_x += s_x
			x += step_x
		else:
			current_distance = d_y
			d_y += s_y
			y += step_y

	return grid_cells


static func segment3_to_grid(from: Vector3, to: Vector3, grid_step: float) -> Array[Vector3i]:
	var grid_cells: Array[Vector3i] = []
	from = from / grid_step; to = to / grid_step;
	var direction := (to - from).normalized()
	var distance := from.distance_to(to)

	var _fx := floorf(from.x)
	var _fy := floorf(from.y)
	var _fz := floorf(from.z)
	var _fxx := floorf(from.x + 1.0)
	var _fyy := floorf(from.y + 1.0)
	var _fzz := floorf(from.z + 1.0)

	var x := int(_fx)
	var y := int(_fy)
	var z := int(_fz)
	var step_x: int = (1 if direction.x > 0.0 else -1)
	var step_y: int = (1 if direction.y > 0.0 else -1)
	var step_z: int = (1 if direction.z > 0.0 else -1)
	var s_x = (absf(1.0 / direction.x) if direction.x != 0.0 else INF)
	var s_y = (absf(1.0 / direction.y) if direction.y != 0.0 else INF)
	var s_z = (absf(1.0 / direction.z) if direction.z != 0.0 else INF)

	var d_x: float = INF
	var d_y: float = INF
	var d_z: float = INF
	if direction.x > 0.0: d_x = (_fxx - from.x) * s_x
	elif direction.x < 0.0: d_x = (from.x - _fx) * s_x
	if direction.y > 0.0: d_y = (_fyy - from.y) * s_y
	elif direction.y < 0.0: d_y = (from.y - _fy) * s_y
	if direction.z > 0.0: d_z = (_fzz - from.z) * s_z
	elif direction.z < 0.0: d_z = (from.z - _fz) * s_z

	var current_distance: float = 0.0
	while current_distance <= distance:
		grid_cells.append(Vector3i(x, y, z))
		if d_x < d_y:
			if d_x < d_z:
				current_distance = d_x
				d_x += s_x
				x += step_x
			else:
				current_distance = d_z
				d_z += s_z
				z += step_z
		else:
			if d_y < d_z:
				current_distance = d_y
				d_y += s_y
				y += step_y
			else:
				current_distance = d_z
				d_z += s_z
				z += step_z

	return grid_cells
