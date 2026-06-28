// Handles drawing itself. drawing the ui, and when and how to draw the other parts of the game
package game

import "core:c"
import "core:math"
import rl "vendor:raylib"

import "core:fmt"

_LOGO_PNG :: #load("../assets/logo.png")
logo_texture: rl.Texture2D

TRANSITION_SPEED: f32 : 1 / 0.3 //seconds

performance_test :: false // Disable vsync and display fps

run := true

camera: rl.Camera2D
prev_window_size: Vec2

// --- Window Size Utils ---

BASE_CAMERA_ZOOM:f32: 4.0

screen_size_metric :: proc() -> f32 {
	return (f32(rl.GetScreenWidth()) + f32(rl.GetScreenHeight())) / 2
}
screen_size_ratio :: proc() -> f32 {
	REFERENCE_SCREEN_METRIC:f32: 1000 // (1280 + 720) / 2
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

// --- Input ---

FrameInput :: struct {
	fire:bool,
	zoom:f32,
	pan:Vec2,
	move:Vec2,
	aim:Vec2,
	select_slot:int,
	pause:bool,
	build_mode:bool,
}
input:FrameInput

get_every_connected_gampad :: proc () -> [dynamic]i32 {
	out:[dynamic]i32 //TODO is dynamic the right choice for this?
	for i:i32; rl.IsGamepadAvailable(i); i+=1 {
		append(&out, i)
	}
	return out
}

deadzone:f32 = 0.02
deadzoned :: proc(raw:f32) -> f32 {
	if abs(raw) < deadzone do return 0
	return raw
}

build_input_vec :: proc(gamepad_idx:i32, x_axis:rl.GamepadAxis, y_axis:rl.GamepadAxis) -> Vec2 {
	return {
		deadzoned(rl.GetGamepadAxisMovement(gamepad_idx, x_axis)),
		deadzoned(rl.GetGamepadAxisMovement(gamepad_idx, y_axis)),
	}
}

deadzoned_v :: proc(raw:Vec2) -> Vec2 {
	return {deadzoned(raw.x), deadzoned(raw.y)}
}

input_active :: proc(val:Vec2, threshold:f32 = deadzone) -> bool {
	return abs(val.x) > threshold || abs(val.y) > threshold
}
clamped_input :: proc(raw:Vec2) -> Vec2 {
	if dist_squared(raw) > 1 do return normalize(raw)
	return raw
}

poll_input :: proc() {
	connected_gamepads := get_every_connected_gampad()
	input.fire = rl.IsMouseButtonPressed(.LEFT)
	for i in connected_gamepads do input.fire |= rl.IsGamepadButtonPressed(i, .RIGHT_FACE_DOWN)
	input.fire |= rl.IsMouseButtonPressed(.RIGHT)

	zoom_delta := rl.GetMouseWheelMove()
	for i in connected_gamepads do zoom_delta -= rl.GetGamepadAxisMovement(i, .LEFT_TRIGGER) * 0.03
	for i in connected_gamepads do zoom_delta += rl.GetGamepadAxisMovement(i, .RIGHT_TRIGGER) * 0.03
	input.zoom *= math.exp(0.2 * zoom_delta) // logarithmic zoom
	input.zoom = clamp(input.zoom, 0.125, 2)

	input.pan = rl.GetMouseDelta() if rl.IsMouseButtonDown(.MIDDLE) else {}

	input.move = {0,0}
	if rl.IsKeyDown(.A) do input.move.x -= 1
	if rl.IsKeyDown(.D) do input.move.x += 1
	if rl.IsKeyDown(.W) do input.move.y -= 1
	if rl.IsKeyDown(.S) do input.move.y += 1
	for i in connected_gamepads do input.move += build_input_vec(i, .LEFT_X, .LEFT_Y)
	input.move = clamped_input(input.move)

	input.build_mode = false
	if currentScreen == .Game || currentScreen == .Draw { //TODO: this is ugly
		// select_slot can persist frame-to-frame
		for numkey, i in ([]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE, .ZERO}) {
			if rl.IsKeyPressed(numkey) {
				if !state.buildMode {
					input.build_mode = true
					play_sfx("ui_click")
				} else if i == input.select_slot {
					input.build_mode = true
					play_sfx("ui_back")
				} else do play_sfx("ui_click")

				input.select_slot = i
				break
			}
		}
		for i in connected_gamepads {
			if rl.IsGamepadButtonPressed(i, .LEFT_TRIGGER_1) {
				input.select_slot -= 1
				play_sfx("ui_click")
				if !state.buildMode do input.build_mode = true
			}
			if rl.IsGamepadButtonPressed(i, .RIGHT_TRIGGER_1) {
				input.select_slot += 1
				play_sfx("ui_click")
				if !state.buildMode do input.build_mode = true
			}
		} // wrapping will have to be done on the consumer side since we don't yet know how many slots there are
	}

	input.build_mode |= rl.IsKeyPressed(.B)
	for i in connected_gamepads do input.build_mode |= rl.IsGamepadButtonPressed(i, .RIGHT_FACE_RIGHT)

	input.pause = rl.IsKeyPressed(.SPACE)
	for i in connected_gamepads {
		input.pause |= rl.IsGamepadButtonPressed(i, .MIDDLE_RIGHT)
		input.pause |= rl.IsGamepadButtonPressed(i, .MIDDLE_LEFT)
	}

	input.aim = {0,0}
	for i in connected_gamepads do input.aim += build_input_vec(i, .RIGHT_X, .RIGHT_Y)
}

