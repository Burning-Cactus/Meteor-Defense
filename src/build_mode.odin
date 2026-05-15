package game

import rl "vendor:raylib"
import "core:math"

current_tower_type := &laserTowerStats
current_pending_tower:Tower

update_build_mode :: proc(state: ^GameState) {
	//NOTE: input processing should only be done in frame loop
	point, normal := find_intersection_point_on_entity(state.cursor, state.comet)
	current_pending_tower.pos = point
	current_pending_tower.rot = vec_angle(normal)
	current_pending_tower.stats = current_tower_type
	current_pending_tower.shape = current_tower_type.shape // is there a way to automate this?

	offset: f32
	switch shape in current_pending_tower.shape {
	case Circle:
		offset = shape.radius
	case Rect:
		offset = math.min(shape.size.x, shape.size.y)
		offset /= 2
	case Polygon:
		vertex := find_closest_vertex(current_pending_tower.pos, shape.vertices)
		offset = math.sqrt(dist_squared(current_pending_tower.pos, vertex))
	}
	current_pending_tower.pos += normal * offset
}

draw_build_mode :: proc(state: ^GameState) {
	can_build := true
	if check_collision_any(current_pending_tower, state.towers) {
		current_pending_tower.col = .RED
		can_build = false
	} else if current_tower_type.cost > state.money {
		current_pending_tower.col = .YELLOW
		can_build = false
	} else {
		current_pending_tower.col = .CYAN
	}

	draw_entity(&current_pending_tower.entity, state)
	if rl.IsMouseButtonPressed(.LEFT) && can_build {
		state.money -= current_pending_tower.stats.cost
		current_pending_tower.col = .PRIMARY
		spawn(&state.towers, current_pending_tower.pos, current_pending_tower)
	}
}
