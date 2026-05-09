package game

import rl "vendor:raylib"

draw_game_screen :: proc(state: GameState) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
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
	}
	rl.EndDrawing()
}

draw_title_screen :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
	midPoint := cast([2]f32) screenSize / 2
	rl.DrawRectangleV(midPoint - {300,100}, {600,200}, rl.GRAY)

	rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), i32(rl.ColorToInt(rl.WHITE)))
	rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), i32(rl.ColorToInt({0x33, 0x88, 0xBB, 0xFF})))
	rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), i32(rl.ColorToInt(rl.WHITE)))
	rl.GuiLabel({midPoint.x - 280, midPoint.y - 90, 560, 20}, "Welcome to JellyJam!")
	if rl.GuiButton({midPoint.x - 280, midPoint.y - 60, 560, 60}, "Start game") {
		start_game()
	}
	rl.EndDrawing()
}

// TODO: Use a ray cast to snap the tower to the comet's edges. I'm too tired to process this right now.
test_draw_build_mode :: proc(state: GameState) {
	//pos := state.comet.pos
	//radius := state.comet.shape.(Circle).radius

	//mousePos := [2]f32{f32(rl.GetMouseX()), f32(rl.GetMouseY())}
}
