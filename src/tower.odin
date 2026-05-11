package game

import rl "vendor:raylib"
import math "core:math"

TowerStats :: struct {
	shape: Shape,
	// Number of seconds between each attack
	attack_cooldown: f32,
	draw: proc(t: Tower, color: rl.Color),
	cost: int,
}

Tower :: struct {
	using entity: Entity,
	attack_timer: f32,
	stats: ^TowerStats,
}

laserTowerStats := TowerStats {
	shape = Rect{{48, 48}},
	draw = drawTower,
	attack_cooldown = 2,
	cost = 5,
}

update_towers :: proc(state: ^GameState, delta: f32) {
	towerCount := len(state.towers)
	for i in 0..<towerCount {
		tower := &state.towers[i]
		if tower.attack_timer <= 0 {
			// TODO: Cache the result somehow to reduce CPU usage
			target := get_target(state)
			if target != nil {
				dir := get_normalized_vector_facing_target(tower.pos, target.pos)
				tower.rot = -math.atan(dir.y / dir.x)
				bulletSpeed :: 1000
				append(&state.projectiles, Entity{
					pos = tower.pos + state.lookVec * 30,
					velocity = dir * bulletSpeed,
					shape = Circle {12},
					alive = true,
				})
				rl.PlaySound(laserSound)
				tower.attack_timer = tower.stats.attack_cooldown
			}
		} else {
			tower.attack_timer -= delta
		}
	}
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

drawTower :: proc(tower: Tower, color: rl.Color) {
	draw_entity(tower, color)
}
