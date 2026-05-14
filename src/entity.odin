// Things that live in the game world which, move, collide, or are drawn.
// Includes abstract definitions and more concrete specific entities; how they're drawn, and how they behave
package game
import rl "vendor:raylib"

Rect :: struct {
	size: Vec2,
}
Circle :: struct {
	radius: f32,
}

Shape :: union {
	Rect,
	Circle,
}

Entity :: struct {
	id:        u64,
	label:     string,
	pos:       Vec2,
	velocity:  Vec2,
	rot:       f32,
	rot_speed: f32,
	shape:     Shape,
	hp:        f32,
	power:     f32,
	col:       ThemeColor,
	draw:      proc(e: ^Entity, state: ^GameState),
	alive:     bool,
	value:     u32,
	death_sfx: rl.Sound,
}

// --- Utils ---

next_entity_id: u64
spawn :: proc(list: ^[dynamic]$T, pos: Vec2, entity: T) -> ^T {
	e := entity
	e.pos = pos
	e.id = next_entity_id
	next_entity_id += 1
	e.alive = true
	append(list, e)
	return &list[len(list) - 1]
}

remove_dead :: proc(list: ^[dynamic]$T) {
	for i := len(list) - 1; i >= 0; i -= 1 {
		if !list[i].alive {
			if list[i].death_sfx.frameCount != 0 do rl.PlaySound(list[i].death_sfx)
			unordered_remove(list, i)
		}
	}
}

entity_bounds :: proc(e: ^Entity) -> Vec2 {
	switch _ in e.shape {
	case Rect:
		return e.shape.(Rect).size
	case Circle:
		x := e.shape.(Circle).radius * 2.0
		return {x, x}
	}
	return {0, 0}
}

entity_size :: proc(e: ^Entity) -> f32 {
	switch _ in e.shape {
	case Rect:
		r := e.shape.(Rect).size
		return max(r.y, r.y)
	case Circle:
		return e.shape.(Circle).radius * 2.0
	}
	return 0
}

// --- Collision ---

rl_rect :: proc(e: Entity, r: Rect) -> rl.Rectangle {
	return rl.Rectangle{e.pos.x, e.pos.y, r.size.x, r.size.y}
}

find_closest_vertex :: proc(pos: Vec2, vertices: []Vec2) -> Vec2 {
	closest_vertex := vertices[0]
	closest_dist := dist_squared(vertices[0], pos)
	for i in 1 ..< len(vertices) {
		d := dist_squared(vertices[i], pos)
		if d < closest_dist {
			closest_vertex = vertices[i]
			closest_dist = d
		}
	}
	return closest_vertex
}

// Check collision between two convex polygons of any rotation.
// This is done by getting the axes perpendicular to every edge of each shape.
// Then for each axis, project both shapes onto the axis as a 1D line segment and see if they overlap.
// They must overlap on all axes to be colliding.
check_collision_sat :: proc(a: Entity, b: Entity) -> bool {
	a_shape := a.shape.(Rect)
	switch b_shape in b.shape {
	case Rect:
		// Convert rectangles to vertex format
		vertices1 := rect_to_vertices(a_shape, a.pos, a.rot)
		vertices2 := rect_to_vertices(b_shape, b.pos, b.rot)
		axes1 := calculate_normals_of_edges(vertices1)
		axes2 := calculate_normals_of_edges(vertices2)

		for i in 0 ..< len(axes1) {
			// Project the shape onto each and every axis.
			min1, max1 := project_shape_onto_axis(vertices1, axes1[i])
			min2, max2 := project_shape_onto_axis(vertices2, axes1[i])
			if min1 > max2 || min2 > max1 {
				return false
			}
		}
		for i in 0 ..< len(axes2) {
			min1, max1 := project_shape_onto_axis(vertices1, axes2[i])
			min2, max2 := project_shape_onto_axis(vertices2, axes2[i])
			if min1 > max2 || min2 > max1 {
				return false
			}
		}
	case Circle:
		vertices1 := rect_to_vertices(a_shape, a.pos, a.rot)
		// The comparison from the circle's side is just the axis connecting the center of the circle and the nearest vertex of the polygon.
		{
			closest_vertex := find_closest_vertex(b.pos, vertices1)
			closest_axis := normalize(closest_vertex - b.pos)
			min1, max1 := project_shape_onto_axis(vertices1, closest_axis)
			circle_projection := dot_product(b.pos, closest_axis)
			min2 := circle_projection - b_shape.radius
			max2 := circle_projection + b_shape.radius
			if min1 > max2 || min2 > max1 {
				return false
			}
		}

		axes1 := calculate_normals_of_edges(vertices1)
		for i in 0 ..< len(axes1) {
			min1, max1 := project_shape_onto_axis(vertices1, axes1[i])
			circle_projection := dot_product(b.pos, axes1[i])
			min2 := circle_projection - b_shape.radius
			max2 := circle_projection + b_shape.radius
			if min1 > max2 || min2 > max1 {
				return false
			}
		}
	}
	return true
}

check_collision :: proc(a: Entity, b: Entity) -> bool {
	if a == b do return false // or perhaps true?
	switch a_shape in a.shape {
	case Rect:
		return check_collision_sat(a, b)
	case Circle:
		switch b_shape in b.shape {
		case Rect:
			return check_collision_sat(b, a)
		case Circle:
			return rl.CheckCollisionCircles(a.pos, a_shape.radius, b.pos, b_shape.radius)
		}
	}
	return false // One of the Entities has no shape?
}

check_collision_any :: proc(a: Entity, list: [dynamic]$T) -> bool {
	for b in list {
		if check_collision(a, b) do return true
	}
	return false //TODO maybe more useful if it returned b
}

// --- Drawing ---

draw_enity_shape :: proc(s: Shape, pos: Vec2, rot: f32, col: ThemeColor, scale_hint: f32) {
	switch _ in s {
	case Rect:
		draw_rect(pos, s.(Rect).size, rot, col, scale_hint)
	case Circle:
		draw_circle(pos, s.(Circle).radius, col, scale_hint)
	}
}

draw_debug := false
draw_entity :: proc(e: ^Entity, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	if e.draw != nil {
		e.draw(e, state)
		if draw_debug do draw_enity_shape(e.shape, e.pos, e.rot, .DEBUG, scale_hint)
	} else {
		draw_enity_shape(e.shape, e.pos, e.rot, e.col, scale_hint)
	}
}

