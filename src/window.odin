// Handles drawing itself. drawing the ui, and when and how to draw the other parts of the game
package game

import fmt "core:fmt"
import rl "vendor:raylib"
import "core:c"

Screen :: enum{Title, Game}
currentScreen := Screen.Game

run := true
paused: bool

GameState :: struct { //TODO: split some of this into new WorldState
	player: Entity,
	lookVec: Vec2,
	meteors: [dynamic]Meteor,
	towers: [dynamic]Tower,
	projectiles: [dynamic]Entity,
	comet: Entity,
	cometHealth: i32,

	gameTime: f64,
	timeRemaining: f32,
	gameOver: bool,

	buildMode: bool,
	cursor: Vec2,
}

state: GameState = { //?
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
	timeRemaining = 60,
}



draw_title_screen :: proc() {
	screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
	midPoint := cast(Vec2) screenSize / 2
	rl.DrawRectangleV(midPoint - {300,100}, {600,200}, rl.GRAY)

	rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), i32(rl.ColorToInt(rl.WHITE)))
	rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), i32(rl.ColorToInt({0x33, 0x88, 0xBB, 0xFF})))
	rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), i32(rl.ColorToInt(rl.WHITE)))
	rl.GuiLabel({midPoint.x - 280, midPoint.y - 90, 560, 20}, "Welcome to JellyJam!")
	if rl.GuiButton({midPoint.x - 280, midPoint.y - 60, 560, 60}, "Start game") {
		start_game()
	}
}

init :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	//rl.SetTargetFPS(10)
	rl.InitWindow(1280, 720, "Meteor Defense")
	// Disable quiting with esc key.
	rl.SetExitKey(.KEY_NULL)

	rl.InitAudioDevice()
	laserSound = rl.LoadSound("assets/sfx/shoot0.wav")
	rockDestroyedSound = rl.LoadSound("assets/sfx/hit0.wav")
}

update :: proc() {
	state.cursor = Vec2{f32(rl.GetMouseX()), f32(rl.GetMouseY())} // we can transform this with camera later
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	switch currentScreen {
	case .Title:
		draw_title_screen()
	case .Game:
		if rl.IsKeyPressed(.ESCAPE) {
			paused = !paused
			fmt.printf("paused")
		}
		if !paused {
			game_loop(rl.GetFrameTime())
		}
		draw_game_screen(state)
	}
	rl.EndDrawing()
	// Anything allocated using temp allocator is invalid after this.
	free_all(context.temp_allocator) //?
}


start_game :: proc() {
	currentScreen = .Game
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		run &&= !rl.WindowShouldClose()
	}
	return run
}

shutdown :: proc() {
	rl.CloseWindow()
}
