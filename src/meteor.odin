package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

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
	speed, spin, size, health, power, attraction: f32,
	reward:                                u32,
	death_sfx:                             string,
}
meteor_presets := [MeteorType]MeteorPreset {
	.SHOOTING_STAR = {
		speed = 145,
		spin = 0.8,
		size = 16,
		health = 1.0,
		power = 0.2,
		reward = 2,
		attraction = 1,
	},
	.METEOROID = {
		speed = 110,
		spin = 0.2,
		size = 48,
		health = 4.0,
		power = 0.1,
		reward = 1,
	},
	.ASTEROID = {
		speed = 55,
		spin = 0.1,
		size = 128,
		health = 64.0,
		power = 5.0,
		reward = 0,
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
	// play sfx if meteor is within bounds
	if abs(m.pos.x) < spawn_radius && abs(m.pos.y) < spawn_radius {
		if sfx := meteor_presets[m.type].death_sfx; sfx != "" {
			play_sfx(sfx)
		}
		play_sfx("hit")
	}
	if m.type > .SHOOTING_STAR {
		spawn_exploded(
			state,
			copy_and_rotate_vertices(m.polygon, m.pos, m.rot),
			m.col,
			m.velocity / 2.0,
		)
	}

	if m.type == .ASTEROID {
		for &frag in spawn_cluster(state, m.pos, .METEOROID, 8) {
			frag.velocity += m.velocity
			frag.velocity += (frag.pos - m.pos) * 0.5 // explode outwards
		}
	} else {
		spawn_bang(state, m.pos, entity_size(m) * 1.0)
	}
}

update_meteors :: proc(state: ^GameState, delta: f32) {
	meteorCount := len(state.meteors)
	for i in 0 ..< meteorCount {
		meteor := &state.meteors[i]
		preset := meteor_presets[meteor.type]
		if preset.attraction != 0 {
			meteor.velocity += acceleration_due_to_gravity(meteor, preset.attraction, state.comet, 10000) * delta
		}
		meteor.pos -= state.comet_velocity * delta
		update_entity(meteor, delta)

		if state.comet.alive && check_collision(meteor^, state.comet) {
			hurt_comet(meteor.power)
			meteor.alive = false
		}
		// prune meteors if they are outside bounds and moving away from the comet
		rel_pos := meteor.pos - state.comet.pos
		rel_vel := meteor.velocity - state.comet_velocity
		if (
			(rel_pos.x < -spawn_radius && rel_vel.x <= 0) ||
			(rel_pos.y < -spawn_radius && rel_vel.y <= 0) ||
			(rel_pos.x > spawn_radius && rel_vel.x >= 0) ||
			(rel_pos.y > spawn_radius && rel_vel.y >= 0)
		) {
			meteor.alive = false
		}
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

// --- Spawning Utils ---

spawn_meteor :: proc(state: ^GameState, pos: Vec2, type: MeteorType) -> ^Meteor {
	preset := meteor_presets[type]
	m := spawn(&state.meteors, pos, Meteor{
		brightness = 0.5,
		on_death  = meteor_on_death,
		draw      = draw_meteor,
		shape     = Circle{preset.size},
		hp        = preset.health,
		max_hp    = preset.health,
		rot_speed = preset.spin,
		value     = preset.reward,
		power     = preset.power,
		type      = type,
	})
	switch type {
	case .METEOROID:
		m.polygon = meteoroid_polygon_cache[m.id % POLYGON_CACHE_SIZE]
	case .ASTEROID:
		m.polygon = asteroid_polygon_cache[m.id % POLYGON_CACHE_SIZE]
	case .SHOOTING_STAR:
	}
	return m
}

// spawn_cluster places meteors in a phyllotaxis (sunflower) spiral centered on pos.
// Returns a slice of the newly appended meteors.
spawn_cluster :: proc(state: ^GameState, pos: Vec2, type: MeteorType, count: int, offset:int=0) -> []Meteor {
	list:= &state.meteors
	start := len(list^)
	golden_angle := math.PI * (3.0 - math.sqrt(f32(5.0)))
	spacing := meteor_presets[type].size * 2.2
	for i in offset ..< count {
		r := spacing * math.sqrt(f32(i))
		angle := f32(i) * golden_angle
		spawn_meteor(state, pos + Vec2{math.cos(angle), math.sin(angle)} * r, type)
	}
	return list[start:]
}

// spawn_field fills a width×height rectangle centered on pos with meteors on a grid.
// density=1 packs meteors touching; variation offsets each position by variation*random_vector().
// Returns a slice of the newly appended meteors.
spawn_field :: proc(state: ^GameState, pos: Vec2, type: MeteorType, width, height, density, variation: f32) -> []Meteor {
	list:= &state.meteors
	start := len(list^)
	step := meteor_presets[type].size * 2.0 / density
	cols := int(width / step)
	rows := int(height / step)
	origin := pos - Vec2{width, height} / 2
	for row in 0 ..< rows {
		for col in 0 ..< cols {
			offset := Vec2{f32(col) * step, f32(row) * step} + variation * random_vector()
			spawn_meteor(state, origin + offset, type)
		}
	}
	return list[start:]
}

// spawn_storm spawns meteors at random positions along a line each frame.
// The line runs through pos, perpendicular to normal, and extends width/2 in each direction.
// density is spawns per second; pass delta each frame to drive the rate.
spawn_shower :: proc(state: ^GameState, pos: Vec2, width: f32, normal: Vec2, type: MeteorType, density, delta: f32) -> []Meteor {
	list:= &state.meteors
	start := len(list^)
	tangent := Vec2{-normal.y, normal.x}
	expected := density * delta
	count := int(expected)
	if rand.float32() < expected - f32(count) do count += 1
	for _ in 0 ..< count {
		t := (rand.float32() * 2 - 1) * width / 2
		spawn_meteor(state, pos + tangent * t, type)
	}
	return list[start:]
}

transform_into_cluster :: proc(state: ^GameState, m:Meteor, count:int) -> []Meteor {
	return spawn_cluster(state, m.pos, m.type, count, 1)
}

// --- Events ---

star_storm :: proc(state: ^GameState, delta: f32) {
	storm_velocity:= Vec2{400, 50}
	relative_normal := (normalize(state.comet_velocity - storm_velocity))
	spawn_pos := relative_normal * spawn_radius + 500
	for &m in spawn_shower(state, spawn_pos, 6000, -relative_normal, .SHOOTING_STAR, 10, delta) {
		m.velocity += storm_velocity
		m.velocity += random_vector() * 145
	}
}

asteroid_field :: proc(state: ^GameState) {
	spawn_field(state, {0,-spawn_radius}, .ASTEROID, spawn_radius, 4000, 0.4, 200)
	spawn_field(state, {0,-spawn_radius}, .METEOROID, spawn_radius, 4000, 0.4, 200)
}

// --- Main Spawn Loop ---

spawn_cooldown: f32 = 4.0
spawn_timer: f32
spawn_radius: f32 = 8000
stages:[]f32 = {
	0,
	30,
	60, // first meteoroids
	90, // first asteroids
	110, //star storm begins
	120, //breathing room
	130, // big clusters
	260, // asteroid field
	350, // game end
}

handle_spawns :: proc(state: ^GameState, delta: f32) {
	if rl.IsMouseButtonPressed(.RIGHT) do spawn_meteor(state, state.cursor, .ASTEROID)
	t := f32(state.gameTime)
	comet_normal := normalize(state.comet_velocity)

	// grace period
	if t < stages[0] do return


	if t > stages[state.stage]{
		state.stage += 1
		if state.stage == 7 {
			asteroid_field(state)
		}
	}

	// Starfall
	star_shower_interval := 6 - 4 * progress(t, stages[0], stages[1]) - 1*progress(t, stages[1]+10, stages[3])
	if state.stage < 5 {
		spawn_shower(state, comet_normal * spawn_radius, spawn_radius, -comet_normal, .SHOOTING_STAR, 1/star_shower_interval , delta)
	}

	// Stage 2: 
	if state.stage >= 2 {
		meteoroid_shower_interval := 10-6*progress(t, 70, 90)
		meteoroid_cluster_chance := 0.2 - 0.2*progress(t, 85, 110)
		for m in spawn_shower(state, comet_normal * spawn_radius, spawn_radius, -comet_normal, .METEOROID, 1/meteoroid_shower_interval, delta) {
			cluster_size:= int(meteoroid_cluster_chance * 70 * rand.float32())
			if cluster_size > 1 && rand.float32() < meteoroid_cluster_chance do transform_into_cluster(state, m, cluster_size)
		}
	}

	// Stage 3: asteroids join the clusters (t=70-82), 40% chance of asteroid
	if state.stage >= 3 {
		spawn_shower(state, comet_normal*spawn_radius, spawn_radius, -comet_normal, .ASTEROID, 0.2, delta)
	}

	// Stage 4: the star storm (t=82-130)
	if state.stage == 4 {
		if t < stages[4]-10 do return
		star_storm(state, delta)
	}

	/*

	// Stage 5: breathing room — sparse starfall only (t=130-160)
	if state.stage == 5 {
		if t < 110 do return
		return
	}

	// Stage 6: heavy mixed clusters (t=160-270), interval 7s→3s, size 6→18
	if state.stage == 6 {
		if tick(&spawn_timer, 7 - 4 * progress(t, 160, 270), delta) {
			type := rand.float32() < 0.35 ? MeteorType.ASTEROID : .METEOROID
			spawn_cluster(state, random_ring_pos(comet_normal), type, 6 + int(12 * progress(t, 160, 270)))
		}
		return
	}
	*/
}


