package game
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

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
	name:     string,
	contents: [dynamic]^Drawable,
}
Drawable :: union{ Drawshape, DrawshapePro, ^DrawshapeGroup }

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

modulate_themecolor :: proc(col: ThemeColor, brightness:f32=1.0) -> rl.Color {
	return modulate_rgb(theme[col], brightness)
}
modulate_rgb :: proc(rgb: [3]u8, brightness:f32) -> rl.Color {
	alpha := cast(u8) (cast(f32)draw_opacity * brightness)
	return {rgb.r, rgb.g, rgb.b, alpha}
}
modulate :: proc{modulate_themecolor, modulate_rgb}

segments :: proc(radius:f32) -> i32{
	return  max(4, i32(math.ceil(math.TAU * math.sqrt(radius) * line_resolution)))
}

// --- Polygons ---

circle_polygon :: proc(pos:Vec2, radius:f32, n:i32, allocator := context.temp_allocator) -> []Vec2 {
	verts := make([]Vec2, n, allocator)
	for i in 0..<n {
		angle := math.TAU * f32(i) / f32(n)
		verts[i] = pos + {math.cos(angle), math.sin(angle)} * radius
	}
	return verts
}

star_polygon :: proc(pos:Vec2, rot:f32, points:i32, radius:f32, sharpness:f32, allocator := context.temp_allocator) -> []Vec2 {
	inner_radius := radius * (1.0 - clamp(sharpness, f32(0), f32(1)))
	sector := math.TAU / f32(points)
	verts := make([]Vec2, points * 2, allocator)
	for i in 0..<points {
		outer_angle := rot + f32(i) * sector
		inner_angle := outer_angle + sector * 0.5
		verts[i*2]   = pos + unit_vector(outer_angle) * radius
		verts[i*2+1] = pos + unit_vector(inner_angle) * inner_radius
	}
	return verts
}

random_convex_polygon :: proc(pos:Vec2, rot:f32, points:i32, width_approx:f32, height_approx:f32, seed:u64, allocator := context.temp_allocator) -> []Vec2 {
	rng_state := rand.create(seed)
	rng := rand.default_random_generator(&rng_state)
	a := width_approx / 2.0
	b := height_approx / 2.0
	sector := math.TAU / f32(points)
	verts := make([]Vec2, points, allocator)
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
	m := calculate_rotation_matrix(rot)
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
	case ^DrawshapeGroup:
		g := d.(^DrawshapeGroup)
		contents := make([dynamic]^Drawable, len(g.contents), allocator)
		for item, i in g.contents {
			ptr := new(Drawable, allocator)
			ptr^ = transformed_drawable(item^, t, allocator)
			contents[i] = ptr
		}
		result := new(DrawshapeGroup, allocator)
		result^ = {g.name, contents}
		return result
	}
	return d
}

// --- Compound Shapes ---

rotate_polygon :: proc(poly: Polygon, rot: f32, pos: Vec2 = 0, allocator := context.temp_allocator) -> []Vec2 {
	return copy_and_rotate_vertices(poly.vertices, pos, rot, allocator)
}

draw_polygon_transformed :: proc(verts: []Vec2, pos: Vec2, rot: f32, scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness: f32 = 1.0) {
	last_idx := len(verts) - 1
	rot_mat := calculate_rotation_matrix(rot)
	for i in 0 ..< last_idx {
		a := verts[i] * rot_mat + pos
		b := verts[i + 1] * rot_mat + pos
		draw_line(a, b, scale_hint, col, brightness)
	}
	a := verts[last_idx] * rot_mat + pos
	b := verts[0] * rot_mat + pos
	draw_line(a, b, scale_hint, col, brightness)
}

draw_rect :: proc(pos: Vec2, size: Vec2, rot: f32, scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness: f32 = 1.0) {
	h := size / 2
	draw_polygon_transformed([]Vec2{
		{-h.x, -h.y},
		{-h.x,  h.y},
		{ h.x,  h.y},
		{ h.x, -h.y},
	}, pos, rot, scale_hint, col, brightness)
}

draw_box ::proc(start:Vec2, end:Vec2,  scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness: f32 = 1.0) {
	draw_polygon([]Vec2{
		start,
		{end.x, start.y},
		end,
		{start.x, end.y},
	}, scale_hint, col, brightness)
}

draw_star :: proc(pos: Vec2, rot: f32, points: i32, radius: f32, sharpness: f32, scale_hint: f32, col: ThemeColor) {
	draw_polygon(star_polygon(pos, rot, points, radius, sharpness), scale_hint, col)
}

draw_random_convex_polygon :: proc(pos: Vec2, rot: f32, points: i32, width_approx: f32, height_approx: f32, seed: u64, scale_hint: f32, col: ThemeColor) {
	draw_polygon(random_convex_polygon(pos, rot, points, width_approx, height_approx, seed), scale_hint, col)
}

// --- Drawing ---

draw_polygon :: proc(verts:[]Vec2, scale_hint:f32=1.0, col:ThemeColor=.PRIMARY, brightness:f32=1.0) {
	n := len(verts)
	for i in 0..<n {
		draw_line(verts[i], verts[(i + 1) % n], scale_hint, col, brightness)
	}
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
		draw_shape(item^, scale_hint, col, brightness)
	}
}

draw_shape :: proc(s:Drawable, scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness:f32=1.0) {
	switch _ in s {
	case Drawshape:
		draw_shape_base(s.(Drawshape), scale_hint, col, brightness)
	case DrawshapePro:
		draw_shape_pro(s.(DrawshapePro), scale_hint)
	case ^DrawshapeGroup:
		draw_shape_group(s.(^DrawshapeGroup)^, scale_hint, col, brightness)
	}
}
