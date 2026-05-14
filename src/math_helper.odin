// Provide some common math operations throughout the project.

package game
import "core:math"

dist_squared :: proc(a:Vec2, b:Vec2) -> f32 {
	x := a.x - b.x
	y := a.y - b.y
	return x*x + y*y
}

sqr :: proc(f:f32)  -> f32 {
	return f*f
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

vec_angle :: proc(v:Vec2) -> f32 {
	return -math.atan(v.y / v.x)
}

angle_facing ::proc(from:Vec2, to:Vec2) -> f32 {
	facingVec := to - from
	return vec_angle(facingVec)
}

unit_vector :: proc(angle: f32) -> Vec2 {
	return Vec2{math.cos(angle), math.sin(angle)}
}

closest_point_on_segment :: proc(point, start, end: Vec2) -> Vec2 {
	ab := end - start
	denom := ab.x*ab.x + ab.y*ab.y
	t := (ab.x*(point.x-start.x) + ab.y*(point.y-start.y)) / denom if denom != 0 else 0
	return start + clamp(t, 0, 1) * ab
}
