package game

import rl "vendor:raylib"

update_build_mode :: proc(state: ^GameState) {
	mousePos := Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
	state.buildCursor = find_intersection_point_on_entity(mousePos, state.comet)
	if rl.IsMouseButtonPressed(.LEFT) {
		tower := Tower{
			pos = state.buildCursor,
			rot = 0,
			stats = &laserTowerStats,
		}
		append(&state.towers, tower)
	}
}

draw_build_mode :: proc(state: GameState) {
	buildPos := state.buildCursor
	tower := Tower{
		pos = buildPos,
		rot = 0,
		stats = &laserTowerStats,
	}
	tower.stats.draw(tower, {0xFF, 0x8F, 0x8F, 0x8F})
}
