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
}


meteor_stats := []MeteorStats{
	MeteorStats{
		speed = 80,
		rot_speed = 0,
		shape = Circle{24},
		max_health = 1.0,
		power = 1.0,
	},
	MeteorStats{
		speed = 120,
		rot_speed = 0.8,
		shape = Circle{16},
		max_health = 2.0,
		power = 2.0,
	},
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

spawn_group :: proc(state: ^GameState, spawn_pos: Vec2) {
	spawn_count := rand.int31_max(5) + 1
	for i in 0..<spawn_count {
		offset_pos := Vec2{spawn_pos.x + f32(i) * 50, spawn_pos.y}
		stats := &meteor_stats[rand.uint32_max(u32(len(meteor_stats)))]
		append(&state.meteors, Meteor{
			pos = offset_pos,
			velocity = get_normalized_vector_facing_target(offset_pos, state.comet.pos) * stats.speed,
			shape = stats.shape,
			alive = true,
			hp= stats.max_health,
			stats = stats,
			draw = draw_shooting_star,
		})
	}
}
