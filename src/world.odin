// The 2D world, all the entities inside it, and how they interact with eachother.
package game

import rl "vendor:raylib"
import "core:fmt"
import "core:math"

Vec2 :: [2]f32

laserSound: rl.Sound
rockDestroyedSound: rl.Sound

// I'm thinking particles can be handled later with an arena.
game_loop :: proc(delta:f32) {
	if state.gameOver {
		state.gameTime += f64(delta) //?
		return
	}
	if rl.IsKeyPressed(.ONE) {
		state.buildMode = !state.buildMode
	}

	if state.buildMode {
		update_build_mode(&state)
	}

	handle_spawns(&state, delta)

	// Handle entities
	handle_input()
	player := &state.player
	player.pos += player.velocity * delta
	mousePos := Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
	state.lookVec = get_normalized_vector_facing_target(player.pos, mousePos)
	player.rot = math.atan(-state.lookVec.y / state.lookVec.x)

	meteorCount := len(state.meteors)
	projectileCount := len(state.projectiles)

	// TODO: Use quadtrees to make collision checks cheaper
	for i in 0..<projectileCount {
		projectile := &state.projectiles[i]
		projectile.pos += projectile.velocity * delta
		for j in 0..<meteorCount {
			meteor := &state.meteors[j]
			if check_collision(projectile^, meteor^) {
				projectile.alive = false
				meteor.alive = false
			}
		}
	}
	update_meteors(&state, delta)
	update_towers(&state, delta)

	// Loop backwards to clear the array.
	for i := meteorCount - 1; i >= 0; i -= 1 {
		if !state.meteors[i].alive {
			unordered_remove(&state.meteors, i)
			rl.PlaySound(rockDestroyedSound)
		}
	}
	// TODO: Define the boundaries of the map, and kill the bullets when they exit.
	for i := projectileCount - 1; i >= 0; i -= 1 {
		if !state.projectiles[i].alive do unordered_remove(&state.projectiles, i)
	}

	state.gameTime += f64(delta)
	state.timeRemaining -= delta
	if state.timeRemaining <= 0 {
		state.gameOver = true
	}
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
		append(&state.projectiles, Entity{
			pos = player.pos + state.lookVec * 30,
			velocity = state.lookVec * bulletSpeed,
			shape = Circle {12},
			alive = true,
		})
		rl.PlaySound(laserSound)
	}
}

find_intersection_point_on_entity :: proc(startPos: Vec2, target: Entity) -> (collisionPoint: Vec2) {
	rayVec := target.pos - startPos
	rayLength := math.sqrt(rayVec.x * rayVec.x + rayVec.y * rayVec.y)
	rayNormal := rayVec / rayLength
	result: Vec2
	switch shape in target.shape {
	case Rect:
		fmt.printf("Not implemented!\n")
	case Circle:
		dist := rayLength - shape.radius
		result = startPos + rayNormal * dist
	}
	return result
}

draw_game_screen :: proc(state: GameState) {
	// This is just for verifying that collision checks work. Feel free to rip out this if statement for the comet color.
	if check_collision(state.comet, state.player) {
		draw_entity(state.comet, rl.RED)
	} else {
		draw_entity(state.comet, rl.WHITE)
	}
	draw_entity(state.player, rl.WHITE)

	meteorCount := len(state.meteors)
	for i in 0..<meteorCount {
		draw_entity(state.meteors[i], rl.RED)
	}
	towerCount := len(state.towers)
	for i in 0..<towerCount {
		tower := state.towers[i]
		tower.stats.draw(tower, rl.LIGHTGRAY)
	}

	projectileCount := len(state.projectiles)
	for i in 0..<projectileCount {
		draw_entity(state.projectiles[i], rl.GRAY)
	}

	if state.gameOver {
		rl.DrawText("VICTORY", rl.GetScreenWidth() / 2 - 240, rl.GetScreenHeight() / 2 - 50, 64, rl.LIGHTGRAY)
	} else {
		rl.DrawText(rl.TextFormat("Time left: %.0f seconds", state.timeRemaining), rl.GetScreenWidth() - 240, 10, 20, rl.WHITE)
	}

	if state.buildMode {
		test_draw_build_mode(state)
		draw_build_mode(state)
	}
}

// TODO: Use a ray cast to snap the tower to the comet's edges. I'm too tired to process this right now.
test_draw_build_mode :: proc(state: GameState) {
	buildPos := state.buildCursor
	rl.DrawRectangleLinesEx({buildPos.x - 8, buildPos.y - 8, 16, 16}, 1.5, rl.GREEN)
}
