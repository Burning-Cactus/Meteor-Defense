package game
import rl "vendor:raylib"

line_thickness :: 1.5
base_line_resolution :: 1

shape_T :: enum {
	DOT, LINE, CIRCLE,
}
Drawshape :: struct {
	type : shape_T,
	start : Vec2,
	end : Vec2,
}

ThemeColor :: enum {
	FILL,
	MID,
	CONTRAST,
	RED,
	BLUE,
	CYAN,
	YELLOW,
}

theme :[ThemeColor] rl.Color
set_theme ::proc() { //if there's a better way to do this I'd love to hear it
	theme[.FILL] =    	rl.BLACK
	theme[.MID] =     	rl.GRAY
	theme[.CONTRAST] =	rl.WHITE
	theme[.RED] =     	rl.MAGENTA
	theme[.BLUE] =    	rl.BLUE
	theme[.CYAN] =    	rl.SKYBLUE
	theme[.YELLOW] =  	rl.YELLOW
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
		rl.DrawRing(pos, radius-t, radius+t, 0.0, 360.0, 16, theme[col])
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

