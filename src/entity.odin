// Things that live in the game world which, move, collide, or are drawn.
// Includes abstract definitions and more concrete specific entities; how they're drawn, and how they behave
package game
import rl "vendor:raylib"
import "core:math"

Rect :: struct {
	size: Vec2,
}
Circle :: struct {
	radius: f32,
}
Polygon :: struct {
	vertices: []Vec2,
}

one_fifth: f32 : math.PI * 2 / 5

pentagon := []Vec2{
	{200 * math.cos(f32(0)), 200 * math.sin(f32(0))},
	{200 * math.cos(one_fifth), 200 * math.sin(one_fifth)},
	{200 * math.cos(one_fifth * 2), 200 * math.sin(one_fifth * 2)},
	{200 * math.cos(one_fifth * 3), 200 * math.sin(one_fifth * 3)},
	{200 * math.cos(one_fifth * 4), 200 * math.sin(one_fifth * 4)},
}

Shape :: union {
	Rect,
	Circle,
	Polygon,
}

Entity :: struct {
	id:        u64,
	label:     string,
	pos:       Vec2,
	velocity:  Vec2,
	rot:       f32,
	rot_speed: f32,
	shape: Shape,
	parent: ^Entity,

	hp: f32,
	power: f32,
	col: ThemeColor,

	draw: proc(e: ^Entity, state: ^GameState),
	on_death: proc(e: ^Entity, state: ^GameState),

	alive: bool,
	value: u32,
}

// --- Utils ---

next_entity_id: u64
get_new_entity_id ::proc() -> u64 {
	defer next_entity_id += 1
	return next_entity_id
}

spawn :: proc(list: ^[dynamic]$T, pos: Vec2, entity: T) -> ^T {
	e := entity
	e.pos = pos
	e.id = get_new_entity_id()
	e.alive = true
	append(list, e)
	return &list[len(list) - 1]
}

remove_dead :: proc(list: ^[dynamic]$T, state: ^GameState) {
	for i := len(list) - 1; i >= 0; i -= 1 {
		e := &list[i]
		if !e.alive {
			if e.on_death != nil do e.on_death(e, state)
			unordered_remove(list, i)
		}
	}
}

entity_bounds :: proc(e: ^Entity) -> Vec2 {
	switch shape in e.shape {
	case Rect:
		return shape.size
	case Polygon:
		break
	case Circle:
		x := shape.radius * 2.0
		return {x, x}
	}
	return {0, 0}
}

entity_size :: proc(e: ^Entity) -> f32 {
	switch shape in e.shape {
	case Rect:
		r := shape.size
		return max(r.y, r.y)
	case Circle:
		return shape.radius * 2.0
	case Polygon:
		break
	}
	return 0
}

// --- Hierarchical Tranforms ---

entity_world_pos :: proc(e: Entity) -> Vec2 {
	return local_to_world(e, {0, 0})
}

entity_world_rot :: proc(e: Entity) -> f32 {
	rot := e.rot
	if e.parent != nil do rot += entity_world_rot(e.parent^) //HACK
	return rot
}

world_to_local :: proc(e: Entity, p: Vec2) -> Vec2 {
	q := e.parent != nil ? world_to_local(e.parent^, p) : p
	d := q - e.pos
	c := math.cos(-e.rot)
	s := math.sin(-e.rot)
	return {d.x * c - d.y * s, d.x * s + d.y * c}
}

local_to_world :: proc(e: Entity, p: Vec2) -> Vec2 {
	c := math.cos(e.rot)
	s := math.sin(e.rot)
	world := e.pos + Vec2{p.x * c - p.y * s, p.x * s + p.y * c}
	return e.parent != nil ? local_to_world(e.parent^, world) : world
}

attach_to_parent :: proc(child: ^Entity, parent: ^Entity) {
	child.pos = world_to_local(parent^, child.pos)
	child.rot -= parent.rot
	child.parent = parent
}

// --- Collision ---

rl_rect :: proc(e: Entity, r: Rect) -> rl.Rectangle {
	return rl.Rectangle{e.pos.x, e.pos.y, r.size.x, r.size.y} // This is still broken right?
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

check_collision_polygon_circle :: proc(vertices1: []Vec2, a_rot: f32, b_pos: Vec2, b_shape: Circle) -> bool {
	// The comparison from the circle's side is just the axis connecting the center of the circle and the nearest vertex of the polygon.
	{
		closest_vertex := find_closest_vertex(b_pos, vertices1)
		closest_axis := normalize(closest_vertex - b_pos)
		min1, max1 := project_shape_onto_axis(vertices1, closest_axis)
		circle_projection := dot_product(b_pos, closest_axis)
		min2 := circle_projection - b_shape.radius
		max2 := circle_projection + b_shape.radius
		if min1 > max2 || min2 > max1 {
			return false
		}
	}

	axes1 := calculate_normals_of_edges(vertices1)
	for i in 0 ..< len(axes1) {
		min1, max1 := project_shape_onto_axis(vertices1, axes1[i])
		circle_projection := dot_product(b_pos, axes1[i])
		min2 := circle_projection - b_shape.radius
		max2 := circle_projection + b_shape.radius
		if min1 > max2 || min2 > max1 {
			return false
		}
	}
	return true
}

check_collision_between_polygons :: proc(vertices1: []Vec2, vertices2: []Vec2) -> bool {
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
	return true
}

// Check collision between two convex polygons of any rotation.
// This is done by getting the axes perpendicular to every edge of each shape.
// Then for each axis, project both shapes onto the axis as a 1D line segment and see if they overlap.
// They must overlap on all axes to be colliding.
check_collision_sat :: proc(a: Entity, b: Entity) -> bool {
	a_pos := entity_world_pos(a)
	a_rot := entity_world_rot(a)
	b_pos := entity_world_pos(b)
	b_rot := entity_world_rot(b)
	vertices1: []Vec2
	#partial switch a_shape in a.shape {
	case Polygon:
		vertices1 = copy_and_rotate_vertices(a_shape.vertices, a_pos, a_rot)
	case Rect:
		vertices1 = rect_to_vertices(a_shape, a_pos, a_rot)
	}
	switch b_shape in b.shape {
	case Polygon:
		vertices2 := copy_and_rotate_vertices(b_shape.vertices, b_pos, b_rot)
		return check_collision_between_polygons(vertices1, vertices2)
	case Rect:
		vertices2 := rect_to_vertices(b_shape, b_pos, b_rot)
		return check_collision_between_polygons(vertices1, vertices2)
	case Circle:
		return check_collision_polygon_circle(vertices1, a_rot, b_pos, b_shape)
	}
	return true
}

