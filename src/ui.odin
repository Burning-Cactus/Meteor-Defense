package game

import rl "vendor:raylib"

Drag :: struct{
	button:union {rl.KeyboardKey, rl.MouseButton},
	start, end: Vec2,
	active: bool,
}

drag_started ::proc(d:^Drag) -> bool {
	out:bool
	switch _ in d.button {
	case rl.KeyboardKey:
		k:=d.button.(rl.KeyboardKey)
		out = rl.IsKeyPressed(k) || (!d.active && rl.IsKeyDown(k))
	case rl.MouseButton:
		b:=d.button.(rl.MouseButton)
		out = rl.IsMouseButtonPressed(b) || (!d.active && rl.IsMouseButtonDown(b))
	}
	d.active |= out
	return out
}

drag_ended ::proc(d:^Drag) -> bool {
	out:bool
	switch _ in d.button {
	case rl.KeyboardKey:
		k:=d.button.(rl.KeyboardKey)
		out = rl.IsKeyReleased(k) || (d.active && !rl.IsKeyDown(k))
	case rl.MouseButton:
		b:=d.button.(rl.MouseButton)
		out = rl.IsMouseButtonReleased(b) || (d.active && !rl.IsMouseButtonDown(b))
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

draw_toolbar :: proc(
		start: Vec2, anchor: DrawDirection, list_direction: DrawDirection, count:int,
		draw_tool:proc(start:Vec2, end:Vec2, idx:int, cursor:Vec2, scale_hint:f32=1.0) -> bool=draw_tool_basic) -> int{
	slot := tool_slot_size
	step := direction_offset(list_direction) * (slot + 18.0)
	offset := direction_offset(anchor) * -tool_slot_size
	// TODO complete direction handling isn't done
	selected_tool := -1
	for i in 0..<count {
		slot_start := start + step * f32(i)
		slot_end := slot_start + offset
		if draw_tool(slot_start, slot_end, i, rl.GetMousePosition()) do selected_tool = i
	}
	return selected_tool // the "correct" way to do this is with `return selected_tool, ok`
}

