package game
import rl "vendor:raylib"

line_thickness :: 1.5

Rect :: struct {
	size: [2]f32,
}
Circle :: struct {
	radius: f32,
}
Shape :: union { Rect, Circle }
Entity :: struct {
	label : string,
	pos: [2]f32,
	velocity: [2]f32,
	shape: Shape,
	rot: f32,
	alive: bool,
}

@(private)
check_collision_rects :: proc(a: Rect, a_pos: [2]f32 , b: Rect, b_pos: [2]f32) -> bool {
	a_nw := a_pos - (a.size / 2)
	b_nw := b_pos - (b.size / 2)
	a_se := a_pos + (a.size / 2)
	b_se := b_pos + (b.size / 2)
	return (
		a_nw.x < b_se.x &&
		a_se.x > b_nw.x &&
		a_nw.y < b_se.y &&
		a_se.y > b_nw.y
	)
}

@private
sqr :: proc(f:f32)  -> f32 {
	return f*f
}

@private
dist_squared :: proc(a:[2]f32, b:[2]f32) -> f32 {
	x := a.x - b.x
	y := a.y - b.y
	return x*x + y*y
}
@(private)
check_collision_circles :: proc(a: Circle, a_pos: [2]f32 , b: Circle, b_pos: [2]f32) -> bool {
	return dist_squared(a_pos, b_pos) < sqr(a.radius + b.radius)
}

check_collision :: proc(a: Entity, b: Entity) -> bool {
	ar, a_is_rect := a.shape.(Rect)
	br, b_is_rect := b.shape.(Rect)
	ac, a_is_circle := a.shape.(Circle)
	bc, b_is_circle := b.shape.(Circle)
	if a_is_rect && b_is_rect {
		return check_collision_rects(ar, a.pos, br, b.pos)
	} if a_is_circle && b_is_circle {
		return check_collision_circles(ac, a.pos, bc, b.pos)
	} if (a_is_circle && b_is_rect) || (a_is_rect && b_is_circle) {
		return true // not implemented
	}

	return false  // One of the Entities has no shape?
}

draw_entity :: proc(e: Entity, color: rl.Color) {
	switch _ in e.shape {
	case Rect:
		r := e.shape.(Rect)
		top_left := e.pos - r.size / 2
		rect := rl.Rectangle { top_left.x, top_left.y, r.size.x, r.size.y }
		rl.DrawRectangleLinesEx(rect, line_thickness, color)
	case Circle:
		c := e.shape.(Circle)
		t :f32 = line_thickness/2.0
		rl.DrawRing(e.pos, c.radius-t, c.radius+t, 0.0, 360.0, 16, color)
	}
}
