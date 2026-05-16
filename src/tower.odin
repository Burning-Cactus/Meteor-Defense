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
	target: Vec2,
	has_target: bool,
	target_closeness_bias, target_ahead_bias: f32,

	debug_info:f32,
}

TowerPreset :: struct {
	cost:u32,

	size,
	height,
	barrel_length:f32,

	cooldown,
	damage:f32,

	aim_arc:i32,
	turn_speed,
	range,
	aim_tolerance:f32,

	attentiveness,
	target_closeness_bias,
	target_ahead_bias:f32,
}

tower_presets := [TowerType]TowerPreset{
	.CANNON = {
		cost          = 20,

		size          = 48,
		height        = 80,
		barrel_length = 40,

		cooldown      = 0.2,
		damage=1.0,

		turn_speed    = 1.8,
		range         = 800,
		aim_arc       = 80,
		aim_tolerance = 0.08,

		attentiveness = 6,
		target_closeness_bias = 1.0,
		target_ahead_bias = 1.0,
	},
	.LASER = {
		cost          = 5,
		size          = 18,
		height        = 60,
		barrel_length = 30,
		cooldown      = 2.0,
		damage=3.0,
		turn_speed    = 5,
		range         = 1800,
		aim_arc       = 60,
		attentiveness = 1,
		target_closeness_bias = 0.2,
		target_ahead_bias = 1.0,
	},
}

init_tower :: proc(tower: ^Tower, type: TowerType) {
	preset := tower_presets[type]
	tower.type          = type
	tower.col           = .BLUE
	tower.shape         = Circle{preset.size / 2}
	tower.cooldown      = preset.cooldown
	tower.power         = preset.damage
	tower.value         = preset.cost
	tower.draw          = draw_tower
	tower.scale         = 1.0
	tower.turn_speed    = preset.turn_speed
	tower.range         = preset.range
	tower.aim_arc       = math.to_radians(f32(preset.aim_arc))
	tower.attentiveness = preset.attentiveness
	tower.aim_tolerance = max(preset.aim_tolerance, 0.001)
	tower.target_closeness_bias = 1.0 //preset.target_closeness_bias
	tower.target_ahead_bias = 1.0 //preset.target_ahead_bias

	assert(tower.target_ahead_bias + tower.target_closeness_bias > 0)
	assert(tower.power > 0)
}

check_tower_near_cursor :: proc(t: Tower, state: ^GameState) -> bool {
	return check_collision(t, cursor_entity())
}

angle_diff :: proc(a, b: f32) -> f32 {
	diff := a - b
	for diff >  math.PI do diff -= 2 * math.PI
	for diff < -math.PI do diff += 2 * math.PI
	return diff
}

target_score :: proc(tower: ^Tower, target: Entity) -> f32 {
	if !target.alive do return 0
	range_sq := tower.range * tower.range
	m_local:= world_to_local(tower, target.pos)

	angle:=vec_angle(m_local) // 0 means straight up
	if abs(angle) > tower.aim_arc do return 0
	angle_from_barrel :f32 = angle - tower.barrel_angle + entity_world_rot(tower)


	d_sq := dist_squared(m_local)
	if d_sq > range_sq do return 0

	assert(range_sq > 0.0)
	d_sq_ratio := 1.0 - d_sq / range_sq
	assert(d_sq_ratio >= 0 && d_sq_ratio <= 1.0)
	angle_sq_ratio := 1.0 - sqr(angle_from_barrel) / sqr(tower.aim_arc) // we sqaure this as well just for fairness
	angle_sq_ratio = math.clamp(angle_sq_ratio, 0, 1)

	return d_sq_ratio * tower.target_closeness_bias + angle_sq_ratio * tower.target_ahead_bias
}

aim_debug :: false
// Use the target_score function to get the best target.
// If `best_score` == 0 then no valid target was found
// NOTE: `target` Entity return may go out of date if not used immediately
// Don't save it, instead, save the id and search for it later
find_target_for_tower :: proc(tower: ^Tower, state: ^GameState) -> (target:^Entity, best_score:f32) {
	for &m in state.meteors {
		score := target_score(tower, m)
		if score > best_score {
			best_score = score
			target = &m
		}
	}
	return
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
			found_target, found_target_score := find_target_for_tower(tower, state)
			tower.has_target = found_target_score > 0
			if tower.has_target do tower.target = entity_world_pos(found_target^)
		}

		base_angle := entity_world_rot(tower^)

		// Turn barrel toward target, clamped to aim_arc from base direction
		if tower.has_target {
			tower_pos     := entity_world_pos(tower^)
			desired_angle := angle_facing(tower_pos, tower.target)

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
			desired_angle := angle_facing(tower_pos, tower.target)
			if abs(angle_diff(tower.barrel_angle, desired_angle)) < tower.aim_tolerance {
				shoot(tower, state)
				tower.attack_timer = 0
			}
		}
	}

	if state.highlighted_tower != nil && !check_collision(state.highlighted_tower^, cursor_entity()) {
		state.highlighted_tower = nil
	}
}

spawn_bullet :: proc(state: ^GameState, pos: Vec2, velocity: Vec2) {
	spawn(&state.projectiles, pos, Entity{
		velocity = velocity,
		shape = Circle{12},
		col = .PRIMARY,
		power = 1.0,
	})
	play_sfx("shoot")
}

shoot :: proc(t: ^Tower, state: ^GameState) {
	switch t.type {
	case .CANNON:
		spawn_bullet(state, t.bullet_origin, unit_vector(t.barrel_angle) * 1000)
	case .LASER:
		target, score := find_target_for_tower(t, state)
		t.has_target = score > 0
		if t.has_target {
			t.target = entity_world_pos(target^)
			spawn_laser_pulse(state, t.bullet_origin, t.target)
			state.money += hurt_entity_directly(target, t.power, {})
		}
		play_sfx("shoot")
	}
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
	//draw_entity_debug_lines(t, t.debug_info)
	//draw_line(entity_world_pos(t), t.target, state.scale_hint)

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
	t.bullet_origin = barrel.tip // NOTE: this will be a frame behind, but it shouldn't matter
}
