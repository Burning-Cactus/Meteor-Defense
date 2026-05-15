// The 2D world, all the entities inside it, and how they interact with eachother.
package game

import rl "vendor:raylib"

laserSound: rl.Sound
hitSound: rl.Sound
asteroidHitSound: rl.Sound

spawn_bullet :: proc(state: ^GameState, pos: Vec2, velocity: Vec2) {
	spawn(&state.projectiles, pos, Entity{
		velocity = velocity,
		shape = Circle{12},
		col = .PRIMARY,
	})
	rl.PlaySound(laserSound)
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
		projectile.pos += projectile.velocity * delta
		for j in 0 ..< meteorCount {
			meteor := &state.meteors[j]
			if check_collision(projectile^, meteor^) {
				projectile.alive = false
				hurt_meteor(projectile^, meteor)
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

	state.difficulty_scale += 0.1 * delta
}

handle_input :: proc() {
	player := &state.player

	playerSpeed :: 100
	player.velocity = {0, 0}
	if rl.IsKeyDown(.A) do player.velocity.x -= playerSpeed
	if rl.IsKeyDown(.D) do player.velocity.x += playerSpeed
	if rl.IsKeyDown(.W) do player.velocity.y -= playerSpeed
	if rl.IsKeyDown(.S) do player.velocity.y += playerSpeed
	if !state.buildMode && rl.IsMouseButtonPressed(.LEFT) {
		bulletSpeed :: 500
		bullet_normal := unit_vector(player.rot)
		spawn_bullet(&state, player.pos + bullet_normal * 30, bullet_normal * bulletSpeed)
	}
}

draw_game_screen :: proc(state: ^GameState) {
	state.comet.col = .RED if check_collision(state.comet, state.player) else .PRIMARY
	draw_entity(&state.comet, state)
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
