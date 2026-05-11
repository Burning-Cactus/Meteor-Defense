package game

import "core:math"
import "core:math/rand"
import "core:fmt"

// Different meteors will have different path strategies in the future.
Meteor :: struct {
	using entity: Entity,
}

MeteorStats :: struct {
	speed: f32,
	rot_speed: f32,
}

update_meteors :: proc(state: ^GameState, delta: f32) {
	meteorCount := len(state.meteors)
	for i in 0..<meteorCount {
		meteor := &state.meteors[i]
		if !meteor.alive do continue

		//meteor.rot += delta
		meteor.pos += meteor.velocity * delta
		if check_collision(meteor^, state.comet) {
			state.cometHealth -= 1
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
		// Spawn meteors
		append(&state.meteors, Meteor{
			pos = spawn_pos,
			velocity = get_normalized_vector_facing_target(spawn_pos, state.comet.pos) * 80,
			shape = Circle{32},
			alive = true,
		})
		spawn_timer = 0
	}
}
