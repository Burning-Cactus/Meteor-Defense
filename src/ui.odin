package game

import rl "vendor:raylib"
import "core:strings"

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

UITool :: struct {
	title: string,
	icon:  Drawable,
	use:   proc(),
}

select_tool :: proc(tools: []UITool) -> int {
	keys := [9]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE}
	for i in 0..<min(len(tools), 9) {
		if rl.IsKeyPressed(keys[i]) do return i
	}
	return -1
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

draw_tools :: proc(tools: []UITool, start: Vec2, icon_direction: DrawDirection, list_direction: DrawDirection) {
	slot := tool_slot_size
	step := direction_offset(list_direction) * slot
	//icon_anchor := (direction_offset(icon_direction) + {1, 1}) * 0.5 * slot
	rgb := theme[.PRIMARY]
	col := rl.Color{rgb.r, rgb.g, rgb.b, 255}

	for tool, i in tools {
		slot_pos := start + step * f32(i)

		rl.DrawRectangleLinesEx({slot_pos.x, slot_pos.y, slot, slot}, 2, col)
		rl.DrawText(rl.TextFormat("%i", i32(i + 1)), i32(slot_pos.x + 2), i32(slot_pos.y + 2), 10, col)

		if tool.icon != nil {
			if ds, ok := tool.icon.(Drawshape); ok {
				scaled := ds
				scaled.start = slot_pos + ds.start * slot
				scaled.end   = slot_pos + ds.end   * slot
				draw_shape(scaled)
			}
		}
		if len(tool.title) > 0 {
			title := strings.clone_to_cstring(tool.title, context.temp_allocator)
			rl.DrawText(title, i32(slot_pos.x), i32(slot_pos.y + slot + 2), 8, col)
		}
	}
}