// --- Interaction ---

set_cursor_captured :: proc(captured: bool) {
	if captured == rl.IsCursorHidden() do return
	if captured {
		rl.DisableCursor()
	} else {
		rl.EnableCursor()
	}
}

soft_cursor_pos: Vec2
draw_cursor :: proc() {
	if rl.IsCursorHidden() do draw_dot(soft_cursor_pos, 1.0, .PRIMARY, 3)
}

handle_camera_zoom :: proc(delta:f32, seconds:f32=0, offset:Vec2={}, tweak:f32=1) {
	speed:= 1 / seconds if seconds > 0 else 0
	base:= BASE_CAMERA_ZOOM * screen_size_ratio()
	target:= base * input.zoom * tweak

	offset_compensation := rl.GetScreenToWorld2D(offset, camera)
	camera.offset = offset
	camera.target = offset_compensation

	if speed > 0 {
		camera.zoom += (target - camera.zoom) * speed * delta
		if abs(target - camera.zoom) < 0.0001 {
			camera.zoom = target
			return
		}
	} else {
		camera.zoom = target
	}
}

handle_freecam :: proc(delta: f32) {
	camera.target -=  input.pan * (1.0 / camera.zoom)
	handle_camera_zoom(delta, 0.2, rl.GetMousePosition())
}

cursor_accum: Vec2
// smoothly blends between moving the cursor and moving the camera towards the screen edge
handle_hybrid_camera :: proc(delta: f32) {
	set_cursor_captured(true)
	center:= screen_vec()/2

	scale := min(screen_vec().x, screen_vec().y) /2

	max_look :: 2
	look_offset: = input.aim * max_look * scale
	cursor_accum += rl.GetMouseDelta() // TODO: use lower latency polling method
	cursor_accum = clamp_radial(cursor_accum, max_look*scale) // clamped to make sure it doesn't drift away infinitely

	look_offset = clamp_radial(cursor_accum + look_offset, max_look*scale)
	cursor_portion := soft_clamp_radial(look_offset, scale)
	pan := look_offset - cursor_portion

	// Subtly zoom out the further the camera pans towards the edge. dist(pan)/scale is
	// 0..1, so at full pan the zoom is multiplied by (1 - EDGE_ZOOM_OUT).
	EDGE_ZOOM_OUT :: 0.5
	handle_camera_zoom(delta, 0.2, center, 1 - dist(pan) / scale * EDGE_ZOOM_OUT)

	camera.target = state.player.pos + pan / camera.zoom
	soft_cursor_pos = cursor_portion + center
}

paused: bool
handle_paused :: proc() -> bool{
	if input.pause do paused = !paused
	if paused {
		msg_start, msg_end := draw_screen_message("PAUSED")
		draw_settings({
			(msg_start.x + msg_end.x)/2,
			msg_end.y,
		}, .TOP)
	}
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
		input.zoom = 0.375 // zoom out when game starts
		clear_music_loop_points()
	case .Title:
		fmt.println("Title")
		reset_game()
		set_music_loop_points(3, 7)
	case .Draw:
		fmt.println("Draw")
		reset_game()
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
	player:            Entity,
	meteors:           [dynamic]Meteor,
	towers:            [dynamic]Tower,
	projectiles:       [dynamic]Entity,
	vfx:               [dynamic]Vfx,
	comet:             Entity,
	comet_velocity:    Vec2,
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
		money = 10,
		difficulty_scale = 1,
		timeScale = 1,
	}
	init_background()
	camera.offset = Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())} / 2
	camera.target = state.player.pos
	camera.zoom = BASE_CAMERA_ZOOM * screen_size_ratio()
	input.zoom = 1 // absolute zoom factor; 1 == base zoom
}

