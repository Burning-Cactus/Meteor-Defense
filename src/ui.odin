package game

import rl "vendor:raylib"

Drag :: struct{
	button:union {rl.KeyboardKey, rl.MouseButton},
	start, end: Vec2,
	active: bool,
}

paranoid_drag :: false
drag_started ::proc(d:^Drag) -> bool {
	out:bool
	switch _ in d.button {
	case rl.KeyboardKey:
		k:=d.button.(rl.KeyboardKey)
		out = rl.IsKeyPressed(k) || (paranoid_drag && !d.active && rl.IsKeyDown(k))
	case rl.MouseButton:
		b:=d.button.(rl.MouseButton)
		out = rl.IsMouseButtonPressed(b) || (paranoid_drag && !d.active && rl.IsMouseButtonDown(b))
	}
	d.active |= out
	return out
}

drag_ended ::proc(d:^Drag) -> bool {
	if !d.active do return false
	out:bool
	switch _ in d.button {
	case rl.KeyboardKey:
		k:=d.button.(rl.KeyboardKey)
		out = rl.IsKeyReleased(k) || (paranoid_drag && !rl.IsKeyDown(k))
	case rl.MouseButton:
		b:=d.button.(rl.MouseButton)
		out = rl.IsMouseButtonReleased(b) || (paranoid_drag && !rl.IsMouseButtonDown(b))
	}
	d.active &= !out
	return out
}

DrawDirection :: enum {
	TOP_LEFT, TOP, TOP_RIGHT,
	LEFT, CENTER, RIGHT,
	BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT,
}

tool_slot_size :: f32(48)

direction_offset :: proc(d: DrawDirection) -> Vec2 {
	table := [DrawDirection]Vec2{
		.TOP_LEFT    = {-1, -1},
		.TOP         = { 0, -1},
		.TOP_RIGHT   = { 1, -1},
		.LEFT        = {-1,  0},
		.CENTER      = { 0,  0},
		.RIGHT       = { 1,  0},
		.BOTTOM_LEFT = {-1,  1},
		.BOTTOM      = { 0,  1},
		.BOTTOM_RIGHT= { 1,  1},
	}
	return table[d]
}

// Whether something has been clicked this frame
// Used to prevent clicking on multiple things at once
// Has to be reset every frame
click_claimed:bool

// NOTE: always check this last, don't claim the click without using it
try_claim_click ::proc() -> bool {
	// TODO maybe handle Pressed() while we're at it
	defer click_claimed = true
	return !click_claimed
}

is_box_hovered :: proc(start:Vec2, end:Vec2, cursor:Vec2) -> bool {
	lo := Vec2{min(start.x, end.x), min(start.y, end.y)}
	hi := Vec2{max(start.x, end.x), max(start.y, end.y)}
	return cursor.x > lo.x && cursor.y > lo.y && cursor.x < hi.x && cursor.y < hi.y
}

is_box_clicked :: proc(start:Vec2, end:Vec2, cursor:Vec2) -> bool {
	return is_box_hovered(start, end, cursor) && rl.IsMouseButtonPressed(.LEFT) && try_claim_click()
}
get_number_pressed ::proc() -> int {
	for key, i in ([]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE, .ZERO}) {
		if rl.IsKeyPressed(key) do return i
	}
	return -1
}
box_geo ::proc(start:Vec2, end:Vec2) -> (center:Vec2, size:Vec2) {
	center = (start + end) / 2
	size = end - start // this is signed and idk if that's a good thing
	return
}

// use as is or as an example
draw_tool_basic :: proc(start:Vec2, end:Vec2, idx:int, cursor:Vec2, scale_hint:f32=1.0) -> bool {
	brightness:f32= 1.0
	if is_box_hovered(start, end, cursor) {
		brightness = 1.8
	}
	draw_box(start, end, scale_hint, .PRIMARY, brightness)
	_, size: = box_geo(start, end)
	x, y := vec_ints(start + size/10)
	rl.DrawText(rl.TextFormat("%i", idx+1), x, y, 10, modulate(.PRIMARY))
	return is_box_clicked(start, end, cursor) || get_number_pressed() == idx
}

draw_button :: proc(pos: Vec2, size: Vec2, rot: f32, cursor: Vec2, text: cstring = "", scale_hint: f32 = 1.0, col: ThemeColor = .PRIMARY, brightness: f32 = 1.0) -> bool {
	start := pos - size / 2
	end := pos + size / 2
	b := brightness
	if is_box_hovered(start, end, cursor) {
		b *= 1.8
	}
	draw_rect(pos, size, rot, scale_hint, col, b)
	font_size: i32 = 20
	text_w := rl.MeasureText(text, font_size)
	rl.DrawText(text, i32(pos.x) - text_w / 2, i32(pos.y) - font_size / 2, font_size, modulate(col, b))
	return is_box_clicked(start, end, cursor)
}

draw_toolbar :: proc(
		start: Vec2, anchor: DrawDirection, list_direction: DrawDirection, count: int,
		draw_tool: proc(start: Vec2, end: Vec2, idx: int, cursor: Vec2, scale_hint: f32 = 1.0) -> bool = draw_tool_basic) -> int {
	slot := min(tool_slot_size, f32(rl.GetScreenHeight())/8, f32(rl.GetScreenWidth())/8)
	gap: f32 = 18.0
	list_dir  := direction_offset(list_direction)
	anchor_dir := direction_offset(anchor)

	// Total bounding box of the toolbar along each axis.
	// Grows in the list direction; stays one slot wide on the perpendicular axis.
	span := f32(count) * (slot + gap) - gap
	bbox_size := Vec2{
		span if list_dir.x != 0 else slot,
		span if list_dir.y != 0 else slot,
	}

	// Map the anchor point to the top-left corner of the bounding box.
	// anchor_dir in [-1,1]: (dir+1)/2 gives 0..1 as fraction across the bbox.
	bbox_topleft := start - (anchor_dir + {1, 1}) / 2 * bbox_size

	// When the list runs in a negative direction, slot 0 starts at the far end.
	slot_0 := bbox_topleft
	if list_dir.x < 0 do slot_0.x = bbox_topleft.x + bbox_size.x - slot
	if list_dir.y < 0 do slot_0.y = bbox_topleft.y + bbox_size.y - slot

	step := list_dir * (slot + gap)
	selected_tool := -1
	for i in 0 ..< count {
		s := slot_0 + step * f32(i)
		if draw_tool(s, s + slot, i, rl.GetMousePosition()) do selected_tool = i
	}
	return selected_tool
}

