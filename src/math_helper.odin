// Provide some common math operations throughout the project.

package game

dist_squared :: proc(a:Vec2, b:Vec2) -> f32 {
	x := a.x - b.x
	y := a.y - b.y
	return x*x + y*y
}
