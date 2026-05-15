package game

import math "core:math"

TowerType :: enum {CANON_TOWER, LASER_TOWER}

Tower :: struct {
	using entity: Entity,
	type: TowerType,
	attack_timer: f32,
	cooldown: f32,
	target: Vec2,
	bullet_origin: Vec2,
}
TowerPreset :: struct {
	cost:u32,
	size:f32,
	height:f32,
	cooldown: f32,
}
tower_presets := [TowerType]TowerPreset{
	.CANON_TOWER = {
		cost = 8,
		size = 48,
		height = 50,
		cooldown = 1.4,
	},
	.LASER_TOWER = {
		cost = 5,
		size = 32,
		height = 60,
		cooldown = 2.0,
	},
}

init_tower :: proc(tower: ^Tower, type: TowerType) {
	preset := tower_presets[type]
	tower.type = type
	tower.col = .BLUE
	tower.shape = Circle{preset.size / 2}
	tower.cooldown = preset.cooldown
	tower.value = preset.cost
	tower.draw =  draw_tower
}

update_towers :: proc(state: ^GameState, delta: f32) {
	towerCount := len(state.towers)
	target := get_target(state)

	for i in 0..<towerCount {
		tower := &state.towers[i]
		if tower.attack_timer > tower.cooldown && target != nil {
			shoot(tower, target.pos, state)
			tower.attack_timer -= tower.cooldown
		}
		tower.attack_timer += delta
	}
}

shoot :: proc(t: ^Tower, target: Vec2, state: ^GameState) {
	dir := get_normalized_vector_facing_target(t.bullet_origin, target)
	t.target = target
	bulletSpeed :: 1000
	spawn_bullet(state, t.bullet_origin, dir * bulletSpeed)
}

draw_tower ::proc(t: ^Tower, state: ^GameState) {
	global_pos := local_to_world(t, {})
	rot := entity_world_rot(t)
	base := Bone{ global_pos, global_pos + unit_vector(rot) * tower_presets[t.type].height }
	barrel := Bone{ base.tip, base.tip + normalize(t.target - base.tip) * 30}

	draw_on_bone(base, open_polygon({
		{-.2, 0},{0,.7},{.2,0},
	}), t.col, state.scale_hint)
	draw_on_bone(base, {{.DOT, {}, {0,1} }}, t.col, state.scale_hint)

	draw_on_bone(barrel, {
		{.LINE, {-.1,.1},{.1,.1}},
		{.LINE, {-.3,.2},{.3,.2}},
		{.LINE, {0,.3},{0,.8}},
		{.DOT, {},{0,1}},
	}, t.col, state.scale_hint)

	t.bullet_origin = barrel.tip // NOTE: since draw is called after update, this will be a frame too late, probably won't matter

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

