package game

import rl "vendor:raylib"
import "core:math"

update_build_mode :: proc(state: ^GameState) {
	mousePos := Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
	buildPos := find_intersection_point_on_entity(mousePos, state.comet)
	state.buildCursor = buildPos
	facingVec := mousePos - buildPos
	if rl.IsMouseButtonPressed(.LEFT) {
		angle := -math.atan(facingVec.y / facingVec.x)
		tower := Tower{
			pos = buildPos,
			rot = angle,
			stats = &laserTowerStats,
		}
		append(&state.towers, tower)
	}
}

draw_build_mode :: proc(state: GameState) {
	mousePos := Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
	buildPos := state.buildCursor
	facingVec := mousePos - buildPos
	angle := -math.atan(facingVec.y / facingVec.x)
	tower := Tower{
		pos = buildPos,
		rot = angle,
		stats = &laserTowerStats,
	}
	tower.stats.draw(tower, {0xFF, 0x8F, 0x8F, 0x8F})
}
