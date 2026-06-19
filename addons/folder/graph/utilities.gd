# Variation of Bresenham's line algorithm fully covering the line
# Graph edges are rasterized on a pixel grid for a faster intersections
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
