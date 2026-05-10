package game
import rl "vendor:raylib"

line_thickness :: 1.5

Rect :: struct {
	size: Vec2,
}
Circle :: struct {
	radius: f32,
}
Shape :: union { Rect, Circle }
Entity :: struct {
	label : string,
	pos: Vec2,
	velocity: Vec2,
	shape: Shape,
	rot: f32,
	alive: bool,
}

// Different meteors will have different path strategies in the future.
Meteor :: struct {
	using entity: Entity,
}

// Possibly check for rotation later?
@(private)
check_collision_rects :: proc(a: Rect, a_pos: Vec2, a_rot: f32, b: Rect, b_pos: Vec2, b_rot: f32) -> bool {
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
dist_squared :: proc(a:Vec2, b:Vec2) -> f32 {
	x := a.x - b.x
	y := a.y - b.y
	return x*x + y*y
}
@(private)
check_collision_circles :: proc(a: Circle, a_pos: Vec2 , b: Circle, b_pos: Vec2) -> bool {
	return dist_squared(a_pos, b_pos) < sqr(a.radius + b.radius)
}

check_collision :: proc(a: Entity, b: Entity) -> bool {
	ar, a_is_rect := a.shape.(Rect)
	br, b_is_rect := b.shape.(Rect)
	ac, a_is_circle := a.shape.(Circle)
	bc, b_is_circle := b.shape.(Circle)
	if a_is_rect && b_is_rect {
		return check_collision_rects(ar, a.pos, a.rot, br, b.pos, b.rot)
	} if a_is_circle && b_is_circle {
		return check_collision_circles(ac, a.pos, bc, b.pos)
	} if (a_is_circle && b_is_rect) || (a_is_rect && b_is_circle) {
		return false // not implemented
	}

	return false  // One of the Entities has no shape?
}

draw_entity :: proc(e: Entity, color: rl.Color) {
	switch _ in e.shape {
	case Rect:
		r := e.shape.(Rect)
		offset := r.size / 2
		rot_mat := get_rotation_matrix(e.rot)
		a_pos := Vec2{-offset.x, -offset.y} * rot_mat + e.pos
		b_pos := Vec2{-offset.x, offset.y} * rot_mat + e.pos
		c_pos := Vec2{offset.x, offset.y} * rot_mat + e.pos
		d_pos := Vec2{offset.x, -offset.y} * rot_mat + e.pos
		line_strip := [5]Vec2{a_pos, b_pos, c_pos, d_pos, a_pos}
		rl.DrawLineStrip(&line_strip[0], 5, color)
	case Circle:
		c := e.shape.(Circle)
		t :f32 = line_thickness/2.0
		rl.DrawRing(e.pos, c.radius-t, c.radius+t, 0.0, 360.0, 16, color)
	}
}
