package game

import "core:math"
import "core:math/rand"

MeteorType :: enum {
	SHOOTING_STAR,
	METEOROID,
	ASTEROID,
}

POLYGON_CACHE_SIZE :: 64
meteoroid_polygon_cache: [POLYGON_CACHE_SIZE][]Vec2
asteroid_polygon_cache: [POLYGON_CACHE_SIZE][]Vec2

init_meteor_polygons :: proc() {
	for i in 0 ..< POLYGON_CACHE_SIZE {
		ms := meteor_presets[.METEOROID]
		as := meteor_presets[.ASTEROID]
		meteoroid_polygon_cache[i] = random_convex_polygon(
			{0, 0},
			0,
			7,
			ms.size * 2,
			ms.size * 2,
			u64(i),
			context.allocator,
		)
		asteroid_polygon_cache[i] = random_convex_polygon(
			{0, 0},
			0,
			17,
			as.size * 2,
			as.size * 2,
			u64(i + POLYGON_CACHE_SIZE),
			context.allocator,
		)
	}
}
Meteor :: struct {
	using entity: Entity,
	type:         MeteorType,
	polygon:      []Vec2,
}

// These are somewhat high-level and open to interpretation
MeteorPreset :: struct {
	speed, spin, size, health, power: f32,
	reward:                           u32,
	death_sfx:                        string,
}
meteor_presets := [MeteorType]MeteorPreset {
	.SHOOTING_STAR = {speed = 120, spin = 0.8, size = 16, health = 1.0, power = 0.2, reward = 1},
	.METEOROID = {speed = 80, spin = 0.2, size = 24, health = 2.0, power = 1.0, reward = 2},
	.ASTEROID = {
		speed = 40,
		spin = 0.1,
		size = 128,
		health = 12.0,
		power = 5.0,
		reward = 10,
		death_sfx = "asteroid_hit",
	},
}

draw_meteor :: proc(m: ^Meteor, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	if m.polygon != nil {
		draw_polygon_transformed(
			m.polygon,
			m.pos,
			m.rot,
			scale_hint,
			m.col,
			m.brightness * damage_brightness_mod(m),
		)
	} else {
		draw_star(
			m.pos,
			m.rot,
			5,
			entity_size(m) / 2,
			0.6,
			scale_hint,
			m.col,
			m.brightness * damage_brightness_mod(m),
		)
	}
}

meteor_on_death :: proc(m: ^Meteor, state: ^GameState) {
	if sfx := meteor_presets[m.type].death_sfx; sfx != "" {
		play_sfx(sfx)
	}
	play_sfx("hit")
	//spawn_sparks(state, m.pos, 10, 220, 0.7)
	if m.type > .SHOOTING_STAR {
		spawn_exploded(
			state,
			copy_and_rotate_vertices(m.polygon, m.pos, m.rot),
			m.col,
			m.velocity / 2.0,
		)
	}

	if m.type == .ASTEROID {
		spawn_group(state, m.pos, .METEOROID, .CIRCLE)
	} else {
		spawn_bang(state, m.pos, entity_size(m) * 1.0)
	}
}

update_meteors :: proc(state: ^GameState, delta: f32) {
	meteorCount := len(state.meteors)
	for i in 0 ..< meteorCount {
		meteor := &state.meteors[i]
		update_entity(meteor, delta)
		if state.comet.alive && check_collision(meteor^, state.comet) {
			hurt_comet(meteor.power)
			meteor.alive = false
		}
	}
}


spawn_cooldown: f32 = 4.0
spawn_timer: f32
spawn_radius: f32 = 2000

handle_spawns :: proc(state: ^GameState, delta: f32) {
	if state.gameTime >= 90 && state.gameTime < 120 {
		star_storm(state, delta)
		return
	}
	spawn_timer += state.difficulty_scale * delta
	if spawn_timer >= spawn_cooldown {
		// We'll determine the spawn position in polar coordinates, then convert to cartesian.
		// Range -1 to 1 => -pi to pi
		r := rand.float32() * 2 - 1
		spawn_angle := r * math.PI + state.comet.rot
		spawn_pos :=
			Vec2{math.cos(spawn_angle), math.sin(spawn_angle)} * spawn_radius + state.comet.pos
		type := choose_meteor_type(state)
		spawn_group(state, spawn_pos, type)
		spawn_timer -= spawn_cooldown
	}

}

