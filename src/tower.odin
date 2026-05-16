package game

import math "core:math"

TowerType :: enum {CANNON, LASER}

Tower :: struct {
	using entity: Entity,
	type: TowerType,
	attack_timer: f32,
	cooldown: f32,
	target: Vec2,
	bullet_origin: Vec2,
	scale: f32,
}
TowerPreset :: struct {
	cost:u32,
	size:f32,
	height:f32,
	barrel_length:f32,
	cooldown: f32,
	icon: Drawable,
}
tower_presets := [TowerType]TowerPreset{
	.CANNON = {
		cost = 20,
		size = 48,
		height = 80,
		barrel_length = 40,
		cooldown = 0.2,
	},
	.LASER = {
		cost = 5,
		size = 18,
		height = 60,
		barrel_length = 30,
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
	tower.scale = 1.0
}

check_tower_near_cursor ::proc(t:Tower, state: ^GameState) -> bool{
	return check_collision(t, Entity{pos=state.cursor, shape=Circle{32}})
}

update_towers :: proc(state: ^GameState, delta: f32) {
	towerCount := len(state.towers)
	target := get_target(state)

	for i in 0..<towerCount {
		tower := &state.towers[i]
		if (
			check_tower_near_cursor(tower^, state) && (
			state.highlighted_tower == nil ||
			entity_dist_squared(tower, state.cursor) < entity_dist_squared(state.highlighted_tower, state.cursor)
		)) {
			state.highlighted_tower = tower
		}

		if tower.attack_timer > tower.cooldown && target != nil {
			shoot(tower, target.pos, state)
			tower.attack_timer -= tower.cooldown
		}
		tower.attack_timer += delta // NOTE: there's a bug here where it will charge up shots when it has no targets to shoot
		// but I think it's kind of cool so perhaps it should be a mechanic for one of the towers
	}
	if state.highlighted_tower != nil && !check_tower_near_cursor(state.highlighted_tower^, state) {
		state.highlighted_tower = nil
	}
}

shoot :: proc(t: ^Tower, target: Vec2, state: ^GameState) {
	dir := get_normalized_vector_facing_target(t.bullet_origin, target)
	t.target = target
	bulletSpeed :: 1000
	spawn_bullet(state, t.bullet_origin, dir * bulletSpeed)
}

draw_tower ::proc(t: ^Tower, state: ^GameState) {
	brightness:f32=1.0
	if state.highlighted_tower == t {
		brightness = 2.0
		draw_enity_shape(t.shape, entity_world_pos(t), entity_world_rot(t), state.scale_hint)
	}
	global_pos := local_to_world(t, {})
	rot := entity_world_rot(t)
	base := Bone{ global_pos, global_pos + unit_vector(rot) * tower_presets[t.type].height * t.scale }
	barrel := Bone{ base.tip, base.tip + normalize(t.target - base.tip) * tower_presets[t.type].barrel_length * t.scale}

	switch t.type {
	case .LASER:
		draw_on_bone(base, open_polygon({
			{-.2, 0},{0,.7},{.2,0},
		}), state.scale_hint, t.col, brightness)
		draw_on_bone(base, {{.DOT, {}, {0,1} }}, state.scale_hint, t.col, brightness)

		draw_on_bone(barrel, {
			{.LINE, {-.1,.1},{.1,.1}},
			{.LINE, {-.3,.2},{.3,.2}},
			{.LINE, {0,.3},{0,.8}},
			{.DOT, {},{0,1}},
		}, state.scale_hint, t.col, brightness)
	case .CANNON:
		draw_on_bone(base, {
			{.LINE, {-.3,0}, {-.3,1}},
			{.LINE, {.3,0}, {.3,1}},
		}, state.scale_hint, t.col, brightness)

		draw_on_bone(barrel, {
			{.DOT, {}, {}},
			{.CIRCLE, {}, {0,.7}},
			{.LINE, {.1,.5}, {.1,1}},
			{.LINE, {-.1,.5}, {-.1,1}},
		}, state.scale_hint, t.col, brightness)
	}
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

