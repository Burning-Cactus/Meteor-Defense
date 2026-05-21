// The 2D world, all the entities inside it, and how they interact with eachother.
package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

cursor_entity :: proc() -> Entity {
	return Entity{pos = state.cursor, alive = true, shape = Circle{32}}
}

star_heart_polygon :: proc(i: int) -> (segments: [5][4]Vec2) {
	comet := state.comet
	star := star_polygon(entity_world_pos(comet), entity_world_rot(comet), 5, 50, 0.5)
	for j in 0 ..< i {
		i2 := j * 2
		segment := [4]Vec2 {
			star[(i2 + 1) % (len(star))],
			star[(i2 + 2) % (len(star))],
			star[(i2 + 3) % (len(star))],
			entity_world_pos(comet),
		}
		segments[j] = segment
	}
	return
}

draw_comet_heart :: proc(comet: ^Entity, state: ^GameState) {
	segments := star_heart_polygon(int(math.ceil(comet.hp)))
	for i in 0 ..< len(segments) {
		if comet.hp <= f32(i) do continue
		bmod: f32 = 1.0
		if f32(i) < comet.hp && comet.hp < f32(i + 1) {
			frac := comet.hp - f32(i)
			bmod = damage_brightness_mod(frac, 1.0, f32(state.gameTime))
		}
		draw_polygon(segments[i][:], state.scale_hint, .BLUE, bmod)
	}
}

hurt_comet :: proc(dmg: f32) {
	if !state.comet.alive do return
	dmg := dmg
	for dmg > 0.5 {
		hurt_comet(0.5)
		dmg -= 0.5
	}

	hp_segments_f, segment_health := math.modf(state.comet.hp)
	hp_segments := int(hp_segments_f)
	fmt.eprintfln("Comet hit!\n%d segments, %.0f%% segment hp", hp_segments, segment_health * 100)
	fmt.eprintfln("Incoming Damager: %.1f", dmg)

	if (segment_health > 0 && dmg >= segment_health) {
		assert(hp_segments < 5)
		seg := star_heart_polygon(hp_segments + 1)[hp_segments]
		spawn_exploded(&state, seg[:], .BLUE, seg[1], 16.0, 0.2, 3.0)
		play_sfx("comet_break")
	}
	play_sfx("comet_hit")
	state.comet.hp -= dmg
	if state.comet.hp <= 0 {
		state.comet.alive = false
		p, ok := state.comet.shape.(Polygon)
		if ok do spawn_exploded(&state, p.vertices, state.comet.col, {}, 60, 0.6, 1.0)
		spawn_bang(&state, state.comet.pos, entity_size(state.comet) * 3, 0.5, 0.2, 0.5)
		spawn_bang(&state, state.comet.pos, entity_size(state.comet) * 3, 1.0, 0, 0.3)
		play_sfx("comet_death")
		game_over()
	}
}

draw_comet :: proc(comet: ^Entity, state: ^GameState) {
	if !comet.alive do return
	e := comet^
	e.hp = e.max_hp // HACK to override damage flashing
	draw_entity(&e, state)
	draw_comet_heart(comet, state)
}

BackgroundStar :: struct {
	pos:      Vec2,
	distance: f32,
}
background_stars: [2048]BackgroundStar
background_size :: 20000
init_background :: proc() {
	for _, i in background_stars {
		background_stars[i].pos = random_vector() * background_size / 2
		background_stars[i].distance = vary(100, .8)
	}
}
update_background :: proc(delta: f32) {
	for &s in background_stars {
		s.pos -= state.comet_velocity * delta / s.distance

		start, end := get_frustum()
		margin :: 10
		start.x -= margin * camera.zoom
		start.y -= margin * camera.zoom
		end.x -= margin * camera.zoom
		end.y -= margin * camera.zoom
		if s.pos.x < start.x do s.pos.x += background_size
		if s.pos.y < start.y do s.pos.y += background_size
		if s.pos.x > end.x do s.pos.x -= background_size
		if s.pos.y > end.y do s.pos.y -= background_size
	}
}
draw_background :: proc() {
	for s in background_stars {
		brightness := 40 * camera.zoom / s.distance
		if brightness > .1 do draw_dot(s.pos, state.scale_hint, .PRIMARY, brightness)
	}

}
// I'm thinking particles can be handled later with an arena.
game_loop :: proc(delta: f32) {
	if state.buildMode {
		update_build_mode(&state)
	}

	handle_spawns(&state, delta)
	state.comet_velocity = {100, -3001}

	state.comet.rot += 0.02 * delta

	// Handle entities
	handle_input(delta)
	player := &state.player
	player.pos += player.velocity * delta
	player.rot = angle_facing(player.pos, state.cursor)

	meteorCount := len(state.meteors)
	projectileCount := len(state.projectiles)

	// TODO: Use quadtrees to make collision checks cheaper
	for i in 0 ..< projectileCount {
		projectile := &state.projectiles[i]
		update_entity(projectile, delta)
		for j in 0 ..< meteorCount {
			meteor := &state.meteors[j]
			if check_collision(projectile^, meteor^) {
				projectile.alive = false
				state.money += hurt_entity_with_entity(projectile^, meteor)
				play_sfx("projectile_hit")
			}
		}
	}
	update_meteors(&state, delta)
	update_towers(&state, delta)
	update_vfx(&state, delta)
	update_background(delta)

	remove_dead(&state.meteors, &state)
	// TODO: Define the boundaries of the map, and kill the bullets when they exit.
	remove_dead(&state.projectiles, &state)
	remove_dead(&state.vfx, &state)

}

move_toward :: proc(f, targ, delta: f32) -> f32 {
	diff := targ - f
	if abs(diff) <= delta do return targ
	return f + math.sign(diff) * delta
}
handle_input :: proc(delta: f32) {
	player := &state.player

	playerSpeed :: 100
	playerAccel :: 300

	target_x: f32
	target_y: f32
	if rl.IsKeyDown(.A) do target_x -= 1
	if rl.IsKeyDown(.D) do target_x += 1
	if rl.IsKeyDown(.W) do target_y -= 1
	if rl.IsKeyDown(.S) do target_y += 1

	player.velocity.x = move_toward(player.velocity.x, target_x * playerSpeed, playerAccel * delta)
	player.velocity.y = move_toward(player.velocity.y, target_y * playerSpeed, playerAccel * delta)
	if !state.buildMode && rl.IsMouseButtonPressed(.LEFT) && try_claim_click() {
		bulletSpeed :: 500
		bullet_normal := unit_vector(player.rot)
		spawn_bullet(&state, player.pos + bullet_normal * 30, bullet_normal * bulletSpeed)
	}
}

draw_game_screen :: proc(state: ^GameState) {
	draw_background()
	draw_comet(&state.comet, state)
	draw_entity(&state.player, state)

	for i in 0 ..< len(state.meteors) {
		draw_entity(&state.meteors[i].entity, state)
	}
	for i in 0 ..< len(state.towers) {
		draw_entity(&state.towers[i].entity, state)
	}
	for i in 0 ..< len(state.projectiles) {
		draw_entity(&state.projectiles[i], state)
	}
	for i in 0 ..< len(state.vfx) {
		draw_entity(&state.vfx[i].entity, state)
	}

	if state.buildMode {
		draw_build_mode(state)
	}
}

