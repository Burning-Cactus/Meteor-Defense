package game
import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

line_thickness :: 4.0
line_resolution ::  48/*lines per 100 pixels*/ / 100.0

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
	FILL,
	RED,
	BLUE,
	CYAN,
	YELLOW,
	DEBUG,
}

draw_opacity :u8: 60
theme := [ThemeColor][3]u8 {
	.FILL =   	{0,    0,    0,  },
	.PRIMARY =	{0xff, 0xff, 0xff},
	.RED =    	{0xff, 0x1e, 0x46},
	.BLUE =   	{0x23, 0x81, 0xdc},
	.CYAN =   	{0x4d, 0xae, 0xce},
	.YELLOW = 	{0xf2, 0xe7, 0x7a},
	.DEBUG =  	{0xff, 0x00, 0xff},
}

// --- Drawing Utilities ---
modulate :: proc(rgb: [3]u8, brightness:f32) -> rl.Color {
	alpha := cast(u8) (cast(f32)draw_opacity * brightness)
	return {rgb.r, rgb.g, rgb.g, alpha}
}
segments :: proc(radius:f32) -> i32{
	return  max(4, i32(math.ceil(math.TAU * math.sqrt(radius) * line_resolution)))
}

// --- Primative Shapes ---

draw_dot :: proc(pos:Vec2, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	rl.DrawCircleV(pos, line_thickness / scale_hint / 2.0, modulate(theme[col], brightness))
}
draw_line :: proc(start:Vec2, end:Vec2, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	rl.DrawLineEx(start, end, line_thickness/scale_hint, modulate(theme[col], brightness))
}
Polygon :: []Vec2

circle_polygon :: proc(pos:Vec2, radius:f32, n:i32, allocator := context.temp_allocator) -> Polygon {
	verts := make(Polygon, n, allocator)
	for i in 0..<n {
		angle := math.TAU * f32(i) / f32(n)
		verts[i] = pos + {math.cos(angle), math.sin(angle)} * radius
	}
	return verts
}

draw_circle :: proc(pos:Vec2, radius:f32, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	scaled_radius := radius * scale_hint
	if scaled_radius < line_thickness * 1.2 {
		draw_dot(pos, col, scale_hint)
	} else {
		n := segments(scaled_radius)
		poly := circle_polygon(pos, radius, n)
		for i in 0..<n {
			draw_line(poly[i], poly[(i+1) % n], col, scale_hint, brightness)
		}
	}
}

// --- Compound Shapes ---

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


draw_star :: proc(pos:Vec2, rot:f32, points:i32, radius:f32, sharpness:f32, col:ThemeColor, scale_hint:f32) {
	inner_radius := radius * (1.0 - clamp(sharpness, f32(0), f32(1)))
	sector := math.TAU / f32(points)
	for i in 0..<points {
		outer_angle := rot + f32(i) * sector
		inner_angle := outer_angle + sector * 0.5
		outer      := pos + unit_vector(outer_angle) * radius
		inner      := pos + unit_vector(inner_angle) * inner_radius
		next_outer := pos + unit_vector(outer_angle + sector) * radius
		draw_line(outer, inner, col, scale_hint)
		draw_line(inner, next_outer, col, scale_hint)
	}
}

draw_random_convex_polygon :: proc(pos:Vec2, rot:f32, points:i32, width_approx:f32, height_approx:f32, seed:u64, col:ThemeColor, scale_hint:f32) {
	rng_state := rand.create(seed)
	rng := rand.default_random_generator(&rng_state)
	verts := make([]Vec2, points, context.temp_allocator)
	a := width_approx / 2.0
	b := height_approx / 2.0
	sector := math.TAU / f32(points)
	for i in 0..<points {
		// Constrain each angle to its own sector to guarantee convexity
		angle := rot + f32(i) * sector + rand.float32(rng) * sector * 0.8
		cos_a := math.cos(angle)
		sin_a := math.sin(angle)
		ellipse_r := (a * b) / math.sqrt(b*b*cos_a*cos_a + a*a*sin_a*sin_a)
		verts[i] = pos + unit_vector(angle) * ellipse_r * (0.7 + rand.float32(rng) * 0.3)
	}
	for i in 0..<points {
		draw_line(verts[i], verts[(i + 1) % points], col, scale_hint)
	}
}

draw_shape ::proc(s:Drawshape, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	switch s.type {
	case shape_T.DOT:
		draw_dot(s.end, col, scale_hint, brightness)
	case shape_T.LINE:
		draw_line(s.start, s.end, col, scale_hint, brightness)
	case shape_T.CIRCLE:
		draw_circle(s.start, rl.Vector2Distance(s.start, s.end), col, scale_hint, brightness)
	}
}