check_collision :: proc(a: Entity, b: Entity) -> bool {
	//if a == b do return false // or perhaps true?
	switch a_shape in a.shape {
	case Rect, Polygon:
		return check_collision_sat(a, b)
	case Circle:
		switch b_shape in b.shape {
		case Rect, Polygon:
			return check_collision_sat(b, a)
		case Circle:
			return rl.CheckCollisionCircles(entity_world_pos(a), a_shape.radius, entity_world_pos(b), b_shape.radius)
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

// --- Intersection ---

find_intersection_point_on_rect :: proc(start_pos: Vec2, r: Rect) -> (pos: Vec2, normal: Vec2) {
	r_start := -r.size / 2
	r_end   :=  r.size / 2

	outside := (
		start_pos.x < r_start.x ||
		start_pos.x > r_end.x ||
		start_pos.y < r_start.y ||
		start_pos.y > r_end.y
	)
	if outside {
		pos = {
			math.clamp(start_pos.x, r_start.x, r_end.x),
			math.clamp(start_pos.y, r_start.y, r_end.y),
		}
		normal = normalize(start_pos - pos)
		return
	}

	// Interior: snap to the nearest face.
	bx, nx := nearest_bound(start_pos.x, r_start.x, r_end.x)
	by, ny := nearest_bound(start_pos.y, r_start.y, r_end.y)
	if abs(start_pos.x - bx) < abs(start_pos.y - by) {
		pos = {bx, start_pos.y}
		normal = {nx, 0}
	} else {
		pos = {start_pos.x, by}
		normal = {0, ny}
	}
	return
}

find_intersection_point_on_circle :: proc(start_pos: Vec2, c:Circle) -> (pos:Vec2, normal:Vec2) {
	normal = normalize(start_pos)
	pos = normal * c.radius
	return
}

find_intersection_point_on_polygon :: proc(start_pos: Vec2, poly: Polygon) -> (pos: Vec2, normal: Vec2) {
	n := len(poly.vertices)
	best_u: f32 = math.F32_MAX
	for i in 0..<n {
		a := poly.vertices[i]
		r := poly.vertices[(i + 1) % n] - a
		// Ray from origin outward through start_pos — finds the boundary on the start_pos
		// side for both interior and exterior points (exterior hits at u<1, interior at u>1).
		t, u, ok := segment_intersect(a, r, {0, 0}, start_pos)
		if !ok || t < 0 || t > 1 || u < 0 || u >= best_u do continue
		best_u = u
		pos = a + t * r
		normal = outward_edge_normal(r, a)
	}
	return
}

find_intersection_point_on_entity :: proc( startPos: Vec2, target: Entity) -> (pos:Vec2, normal:Vec2) {
	local_startpos := world_to_local(target, startPos)

	switch shape in target.shape {
	case Rect:
		pos, normal = find_intersection_point_on_rect( local_startpos, shape )
	case Polygon:
		pos, normal = find_intersection_point_on_polygon(local_startpos, shape)
		// Solve for scalars t and u
	case Circle:
		pos, normal = find_intersection_point_on_circle( local_startpos, shape )
	}
	pos = local_to_world(target, pos)
	normal = normalize(local_to_world(target, normal)) //TODO rotating would be more efficient
	return pos, normal
}

// --- Drawing ---

draw_enity_shape :: proc(s: Shape, pos: Vec2, rot: f32, scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness: f32 = 1.0) {
	switch shape in s {
	case Rect:
		draw_rect(pos, shape.size, rot, scale_hint, col, brightness)
	case Circle:
		draw_circle(pos, shape.radius, scale_hint, col, brightness)
	case Polygon:
		draw_polygon_transformed(shape.vertices, pos, rot, scale_hint, col, brightness)
	}
}

draw_debug := false
draw_entity :: proc(e: ^Entity, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	if e.draw != nil {
		e.draw(e, state)
		if draw_debug do draw_enity_shape(e.shape, entity_world_pos(e^), entity_world_rot(e^), scale_hint, .DEBUG)
	} else {
		draw_enity_shape(e.shape, entity_world_pos(e^), entity_world_rot(e^), scale_hint, e.col)
	}
}
