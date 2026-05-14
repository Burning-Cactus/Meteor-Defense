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

// --- Polygons ---

Polygon :: []Vec2

circle_polygon :: proc(pos:Vec2, radius:f32, n:i32, allocator := context.temp_allocator) -> Polygon {
	verts := make(Polygon, n, allocator)
	for i in 0..<n {
		angle := math.TAU * f32(i) / f32(n)
		verts[i] = pos + {math.cos(angle), math.sin(angle)} * radius
	}
	return verts
}

star_polygon :: proc(pos:Vec2, rot:f32, points:i32, radius:f32, sharpness:f32, allocator := context.temp_allocator) -> Polygon {
	inner_radius := radius * (1.0 - clamp(sharpness, f32(0), f32(1)))
	sector := math.TAU / f32(points)
	verts := make(Polygon, points * 2, allocator)
	for i in 0..<points {
		outer_angle := rot + f32(i) * sector
		inner_angle := outer_angle + sector * 0.5
		verts[i*2]   = pos + unit_vector(outer_angle) * radius
		verts[i*2+1] = pos + unit_vector(inner_angle) * inner_radius
	}
	return verts
}

random_convex_polygon :: proc(pos:Vec2, rot:f32, points:i32, width_approx:f32, height_approx:f32, seed:u64, allocator := context.temp_allocator) -> Polygon {
	rng_state := rand.create(seed)
	rng := rand.default_random_generator(&rng_state)
	a := width_approx / 2.0
	b := height_approx / 2.0
	sector := math.TAU / f32(points)
	verts := make(Polygon, points, allocator)
	for i in 0..<points {
		angle := rot + f32(i) * sector + rand.float32(rng) * sector * 0.8
		cos_a := math.cos(angle)
		sin_a := math.sin(angle)
		ellipse_r := (a * b) / math.sqrt(b*b*cos_a*cos_a + a*a*sin_a*sin_a)
		verts[i] = pos + unit_vector(angle) * ellipse_r * (0.7 + rand.float32(rng) * 0.3)
	}
	return verts
}

// --- Primative Shapes ---

draw_dot :: proc(pos:Vec2, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	// drawing slightly oversized because it doesn't look right otherwise
	rl.DrawCircleV(pos, line_thickness *0.8 / scale_hint, modulate(theme[col], brightness))
}
draw_line :: proc(start:Vec2, end:Vec2, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	angle := vec_angle(end - start)
	a1 := math.to_degrees(angle + math.PI)
	a2 := math.to_degrees(angle - math.PI)
	line_col := modulate(theme[col], brightness)
	end_col := modulate(theme[col], brightness * 0.6)
	rl.DrawLineEx(start, end, line_thickness/scale_hint, line_col)
	rl.DrawCircleSector(start, line_thickness/2.0/scale_hint, a1, a2, 8, end_col)
	rl.DrawCircleSector(end, line_thickness/2.0/scale_hint, a2, a1, 8, end_col)
}
draw_circle :: proc(pos:Vec2, radius:f32, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	scaled_radius := radius * scale_hint
	if scaled_radius < line_thickness * 1.2 {
		draw_dot(pos, col, scale_hint)
	} else {
		draw_polygon(circle_polygon(pos, radius, segments(scaled_radius)), col, scale_hint, brightness)
	}
}


// --- Compound Shapes ---

rotate_polygon :: proc(poly:Polygon, rot:f32, pos:Vec2 = 0, allocator := context.temp_allocator) -> Polygon {
	rot_mat := get_rotation_matrix(rot)
	result  := make(Polygon, len(poly), allocator)
	for i in 0..<len(poly) {
		result[i] = poly[i] * rot_mat + pos
	}
	return result
}

draw_polygon :: proc(poly:Polygon, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	n := i32(len(poly))
	for i in 0..<n {
		draw_line(poly[i], poly[(i+1) % n], col, scale_hint, brightness)
	}
}

draw_polygon_transformed :: proc(poly:Polygon, pos:Vec2, rot:f32, col:ThemeColor, scale_hint:f32, brightness:f32 = 1.0) {
	draw_polygon(rotate_polygon(poly, rot, pos), col, scale_hint, brightness)
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


draw_star :: proc(pos:Vec2, rot:f32, points:i32, radius:f32, sharpness:f32, col:ThemeColor, scale_hint:f32) {
	draw_polygon(star_polygon(pos, rot, points, radius, sharpness), col, scale_hint)
}

draw_random_convex_polygon :: proc(pos:Vec2, rot:f32, points:i32, width_approx:f32, height_approx:f32, seed:u64, col:ThemeColor, scale_hint:f32) {
	draw_polygon(random_convex_polygon(pos, rot, points, width_approx, height_approx, seed), col, scale_hint)
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

