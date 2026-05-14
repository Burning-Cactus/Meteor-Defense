package game

import "core:math"
import "core:math/rand"

VfxType :: enum { BANG, SPARK }

Vfx :: struct {
	using entity: Entity,
	type:     VfxType,
	age:      f32,
	lifetime: f32,
}

update_vfx :: proc(state: ^GameState, delta: f32) {
	for i in 0..<len(state.vfx) {
		v := &state.vfx[i]
		if !v.alive do continue
		v.age += delta
		v.pos += v.velocity * delta
		if v.age >= v.lifetime {
			v.alive = false
		}
	}
}

draw_vfx :: proc(v: ^Vfx, state: ^GameState) {
	scale_hint: f32 = 1.0
	if state != nil && state.scale_hint != 0 do scale_hint = state.scale_hint
	switch v.type {
	case .BANG:
		t := v.age / v.lifetime
		radius := v.shape.(Circle).radius * t
		draw_circle(v.pos, radius, v.col, scale_hint, (1.0-t) * 6.0)
	case .SPARK:
		trail_time: f32 = 0.1
		trail_end := v.pos - v.velocity * trail_time
		draw_line(trail_end, v.pos, v.col, scale_hint)
	}
}

spawn_vfx :: proc(state: ^GameState, pos: Vec2, vfx: Vfx) {
	spawn(&state.vfx, pos, vfx)
}

// BANG: circle expanding outward and decaying.
spawn_bang :: proc(state: ^GameState, pos: Vec2, radius: f32 = 60.0) {
	spawn_vfx(state, pos, Vfx{
		type     = .BANG,
		draw     = draw_vfx,
		shape    = Circle{radius},
		lifetime = radius / 400.0,
	})
}

// SPARK: particle flying in a straight line with a velocity-based trail.
spawn_spark :: proc(state: ^GameState, pos: Vec2, direction:f32, speed:f32, lifetime: f32 = 0.6) {
	spawn_vfx(state, pos, Vfx{
		type     = .SPARK,
		draw     = draw_vfx,
		velocity = unit_vector(direction) * speed,
		lifetime = lifetime,
	})
}

// SPARKS: burst of sparks in random directions with randomized parameters.
spawn_sparks :: proc(state: ^GameState, pos: Vec2, count: int = 8, speed: f32 = 200.0, lifetime: f32 = 0.6) {
	for _ in 0..<count {
		angle := rand.float32() * math.TAU
		spd   := speed * (0.4 + rand.float32() * 0.8)
		lt    := lifetime * (0.6 + rand.float32() * 0.8)
		spawn_spark(state, pos, angle, spd, lt)
	}
}
