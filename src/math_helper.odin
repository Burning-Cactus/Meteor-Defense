// Provide some common math operations throughout the project.

package game
import "core:math"

dist_squared :: proc(a: Vec2, b: Vec2) -> f32 {
	x := a.x - b.x
	y := a.y - b.y
	return x * x + y * y
}

sqr :: proc(f: f32) -> f32 {
	return f * f
}

get_rotation_matrix :: proc(radians: f32) -> matrix[2, 2]f32 {
	c := math.cos(radians)
	s := math.sin(radians)
	m := matrix[2, 2]f32{
		c, -s,
		s, c,
	}
	return m
}

get_normalized_vector_facing_target :: proc(base: Vec2, target: Vec2) -> Vec2 {
	difference := target - base
	distance := math.sqrt(difference.x * difference.x + difference.y * difference.y)
	return difference / distance
}

vec_angle :: proc(v: Vec2) -> f32 {
	return -math.atan(v.y / v.x)
}

angle_facing :: proc(from: Vec2, to: Vec2) -> f32 {
	facingVec := to - from
	return vec_angle(facingVec)
}

unit_vector :: proc(angle: f32) -> Vec2 {
	return Vec2{math.cos(angle), math.sin(angle)}
}

normalize :: proc(vector: Vec2) -> Vec2 {
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
	vertices := make([]Vec2, 4, allocator)
	offset_x := rect.size.x / 2
	offset_y := rect.size.y / 2
	vertices[0] = {-offset_x, -offset_y}
	vertices[1] = {-offset_x, offset_y}
	vertices[2] = {offset_x, offset_y}
	vertices[3] = {offset_x, -offset_y}
	if rot != 0 {
		rot_mat := get_rotation_matrix(rot)
		for i in 0 ..< 4 {
			vertices[i] = rot_mat * vertices[i]
		}
	}
	for i in 0 ..< 4 {
		vertices[i] += offset_pos
	}
	return vertices
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