choose_meteor_type :: proc(state: ^GameState) -> MeteorType {
	star_weight: i32 = 6
	meteor_weight := i32(1.5 * state.difficulty_scale + 1)
	asteroid_weight := i32(1.1 * (state.difficulty_scale - 1.05))
	if asteroid_weight < 0 do asteroid_weight = 0
	r := rand.int31_max(star_weight + meteor_weight + asteroid_weight)
	if r < asteroid_weight do return MeteorType.ASTEROID
	if r < asteroid_weight + meteor_weight do return MeteorType.METEOROID
	return MeteorType.SHOOTING_STAR
}

choose_formation :: proc(state: ^GameState) -> Formation {
	wide_weight: i32 = 4
	long_weight: i32 = 2
	circle_weight: i32 = 3
	erratic: i32 = 2
	r := rand.int31_max(wide_weight + long_weight + circle_weight + erratic)
	if r < wide_weight do return Formation.WIDE
	if r < wide_weight + long_weight do return Formation.LONG
	if r < wide_weight + long_weight + circle_weight do return Formation.CIRCLE
	return Formation.ERRATIC
}

Formation :: enum {
	WIDE,
	LONG,
	CIRCLE,
	ERRATIC,
}

spawn_meteor :: proc(state: ^GameState, pos: Vec2, type: MeteorType) {
	preset := meteor_presets[type]
	m := spawn(
	&state.meteors,
	pos,
	Meteor {
		col       = .RED,
		on_death  = meteor_on_death,
		draw      = draw_meteor,
		shape     = Circle{preset.size}, //TODO: support polygonal asteroids
		hp        = preset.health,
		max_hp    = preset.health,
		rot_speed = preset.spin,
		value     = preset.reward,
		power     = preset.power,
		velocity  = get_normalized_vector_facing_target(pos, state.comet.pos) * preset.speed,
		type      = type,
	},
	)
	switch type {
	case .METEOROID:
		m.polygon = meteoroid_polygon_cache[m.id % POLYGON_CACHE_SIZE]
	case .ASTEROID:
		m.polygon = asteroid_polygon_cache[m.id % POLYGON_CACHE_SIZE]
	case .SHOOTING_STAR: // nil
	}
}


spawn_group :: proc(
	state: ^GameState,
	spawn_pos: Vec2,
	type: MeteorType,
	formation := Formation.WIDE,
) {
	facing_vec := get_normalized_vector_facing_target(spawn_pos, state.comet.pos)
	facing_angle := math.atan2(facing_vec.y, facing_vec.x)
	facing_rot_mat := calculate_rotation_matrix(facing_angle)

	temp_pos := spawn_pos
	spawn_count := rand.int31_max(5) + 1
	size := meteor_presets[type].size
	slice_rot_mat: matrix[2, 2]f32
	p: Vec2

	f := Formation.CIRCLE
	if f == .CIRCLE {
		circle_slice_size := (math.PI * 2) / f32(spawn_count)
		slice_rot_mat = calculate_rotation_matrix(circle_slice_size)
		p = Vec2{(size + 10) * 2, 0}
	}
	for i in 0 ..< spawn_count {
		switch f {
		case .WIDE:
			p = Vec2{0, f32(i) * (size * 1.5)} * facing_rot_mat
			temp_pos += p
			spawn_meteor(state, temp_pos, type)
		case .LONG:
			p = Vec2{f32(i) * (size * 1.5), 0} * facing_rot_mat
			temp_pos += p
			spawn_meteor(state, temp_pos, type)
		case .CIRCLE:
			p *= slice_rot_mat
			spawn_meteor(state, temp_pos + p, type)
		case .ERRATIC:
			p =
				Vec2{size * f32(rand.int31_max(i) + 1), size * f32(rand.int31_max(i) + 1)} *
				facing_rot_mat
			temp_pos += p
			spawn_meteor(state, temp_pos, type)
		}
	}
}

star_storm :: proc(state: ^GameState, delta: f32) {
	spawn_pos := normalize(state.comet_velocity) * 4000
	spawn_timer += state.difficulty_scale * delta
	if spawn_timer >= 2.0 {
		spawn_count := rand.int31_max(10) + 1
		type := choose_meteor_type(state)
		spawn_meteor(state, spawn_pos, type)

		spawn_timer -= 2.0
	}
}

