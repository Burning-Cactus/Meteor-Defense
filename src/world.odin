// The 2D world, all the entities inside it, and how they interact with eachother.
package game

import "core:math/linalg"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

laserSound: rl.Sound
rockDestroyedSound: rl.Sound

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
	if rl.IsKeyPressed(.ONE) {
		state.buildMode = !state.buildMode
	}

	if state.buildMode {
		update_build_mode(&state)
	}

	handle_spawns(&state, delta)

	state.comet.rot += 0.1 * delta

	// Handle entities
	handle_input()
	player := &state.player
	player.pos += player.velocity * delta
	state.lookVec = get_normalized_vector_facing_target(player.pos, state.cursor)
	player.rot = math.atan(state.lookVec.y / state.lookVec.x)

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

	state.difficulty_scale += 0.025 * delta
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
		spawn_bullet(&state, player.pos + state.lookVec * 30, state.lookVec * bulletSpeed)
	}
}

find_intersection_point_on_entity :: proc(
	startPos: Vec2,
	target: Entity,
) -> (
	collisionPoint: Vec2,
) {
	rayVec := target.pos - startPos
	rayLength := math.sqrt(rayVec.x * rayVec.x + rayVec.y * rayVec.y)
	rayNormal := rayVec / rayLength
	result: Vec2
	switch shape in target.shape {
	case Rect:
		fmt.printf("Not implemented!\n")
	case Polygon:
		vertices := copy_and_rotate_vertices(shape.vertices, target.pos, target.rot)
		// Solve for scalars t and u
		last_idx := len(shape.vertices) - 1
		for i in 0..<last_idx {
			p := vertices[i]
			r := vertices[i+1]-p
			s := rayVec
			if linalg.cross(r, s) == 0 do continue
			t := linalg.cross(startPos - p, s / linalg.cross(r, s))
			if t < 0 || t > 1 do continue
			u := linalg.cross(p - startPos, r / linalg.cross(s, r))
			if u < 0 || u > 1 do continue
			return p + t * r
		}
		p := vertices[last_idx]
		r := vertices[0]-p
		s := rayVec
		if linalg.cross(r, s) == 0 {
			return result
		}
		t := linalg.cross(startPos - p, s / linalg.cross(r, s))
		if t < 0 || t > 1 do return result
		u := linalg.cross(p - startPos, r / linalg.cross(s, r))
		if u < 0 || u > 1 do return result
		return p + t * r
	case Circle:
		dist := rayLength - shape.radius
		result = startPos + rayNormal * dist
	}
	return result
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
