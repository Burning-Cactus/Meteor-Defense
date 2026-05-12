package game

import "core:math"
import "core:math/rand"

Meteor :: struct {
	using entity: Entity,
	stats: ^MeteorStats,
}

MeteorStats :: struct {
	max_health: f32,
	power: f32,
	speed: f32,
	rot_speed: f32,
	shape: Shape,
	draw: proc(e: ^Entity, state: ^GameState),
}

meteor_stats := []MeteorStats{
	MeteorStats{
		speed = 80,
		rot_speed = 0.2,
		shape = Circle{24},
		max_health = 1.0,
		power = 1.0,
		draw = draw_large_meteor,
	},
	MeteorStats{
		speed = 120,
		rot_speed = 0.8,
		shape = Circle{16},
		max_health = 2.0,
		power = 2.0,
		draw = draw_small_meteor,
	},
}

draw_small_meteor :: proc(e: ^Entity, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	draw_star(e.pos, e.rot, 5, e.shape.(Circle).radius, 0.6, e.col, scale_hint)
}

draw_large_meteor :: proc(e: ^Entity, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	r := e.shape.(Circle).radius
	draw_random_convex_polygon(e.pos, e.rot, 7, r * 2, r * 2, 42, e.col, scale_hint)
}

update_meteors :: proc(state: ^GameState, delta: f32) {
	meteorCount := len(state.meteors)
	for i in 0..<meteorCount {
		meteor := &state.meteors[i]
		if !meteor.alive do continue

		if meteor.stats.rot_speed != 0.0{
			meteor.rot += meteor.stats.rot_speed * delta
		} else {
			meteor.rot = -vec_angle(meteor.velocity)
		}
		meteor.pos += meteor.velocity * delta
		if check_collision(meteor^, state.comet) {
			state.comet.hp -= meteor.stats.power //FIXME: this doesn't work
			meteor.alive = false
		}
	}
}

// Spawns are done on a circle on the outside of the battlefield.

spawn_cooldown: f32 = 1.5
spawn_timer: f32
spawn_radius: f32 = 400

handle_spawns :: proc(state: ^GameState, delta: f32) {
	spawn_timer += delta
	if spawn_timer >= spawn_cooldown {
		// We'll determine the spawn position in polar coordinates, then convert to cartesian.
		// Range -1 to 1 => -pi to pi
		r := rand.float32() * 2 - 1
		spawn_angle := r * math.PI + state.comet.rot
		spawn_pos := Vec2{math.cos(spawn_angle), math.sin(spawn_angle)} * spawn_radius + state.comet.pos
		spawn_group(state, spawn_pos)
		spawn_timer -= spawn_cooldown
	}
}

spawn_meteor :: proc(state: ^GameState, pos: Vec2, stats: ^MeteorStats) {
	spawn(&state.meteors, Meteor{
		pos = pos,
		velocity = get_normalized_vector_facing_target(pos, state.comet.pos) * stats.speed,
		shape = stats.shape,
		col = .RED,
		alive = true,
		hp = stats.max_health,
		stats = stats,
		draw = stats.draw,
		reward = 1,
		death_sfx = rockDestroyedSound,
	})
}

spawn_group :: proc(state: ^GameState, spawn_pos: Vec2) {
	spawn_count := rand.int31_max(5) + 1
	for i in 0..<spawn_count {
		stats := &meteor_stats[rand.uint32_max(u32(len(meteor_stats)))]
		spawn_meteor(state, Vec2{spawn_pos.x + f32(i) * 50, spawn_pos.y}, stats)
	}
}
