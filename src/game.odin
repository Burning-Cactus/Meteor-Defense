package game

import rl "vendor:raylib"
import "core:c"
import "core:fmt"
import "core:math"

run: bool
init :: proc() {
	run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Meteor Defense")
	rl.SetTargetFPS(60)
	currentScreen = .Title
	// Disable quiting with esc key.
	rl.SetExitKey(.KEY_NULL)
}

start_game :: proc() {
	currentScreen = .Game
	state = GameState{}
	state.player = Entity{
		pos = {700, 600},
		size = {32, 32},
		alive = true,
	}
	state.comet = Entity{
		pos = {400, 300},
		size = {200, 200},
	}
	state.cometHealth = 100
	append(&state.meteors, Meteor{
			pos = {0, 100},
			size = {32, 32},
			velocity = {40, 0},
			alive = true,
		})
	append(&state.meteors, Meteor{
			pos = {0, 300},
			size = {28, 28},
			velocity = {20, 0},
			alive = true,
		})
	append(&state.meteors, Meteor{
			pos = {0, 500},
			size = {24, 24},
			velocity = {20, -3},
			alive = true,
		})
}

GameState :: struct {
	player: Entity,
	lookVec: [2]f32,
	meteors: [dynamic]Meteor,
	projectiles: [dynamic]Entity,
	comet: Entity,
	cometHealth: i32,

	paused: bool,
}
state: GameState

// Normally I would use a fat struct, but TD games can sometimes simulate a massive number of enemies. We'll see what we need as we go.
Entity :: struct {
	pos: [2]f32,
	velocity: [2]f32,
	size: [2]f32,
	rot: f32, // Rotation will be necessary in the future for collision checking and drawing, though raylib doesn't seem to have built-in support for rotating shapes.
	alive: bool,
}

// Different meteors will have different path strategies in the future.
Meteor :: struct {
	using entity: Entity,
}

currentScreen: Screen
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

Screen :: enum{Title, Game}

game_loop :: proc() {
	if rl.IsKeyPressed(.ESCAPE) do state.paused = !state.paused
	if state.paused do return
	delta := rl.GetFrameTime()
	player := &state.player

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
		if !state.meteors[i].alive do unordered_remove(&state.meteors, i)
	}
	// TODO: Define the boundaries of the map, and kill the bullets when they exit.
	for i := projectileCount - 1; i >= 0; i -= 1 {
		if !state.projectiles[i].alive do unordered_remove(&state.projectiles, i)
	}
}

check_collision :: proc(a: Entity, b: Entity) -> bool {
	aPos := a.pos - (a.size / 2)
	bPos := b.pos - (b.size / 2)
	return (
		aPos.x < bPos.x + b.size.x
		&& aPos.x + a.size.x > bPos.x
		&& aPos.y < bPos.y + b.size.y
		&& aPos.y + a.size.y > bPos.y
	)
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
		targetX := f32(rl.GetMouseX()) - player.pos.x
		targetY := f32(rl.GetMouseY()) - player.pos.y
		targetLen := math.sqrt(targetX * targetX + targetY * targetY)
		state.lookVec = {targetX, targetY} / targetLen
		bulletSpeed :: 250
		append(&state.projectiles, Entity{
			pos = player.pos + state.lookVec * 30,
			velocity = state.lookVec * bulletSpeed,
			size = {12, 12},
			alive = true,
		})
	}
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
