// Things that live in the game world which, move, collide, or are drawn.
// Includes abstract definitions and more concrete specific entities; how they're drawn, and how they behave
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

// --- Collision ---

rl_rect ::proc(e:Entity, r:Rect) -> rl.Rectangle {
		return rl.Rectangle{e.pos.x, e.pos.y, r.size.x, r.size.y}
}


check_collision_rect_other ::proc(a:rl.Rectangle, b:Entity) -> bool {
	switch _ in b.shape {
	case Rect:
		return rl.CheckCollisionRecs(a, rl_rect(b, b.shape.(Rect)))
	case Circle:
		return rl.CheckCollisionCircleRec(b.pos, b.shape.(Circle).radius, a)
	}
	return false//TODO: warning?
}
check_collision_circle_other ::proc(a:Circle, a_pos:Vec2, b:Entity) -> bool {
	switch _ in b.shape {
	case Rect:
		return rl.CheckCollisionCircleRec(a_pos, a.radius, rl_rect(b, b.shape.(Rect)))
	case Circle:
		return rl.CheckCollisionCircles(a_pos, a.radius, b.pos, b.shape.(Circle).radius)
	}
	return false
}

check_collision :: proc(a: Entity, b: Entity) -> bool {
	if a == b do return false // or perhaps true?
	switch _ in a.shape {
	case Rect:
		return check_collision_rect_other(rl_rect(a, a.shape.(Rect)), b)
	case Circle:
		return check_collision_circle_other(a.shape.(Circle), a.pos, b)
	}
	return false  // One of the Entities has no shape?
}

check_collision_any :: proc(a: Entity, list:[dynamic]Tower) -> bool{ //HACK: this is supposed to be useable for all entities, not just towers
	for b in list {
		if check_collision(a, b) do return true
	}
	return false //TODO maybe more useful if it returned b
}

// --- Drawing ---

draw_shape ::proc(s:Shape, pos:Vec2, rot:f32, color:rl.Color) {
	switch _ in s {
	case Rect:
		r := s.(Rect)
		offset := r.size / 2
		rot_mat := get_rotation_matrix(rot)
		a_pos := Vec2{-offset.x, -offset.y} * rot_mat + pos
		b_pos := Vec2{-offset.x, offset.y} * rot_mat + pos
		c_pos := Vec2{offset.x, offset.y} * rot_mat + pos
		d_pos := Vec2{offset.x, -offset.y} * rot_mat + pos
		line_strip := [5]Vec2{a_pos, b_pos, c_pos, d_pos, a_pos}
		rl.DrawLineStrip(&line_strip[0], 5, color) //FIXME: this doesn't apply thickness
	case Circle:
		c := s.(Circle)
		t :f32 = line_thickness/2.0
		rl.DrawRing(pos, c.radius-t, c.radius+t, 0.0, 360.0, 16, color)
	}

}
draw_entity :: proc(e: Entity, color: rl.Color) {
	draw_shape(e.shape, e.pos, e.rot, color)
}
