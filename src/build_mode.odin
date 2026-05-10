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

	if rl.IsMouseButtonPressed(.LEFT) {
		append(&state.towers, current_pending_tower)
	}
}

draw_build_mode :: proc(state: GameState) {
	draw_entity(current_pending_tower, {0xFF, 0x8F, 0x8F, 0x8F})
}
