package game

import rl "vendor:raylib"

current_tower_type := &laserTowerStats
current_pending_tower:Tower

update_build_mode :: proc(state: ^GameState) {
	//NOTE: input processing should only be done in frame loop
	current_pending_tower.pos = find_intersection_point_on_entity(state.cursor, state.comet)
	current_pending_tower.rot = angle_facing(current_pending_tower.pos, state.cursor)
	current_pending_tower.stats = current_tower_type
	current_pending_tower.shape = current_tower_type.shape // is there a way to automate this?
}

draw_build_mode :: proc(state: ^GameState) {
	color:rl.Color = {0x8F, 0xFF, 0x8F, 0xFF}
	can_build:=true
	if check_collision_any(current_pending_tower, state.towers) {
		color = {0xFF, 0x3F, 0x3F, 0xFF}
		can_build = false
	} else if current_tower_type.cost > state.money {
		color = {0xFF, 0xFF, 0x3F, 0xFF}
		can_build = false
	}

	draw_entity(current_pending_tower, color)
	if rl.IsMouseButtonPressed(.LEFT) && can_build {
		state.money -= current_pending_tower.stats.cost
		append(&state.towers, current_pending_tower)
	}
}
