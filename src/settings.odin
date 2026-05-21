package game

import "core:math"
import rl "vendor:raylib"

MIN_VOLUME_DB      :: f32(-60)
MAX_VOLUME_DB      :: f32(0)
BASE_GLOW_RADIUS   :: f32(3.8)
BASE_GLOW_STRENGTH :: f32(0.4)

Settings :: struct {
	sfx_volume_db:    f32,
	music_volume_db:  f32,
	brightness:       f32,
	flicker:          f32,
	_drag_sfx:        Drag,
	_drag_music:      Drag,
	_drag_brightness: Drag,
	_drag_flicker:    Drag,
}

default_settings :: Settings{
	sfx_volume_db   = MAX_VOLUME_DB,
	music_volume_db = MAX_VOLUME_DB,
	brightness      = 1.0,
	flicker         = 0.35,
}

settings := Settings{
	sfx_volume_db   = default_settings.sfx_volume_db,
	music_volume_db = default_settings.music_volume_db,
	brightness      = default_settings.brightness,
	flicker         = default_settings.flicker,
}

db_to_linear :: proc(db: f32) -> f32 {
	if db <= MIN_VOLUME_DB do return 0
	return math.pow(f32(10), db / 20)
}

apply_settings :: proc() {
	sfx_volume_linear   = db_to_linear(settings.sfx_volume_db)
	music_volume_linear = db_to_linear(settings.music_volume_db)
	draw_opacity        = BASE_DRAW_OPACITY * settings.brightness
	line_thickness      = 4.0 * (1 + (settings.brightness-1)*0.5 )
	shader_params.glow_radius    = BASE_GLOW_RADIUS   * (1 + (settings.brightness-1)*0.5 )
	shader_params.glow_strength  = BASE_GLOW_STRENGTH * (1 + (settings.brightness-1)*0.3 )
	shader_params.noise_strength = settings.flicker
}

draw_settings :: proc(pos: Vec2, anchor: DrawDirection) {
	PAD     :: f32(12)
	LABEL_W :: f32(110)
	SLIDER_W :: f32(160)
	ROW     :: f32(24)
	GAP     :: f32(10)
	FONT    :: i32(14)
	N       :: 4

	total_w := PAD*2 + LABEL_W + GAP + SLIDER_W
	total_h := PAD*2 + f32(N)*ROW + f32(N-1)*GAP

	dir      := direction_offset(anchor)
	top_left := pos - (dir + {1, 1}) / 2 * {total_w, total_h}
	cursor   := rl.GetMousePosition()

	rl.DrawRectangle(i32(top_left.x), i32(top_left.y), i32(total_w), i32(total_h), {0, 0, 0, 200})

	lx := top_left.x + PAD
	sx := lx + LABEL_W + GAP
	y  := top_left.y + PAD + ROW/2

	draw_text("SFX Volume",   {lx, y}, FONT, .LEFT)
	draw_slider({sx, y}, SLIDER_W, &settings.sfx_volume_db,   MIN_VOLUME_DB, MAX_VOLUME_DB, default_settings.sfx_volume_db, cursor, &settings._drag_sfx)
	y += ROW + GAP

	draw_text("Music Volume", {lx, y}, FONT, .LEFT)
	draw_slider({sx, y}, SLIDER_W, &settings.music_volume_db, MIN_VOLUME_DB, MAX_VOLUME_DB, default_settings.music_volume_db, cursor, &settings._drag_music)
	y += ROW + GAP

	draw_text("Brightness",   {lx, y}, FONT, .LEFT)
	draw_slider({sx, y}, SLIDER_W, &settings.brightness,      0, 3, default_settings.brightness, cursor, &settings._drag_brightness)
	y += ROW + GAP

	draw_text("Flicker",      {lx, y}, FONT, .LEFT)
	draw_slider({sx, y}, SLIDER_W, &settings.flicker,         0, 1, default_settings.flicker, cursor, &settings._drag_flicker)

	apply_settings()
}
