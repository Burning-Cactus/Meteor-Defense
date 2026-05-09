package game

import rl "vendor:raylib"
import "core:c"
import "core:fmt"
import "core:math"

Vec2 :: [2]f32

run: bool
laserSound: rl.Sound
rockDestroyedSound: rl.Sound

init :: proc() {
	run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Meteor Defense")
	currentScreen = .Title
	// Disable quiting with esc key.
	rl.SetExitKey(.KEY_NULL)

	rl.InitAudioDevice()
	laserSound = rl.LoadSound("assets/sfx/shoot0.wav")
	rockDestroyedSound = rl.LoadSound("assets/sfx/hit0.wav")
}

start_game :: proc() {
	currentScreen = .Game
}

GameState :: struct {
	player: Entity,
	lookVec: Vec2,
	meteors: [dynamic]Meteor,
	projectiles: [dynamic]Entity,
	comet: Entity,
	cometHealth: i32,

	gameTime: f64,
	timeRemaining: f32,
	gameOver: bool,

	paused: bool,
	buildMode: bool,
	buildCursor: Vec2,
}

state: GameState = {
	player = Entity{
		label = "jelly",
		pos = {700, 600},
		shape = Rect{32},
		alive = true,
	},
	comet = Entity{
		label = "comet",
		pos = {400, 300},
		shape = Circle{200},
	},
	cometHealth = 20,
	timeRemaining = 30,
}
spawnTimer: f32

// Different meteors will have different path strategies in the future.
Meteor :: struct {
	using entity: Entity,
}

Screen :: enum{Title, Game}
currentScreen := Screen.Game
// I'm thinking particles can be handled later with an arena.
update :: proc() {
	switch currentScreen {
	// TODO: Make a title screen for progressing to the main game.
	case .Title:
		draw_title_screen()
	case .Game:
		game_loop()
		draw_game_screen(state)
	}
	// Anything allocated using temp allocator is invalid after this.
	free_all(context.temp_allocator)
}

game_loop :: proc() {
	delta := rl.GetFrameTime()
	if rl.IsKeyPressed(.ESCAPE) do state.paused = !state.paused
	if state.paused do return
	if state.gameOver {
		state.gameTime += f64(delta)
		return
	}
	if rl.IsKeyPressed(.ONE) {
		state.buildMode = !state.buildMode
	}

	if state.buildMode {
		mousePos := Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
		state.buildCursor = find_intersection_point_on_entity(mousePos, state.comet)
	}

	player := &state.player

	spawnTimer -= delta
	if spawnTimer <= 0 {
		// Spawn meteors
		spawners := [3]Vec2{
			{50, 50},
			{700, 100},
			{600, 700},
		}
		for i in 0..<len(spawners) {
			position := spawners[i]
			append(&state.meteors, Meteor{
				pos = position,
				velocity = get_normalized_vector_facing_target(position, state.comet.pos) * 80,
				shape = Circle{32},
				alive = true,
			})
		}
		spawnTimer = 1.5
	}

	// Handle entities
	handle_input()
	player.pos += player.velocity * delta

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
	for i in 0..<meteorCount {
		meteor := &state.meteors[i]
		if !meteor.alive do continue
		meteor.pos += meteor.velocity * delta
		if check_collision(meteor^, state.comet) {
			state.cometHealth -= 1
			fmt.printf("Remaining comet health: %d\n", state.cometHealth)
			meteor.alive = false
		}
	}

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
	if rl.IsMouseButtonPressed(.LEFT) {
		mousePos := Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
		state.lookVec = get_normalized_vector_facing_target(player.pos, mousePos)
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

get_normalized_vector_facing_target :: proc(base: Vec2, target: Vec2) -> Vec2 {
	difference := target - base
	distance := math.sqrt(difference.x * difference.x + difference.y * difference.y)
	return difference / distance
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
}

shutdown :: proc() {
	rl.CloseWindow()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			run = false
		}
	}

	return run
}
