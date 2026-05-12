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

Shape :: union { Rect, Circle }

Entity :: struct {
	id: u64,
	label : string,
	pos: Vec2,
	velocity: Vec2,
	rot: f32,
	rot_speed: f32,
	shape: Shape,

	hp: f32,
	power: f32,
	col: ThemeColor,

	draw: proc(e: ^Entity, state: ^GameState),

	alive: bool,
	value: u32,
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
		return {x,x}
	}
	return {0,0}
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

check_collision_any :: proc(a: Entity, list: [dynamic]$T) -> bool {
	for b in list {
		if check_collision(a, b) do return true
	}
	return false //TODO maybe more useful if it returned b
}

// --- Drawing ---

draw_enity_shape ::proc(s:Shape, pos:Vec2, rot:f32, col:ThemeColor, scale_hint:f32) {
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
