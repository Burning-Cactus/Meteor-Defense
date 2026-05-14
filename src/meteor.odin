package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

MeteorType :: enum {SHOOTING_STAR, METEOROID, ASTEROID}
Meteor :: struct {
	using entity: Entity,
	type : MeteorType,
}

// These are somewhat high-level and open to interpretation
MeteorPreset :: struct {
	speed, spin, size, health, power:f32,
	reward:u32,
}
meteor_presets := [MeteorType]MeteorPreset{
	.SHOOTING_STAR = {
		speed = 120,
		spin = 0.8,
		size = 16,
		health = 1.0,
		power = 1.0,
		reward = 1,
	},
	.METEOROID = {
		speed = 80,
		spin = 0.2,
		size = 24,
		health = 2.0,
		power = 1.0,
		reward = 2,
	},
	.ASTEROID = {
		speed = 30,
		spin = 0.1,
		size = 128,
		health = 12.0,
		power = 5.0,
		reward = 10,
	},
}

draw_meteor :: proc(m: ^Meteor, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	switch m.type {
	case .SHOOTING_STAR:
		draw_star(m.pos, m.rot, 5, entity_size(m)/2, 0.6, m.col, scale_hint)
	case .METEOROID:
		r := entity_bounds(m)
		draw_random_convex_polygon(m.pos, m.rot, 7, r.x, r.y, m.id, m.col, scale_hint)
	case .ASTEROID:
		r := entity_bounds(m)
		draw_random_convex_polygon(m.pos, m.rot, 17, r.x, r.y, m.id, m.col, scale_hint)
	}
}

meteor_on_death :: proc(m: ^Meteor) {
	rl.PlaySound(rockDestroyedSound)
}

update_meteors :: proc(state: ^GameState, delta: f32) {
	meteorCount := len(state.meteors)
	for i in 0..<meteorCount {
		meteor := &state.meteors[i]
		if !meteor.alive do continue

		meteor.rot += meteor.rot_speed * delta
		meteor.pos += meteor.velocity * delta

		if check_collision(meteor^, state.comet) {
			state.comet.hp -= meteor.power
			meteor.alive = false
		}
	}
}

spawn_cooldown: f32 = 1.5
spawn_timer: f32
spawn_radius: f32 = 1000

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

spawn_meteor :: proc(state: ^GameState, pos: Vec2, type: MeteorType) {
	preset := meteor_presets[type]
	spawn(&state.meteors, pos, Meteor{
		col = .RED,
		on_death = meteor_on_death,
		draw = draw_meteor,
		shape = Circle{preset.size}, //TODO: support polygonal asteroids
		hp = preset.health,
		rot_speed = preset.spin,
		value = preset.reward,
		power = preset.power,
		velocity = get_normalized_vector_facing_target(pos, state.comet.pos) * preset.speed,
		type = type,
	})
}

spawn_group :: proc(state: ^GameState, spawn_pos: Vec2) {
	spawn_count := rand.int31_max(5) + 1
	for i in 0..<spawn_count {
		type:=rand.choice_enum(MeteorType)
		spawn_meteor(state, Vec2{spawn_pos.x + f32(i) * 50, spawn_pos.y}, type)
	}
}
