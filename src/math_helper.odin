// Provide some common math operations throughout the project.

package game
import "core:math"
import "core:math/linalg"

Vec2 :: [2]f32

dist_squared :: proc(a: Vec2, b: Vec2) -> f32 {
	x := a.x - b.x
	y := a.y - b.y
	return x * x + y * y
}

sqr :: proc(f: f32) -> f32 {
	return f * f
}

calculate_rotation_matrix :: proc(radians: f32) -> matrix[2, 2]f32 {
	return linalg.matrix2_rotate(-radians)
}

get_normalized_vector_facing_target :: proc(base: Vec2, target: Vec2) -> Vec2 {
	difference := target - base
	distance := math.sqrt(difference.x * difference.x + difference.y * difference.y)
	return difference / distance
}

vec_angle :: proc(v: Vec2) -> f32 {
	if v == {} do return 0
	return math.atan(v.y / v.x)
}

angle_facing :: proc(from: Vec2, to: Vec2) -> f32 {
	facingVec := to - from
	return vec_angle(facingVec)
}

unit_vector :: proc(angle: f32) -> Vec2 {
	return Vec2{math.cos(angle), math.sin(angle)}
}

normalize :: proc(vector: Vec2) -> Vec2 {
	if vector == {} do return {0,1}
	distance := math.sqrt(vector.x * vector.x + vector.y * vector.y)
	return vector / distance
}

dot_product :: proc(a: Vec2, b: Vec2) -> f32 {
	return a.x * b.x + a.y * b.y
}

/*
	Convert a rectangle to vertex format. The origin of the rectangle will be at its center.
	offsetPos - A vector that gets added to all vertices after rotations are complete.
	rot - The rotation in radians.
*/
rect_to_vertices :: proc(
	rect: Rect,
	offset_pos: Vec2,
	rot: f32,
	allocator := context.temp_allocator,
) -> []Vec2 {
	offset_x := rect.size.x / 2
	offset_y := rect.size.y / 2
	vertices := [4]Vec2 {
		{-offset_x, -offset_y},
		{-offset_x, offset_y},
		{offset_x, offset_y},
		{offset_x, -offset_y},
	}
	return copy_and_rotate_vertices(vertices[:], offset_pos, rot, allocator)
}

/*
	Allocate a new array copied from the vertices passed in. Rotations are applied to the copy.
*/
copy_and_rotate_vertices :: proc(vertices: []Vec2, offset_pos: Vec2, rot: f32, allocator := context.temp_allocator) -> []Vec2 {
	copy := make([]Vec2, len(vertices), allocator)
	rot_mat := calculate_rotation_matrix(rot)
	for i in 0..<len(vertices) {
		copy[i] = vertices[i] * rot_mat
		copy[i] += offset_pos
	}
	return copy
}

// Calculate and return an array of the normal vectors perpendicular to each edge formed by the vertices passed in.
calculate_normals_of_edges :: proc(
	vertices: []Vec2,
	allocator := context.temp_allocator,
) -> []Vec2 {
	axes := make([]Vec2, len(vertices), allocator)
	last_idx := len(axes) - 1
	for i in 0 ..< last_idx {
		edge := vertices[i + 1] - vertices[i]
		// Get the vector perpendicular to the edge
		edge = normalize({-edge.y, edge.x})
		axes[i] = edge
	}
	// Handle the base case
	edge := vertices[0] - vertices[last_idx]
	edge = normalize({-edge.y, edge.x})
	axes[last_idx] = edge
	return axes
}

project_shape_onto_axis :: proc(vertices: []Vec2, axis: Vec2) -> (min, max: f32) {
	min = dot_product(vertices[0], axis)
	max = min
	for i in 1 ..< len(vertices) {
		p := dot_product(vertices[i], axis)
		if p < min {
			min = p
		} else if p > max {
			max = p
		}
	}

	return min, max
}

// Parametric intersection of segment (a, a+r) with segment (b, b+s).
// Returns t along r and u along s such that a+t*r = b+u*s.
// ok is false when the segments are parallel.
segment_intersect :: proc(a, r, b, s: Vec2) -> (t, u: f32, ok: bool) {
	denom := linalg.cross(r, s)
	if denom == 0 do return
	diff := b - a
	t = linalg.cross(diff, s) / denom
	u = linalg.cross(diff, r) / denom
	ok = true
	return
}

// Returns the outward-facing normal of an edge belonging to a convex polygon centered at the origin.
// edge_start is the first vertex of the edge and is used to resolve which perpendicular faces outward.
outward_edge_normal :: proc(edge, edge_start: Vec2) -> Vec2 {
	n := Vec2{-edge.y, edge.x}
	if dot_product(n, edge_start) < 0 do n = -n
	return normalize(n)
}

nearest :: proc (f:f32, a:f32, b:f32) -> f32{
	return a if abs(f-a) < abs(f-b) else b
}

// Returns the nearest boundary of [lo, hi] to x, and its outward normal sign (-1 for lo, +1 for hi).
nearest_bound :: proc(x, lo, hi: f32) -> (bound: f32, normal_sign: f32) {
	if x - lo <= hi - x {
		return lo, -1
	}
	return hi, 1
}
