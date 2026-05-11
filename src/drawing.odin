package game
import rl "vendor:raylib"
import "core:math"

line_thickness :: 3.0
line_resolution ::  5/*lines per 100 pixels*/ / 100.0

shape_T :: enum {
	DOT, LINE, CIRCLE,
}
Drawshape :: struct {
	type : shape_T,
	start : Vec2,
	end : Vec2,
}

ThemeColor :: enum {
	PRIMARY,
	MID,
	FILL,
	RED,
	BLUE,
	CYAN,
	YELLOW,
	DEBUG,
}

theme :[ThemeColor] rl.Color
set_theme ::proc() { //if there's a better way to do this I'd love to hear it
	theme[.FILL] =    	rl.BLACK
	theme[.MID] =     	rl.GRAY
	theme[.PRIMARY] =	rl.WHITE
	theme[.RED] =     	rl.MAROON
	theme[.BLUE] =    	rl.BLUE
	theme[.CYAN] =    	rl.SKYBLUE
	theme[.YELLOW] =  	rl.YELLOW
	theme[.DEBUG] =  	rl.MAGENTA
}

// scale_hint indicates how large the shape will be drawn in screen, relative to its computer size (i.e. the zoom)
// used for constant line thickness and controlling resolution
draw_dot :: proc(pos:Vec2, col:ThemeColor, scale_hint:f32) {
	rl.DrawCircleV(pos, line_thickness / scale_hint / 2.0, theme[col])
}
draw_line :: proc(start:Vec2, end:Vec2, col:ThemeColor, scale_hint:f32) {
	draw_dot(start, col, scale_hint)
	rl.DrawLineEx(start, end, line_thickness/scale_hint, theme[col])
	draw_dot(end, col, scale_hint)
}
draw_circle :: proc(pos:Vec2, radius:f32, col:ThemeColor, scale_hint:f32) {
	t :f32 = line_thickness/2.0/scale_hint
	segments := max(3, int(math.ceil(math.TAU * radius * scale_hint * line_resolution)))
	rl.DrawRing(pos, radius-t, radius+t, 0.0, 360.0, i32(segments), theme[col])
}

draw_rect :: proc(pos:Vec2, size:Vec2, rot:f32, col:ThemeColor, scale_hint:f32) {
	offset := size / 2
	rot_mat := get_rotation_matrix(rot)
	a := Vec2{-offset.x, -offset.y} * rot_mat + pos
	b := Vec2{-offset.x,  offset.y} * rot_mat + pos
	c := Vec2{ offset.x,  offset.y} * rot_mat + pos
	d := Vec2{ offset.x, -offset.y} * rot_mat + pos
	draw_line(a, b, col, scale_hint)
	draw_line(b, c, col, scale_hint)
	draw_line(c, d, col, scale_hint)
	draw_line(d, a, col, scale_hint)
}

draw_shape ::proc(s:Drawshape, col:ThemeColor, scale_hint:f32) {
	switch s.type {
	case shape_T.DOT:
		draw_dot(s.end, col, scale_hint)
	case shape_T.LINE:
		draw_line(s.start, s.end, col, scale_hint)
	case shape_T.CIRCLE:
		draw_circle(s.start, rl.Vector2Distance(s.start, s.end), col, scale_hint)
	}
}

