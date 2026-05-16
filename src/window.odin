// Handles drawing itself. drawing the ui, and when and how to draw the other parts of the game
package game

import "core:c"
import "core:math"
import rl "vendor:raylib"

Screen :: enum{Title, Game, Draw}
currentScreen := Screen.Game

run := true
paused: bool

camera: rl.Camera2D
prev_window_size: Vec2

GameState :: struct { //TODO: split some of this into new WorldState
	player: Entity,
	meteors: [dynamic]Meteor,
	towers: [dynamic]Tower,
	projectiles: [dynamic]Entity,
	vfx: [dynamic]Vfx,
	comet: Entity,
	highlighted_tower: ^Tower,

	gameTime: f64,
	timeRemaining: f32,
	gameOver:      bool,
	money:         u32,
	buildMode:     bool,
	cursor:        Vec2,
	scale_hint:    f32,

	difficulty_scale: f32,
}

state: GameState = {
	player = Entity{
		label = "jelly",
		pos = {200, -100},
		shape = Rect{32},
		alive = true,
//		draw = draw_player,
	},
	comet = Entity{
		label = "comet",
		hp = 20.0,
		shape = Polygon{pentagon},
	},
	timeRemaining = 60,
	money = 20,
	difficulty_scale = 1,
}

pan_to_new_window_size :: proc() {
	curr_size := Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	delta := curr_size - prev_window_size
	camera.target -= delta * (0.5 / camera.zoom)
	prev_window_size = curr_size
}

draw_title_screen :: proc() {
	screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
	midPoint := cast(Vec2)screenSize / 2
	rl.DrawRectangleV(midPoint - {300, 100}, {600, 200}, rl.GRAY)

	rl.GuiSetStyle(
		.LABEL,
		i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL),
		i32(rl.ColorToInt(rl.WHITE)),
	)
	rl.GuiSetStyle(
		.BUTTON,
		i32(rl.GuiControlProperty.BASE_COLOR_NORMAL),
		i32(rl.ColorToInt({0x33, 0x88, 0xBB, 0xFF})),
	)
	rl.GuiSetStyle(
		.BUTTON,
		i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL),
		i32(rl.ColorToInt(rl.WHITE)),
	)
	rl.GuiLabel({midPoint.x - 280, midPoint.y - 90, 560, 20}, "Welcome to JellyJam!")
	if rl.GuiButton({midPoint.x - 280, midPoint.y - 60, 560, 60}, "Start game") {
		start_game()
	}
}

init :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	//rl.SetTargetFPS(10)
	rl.InitWindow(1280, 720, "Meteor Defense")
	// Disable quiting with esc key.
	rl.SetExitKey(.KEY_NULL)

	camera.zoom = 1.0
	pan_to_new_window_size()

	rl.InitAudioDevice()
	init_sfx()
	init_meteor_polygons()
	init_shader()
}

update :: proc() {
	click_claimed = false
	delta := rl.GetFrameTime()
	screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}

	if rl.IsWindowResized() {
		pan_to_new_window_size()
		resize_shader()
	}

	// Pan with middle mouse button
	if rl.IsMouseButtonDown(.MIDDLE) {
		mouse_delta := rl.GetMouseDelta()
		camera.target -= Vec2{mouse_delta.x, mouse_delta.y} * (1.0 / camera.zoom)
	}

	// Zoom to cursor with scroll wheel
	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		camera.offset = rl.GetMousePosition()
		camera.target = mouse_world
		scale := f32(0.2) * wheel
		camera.zoom = clamp(math.exp_f32(math.ln_f32(camera.zoom) + scale), f32(0.125), f32(64.0))
	}

	state.cursor = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
	state.scale_hint = camera.zoom

	rl.BeginTextureMode(shader_target)

	afterimage_amount :: 0.65
	curr_fps := max(cast(f32)rl.GetFPS(), 1.0)
	wipe_opacity := cast(u8) min(255.0 * (1.0 - afterimage_amount) * 100.0 / curr_fps, 255.0)

	rl.DrawRectangle(0, 0, screenSize.x, screenSize.y, {0, 0, 0, wipe_opacity})
	//rl.BeginBlendMode(.ADDITIVE) TODO: this would take some work but look nicer
	switch currentScreen {
	case .Title:
		draw_title_screen()
	case .Game:
		draw_tower_toolbar()

		// pause
		if rl.IsKeyPressed(.ESCAPE) {
			paused = !paused
		}
		if !paused && !state.gameOver {
			game_loop(delta)
			state.gameTime += f64(delta)
			state.timeRemaining -= delta
			if state.timeRemaining <= 0 {
				state.gameOver = true
			}
		}

		rl.BeginMode2D(camera)
		draw_game_screen(&state)
		rl.EndMode2D()
		if state.gameOver {
			rl.DrawText("VICTORY", screenSize.x / 2 - 240, screenSize.y / 2 - 50, 64, rl.LIGHTGRAY)
		} else {
			rl.DrawText(
				rl.TextFormat("Time left: %.0f seconds", state.timeRemaining),
				rl.GetScreenWidth() - 240,
				10,
				20,
				rl.WHITE,
			)
			rl.DrawText(rl.TextFormat("$%d", state.money), screenSize.x - 240, 40, 20, rl.WHITE)
			rl.DrawText(
				rl.TextFormat("HP: %.0f", state.comet.hp),
				screenSize.x - 240,
				70,
				20,
				rl.WHITE,
			)
		}
	case .Draw:
		rl.BeginMode2D(camera)
		canvas_loop(delta)
		rl.EndMode2D()

		/*if i:= select_tool(canvas_tools[:]); i>=0 {
			selected_tool = &canvas_tools[i]
		}
		draw_tools(canvas_tools[:], {10, 10}, .TOP_LEFT, .RIGHT)
		*/
	}
	rl.EndTextureMode()
	//rl.EndBlendMode()

	rl.BeginDrawing()
	defer free_all(context.temp_allocator)
	defer rl.EndDrawing()
	draw_shader()
	draw_shader_debug()
}


start_game :: proc() {
	currentScreen = .Game
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
	pan_to_new_window_size()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		run &&= !rl.WindowShouldClose()
	}
	return run
}

shutdown :: proc() {
	shutdown_sfx()
	shutdown_shader()
	rl.CloseWindow()
}
