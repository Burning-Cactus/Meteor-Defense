// The 2D world, all the entities inside it, and how they interact with eachother.
package game

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

cursor_entity ::proc() -> Entity {
	return Entity{
		pos=state.cursor,
		alive = true,
		shape = Circle{32},
	}
}

star_heart_polygon :: proc(i:int) -> (segments:[5][4]Vec2) {
	comet:= state.comet
	star := star_polygon(
		entity_world_pos(comet),
		entity_world_rot(comet),
		5, 50, 0.5,
	)
	for j in 0..<i {
		i2 := j * 2
		segment := [4]Vec2{
			star[(i2+1) % (len(star))],
			star[(i2+2) % (len(star))],
			star[(i2+3) % (len(star))],
			entity_world_pos(comet),
		}
		segments[j] = segment
	}
	return
}

draw_comet_heart :: proc(comet: ^Entity, state: ^GameState) {
	segments := star_heart_polygon(int(math.ceil(comet.hp)))
	for i in 0..<len(segments) {
		if comet.hp <= f32(i) do continue
		bmod: f32 = 1.0
		if f32(i) < comet.hp && comet.hp < f32(i + 1) {
			frac := comet.hp - f32(i)
			bmod = damage_brightness_mod(frac, 1.0, f32(state.gameTime))
		}
		draw_polygon(segments[i][:], state.scale_hint, .BLUE, bmod)
	}
}

hurt_comet :: proc(dmg:f32) {
	dmg:=dmg
	for dmg>0.5 {
		hurt_comet(0.5)
		dmg-=0.5
	}

	hp_segments_f, segment_health := math.modf(state.comet.hp)
	hp_segments := int(hp_segments_f)
	fmt.eprintfln("Comet hit!\n%d segments, %.0f%% segment hp", hp_segments, segment_health*100)
	fmt.eprintfln("Incoming Damager: %.1f", dmg)

	if (segment_health > 0 && dmg >= segment_health) {
		assert(hp_segments < 5)
		seg:= star_heart_polygon(hp_segments + 1)[hp_segments]
		spawn_exploded(&state, seg[:], .BLUE, seg[1], 16.0, 0.2, 3.0)
	}
	state.comet.hp -= dmg
}

draw_comet :: proc(comet: ^Entity, state: ^GameState) {
	e := comet^
	e.hp=e.max_hp // HACK to override damage flashing
	draw_entity(&e, state)
	draw_comet_heart(comet, state)
}

// I'm thinking particles can be handled later with an arena.
game_loop :: proc(delta: f32) {
	if state.buildMode {
		update_build_mode(&state)
	}

	handle_spawns(&state, delta)

	state.comet.rot += 0.1 * delta

	// Handle entities
	handle_input()
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
			}
		}
	}
	update_meteors(&state, delta)
	update_towers(&state, delta)
	update_vfx(&state, delta)

	remove_dead(&state.meteors, &state)
	// TODO: Define the boundaries of the map, and kill the bullets when they exit.
	remove_dead(&state.projectiles, &state)
	remove_dead(&state.vfx, &state)

	state.difficulty_scale += 0.05 * delta
}

handle_input :: proc() {
	player := &state.player

	playerSpeed :: 100
	player.velocity = {0, 0}
	if rl.IsKeyDown(.A) do player.velocity.x -= playerSpeed
	if rl.IsKeyDown(.D) do player.velocity.x += playerSpeed
	if rl.IsKeyDown(.W) do player.velocity.y -= playerSpeed
	if rl.IsKeyDown(.S) do player.velocity.y += playerSpeed
	if !state.buildMode && rl.IsMouseButtonPressed(.LEFT) && try_claim_click() {
		bulletSpeed :: 500
		bullet_normal := unit_vector(player.rot)
		spawn_bullet(&state, player.pos + bullet_normal * 30, bullet_normal * bulletSpeed)
	}
}

draw_game_screen :: proc(state: ^GameState) {
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
	for i in 0..<len(state.vfx) {
		draw_entity(&state.vfx[i].entity, state)
	}

	if state.buildMode {
		draw_build_mode(state)
	}
}
