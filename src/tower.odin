package game

import math "core:math"
import "core:math/rand"

TowerType :: enum {CANNON, LASER}

Tower :: struct {
	using entity:  Entity,
	type:          TowerType,
	attack_timer:  f32,
	cooldown:      f32,
	bullet_origin: Vec2,
	scale:         f32,

	turn_speed:    f32,
	range:         f32,
	aim_arc:       f32,
	attentiveness: f32,
	aim_tolerance: f32,

	barrel_angle:        f32,
	has_target:          bool,
	target_id:           u64,
}

TowerPreset :: struct {
	cost:          u32,
	size:          f32,
	height:        f32,
	barrel_length: f32,
	cooldown:      f32,

	turn_speed:    f32,
	range:         f32,
	aim_arc:       f32,
	attentiveness: f32,
	aim_tolerance: f32,
}

tower_presets := [TowerType]TowerPreset{
	.CANNON = {
		cost          = 20,
		size          = 48,
		height        = 80,
		barrel_length = 40,
		cooldown      = 0.2,
		turn_speed    = 1.8,
		range         = 800,
		aim_arc       = math.PI * 0.65,
		attentiveness = 0.1,
		aim_tolerance = 0.08,
	},
	.LASER = {
		cost          = 5,
		size          = 18,
		height        = 60,
		barrel_length = 30,
		cooldown      = 2.0,
		turn_speed    = 12.0,
		range         = 500,
		aim_arc       = math.PI * 0.55,
		attentiveness = 0.6,
		aim_tolerance = 0.2,
	},
}

init_tower :: proc(tower: ^Tower, type: TowerType) {
	preset := tower_presets[type]
	tower.type          = type
	tower.col           = .BLUE
	tower.shape         = Circle{preset.size / 2}
	tower.cooldown      = preset.cooldown
	tower.value         = preset.cost
	tower.draw          = draw_tower
	tower.scale         = 1.0
	tower.turn_speed    = preset.turn_speed
	tower.range         = preset.range
	tower.aim_arc       = preset.aim_arc
	tower.attentiveness = preset.attentiveness
	tower.aim_tolerance = preset.aim_tolerance
}

check_tower_near_cursor :: proc(t: Tower, state: ^GameState) -> bool {
	return check_collision(t, Entity{pos = state.cursor, shape = Circle{32}})
}

angle_diff :: proc(a, b: f32) -> f32 {
	diff := a - b
	for diff >  math.PI do diff -= 2 * math.PI
	for diff < -math.PI do diff += 2 * math.PI
	return diff
}

find_target_for_tower :: proc(tower: ^Tower, state: ^GameState) -> (id: u64, ok: bool) {
	range_sq     := tower.range * tower.range
	best_dist_sq : f32 = math.F32_MAX
	tower_pos    := entity_world_pos(tower^)
	for i in 0..<len(state.meteors) {
		meteor := &state.meteors[i]
		if !meteor.alive do continue
		d_sq := dist_squared(entity_world_pos(meteor.entity), tower_pos)
		if d_sq <= range_sq && d_sq < best_dist_sq {
			best_dist_sq = d_sq
			id = meteor.id
			ok = true
		}
	}
	return
}

get_target_pos :: proc(target_id: u64, state: ^GameState) -> (pos: Vec2, ok: bool) {
	for i in 0..<len(state.meteors) {
		meteor := &state.meteors[i]
		if meteor.id == target_id && meteor.alive {
			return entity_world_pos(meteor.entity), true
		}
	}
	return {}, false
}

update_towers :: proc(state: ^GameState, delta: f32) {
	towerCount := len(state.towers)

	for i in 0..<towerCount {
		tower := &state.towers[i]
		if (
			check_tower_near_cursor(tower^, state) && (
			state.highlighted_tower == nil ||
			entity_dist_squared(tower, state.cursor) < entity_dist_squared(state.highlighted_tower, state.cursor)
		)) {
			state.highlighted_tower = tower
		}

		if rand.float32() < tower.attentiveness * delta {
			id, ok := find_target_for_tower(tower, state)
			tower.target_id  = id
			tower.has_target = ok
		}

		// Clear target if it's no longer alive
		target_pos: Vec2
		if tower.has_target {
			alive: bool
			target_pos, alive = get_target_pos(tower.target_id, state)
			if !alive do tower.has_target = false
		}

		base_angle := entity_world_rot(tower^)

		// Turn barrel toward target, clamped to aim_arc from base direction
		if tower.has_target {
			tower_pos     := entity_world_pos(tower^)
			desired_angle := angle_facing(tower_pos, target_pos)

			// Clamp the desired angle to within aim_arc of the base bone
			diff_to_base    := angle_diff(desired_angle, base_angle)
			clamped_diff    := clamp(diff_to_base, -tower.aim_arc, tower.aim_arc)
			clamped_desired := base_angle + clamped_diff

			turn_diff := angle_diff(clamped_desired, tower.barrel_angle)
			max_turn  := tower.turn_speed * delta
			if abs(turn_diff) <= max_turn {
				tower.barrel_angle = clamped_desired
			} else {
				tower.barrel_angle += (f32(1) if turn_diff > 0 else f32(-1)) * max_turn
			}
		}

		// Re-clamp barrel after any comet rotation dragging it out of arc
		diff_to_base := angle_diff(tower.barrel_angle, base_angle)
		clamped_diff := clamp(diff_to_base, -tower.aim_arc, tower.aim_arc)
		tower.barrel_angle = base_angle + clamped_diff

		// Shoot when aim is within tolerance and cooldown is ready
		tower.attack_timer += delta
		if tower.has_target && tower.attack_timer > tower.cooldown {
			tower_pos     := entity_world_pos(tower^)
			desired_angle := angle_facing(tower_pos, target_pos)
			if abs(angle_diff(tower.barrel_angle, desired_angle)) < tower.aim_tolerance {
				shoot(tower, state)
				tower.attack_timer -= tower.cooldown
			}
		}
	}

	if state.highlighted_tower != nil && !check_tower_near_cursor(state.highlighted_tower^, state) {
		state.highlighted_tower = nil
	}
}

shoot :: proc(t: ^Tower, state: ^GameState) {
	bulletSpeed :: 1000
	spawn_bullet(state, t.bullet_origin, unit_vector(t.barrel_angle) * bulletSpeed)
}

draw_tower :: proc(t: ^Tower, state: ^GameState) {
	brightness: f32 = 1.0
	if state.highlighted_tower == t {
		brightness = 2.0
		draw_enity_shape(t.shape, entity_world_pos(t), entity_world_rot(t), state.scale_hint)
	}
	global_pos := local_to_world(t, {})
	rot        := entity_world_rot(t)
	base   := Bone{global_pos, global_pos + unit_vector(rot) * tower_presets[t.type].height * t.scale}
	barrel := Bone{base.tip, base.tip + unit_vector(t.barrel_angle) * tower_presets[t.type].barrel_length * t.scale}

	switch t.type {
	case .LASER:
		draw_on_bone(base, open_polygon({
			{-.2, 0},{0,.7},{.2,0},
		}), state.scale_hint, t.col, brightness)
		draw_on_bone(base, {{.DOT, {}, {0,1}}}, state.scale_hint, t.col, brightness)

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
	t.bullet_origin = barrel.tip // frame-late; acknowledged as acceptable
}