draw_radar :: proc() {
	screen_end := screen_vec()
	screen_center := screen_end / 2
	for m in state.meteors {
		inset:f32: 50
		ms := rl.GetWorldToScreen2D(m.pos, camera)
		if ms.x >= 0 && ms.x <= screen_end.x &&
		   ms.y >= 0 && ms.y <= screen_end.y {
			continue
		}
		dir := ms - screen_center
		if dir == {} do continue
		tx: f32 = math.F32_MAX
		ty: f32 = math.F32_MAX
		if dir.x > 0 do tx = (screen_end.x - inset - screen_center.x) / dir.x
		else if dir.x < 0 do tx = (inset - screen_center.x) / dir.x
		if dir.y > 0 do ty = (screen_end.y - inset - screen_center.y) / dir.y
		else if dir.y < 0 do ty = (inset - screen_center.y) / dir.y
		draw_dot(screen_center + dir * min(tx, ty), 1.0, .PRIMARY, 2.0-dist_squared({tx,ty}, ms) * 0.00001)
	}
}

// --- Screen: Title ---

slider_drag:Drag
draw_title_screen :: proc(delta: f32) {
	rl.BeginMode2D(camera)
	draw_game_screen(&state)
	rl.EndMode2D()
	update_background(delta)
	draw_background()

	pad_x, pad_y := padding()
	padv:Vec2 = {f32(pad_x), f32(pad_y)}
	draw_start:= padv
	tx_rect:=draw_texture(logo_texture, {f32(pad_x), f32(pad_y)}, .TOP_LEFT, .WIDTH, 0.5, 600)
	draw_start.y += tx_rect.y

	draw_text("jcomcl and BurningCactus",
		{tx_rect.x/2 -padv.x, draw_start.y},
	17, .CENTER)

	draw_start.y += padv.y

	btn_size := Vec2{240, 52}
	if draw_button(draw_start + padv, btn_size, rl.GetMousePosition(), "commence") {
		play_sfx("game_start")
		set_screen(.Game)
	}
	draw_start.y += btn_size.y + padv.y *2
	draw_settings(draw_start, .TOP_LEFT)
}

// --- Main Loop ---

update :: proc() {
	click_claimed = false
	poll_input()
	update_music()
	delta := rl.GetFrameTime()
	update_transition(delta)
	state.scale_hint = camera.zoom

	if rl.IsWindowResized() {
		resize_shader()
		pan_to_new_window_size()
	}

	if input_active(input.aim) {
		state.cursor = state.player.pos + input.aim * 1000
	} else if rl.IsCursorHidden() {
		state.cursor = rl.GetScreenToWorld2D(soft_cursor_pos, camera)
	} else {
		state.cursor = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
	}

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
		set_cursor_captured(false)
		draw_title_screen(delta)
	case .Game:
		if !handle_paused() {
			if state.gameOver {
				msg: cstring = "VICTORY" if state.endReason == .Victory else "GAME OVER"
				draw_screen_message(msg)
				GAME_OVER_SLOMO_TIME: f32 : 3 // seconds to reach zero time scale
				state.timeScale = max(state.timeScale - delta / GAME_OVER_SLOMO_TIME, 0)
				state.endTimer += delta
				if state.endTimer >= 4.0 do transition_to(.Game)
			}
			scaled_delta := delta * state.timeScale
			draw_tower_toolbar() // must be before game loop to be clickable
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
			handle_hybrid_camera(delta)
		} else {
			set_cursor_captured(false)
			handle_freecam(delta)
		}

		draw_radar()

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
		//if cursor_captured do draw_cursor()
	case .Draw:
		set_cursor_captured(false)
		handle_freecam(delta)
		draw_canvas_toolbar()
		rl.BeginMode2D(camera)
		canvas_loop(delta)
		rl.EndMode2D()
	}
	draw_cursor()
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

