// Handles drawing itself. drawing the ui, and when and how to draw the other parts of the game
package game

import "core:c"
import "core:math"
import rl "vendor:raylib"

Screen :: enum{Title, Game, Draw}
currentScreen := Screen.Title

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

state:GameState
reset_game :: proc() {
	delete(state.meteors)
	delete(state.towers)
	delete(state.projectiles)
	delete(state.vfx)
	state = {
		player = Entity{
			label      = "jelly",
			pos        = {200, -100},
			shape      = Rect{32},
			alive      = true,
			brightness = 1.8,
		},
		comet = Entity{
			label      = "comet",
			hp         = 5.0,
			shape      = Polygon{pentagon},
			brightness = 1.0,
		},
		timeRemaining    = 360,
		money            = 200,
		difficulty_scale = 1,
	}
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
		transition_to(.Game)
	}
}

performance_test :: false
init :: proc() {
	if !performance_test {
		rl.SetConfigFlags({.VSYNC_HINT})
	}
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	//rl.SetTargetFPS(10)
	rl.InitWindow(1280, 720, "Meteor Defense")
	// Disable quiting with esc key.
	rl.SetExitKey(.KEY_NULL)

	camera.zoom = 1.0
	pan_to_new_window_size()

	rl.InitAudioDevice()
	set_screen(currentScreen)
	init_sfx()
	init_meteor_polygons()
	init_shader()
}

update :: proc() {
	update_music()
	delta := rl.GetFrameTime()
	update_transition(delta)
	click_claimed = false
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

	// non opaque screen clear
	afterimage_amount :: 0.65
	curr_fps := max(cast(f32)rl.GetFPS(), 1.0)
	wipe_opacity := cast(u8) min(255.0 * (1.0 - afterimage_amount) * 100.0 / curr_fps, 255.0)
	rl.DrawRectangle(0, 0, screenSize.x, screenSize.y, {0, 0, 0, wipe_opacity})

	if performance_test {
		rl.DrawFPS(50,30)
	}
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
		if rl.IsKeyPressed(.R) {
			transition_to(.Game)
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
		}
	case .Draw:
		draw_canvas_toolbar()
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
	draw_transition_curtain()
}


TransitionPhase :: enum { Idle, FadeIn, FadeOut }

_transition_phase:  TransitionPhase
_transition_target: Screen
_transition_alpha:  f32

TRANSITION_SPEED:f32:1/  0.1//seconds

transition_to :: proc(target: Screen) {
	queue_music_restart()
	if _transition_phase != .Idle do return
	_transition_target = target
	_transition_phase  = .FadeIn
}

set_screen :: proc(target: Screen) {
	defer currentScreen = target
	switch _transition_target {
	case .Game:
		reset_game()
		clear_music_loop_points()
	case .Title:
		set_music_loop_points(3,7)
	case .Draw:
	}

}

update_transition :: proc(delta: f32) {
	switch _transition_phase {
	case .Idle:
	case .FadeIn:
		_transition_alpha += TRANSITION_SPEED * delta
		if _transition_alpha >= 1.0 {
			_transition_alpha = 1.0
			_transition_phase = .FadeOut
			set_screen(_transition_target)
		}
	case .FadeOut:
		_transition_alpha -= TRANSITION_SPEED * delta
		if _transition_alpha <= 0.0 {
			_transition_alpha = 0.0
			_transition_phase = .Idle
		}
	}
}

draw_transition_curtain :: proc() {
	if _transition_phase == .Idle do return
	screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
	rl.DrawRectangle(0, 0, screenSize.x, screenSize.y, {0, 0, 0, u8(_transition_alpha * 255)})
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
