package game

import "core:encoding/json"
import "core:log"
import "core:reflect"
import "core:strings"

// Encodes a Drawable to JSON bytes.
drawable_encode :: proc(d: Drawable, allocator := context.allocator) -> (data: []byte, err: json.Marshal_Error) {
	val := drawable_to_json_value(d, context.temp_allocator)
	defer json.destroy_value(val, context.temp_allocator)
	return json.marshal(val, {pretty = true, sort_maps_by_key = true}, allocator)
}

// Decodes a Drawable from JSON bytes. Caller owns any allocated group memory.
drawable_decode :: proc(data: []byte, allocator := context.allocator) -> (d: Drawable, ok: bool) {
	val, err := json.parse(data, allocator = context.temp_allocator)
	defer json.destroy_value(val, context.temp_allocator)
	if err != .None {
		return nil, false
	}
	return drawable_from_json_value(val, allocator)
}

// --- value-level helpers (used internally and in tests) ---

drawable_to_json_value :: proc(d: Drawable, allocator := context.allocator) -> json.Value {
	context.allocator = allocator
	switch v in d {
	case Drawshape:
		obj := make(json.Object)
		obj["brightness"] = json.Float(1.0) // not stored; placeholder to keep field set uniform with shape_pro
		obj["col"]        = json.String(reflect.enum_string(ThemeColor.PRIMARY))
		obj["end"]        = vec2_to_json_value(v.end)
		obj["kind"]       = json.String("shape")
		obj["start"]      = vec2_to_json_value(v.start)
		obj["type"]       = json.String(reflect.enum_string(v.type))
		return obj
	case DrawshapeEx:
		col_name, _ := reflect.enum_name_from_value(v.col)
		obj := make(json.Object)
		obj["brightness"] = json.Float(f64(v.brightness))
		obj["col"]        = json.String(col_name)
		obj["end"]        = vec2_to_json_value(v.end)
		obj["kind"]       = json.String("shape_pro")
		obj["start"]      = vec2_to_json_value(v.start)
		obj["type"]       = json.String(reflect.enum_string(v.type))
		return obj
	case ^DrawshapeGroup:
		if v == nil {
			return json.Null(nil)
		}
		contents := make(json.Array, len(v.contents))
		for item, i in v.contents {
			contents[i] = drawable_to_json_value(item^)
		}
		obj := make(json.Object)
		obj["contents"] = contents
		obj["kind"]     = json.String("group")
		obj["name"]     = json.String(v.name)
		return obj
	}
	return json.Null(nil)
}

drawable_from_json_value :: proc(v: json.Value, allocator := context.allocator) -> (d: Drawable, ok: bool) {
	obj := v.(json.Object) or_return
	kind := obj["kind"].(json.String) or_return

	switch kind {
	case "shape":
		s: Drawshape
		type_str := obj["type"].(json.String) or_return
		s.type    = reflect.enum_from_name(Drawshape_Type, type_str) or_return
		s.start   = vec2_from_json_value(obj["start"]) or_return
		s.end     = vec2_from_json_value(obj["end"]) or_return
		return s, true

	case "shape_pro":
		p: DrawshapeEx
		type_str  := obj["type"].(json.String) or_return
		col_str   := obj["col"].(json.String) or_return
		p.type       = reflect.enum_from_name(Drawshape_Type, type_str) or_return
		p.col        = reflect.enum_from_name(ThemeColor, col_str) or_return
		p.brightness = f32(obj["brightness"].(json.Float) or_return)
		p.start      = vec2_from_json_value(obj["start"]) or_return
		p.end        = vec2_from_json_value(obj["end"]) or_return
		return p, true

	case "group":
		g := new(DrawshapeGroup, allocator)
		name_src, _ := obj["name"].(json.String)
		g.name = strings.clone(name_src, allocator)
		arr := obj["contents"].(json.Array) or_return
		g.contents = make([dynamic]^Drawable, len(arr), allocator)
		for item, i in arr {
			ptr  := new(Drawable, allocator)
			ptr^, ok = drawable_from_json_value(item, allocator)
			if !ok {
				return nil, false
			}
			g.contents[i] = ptr
		}
		return g, true
	}
	return nil, false
}

vec2_to_json_value :: proc(v: Vec2, allocator := context.allocator) -> json.Value {
	arr := make(json.Array, 2, allocator)
	arr[0] = json.Float(f64(v.x))
	arr[1] = json.Float(f64(v.y))
	return arr
}

vec2_from_json_value :: proc(v: json.Value) -> (out: Vec2, ok: bool) {
	arr := v.(json.Array) or_return
	if len(arr) < 2 {
		return {}, false
	}
	x := arr[0].(json.Float) or_return
	y := arr[1].(json.Float) or_return
	return Vec2{f32(x), f32(y)}, true
}

// --- Tests ---

test_drawable_json :: proc() {
	// Two leaf drawables to embed in a group.
	inner_dot := new(Drawable)
	inner_dot^ = Drawshape{type = .DOT, end = {1, 2}}
	inner_line := new(Drawable)
	inner_line^ = DrawshapeEx{
		drawshape  = {type = .LINE, start = {0, 0}, end = {10, 10}},
		col        = .BLUE,
		brightness = 1.0,
	}

	group := new(DrawshapeGroup)
	group.name     = "test_group"
	group.contents = make([dynamic]^Drawable, 2)
	group.contents[0] = inner_dot
	group.contents[1] = inner_line

	cases := []Drawable{
		Drawshape{type = .DOT, end = {5, 5}},
		Drawshape{type = .LINE, start = {10, 20}, end = {30, 40}},
		Drawshape{type = .CIRCLE, start = {0, 0}, end = {50, 0}},
		DrawshapeEx{
			drawshape  = {type = .CIRCLE, start = {0, 0}, end = {50, 50}},
			col        = .RED,
			brightness = 0.8,
		},
		group,
	}

	pass, fail := 0, 0
	for original in cases {
		data, enc_err := drawable_encode(original)
		if enc_err != nil {
			log.errorf("test_drawable_json: encode failed: %v", enc_err)
			fail += 1
			continue
		}
		defer delete(data)

		decoded, ok := drawable_decode(data)
		if !ok {
			log.errorf("test_drawable_json: decode failed for JSON:\n%s", string(data))
			fail += 1
			continue
		}

		data2, _ := drawable_encode(decoded)
		defer delete(data2)

		if string(data) == string(data2) {
			pass += 1
		} else {
			log.errorf("test_drawable_json: round-trip mismatch\n  encoded:  %s\n  re-encoded: %s",
				string(data), string(data2))
			fail += 1
		}
	}

	if fail == 0 {
		log.infof("test_drawable_json: all %d cases passed", pass)
	} else {
		log.errorf("test_drawable_json: %d passed, %d FAILED", pass, fail)
	}
}
