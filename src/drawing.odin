package game
import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

line_thickness :: 4.0
line_resolution ::  48/*lines per 100 pixels*/ / 100.0

Drawshape_Type :: enum {
	DOT, LINE, CIRCLE,
}
Drawshape :: struct {
	type : Drawshape_Type,
	start : Vec2,
	end : Vec2,
}
DrawshapePro :: struct { //dumb naming scheme but raylib uses it so why not
	using drawshape: Drawshape,
	col: ThemeColor,
	brightness: f32,
}
DrawshapeGroup :: struct {
	name : string,
	contents: []Drawable,
}
Drawable :: union{ Drawshape, DrawshapePro, DrawshapeGroup }


ThemeColor :: enum {
	PRIMARY,
	FILL,
	RED,
	BLUE,
	CYAN,
	YELLOW,
	DEBUG,
}

draw_opacity :u8: 40
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
	return {rgb.r, rgb.g, rgb.b, alpha}
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

draw_dot :: proc(pos:Vec2, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32 = 1.0) {
	// drawing slightly oversized because it doesn't look right otherwise
	rl.DrawCircleV(pos, line_thickness *0.8 / scale_hint, modulate(theme[col], brightness))
}

draw_line :: proc(start:Vec2, end:Vec2, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32 = 1.0) {
	angle := vec_angle(end - start)
	a1 := math.to_degrees(angle + math.PI)
	a2 := math.to_degrees(angle - math.PI)
	line_col := modulate(theme[col], brightness)
	end_col := modulate(theme[col], brightness * 0.6)
	rl.DrawLineEx(start, end, line_thickness/scale_hint, line_col)
	rl.DrawCircleSector(start, line_thickness/2.0/scale_hint, a1, a2, 8, end_col)
	rl.DrawCircleSector(end, line_thickness/2.0/scale_hint, a2, a1, 8, end_col)
}

draw_circle :: proc(pos:Vec2, radius:f32, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32 = 1.0) {
	scaled_radius := radius * scale_hint
	if scaled_radius < line_thickness * 1.2 {
		draw_dot(pos, scale_hint, col, brightness)
	} else {
		draw_polygon(circle_polygon(pos, radius, segments(scaled_radius)), scale_hint, col, brightness)
	}
}


// --- Transforms ---

Transform2D :: struct {
	mat: matrix[2, 2]f32,
	pos: Vec2,
}

transform_identity :: proc() -> Transform2D {
	return {mat = matrix[2, 2]f32{1, 0, 0, 1}}
}

transform_trs :: proc(pos: Vec2, rot: f32, scale: Vec2) -> Transform2D {
	m := get_rotation_matrix(rot)
	return {mat = matrix[2, 2]f32{m[0,0]*scale.x, m[0,1]*scale.y, m[1,0]*scale.x, m[1,1]*scale.y}, pos = pos}
}

transform_point :: proc(t: Transform2D, p: Vec2) -> Vec2 {
	return p * t.mat + t.pos
}

transformed_drawshape :: proc(s: Drawshape, t: Transform2D) -> Drawshape {
	return {s.type, transform_point(t, s.start), transform_point(t, s.end)}
}

transformed_drawable :: proc(d: Drawable, t: Transform2D, allocator := context.temp_allocator) -> Drawable {
	switch _ in d {
	case Drawshape:
		return transformed_drawshape(d.(Drawshape), t)
	case DrawshapePro:
		p := d.(DrawshapePro)
		p.drawshape = transformed_drawshape(p.drawshape, t)
		return p
	case DrawshapeGroup:
		g := d.(DrawshapeGroup)
		contents := make([]Drawable, len(g.contents), allocator)
		for item, i in g.contents {
			contents[i] = transformed_drawable(item, t, allocator)
		}
		return DrawshapeGroup{g.name, contents}
	}
	return d
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

draw_polygon_transformed :: proc(poly:Polygon, pos:Vec2, rot:f32, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32 = 1.0) {
	draw_polygon(rotate_polygon(poly, rot, pos), scale_hint, col, brightness)
}

draw_rect :: proc(pos:Vec2, size:Vec2, rot:f32, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32 = 1.0) {
	offset := size / 2
	draw_polygon_transformed({
		{-offset.x, -offset.y},
		{-offset.x,  offset.y},
		{ offset.x,  offset.y},
		{ offset.x, -offset.y},
	}, pos, rot, scale_hint, col, brightness)
}


draw_star :: proc(pos:Vec2, rot:f32, points:i32, radius:f32, sharpness:f32, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32=1.0) {
	draw_polygon(star_polygon(pos, rot, points, radius, sharpness), scale_hint, col, brightness)
}

// NOTE: not actually convex
gen_random_convex_polygon :: proc(pos:Vec2, rot:f32, points:i32, width_approx:f32, height_approx:f32, seed:u64, allocator := context.allocator) -> []Vec2 {
	rng_state := rand.create(seed)
	rng := rand.default_random_generator(&rng_state)
	verts := make([]Vec2, points, allocator)
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
	return verts
}

// --- Drawing ---

draw_polygon :: proc(verts:[]Vec2, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32=1.0) {
	n := len(verts)
	for i in 0..<n {
		draw_line(verts[i], verts[(i + 1) % n], scale_hint, col, brightness)
	}
}

draw_random_convex_polygon :: proc(
		pos:Vec2, rot:f32, points:i32, width_approx:f32, height_approx:f32, seed:u64,
		scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32=1.0
) {
	verts := gen_random_convex_polygon(pos, rot, points, width_approx, height_approx, seed, context.temp_allocator)
	draw_polygon(verts, scale_hint, col, brightness)
}

draw_shape_base :: proc(s: Drawshape, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32=1.0) {
	switch s.type {
	case .DOT:
		draw_dot(s.end, scale_hint, col, brightness)
	case .LINE:
		draw_line(s.start, s.end, scale_hint, col, brightness)
	case .CIRCLE:
		draw_circle(s.start, rl.Vector2Distance(s.start, s.end), scale_hint, col, brightness)
	}
}

draw_shape_pro :: proc(s: DrawshapePro, scale_hint:f32=1.0) {
	draw_shape_base(s.drawshape, scale_hint, s.col, s.brightness)
}

draw_shape_group :: proc(g: DrawshapeGroup, scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness:f32 = 1.0) {
	for item in g.contents {
		draw_shape(item, scale_hint, col, brightness)
	}
}

draw_shape :: proc(s:Drawable, scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness:f32=1.0) {
	switch _ in s {
	case Drawshape:
		draw_shape_base(s.(Drawshape), scale_hint, col, brightness)
	case DrawshapePro:
		draw_shape_pro(s.(DrawshapePro), scale_hint)
	case DrawshapeGroup:
		draw_shape_group(s.(DrawshapeGroup), scale_hint, col, brightness)
	}
}

