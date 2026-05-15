package game

import "core:math"
import "core:math/rand"

VfxType :: enum { BANG, SPARK, DEBRIS }

Vfx :: struct {
	using entity: Entity,
	type:     VfxType,
	age:      f32,
	lifetime: f32,
	line:     [2]Vec2, // local-space endpoints, used by DEBRIS
}

update_vfx :: proc(state: ^GameState, delta: f32) {
	for i in 0..<len(state.vfx) {
		v := &state.vfx[i]
		if !v.alive do continue
		v.age += delta
		v.pos += v.velocity * delta
		v.rot += v.rot_speed * delta
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
		draw_circle(v.pos, radius, scale_hint, v.col, (1.0-t) * 6.0)
	case .SPARK:
		trail_time: f32 = 0.1
		trail_end := v.pos - v.velocity * trail_time
		draw_line(trail_end, v.pos, scale_hint, v.col)
	case .DEBRIS:
		t   := v.age / v.lifetime
		seg := copy_and_rotate_vertices(v.line[:], v.pos, v.rot)
		draw_line(seg[0], seg[1], scale_hint, v.col, 2.0 - t)
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

// DEBRIS: a line segment with velocity and spin.
spawn_debris :: proc(state: ^GameState, a: Vec2, b: Vec2, vel: Vec2, col: ThemeColor, lifetime: f32 = .4) {
	mid  := (a + b) / 2
	half := (b - a) / 2
	spawn_vfx(state, mid, Vfx{
		type      = .DEBRIS,
		draw      = draw_vfx,
		col       = col,
		velocity  = vel,
		rot_speed = (rand.float32() - 0.5) * 1.1,
		lifetime  = lifetime + (lifetime * (rand.float32() - 0.5) * 0.8),
		line      = {-half, half},
	})
}

// EXPLODED: spawns one debris piece per polygon edge, each flying away from the polygon center.
// Expects a world-space polygon (already rotated and translated).
spawn_exploded :: proc(state: ^GameState, poly: []Vec2, col: ThemeColor, initial_velocity:Vec2={}, impulse: f32 = 30.0) {
	center: Vec2
	for v in poly do center += v
	center /= f32(len(poly))
	n := len(poly)
	for i in 0..<n {
		a   := poly[i]
		b   := poly[(i+1) % n]
		mid := (a + b) / 2
		vel := get_normalized_vector_facing_target(center, mid) * impulse * (0.7 + rand.float32() * 0.6) + initial_velocity
		spawn_debris(state, a, b, vel, col)
	}
}
