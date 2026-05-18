// Handles drawing itself. drawing the ui, and when and how to draw the other parts of the game
package game

import "core:c"
import "core:math"
import rl "vendor:raylib"

import "core:fmt"

_LOGO_PNG :: #load("../assets/logo.png")
logo_texture: rl.Texture2D

TRANSITION_SPEED: f32 : 1 / 0.3 //seconds
ZOOMOUT_SPEED: f32 : 2 / 1 //seconds
GAME_OVER_SLOMO_TIME: f32 : 3 // seconds to reach zero time scale

performance_test :: false // Disable vsync and display fps

run := true

camera: rl.Camera2D
prev_window_size: Vec2

// --- Window Size Utils ---

REFERENCE_SCREEN_METRIC:f32: 1000 // (1280 + 720) / 2
BASE_CAMERA_ZOOM:f32: 4.0

screen_size_metric :: proc() -> f32 {
	return (f32(rl.GetScreenWidth()) + f32(rl.GetScreenHeight())) / 2
}
screen_size_ratio :: proc() -> f32 {
	return screen_size_metric() / REFERENCE_SCREEN_METRIC
}

// --- Camera Utils ---

pan_to_new_window_size :: proc() {
	curr_size := Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	old_metric := (prev_window_size.x + prev_window_size.y) / 2
	new_metric := (curr_size.x + curr_size.y) / 2
	if old_metric > 0 {
		camera.zoom *= new_metric / old_metric
	}
	delta := curr_size - prev_window_size
	camera.target -= delta * (0.5 / camera.zoom)
	prev_window_size = curr_size
}

get_frustum :: proc() -> (start: Vec2, end: Vec2) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	start = rl.GetScreenToWorld2D({0, 0}, camera)
	end = rl.GetScreenToWorld2D({sw, sh}, camera)
	return
}

// --- Interaction ---

handle_camera_move :: proc(delta: f32) {
	// Pan with middle mouse button
	if rl.IsMouseButtonDown(.MIDDLE) {
		mouse_delta := rl.GetMouseDelta()
		camera.target -= Vec2{mouse_delta.x, mouse_delta.y} * (1.0 / camera.zoom)
	}

	// Zoom to cursor with scroll wheel
	wheel := rl.GetMouseWheelMove()
	effective_max_zoom := state.max_zoom * screen_size_ratio()
	if (wheel > 0 && camera.zoom <= effective_max_zoom - 0.1) || wheel < 0 {
		scale := f32(0.2) * wheel
		mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		camera.offset = rl.GetMousePosition()
		camera.target = mouse_world
		camera.zoom = clamp(math.exp_f32(math.ln_f32(camera.zoom) + scale), f32(0.125), f32(64.0))
	}

	if state.max_zoom > 0 && camera.zoom > effective_max_zoom {
		camera.zoom += (effective_max_zoom - camera.zoom) * ZOOMOUT_SPEED * delta
	}

}

paused: bool
handle_paused :: proc() -> bool{
	if rl.IsKeyPressed(.SPACE) do paused = !paused
	if paused do draw_screen_message("PAUSED")
	return paused
}

// --- Screen  ---

Screen :: enum {
	Title,
	Game,
	Draw,
}
currentScreen := Screen.Title

EndReason :: enum {
	None,
	Victory,
	Defeat,
}

game_over :: proc() {
	state.gameOver = true
	state.endReason = .Defeat
	play_sfx("defeat")
}

// --- Screen Transition ---

TransitionPhase :: enum {
	Idle,
	FadeIn,
	FadeOut,
}

_transition_phase: TransitionPhase
_transition_target: Screen
_transition_alpha: f32


transition_to :: proc(target: Screen) {
	queue_music_restart()
	if _transition_phase != .Idle do return
	_transition_target = target
	_transition_phase = .FadeIn
}

set_screen :: proc(target: Screen) {
	fmt.print("Setting screen: ")
	switch target {
	case .Game:
		fmt.println("Game")
		reset_game()
		clear_music_loop_points()
	case .Title:
		fmt.println("Title")
		reset_game()
		set_music_loop_points(3, 7)
	case .Draw:
		fmt.println("Draw")
		reset_game()
		state.max_zoom = 64
	}
	currentScreen = target
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

// --- Screen: Game ---

GameState :: struct {
	//TODO: split some of this into new WorldState
	player:            Entity,
	meteors:           [dynamic]Meteor,
	towers:            [dynamic]Tower,
	projectiles:       [dynamic]Entity,
	vfx:               [dynamic]Vfx,
	comet:             Entity,
	comet_velocity:    Vec2, //purely cosmetic
	highlighted_tower: ^Tower,
	gameTime:          f64,
	timeRemaining:     f32,
	gameOver:          bool,
	endReason:         EndReason,
	endTimer:          f32,
	timeScale:         f32,
	money:             u32,
	buildMode:         bool,
	cursor:            Vec2,
	scale_hint:        f32,
	difficulty_scale:  f32,
	max_zoom:          f32,
}

state: GameState
reset_game :: proc() {
	delete(state.meteors)
	delete(state.towers)
	delete(state.projectiles)
	delete(state.vfx)
	polygon, ok := state.comet.shape.(Polygon)
	if ok {
		delete(polygon.vertices)
	}
	state = {
		player = Entity {
			label = "jelly",
			pos = {200, -100},
			shape = Rect{32},
			alive = true,
			brightness = 1.8,
			draw = draw_player,
		},
		comet = Entity {
			label = "comet",
			hp = 5.0,
			alive = true,
			max_hp = 5.0,
			shape = Polygon{generate_comet_shape()},
			brightness = 1.0,
		},
		timeRemaining = 360,
		money = 200,
		difficulty_scale = 1,
		timeScale = 1,
		max_zoom = 1.5,
	}
	init_background()
	camera.offset = Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())} / 2
	camera.target = state.player.pos
	camera.zoom = BASE_CAMERA_ZOOM * screen_size_ratio()
}

