package game

import math "core:math"

TowerType :: enum {CANON_TOWER, LASER_TOWER}

Tower :: struct {
	using entity: Entity,
	attack_timer: f32,
	cooldown: f32,
}
TowerPreset :: struct {
	cost:u32,
	size:f32,
	cooldown: f32,
}
tower_presets := [TowerType]TowerPreset{
	.CANON_TOWER = {
		cost = 8,
		size = 48,
		cooldown = 1.4,
	},
	.LASER_TOWER = {
		cost = 5,
		size = 32,
		cooldown = 2.0,
	},
}

init_tower :: proc(tower: ^Tower, type: TowerType) {
	preset := tower_presets[type]
	tower.col = .BLUE
	tower.shape = Circle{preset.size / 2}
	tower.cooldown = preset.cooldown
	tower.value = preset.cost
	//tower.draw =  draw_tower
}

update_towers :: proc(state: ^GameState, delta: f32) {
	towerCount := len(state.towers)
	target := get_target(state)

	for i in 0..<towerCount {
		tower := &state.towers[i]
		if tower.attack_timer <= 0 && target != nil {
			global_pos := local_to_world(tower, {})
			dir := get_normalized_vector_facing_target(global_pos, target.pos)
			tower.rot = -math.atan(dir.y / dir.x)
			bulletSpeed :: 1000
			spawn_bullet(state, global_pos + state.lookVec * 30, dir * bulletSpeed)
			tower.attack_timer = tower.cooldown
		}
		tower.attack_timer -= delta
	}
}

draw_tower ::proc(t: ^Tower, state: ^GameState) {
}

get_target :: proc(state: ^GameState) -> (target: ^Entity) {
	distanceSq: f32 = math.F32_MAX
	meteorCount := len(state.meteors)
	for i in 0..<meteorCount {
		meteor := &state.meteors[i]
		d := dist_squared(meteor.pos, state.comet.pos)
		if d < distanceSq {
			distanceSq = d
			target = meteor
		}
	}
	return target
}