// --- Screen: Title ---

draw_title_screen :: proc(delta: f32) {
	rl.BeginMode2D(camera)
	draw_game_screen(&state)
	rl.EndMode2D()
	//update_background(delta)

	mid := Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())} / 2
	cursor := rl.GetMousePosition()

	screen := mid * 2
	logo_scale := min(screen.x / f32(logo_texture.width), screen.y / f32(logo_texture.height), 1.0)
	logo_draw_size := Vec2{f32(logo_texture.width), f32(logo_texture.height)} * logo_scale
	logo_dst := rl.Rectangle {
		mid.x - logo_draw_size.x / 2,
		mid.y - logo_draw_size.y / 2 - 60,
		logo_draw_size.x,
		logo_draw_size.y,
	}
	rl.DrawTexturePro(
		logo_texture,
		{0, 0, f32(logo_texture.width), f32(logo_texture.height)},
		logo_dst,
		{0, 0},
		0,
		rl.WHITE,
	)

	btn_size := Vec2{240, 52}
	btn_pos := Vec2{mid.x, mid.y + 60}
	if draw_button(btn_pos, btn_size, 0, cursor, "commence") {
		play_sfx("game_start")
		transition_to(.Game)
	}
}

// --- Main Loop ---

update :: proc() {
	update_music()
	delta := rl.GetFrameTime()
	update_transition(delta)
	click_claimed = false
	state.scale_hint = camera.zoom

	if rl.IsWindowResized() {
		resize_shader()
		pan_to_new_window_size()
	}

	state.cursor = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

	rl.BeginTextureMode(shader_target)

	// non opaque screen clear — both values scale with delta so trail length and
	// brightness are framerate-independent. 100 fps is the reference.
	afterimage_amount :: 0.65
	fps_scale := min(delta * 100.0, 255.0)
	wipe_opacity := cast(u8)min(255.0 * (1.0 - afterimage_amount) * fps_scale, 255.0)
	draw_opacity = BASE_DRAW_OPACITY * fps_scale
	rl.DrawRectangle(0, 0, screen_size(), {0, 0, 0, wipe_opacity})

	if performance_test {
		rl.DrawFPS(50, 30)
	}
	switch currentScreen {
	case .Title:
		draw_title_screen(delta)
	case .Game:
		if !handle_paused() {
			if state.gameOver {
				msg: cstring = "VICTORY" if state.endReason == .Victory else "GAME OVER"
				draw_screen_message(msg)
				state.timeScale = max(state.timeScale - delta / GAME_OVER_SLOMO_TIME, 0)
				state.endTimer += delta
				if state.endTimer >= 4.0 do transition_to(.Game)
			}
			scaled_delta := delta * state.timeScale
			game_loop(scaled_delta)
			state.gameTime += f64(scaled_delta)
			if !state.gameOver {
				state.timeRemaining -= delta
				if state.timeRemaining <= 0 {
					state.gameOver = true
					state.endReason = .Victory
					play_sfx("victory")
				}
			}
		}
		handle_camera_move(delta)

		draw_tower_toolbar()

		rl.BeginMode2D(camera)
		draw_game_screen(&state)
		rl.EndMode2D()
		if state.gameOver {
			msg: cstring = "VICTORY" if state.endReason == .Victory else "GAME OVER"
			draw_screen_message(msg)
		} else {
			rl.DrawText(
				rl.TextFormat("Time left: %.0f seconds", state.timeRemaining),
				rl.GetScreenWidth() - 240,
				10,
				20,
				rl.WHITE,
			)
			x, _ := screen_size()
			rl.DrawText(rl.TextFormat("$%d", state.money), x - 240, 40, 20, rl.WHITE)
		}
	case .Draw:
		handle_camera_move(delta)
		draw_canvas_toolbar()
		rl.BeginMode2D(camera)
		canvas_loop(delta)
		rl.EndMode2D()
	}
	rl.EndTextureMode()

	rl.BeginDrawing()
	defer free_all(context.temp_allocator)
	defer rl.EndDrawing()
	draw_shader()
	draw_shader_debug()
	draw_transition_curtain()
}


// --- Core ---

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
	rl.UnloadTexture(logo_texture)
	shutdown_sfx()
	shutdown_shader()
	rl.CloseWindow()
}

init :: proc() {
	if !performance_test {
		rl.SetConfigFlags({.VSYNC_HINT})
	}
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	//rl.SetTargetFPS(10)
	rl.InitWindow(1280, 720, "Meteor Defense")
	// Disable quiting with esc key.
	rl.SetExitKey(.KEY_NULL)

	pan_to_new_window_size()

	rl.InitAudioDevice()
	set_screen(currentScreen)
	init_sfx()
	init_meteor_polygons()
	init_shader()

	img := rl.LoadImageFromMemory(".png", raw_data(_LOGO_PNG), i32(len(_LOGO_PNG)))
	logo_texture = rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
}

